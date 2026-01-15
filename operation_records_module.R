operationRecordsUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = "操作记录查询", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        fluidRow(
          column(3,
                 selectInput(ns("host_filter"), "主机过滤",
                             choices = c("全部" = "All"),
                             selected = "All")
          ),
          column(3,
                 selectInput(ns("operation_type_filter"), "操作类型过滤",
                             choices = c(
                               "全部" = "All",
                               "PowerShell_Installation" = "PowerShell_Installation",
                               "WinRM_Configuration" = "WinRM_Configuration",
                               "Host_Information" = "Host_Information",
                               "Host_Renaming" = "Host_Renaming",
                               "Domain_Joining" = "Domain_Joining",
                               "Local_Admin_Configuration" = "Local_Admin_Configuration",
                               "Tools_Deployment" = "Tools_Deployment",
                               "Linux_Deployment" = "Linux_Deployment",
                               "Health_Check" = "Health_Check"
                             ),
                             selected = "All")
          ),
          column(3,
                 selectInput(ns("status_filter"), "状态过滤",
                             choices = c(
                               "全部" = "All",
                               "Success" = "Success",
                               "Failed" = "Failed",
                               "Pending" = "Pending",
                               "Running" = "Running"
                             ),
                             selected = "All")
          ),
          column(3,
                 dateRangeInput(ns("date_range"), "日期范围",
                                start = Sys.Date() - 30,
                                end = Sys.Date(),
                                language = "zh")
          )
        ),
        
        div(
          style = "margin-top: 15px; margin-bottom: 15px;",
          fluidRow(
            column(6,
                   textInput(ns("search_keyword"), "关键词搜索",
                             placeholder = "搜索主机名、脚本名或错误信息...")
            ),
            column(3,
                   actionButton(ns("search_records"), "搜索记录", 
                                icon = icon("search"), class = "btn-info")
            ),
            column(3,
                   actionButton(ns("refresh_records"), "刷新", 
                                icon = icon("sync"), class = "btn-secondary")
            )
          )
        ),
        
        DT::dataTableOutput(ns("operation_records_table"))
      )
    ),
    
    fluidRow(
      box(
        title = "操作统计", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        fluidRow(
          column(3,
                 valueBox(
                   textOutput(ns("total_operations")),
                   "总操作数",
                   icon = icon("tasks"),
                   color = "blue"
                 )
          ),
          column(3,
                 valueBox(
                   textOutput(ns("success_operations")),
                   "成功操作",
                   icon = icon("check-circle"),
                   color = "green"
                 )
          ),
          column(3,
                 valueBox(
                   textOutput(ns("failed_operations")),
                   "失败操作",
                   icon = icon("times-circle"),
                   color = "red"
                 )
          ),
          column(3,
                 valueBox(
                   textOutput(ns("avg_duration")),
                   "平均耗时(秒)",
                   icon = icon("clock"),
                   color = "purple"
                 )
          )
        )
      )
    ),
    
    fluidRow(
      box(
        title = "操作趋势", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        plotly::plotlyOutput(ns("operations_trend_chart"))
      )
    ),
    
    fluidRow(
      box(
        title = "操作详情", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        uiOutput(ns("operation_details"))
      )
    )
  )
}

operationRecordsServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    observe({
      hosts <- get_all_hosts()
      host_choices <- c("全部" = "All")
      if (nrow(hosts) > 0) {
        host_choices <- c(host_choices, setNames(hosts$hostname, hosts$id))
      }
      updateSelectInput(session, "host_filter", choices = host_choices)
    })
    
    operation_data <- reactive({
      req(input$host_filter, input$operation_type_filter, input$status_filter, input$date_range)
      
      data <- get_all_operations()
      
      if (nrow(data) == 0) {
        return(data)
      }
      
      if (input$host_filter != "All") {
        data <- data[data$host_id == as.integer(input$host_filter), ]
      }
      
      if (input$operation_type_filter != "All") {
        data <- data[data$operation_type == input$operation_type_filter, ]
      }
      
      if (input$status_filter != "All") {
        data <- data[data$status == input$status_filter, ]
      }
      
      if (!is.null(input$date_range)) {
        start_date <- as.Date(input$date_range[1])
        end_date <- as.Date(input$date_range[2])
        data <- data[as.Date(data$created_at) >= start_date & as.Date(data$created_at) <= end_date, ]
      }
      
      if (!is.null(input$search_keyword) && input$search_keyword != "") {
        keyword <- tolower(input$search_keyword)
        data <- data[
          grepl(keyword, tolower(data$hostname)) |
          grepl(keyword, tolower(data$script_name)) |
          grepl(keyword, tolower(data$error_message)),
        ]
      }
      
      return(data)
    })
    
    operation_stats <- reactive({
      data <- operation_data()
      
      if (nrow(data) == 0) {
        return(list(
          total = 0,
          success = 0,
          failed = 0,
          avg_duration = 0
        ))
      }
      
      total <- nrow(data)
      success <- sum(data$status == "Success", na.rm = TRUE)
      failed <- sum(data$status == "Failed", na.rm = TRUE)
      avg_duration <- mean(data$duration_seconds, na.rm = TRUE)
      
      list(
        total = total,
        success = success,
        failed = failed,
        avg_duration = round(avg_duration, 2)
      )
    })
    
    output$total_operations <- renderText({
      operation_stats()$total
    })
    
    output$success_operations <- renderText({
      operation_stats()$success
    })
    
    output$failed_operations <- renderText({
      operation_stats()$failed
    })
    
    output$avg_duration <- renderText({
      operation_stats()$avg_duration
    })
    
    output$operation_records_table <- DT::renderDataTable({
      data <- operation_data()
      
      if (nrow(data) == 0) {
        return(data.frame(提示 = "没有符合条件的操作记录"))
      }
      
      data$status <- sapply(data$status, function(x) {
        get_status_badge(x)
      })
      
      DT::datatable(data, 
                   selection = 'single',
                   extensions = 'Buttons',
                   options = list(
                     dom = 'Bfrtip',
                     buttons = c('copy', 'csv', 'excel', 'pdf'),
                     pageLength = 20,
                     scrollX = TRUE,
                     order = list(list(7, 'desc'))
                   ),
                   escape = FALSE)
    })
    
    output$operations_trend_chart <- plotly::renderPlotly({
      data <- operation_data()
      
      if (nrow(data) == 0) {
        return(plotly::plot_ly(type = "scatter") %>% 
                 add_trace(x = c(0), y = c(0), mode = "markers", 
                          marker = list(color = "#cccccc")))
      }
      
      data$date <- as.Date(data$created_at)
      
      daily_success <- aggregate(status ~ date, data[data$status == "Success", ], length)
      daily_failed <- aggregate(status ~ date, data[data$status == "Failed", ], length)
      names(daily_success)[2] <- "success"
      names(daily_failed)[2] <- "failed"
      
      daily_stats <- merge(daily_success, daily_failed, by = "date", all = TRUE)
      daily_stats[is.na(daily_stats)] <- 0
      daily_stats$total <- daily_stats$success + daily_stats$failed
      
      plotly::plot_ly() %>%
        plotly::add_trace(
          data = daily_stats,
          x = ~date,
          y = ~success,
          type = 'scatter',
          mode = 'lines+markers',
          name = '成功',
          line = list(color = '#28a745')
        ) %>%
        plotly::add_trace(
          data = daily_stats,
          x = ~date,
          y = ~failed,
          type = 'scatter',
          mode = 'lines+markers',
          name = '失败',
          line = list(color = '#dc3545')
        ) %>%
        plotly::layout(
          title = '操作趋势',
          xaxis = list(title = '日期'),
          yaxis = list(title = '操作数量'),
          hovermode = 'x unified'
        )
    })
    
    output$operation_details <- renderUI({
      selected_row <- input$operation_records_table_rows_selected
      
      if (is.null(selected_row) || length(selected_row) == 0) {
        return(div(style = "padding: 20px; text-align: center; color: #6c757d;", 
                   "请选择一条操作记录查看详情"))
      }
      
      data <- operation_data()
      if (nrow(data) == 0 || selected_row > nrow(data)) {
        return(div(style = "padding: 20px; text-align: center; color: #6c757d;", 
                   "未找到操作记录"))
      }
      
      record <- data[selected_row, ]
      
      tagList(
        div(
          style = "display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; margin-bottom: 20px;",
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("主机名: "), record$hostname
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("IP地址: "), record$ip_address
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("操作类型: "), record$operation_type
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("脚本名称: "), record$script_name
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("状态: "), get_status_badge(record$status)
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("开始时间: "), record$start_time
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("结束时间: "), record$end_time
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("耗时: "), paste0(record$duration_seconds, " 秒")
          )
        ),
        
        if (!is.null(record$output) && record$output != "") {
          div(
            style = "margin-bottom: 20px;",
            h4("输出:"),
            pre(
              style = "background: #f8f9fa; padding: 15px; border-radius: 5px; max-height: 300px; overflow-y: auto;",
              record$output
            )
          )
        },
        
        if (!is.null(record$error_message) && record$error_message != "") {
          div(
            style = "margin-bottom: 20px;",
            h4("错误信息:"),
            pre(
              style = "background: #f8f9fa; padding: 15px; border-radius: 5px; max-height: 300px; overflow-y: auto; color: #dc3545;",
              record$error_message
            )
          )
        }
      )
    })
    
    observeEvent(input$search_records, {
      session$reload()
    })
    
    observeEvent(input$refresh_records, {
      session$reload()
    })
  })
}