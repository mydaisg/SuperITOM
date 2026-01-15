batchOperationsUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = "批量操作", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        fluidRow(
          column(6,
                 selectInput(ns("operation_type"), "选择操作类型",
                             choices = c(
                               "安装PowerShell 7" = "PowerShell_Installation",
                               "配置WinRM" = "WinRM_Configuration",
                               "收集主机信息" = "Host_Information",
                               "重命名主机" = "Host_Renaming",
                               "加入域" = "Domain_Joining",
                               "配置本地管理员" = "Local_Admin_Configuration",
                               "部署工具" = "Tools_Deployment",
                               "Linux部署" = "Linux_Deployment",
                               "健康检查" = "Health_Check"
                             ),
                             selected = "Host_Information")
          ),
          column(3,
                 actionButton(ns("select_all_hosts"), "全选主机", 
                              icon = icon("check-double"), class = "btn-info")
          ),
          column(3,
                 actionButton(ns("deselect_all_hosts"), "取消选择", 
                              icon = icon("times"), class = "btn-warning")
          )
        ),
        
        div(
          style = "margin-top: 15px; margin-bottom: 15px;",
          DT::dataTableOutput(ns("host_selection_table"))
        ),
        
        div(
          style = "margin-top: 15px; margin-bottom: 15px;",
          fluidRow(
            column(4,
                   textInput(ns("script_parameters"), "脚本参数（可选）", 
                             placeholder = "例如: -Force -Verbose")
            ),
            column(4,
                   selectInput(ns("execution_mode"), "执行模式",
                               choices = c(
                                 "顺序执行" = "sequential",
                                 "并行执行" = "parallel"
                               ),
                               selected = "sequential")
            ),
            column(4,
                   actionButton(ns("execute_batch"), "执行批量操作", 
                                icon = icon("play"), class = "btn-success btn-lg",
                                style = "width: 100%;")
            )
          )
        )
      )
    ),
    
    fluidRow(
      box(
        title = "执行进度", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        div(
          style = "margin-bottom: 15px;",
          shinyWidgets::progressBar(ns("batch_progress"), value = 0, 
                   title = "准备执行...", 
                   striped = TRUE)
        ),
        
        div(
          style = "margin-bottom: 15px;",
          uiOutput(ns("execution_summary"))
        ),
        
        DT::dataTableOutput(ns("execution_results"))
      )
    ),
    
    fluidRow(
      box(
        title = "操作日志", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        verbatimTextOutput(ns("operation_log"))
      )
    )
  )
}

batchOperationsServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    host_data <- reactiveVal(data.frame())
    selected_hosts <- reactiveVal(character())
    execution_log <- reactiveVal(character())
    execution_results <- reactiveVal(data.frame())
    
    observe({
      host_data(get_all_hosts())
    })
    
    observeEvent(input$select_all_hosts, {
      if (nrow(host_data()) > 0) {
        selected_hosts(host_data()$id)
      }
    })
    
    observeEvent(input$deselect_all_hosts, {
      selected_hosts(character())
    })
    
    output$host_selection_table <- DT::renderDataTable({
      data <- host_data()
      
      if (nrow(data) == 0) {
        return(data.frame(提示 = "没有可用主机"))
      }
      
      DT::datatable(data, 
                   selection = 'multiple',
                   options = list(
                     pageLength = 15,
                     scrollX = TRUE
                   ),
                   rownames = FALSE) %>%
        DT::formatStyle('hostname', cursor = 'pointer')
    })
    
    observe({
      selected_rows <- input$host_selection_table_rows_selected
      if (!is.null(selected_rows) && length(selected_rows) > 0) {
        data <- host_data()
        selected_hosts(data$id[selected_rows])
      } else {
        selected_hosts(character())
      }
    })
    
    observeEvent(input$execute_batch, {
      hosts <- selected_hosts()
      
      if (length(hosts) == 0) {
        showNotification("请先选择要操作的主机", type = "error")
        return()
      }
      
      operation_type <- input$operation_type
      script_info <- available_scripts[[which(sapply(available_scripts, function(x) x$operation_type == operation_type))]]
      
      if (is.null(script_info)) {
        showNotification("未找到对应的脚本", type = "error")
        return()
      }
      
      script_path <- file.path(scripts_path, script_info$script)
      
      if (!file.exists(script_path)) {
        showNotification(sprintf("脚本文件不存在: %s", script_path), type = "error")
        return()
      }
      
      execution_mode <- input$execution_mode
      parameters <- input$script_parameters
      
      execution_log(c(
        paste0("开始执行批量操作: ", script_info$name),
        paste0("操作类型: ", operation_type),
        paste0("选中主机数量: ", length(hosts)),
        paste0("执行模式: ", execution_mode),
        paste0("脚本路径: ", script_path),
        paste0("参数: ", ifelse(is.null(parameters) || parameters == "", "无", parameters)),
        "----------------------------------------"
      ))
      
      results <- data.frame(
        host_id = integer(),
        hostname = character(),
        ip_address = character(),
        status = character(),
        start_time = character(),
        end_time = character(),
        duration = character(),
        error_message = character()
      )
      
      total_hosts <- length(hosts)
      
      for (i in seq_along(hosts)) {
        host_id <- hosts[i]
        host_info <- get_host_by_id(host_id)
        
        if (nrow(host_info) == 0) {
          results <- rbind(results, data.frame(
            host_id = host_id,
            hostname = "未知",
            ip_address = "未知",
            status = "Failed",
            start_time = Sys.time(),
            end_time = Sys.time(),
            duration = 0,
            error_message = "主机信息不存在"
          ))
          next
        }
        
        hostname <- host_info$hostname
        ip_address <- host_info$ip_address
        
        execution_log(c(
          paste0("执行主机 [", i, "/", total_hosts, "]: ", hostname, " (", ip_address, ")"),
          paste0("开始时间: ", Sys.time())
        ))
        
        start_time <- Sys.time()
        
        operation_id <- create_operation(
          host_id = host_id,
          operation_type = operation_type,
          script_name = script_info$script,
          status = "Running",
          created_by = session$userData$user$id
        )
        
        result <- execute_powershell_script(script_path, hostname, list())
        
        end_time <- Sys.time()
        duration <- as.numeric(difftime(end_time, start_time, units = "secs"))
        
        if (result$success) {
          update_operation_status(operation_id, "Success", end_time, duration, result$output, NULL)
          
          results <- rbind(results, data.frame(
            host_id = host_id,
            hostname = hostname,
            ip_address = ip_address,
            status = "Success",
            start_time = as.character(start_time),
            end_time = as.character(end_time),
            duration = round(duration, 2),
            error_message = ""
          ))
          
          execution_log(c(
            paste0("执行成功"),
            paste0("结束时间: ", end_time),
            paste0("耗时: ", round(duration, 2), " 秒"),
            paste0("输出: ", substr(result$output, 1, 200))
          ))
        } else {
          update_operation_status(operation_id, "Failed", end_time, duration, NULL, result$error)
          
          results <- rbind(results, data.frame(
            host_id = host_id,
            hostname = hostname,
            ip_address = ip_address,
            status = "Failed",
            start_time = as.character(start_time),
            end_time = as.character(end_time),
            duration = round(duration, 2),
            error_message = substr(result$error, 1, 200)
          ))
          
          execution_log(c(
            paste0("执行失败"),
            paste0("结束时间: ", end_time),
            paste0("耗时: ", round(duration, 2), " 秒"),
            paste0("错误: ", result$error)
          ))
        }
        
        updateProgress(ns("batch_progress"), i / total_hosts)
        
        if (execution_mode == "sequential") {
          Sys.sleep(1)
        }
      }
      
      execution_results(results)
      
      execution_log(c(
        "----------------------------------------",
        paste0("批量操作完成"),
        paste0("成功: ", sum(results$status == "Success")),
        paste0("失败: ", sum(results$status == "Failed")),
        paste0("总计: ", nrow(results))
      ))
      
      showNotification("批量操作执行完成", type = "message")
    })
    
    output$execution_summary <- renderUI({
      results <- execution_results()
      
      if (nrow(results) == 0) {
        return(NULL)
      }
      
      total <- nrow(results)
      success <- sum(results$status == "Success")
      failed <- sum(results$status == "Failed")
      
      div(
        style = "display: flex; justify-content: space-around; padding: 10px; background: #f8f9fa; border-radius: 5px;",
        div(
          style = "text-align: center;",
          h4(style = "margin: 0; color: #007bff;", total),
          span(style = "color: #6c757d;", "总计")
        ),
        div(
          style = "text-align: center;",
          h4(style = "margin: 0; color: #28a745;", success),
          span(style = "color: #6c757d;", "成功")
        ),
        div(
          style = "text-align: center;",
          h4(style = "margin: 0; color: #dc3545;", failed),
          span(style = "color: #6c757d;", "失败")
        )
      )
    })
    
    output$execution_results <- DT::renderDataTable({
      results <- execution_results()
      
      if (nrow(results) == 0) {
        return(data.frame(提示 = "暂无执行结果"))
      }
      
      results$status <- sapply(results$status, function(x) {
        get_status_badge(x)
      })
      
      DT::datatable(results, 
                   selection = 'none',
                   options = list(
                     pageLength = 15,
                     scrollX = TRUE
                   ),
                   escape = FALSE)
    })
    
    output$operation_log <- renderPrint({
      log <- execution_log()
      if (length(log) > 0) {
        cat(log, sep = "\n")
      } else {
        cat("暂无操作日志")
      }
    })
  })
}

updateProgress <- function(ns, value) {
  shinyWidgets::updateProgressBar(ns("batch_progress"), value = value)
}