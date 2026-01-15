hostStatusUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = "主机状态概览", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        fluidRow(
          column(3,
                 valueBox(
                   textOutput(ns("total_hosts")),
                   "总主机数",
                   icon = icon("server"),
                   color = "blue"
                 )
          ),
          column(3,
                 valueBox(
                   textOutput(ns("success_hosts")),
                   "成功主机",
                   icon = icon("check-circle"),
                   color = "green"
                 )
          ),
          column(3,
                 valueBox(
                   textOutput(ns("failed_hosts")),
                   "失败主机",
                   icon = icon("times-circle"),
                   color = "red"
                 )
          ),
          column(3,
                 valueBox(
                   textOutput(ns("success_rate")),
                   "成功率",
                   icon = icon("chart-pie"),
                   color = "purple"
                 )
          )
        )
      )
    ),
    
    fluidRow(
      box(
        title = "主机状态表", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        div(
          style = "margin-bottom: 15px;",
          fluidRow(
            column(4,
                   selectInput(ns("location_filter"), "位置过滤",
                               choices = c("全部" = "All", "TEST" = "TEST", "OPS" = "OPS", "IT" = "IT"),
                               selected = "All")
            ),
            column(4,
                   selectInput(ns("status_filter"), "状态过滤",
                               choices = c("全部" = "All", "Success" = "Success", "Failed" = "Failed", "Unknown" = "Unknown"),
                               selected = "All")
            ),
            column(4,
                   actionButton(ns("refresh_data"), "刷新数据", 
                                icon = icon("sync"), class = "btn-info")
            )
          )
        ),
        
        DT::dataTableOutput(ns("host_status_table"))
      )
    ),
    
    fluidRow(
      box(
        title = "主机状态分布", status = "primary", solidHeader = TRUE,
        width = 6, collapsible = TRUE,
        
        plotly::plotlyOutput(ns("status_pie_chart"))
      ),
      
      box(
        title = "位置分布", status = "primary", solidHeader = TRUE,
        width = 6, collapsible = TRUE,
        
        plotly::plotlyOutput(ns("location_bar_chart"))
      )
    ),
    
    fluidRow(
      box(
        title = "配置完成度", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        plotly::plotlyOutput(ns("configuration_radar_chart"))
      )
    )
  )
}

hostStatusServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    host_data <- reactive({
      req(input$location_filter, input$status_filter)
      
      data <- get_all_host_status()
      
      if (input$location_filter != "All") {
        data <- data[data$location == input$location_filter, ]
      }
      
      if (input$status_filter != "All") {
        data <- data[data$host_status == input$status_filter, ]
      }
      
      return(data)
    })
    
    host_stats <- reactive({
      data <- host_data()
      
      total <- nrow(data)
      success <- sum(data$host_status == "Success", na.rm = TRUE)
      failed <- sum(data$host_status == "Failed", na.rm = TRUE)
      unknown <- sum(data$host_status == "Unknown", na.rm = TRUE)
      
      success_rate <- ifelse(total > 0, round(success / total * 100, 2), 0)
      
      list(
        total = total,
        success = success,
        failed = failed,
        unknown = unknown,
        success_rate = success_rate
      )
    })
    
    output$total_hosts <- renderText({
      host_stats()$total
    })
    
    output$success_hosts <- renderText({
      host_stats()$success
    })
    
    output$failed_hosts <- renderText({
      host_stats()$failed
    })
    
    output$success_rate <- renderText({
      paste0(host_stats()$success_rate, "%")
    })
    
    output$host_status_table <- DT::renderDataTable({
      data <- host_data()
      
      if (nrow(data) == 0) {
        return(data.frame(提示 = "没有符合条件的数据"))
      }
      
      data$ps7_installed <- ifelse(data$ps7_installed == 1, "是", "否")
      data$winrm_enabled <- ifelse(data$winrm_enabled == 1, "是", "否")
      data$domain_joined <- ifelse(data$domain_joined == 1, "是", "否")
      data$local_admin_configured <- ifelse(data$local_admin_configured == 1, "是", "否")
      data$tools_deployed <- ifelse(data$tools_deployed == 1, "是", "否")
      data$health_check_passed <- ifelse(data$health_check_passed == 1, "是", "否")
      
      data$host_status <- sapply(data$host_status, function(x) {
        get_status_badge(x)
      })
      
      DT::datatable(data, 
                   selection = 'single',
                   extensions = 'Buttons',
                   options = list(
                     dom = 'Bfrtip',
                     buttons = c('copy', 'csv', 'excel', 'pdf'),
                     pageLength = 15,
                     scrollX = TRUE
                   ),
                   escape = FALSE)
    })
    
    output$status_pie_chart <- plotly::renderPlotly({
      stats <- host_stats()
      
      if (stats$total == 0) {
        return(plotly::plot_ly(type = "pie") %>% 
                 add_trace(values = c(1), labels = c("无数据"), marker = list(colors = "#cccccc")))
      }
      
      pie_df <- data.frame(
        status = c("成功", "失败", "未知"),
        values = c(stats$success, stats$failed, stats$unknown),
        colors = c("#28a745", "#dc3545", "#6c757d")
      )
      
      plotly::plot_ly(
        data = pie_df,
        labels = ~status,
        values = ~values,
        type = "pie",
        marker = list(colors = ~colors)
      ) %>%
        plotly::layout(title = "主机状态分布")
    })
    
    output$location_bar_chart <- plotly::renderPlotly({
      data <- host_data()
      
      if (nrow(data) == 0) {
        return(plotly::plot_ly(type = "bar") %>% 
                 add_trace(x = c("无数据"), y = c(1), marker = list(color = "#cccccc")))
      }
      
      location_counts <- table(data$location)
      location_df <- data.frame(
        location = names(location_counts),
        count = as.numeric(location_counts)
      )
      
      plotly::plot_ly(
        data = location_df,
        x = ~location,
        y = ~count,
        type = "bar",
        marker = list(color = "#007bff")
      ) %>%
        plotly::layout(title = "主机位置分布",
                       xaxis = list(title = "位置"),
                       yaxis = list(title = "主机数量"))
    })
    
    output$configuration_radar_chart <- plotly::renderPlotly({
      data <- host_data()
      
      if (nrow(data) == 0) {
        return(plotly::plot_ly(type = "scatterpolar", mode = "markers") %>% 
                 add_trace(r = c(0), theta = c("无数据"), type = "scatterpolar"))
      }
      
      config_stats <- list(
        "PowerShell 7" = sum(data$ps7_installed == 1, na.rm = TRUE),
        "WinRM" = sum(data$winrm_enabled == 1, na.rm = TRUE),
        "域加入" = sum(data$domain_joined == 1, na.rm = TRUE),
        "本地管理员" = sum(data$local_admin_configured == 1, na.rm = TRUE),
        "工具部署" = sum(data$tools_deployed == 1, na.rm = TRUE),
        "健康检查" = sum(data$health_check_passed == 1, na.rm = TRUE)
      )
      
      plotly::plot_ly(
        type = 'scatterpolar',
        mode = 'lines+markers',
        r = unlist(config_stats),
        theta = names(config_stats),
        fill = 'toself'
      ) %>%
        plotly::layout(
          polar = list(
            radialaxis = list(
              visible = TRUE,
              range = c(0, max(unlist(config_stats)))
            )
          ),
          title = "配置完成度"
        )
    })
    
    observeEvent(input$refresh_data, {
      session$reload()
    })
  })
}