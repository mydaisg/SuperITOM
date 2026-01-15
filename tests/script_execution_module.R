scriptExecutionUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = "脚本执行", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        fluidRow(
          column(6,
                 selectInput(ns("execution_mode"), "执行模式",
                             choices = c(
                               "选择预定义脚本" = "predefined",
                               "自定义PowerShell脚本" = "custom"
                             ),
                             selected = "predefined")
          ),
          column(6,
                 selectInput(ns("target_host"), "目标主机",
                             choices = c("全部主机" = "All"),
                             selected = "All")
          )
        ),
        
        conditionalPanel(
          condition = sprintf("input['%s'] == 'predefined'", ns("execution_mode")),
          ns = ns,
          selectInput(ns("predefined_script"), "选择脚本",
                      choices = c(
                        "安装PowerShell 7" = "0_pwsh7.ps1",
                        "配置WinRM" = "0_winrm.ps1",
                        "收集主机信息" = "1_hostinfo.ps1",
                        "重命名主机" = "2_rename_host.ps1",
                        "加入域" = "3_JoinDomain_LVCC.ps1",
                        "配置本地管理员" = "4_LocalAdmin.ps1",
                        "部署工具" = "5_deploy_tools.ps1",
                        "Linux部署" = "6_linux_deploy.ps1",
                        "健康检查" = "7_HealthCheck.ps1"
                      ),
                      selected = "1_hostinfo.ps1")
        ),
        
        conditionalPanel(
          condition = sprintf("input['%s'] == 'custom'", ns("execution_mode")),
          ns = ns,
          textAreaInput(ns("custom_script"), "自定义PowerShell脚本",
                        placeholder = "在此输入PowerShell脚本代码...",
                        height = "300px")
        ),
        
        div(
          style = "margin-top: 15px; margin-bottom: 15px;",
          textInput(ns("script_parameters"), "脚本参数（可选）", 
                    placeholder = "例如: -Force -Verbose")
        ),
        
        div(
          style = "margin-top: 15px; margin-bottom: 15px;",
          fluidRow(
            column(6,
                   actionButton(ns("execute_script"), "执行脚本", 
                                icon = icon("play"), class = "btn-success btn-lg",
                                style = "width: 100%;")
            ),
            column(6,
                   actionButton(ns("clear_output"), "清空输出", 
                                icon = icon("eraser"), class = "btn-secondary btn-lg",
                                style = "width: 100%;")
            )
          )
        )
      )
    ),
    
    fluidRow(
      box(
        title = "执行结果", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        div(
          style = "margin-bottom: 15px;",
          uiOutput(ns("execution_status"))
        ),
        
        verbatimTextOutput(ns("script_output"), placeholder = TRUE)
      )
    ),
    
    fluidRow(
      box(
        title = "执行历史", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        DT::dataTableOutput(ns("execution_history"))
      )
    )
  )
}

scriptExecutionServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    observe({
      hosts <- get_all_hosts()
      host_choices <- c("全部主机" = "All")
      if (nrow(hosts) > 0) {
        host_choices <- c(host_choices, setNames(hosts$hostname, hosts$id))
      }
      updateSelectInput(session, "target_host", choices = host_choices)
    })
    
    execution_history <- reactiveVal(data.frame())
    execution_log <- reactiveVal(character())
    
    observeEvent(input$execute_script, {
      target_host <- input$target_host
      execution_mode <- input$execution_mode
      
      if (target_host == "All") {
        showNotification("请选择单个主机执行脚本", type = "warning")
        return()
      }
      
      host_info <- get_host_by_id(as.integer(target_host))
      
      if (nrow(host_info) == 0) {
        showNotification("主机信息不存在", type = "error")
        return()
      }
      
      hostname <- host_info$hostname
      ip_address <- host_info$ip_address
      
      execution_log(c(
        paste0("开始执行脚本"),
        paste0("目标主机: ", hostname, " (", ip_address, ")"),
        paste0("执行模式: ", execution_mode),
        paste0("开始时间: ", Sys.time()),
        "----------------------------------------"
      ))
      
      script_path <- NULL
      script_content <- NULL
      script_name <- NULL
      operation_type <- "Custom_Script"
      
      if (execution_mode == "predefined") {
        script_name <- input$predefined_script
        script_path <- file.path(scripts_path, script_name)
        
        if (!file.exists(script_path)) {
          showNotification(sprintf("脚本文件不存在: %s", script_path), type = "error")
          execution_log(c(
            paste0("错误: 脚本文件不存在"),
            paste0("路径: ", script_path)
          ))
          return()
        }
        
        script_info <- available_scripts[[which(sapply(available_scripts, function(x) x$script == script_name))]]
        if (!is.null(script_info)) {
          operation_type <- script_info$operation_type
        }
      } else {
        script_content <- input$custom_script
        
        if (is.null(script_content) || script_content == "") {
          showNotification("请输入自定义脚本", type = "warning")
          return()
        }
        
        script_name <- "custom_script.ps1"
      }
      
      parameters <- input$script_parameters
      
      execution_log(c(
        paste0("脚本名称: ", script_name),
        paste0("操作类型: ", operation_type),
        paste0("参数: ", ifelse(is.null(parameters) || parameters == "", "无", parameters))
      ))
      
      start_time <- Sys.time()
      
      operation_id <- create_operation(
        host_id = as.integer(target_host),
        operation_type = operation_type,
        script_name = script_name,
        status = "Running",
        created_by = session$userData$user$id
      )
      
      result <- NULL
      
      if (execution_mode == "predefined") {
        result <- execute_powershell_script(script_path, hostname, list())
      } else {
        temp_script <- tempfile(fileext = ".ps1")
        writeLines(script_content, temp_script)
        
        result <- execute_powershell_script(temp_script, hostname, list())
        
        unlink(temp_script)
      }
      
      end_time <- Sys.time()
      duration <- as.numeric(difftime(end_time, start_time, units = "secs"))
      
      if (result$success) {
        update_operation_status(operation_id, "Success", end_time, duration, result$output, NULL)
        
        execution_log(c(
          paste0("执行成功"),
          paste0("结束时间: ", end_time),
          paste0("耗时: ", round(duration, 2), " 秒"),
          paste0("输出: ", substr(result$output, 1, 500))
        ))
        
        showNotification("脚本执行成功", type = "message")
      } else {
        update_operation_status(operation_id, "Failed", end_time, duration, NULL, result$error)
        
        execution_log(c(
          paste0("执行失败"),
          paste0("结束时间: ", end_time),
          paste0("耗时: ", round(duration, 2), " 秒"),
          paste0("错误: ", result$error)
        ))
        
        showNotification("脚本执行失败", type = "error")
      }
      
      new_history <- data.frame(
        hostname = hostname,
        ip_address = ip_address,
        script_name = script_name,
        execution_mode = execution_mode,
        status = ifelse(result$success, "Success", "Failed"),
        start_time = as.character(start_time),
        end_time = as.character(end_time),
        duration = round(duration, 2),
        stringsAsFactors = FALSE
      )
      
      current_history <- execution_history()
      execution_history(rbind(new_history, current_history))
    })
    
    observeEvent(input$clear_output, {
      execution_log(character())
    })
    
    output$execution_status <- renderUI({
      log <- execution_log()
      
      if (length(log) == 0) {
        return(NULL)
      }
      
      last_line <- log[length(log)]
      
      if (grepl("执行成功", last_line)) {
        div(
          style = "padding: 10px; background: #d4edda; color: #155724; border-radius: 5px; margin-bottom: 10px;",
          icon("check-circle"), " ", last_line
        )
      } else if (grepl("执行失败|错误", last_line)) {
        div(
          style = "padding: 10px; background: #f8d7da; color: #721c24; border-radius: 5px; margin-bottom: 10px;",
          icon("times-circle"), " ", last_line
        )
      } else {
        div(
          style = "padding: 10px; background: #e2e3e5; color: #383d41; border-radius: 5px; margin-bottom: 10px;",
          icon("info-circle"), " ", last_line
        )
      }
    })
    
    output$script_output <- renderPrint({
      log <- execution_log()
      if (length(log) > 0) {
        cat(log, sep = "\n")
      } else {
        cat("暂无输出")
      }
    })
    
    output$execution_history <- DT::renderDataTable({
      history <- execution_history()
      
      if (nrow(history) == 0) {
        return(data.frame(提示 = "暂无执行历史"))
      }
      
      history$status <- sapply(history$status, function(x) {
        get_status_badge(x)
      })
      
      DT::datatable(history, 
                   selection = 'none',
                   options = list(
                     pageLength = 10,
                     scrollX = TRUE,
                     order = list(list(6, 'desc'))
                   ),
                   escape = FALSE)
    })
  })
}