systemInfoUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = "主机选择", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        selectInput(ns("host_selector"), "选择主机查看系统信息",
                    choices = c("请选择主机" = ""),
                    selected = "")
      )
    ),
    
    fluidRow(
      box(
        title = "系统基本信息", status = "primary", solidHeader = TRUE,
        width = 6, collapsible = TRUE,
        
        uiOutput(ns("basic_system_info"))
      ),
      
      box(
        title = "硬件信息", status = "primary", solidHeader = TRUE,
        width = 6, collapsible = TRUE,
        
        uiOutput(ns("hardware_info"))
      )
    ),
    
    fluidRow(
      box(
        title = "网络信息", status = "primary", solidHeader = TRUE,
        width = 6, collapsible = TRUE,
        
        uiOutput(ns("network_info"))
      ),
      
      box(
        title = "操作系统信息", status = "primary", solidHeader = TRUE,
        width = 6, collapsible = TRUE,
        
        uiOutput(ns("os_info"))
      )
    ),
    
    fluidRow(
      box(
        title = "已安装软件", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        DT::dataTableOutput(ns("installed_software"))
      )
    ),
    
    fluidRow(
      box(
        title = "系统服务", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        DT::dataTableOutput(ns("system_services"))
      )
    ),
    
    fluidRow(
      box(
        title = "磁盘信息", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        DT::dataTableOutput(ns("disk_info"))
      )
    ),
    
    fluidRow(
      box(
        title = "系统日志", status = "primary", solidHeader = TRUE,
        width = 12, collapsible = TRUE,
        
        fluidRow(
          column(4,
                 selectInput(ns("log_type"), "日志类型",
                             choices = c(
                               "系统日志" = "System",
                               "应用程序日志" = "Application",
                               "安全日志" = "Security"
                             ),
                             selected = "System")
          ),
          column(4,
                 numericInput(ns("log_entries"), "显示条数",
                              value = 50, min = 10, max = 500)
          ),
          column(4,
                 actionButton(ns("refresh_logs"), "刷新日志", 
                              icon = icon("sync"), class = "btn-info")
          )
        ),
        
        DT::dataTableOutput(ns("system_logs"))
      )
    )
  )
}

systemInfoServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    observe({
      hosts <- get_all_hosts()
      host_choices <- c("请选择主机" = "")
      if (nrow(hosts) > 0) {
        host_choices <- c(host_choices, setNames(hosts$hostname, hosts$id))
      }
      updateSelectInput(session, "host_selector", choices = host_choices)
    })
    
    system_data <- reactive({
      host_id <- input$host_selector
      
      if (is.null(host_id) || host_id == "") {
        return(NULL)
      }
      
      data <- get_system_info_by_host_id(as.integer(host_id))
      
      if (nrow(data) == 0) {
        return(NULL)
      }
      
      return(data)
    })
    
    output$basic_system_info <- renderUI({
      data <- system_data()
      
      if (is.null(data)) {
        return(div(style = "padding: 20px; text-align: center; color: #6c757d;", 
                   "请选择主机查看系统信息"))
      }
      
      info <- jsonlite::fromJSON(data$info_json)
      
      tagList(
        div(
          style = "display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px;",
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("主机名: "), info$hostname
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("域名: "), info$domain
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("位置: "), info$location
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("部门: "), info$department
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("最后检查时间: "), data$last_check
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("更新时间: "), data$updated_at
          )
        )
      )
    })
    
    output$hardware_info <- renderUI({
      data <- system_data()
      
      if (is.null(data)) {
        return(div(style = "padding: 20px; text-align: center; color: #6c757d;", 
                   "请选择主机查看硬件信息"))
      }
      
      info <- jsonlite::fromJSON(data$info_json)
      
      tagList(
        div(
          style = "display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px;",
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("CPU: "), info$cpu
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("内存: "), info$memory
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("制造商: "), info$manufacturer
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("型号: "), info$model
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("序列号: "), info$serial_number
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("BIOS版本: "), info$bios_version
          )
        )
      )
    })
    
    output$network_info <- renderUI({
      data <- system_data()
      
      if (is.null(data)) {
        return(div(style = "padding: 20px; text-align: center; color: #6c757d;", 
                   "请选择主机查看网络信息"))
      }
      
      info <- jsonlite::fromJSON(data$info_json)
      
      tagList(
        div(
          style = "display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px;",
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("IP地址: "), info$ip_address
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("子网掩码: "), info$subnet_mask
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("默认网关: "), info$default_gateway
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("DNS服务器: "), paste(info$dns_servers, collapse = ", ")
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("MAC地址: "), info$mac_address
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("网络适配器: "), info$network_adapter
          )
        )
      )
    })
    
    output$os_info <- renderUI({
      data <- system_data()
      
      if (is.null(data)) {
        return(div(style = "padding: 20px; text-align: center; color: #6c757d;", 
                   "请选择主机查看操作系统信息"))
      }
      
      info <- jsonlite::fromJSON(data$info_json)
      
      tagList(
        div(
          style = "display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px;",
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("操作系统: "), info$os_name
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("版本: "), info$os_version
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("架构: "), info$os_architecture
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("安装日期: "), info$install_date
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("上次启动: "), info$last_boot_time
          ),
          
          div(
            style = "padding: 10px; background: #f8f9fa; border-radius: 5px;",
            strong("PowerShell版本: "), info$pwsh_version
          )
        )
      )
    })
    
    output$installed_software <- DT::renderDataTable({
      data <- system_data()
      
      if (is.null(data)) {
        return(data.frame(提示 = "请选择主机查看已安装软件"))
      }
      
      info <- jsonlite::fromJSON(data$info_json)
      software <- info$installed_software
      
      if (is.null(software) || length(software) == 0) {
        return(data.frame(提示 = "暂无软件信息"))
      }
      
      software_df <- do.call(rbind, lapply(software, function(x) {
        data.frame(
          名称 = x$name,
          版本 = x$version,
          发布商 = x$publisher,
          安装日期 = x$install_date,
          stringsAsFactors = FALSE
        )
      }))
      
      DT::datatable(software_df, 
                   selection = 'none',
                   options = list(
                     pageLength = 20,
                     scrollX = TRUE
                   ),
                   rownames = FALSE)
    })
    
    output$system_services <- DT::renderDataTable({
      data <- system_data()
      
      if (is.null(data)) {
        return(data.frame(提示 = "请选择主机查看系统服务"))
      }
      
      info <- jsonlite::fromJSON(data$info_json)
      services <- info$services
      
      if (is.null(services) || length(services) == 0) {
        return(data.frame(提示 = "暂无服务信息"))
      }
      
      services_df <- do.call(rbind, lapply(services, function(x) {
        data.frame(
          名称 = x$name,
          显示名称 = x$display_name,
          状态 = x$status,
          启动类型 = x$start_type,
          stringsAsFactors = FALSE
        )
      }))
      
      services_df$状态 <- sapply(services_df$状态, function(x) {
        if (x == "Running") {
          get_status_badge("Success")
        } else {
          get_status_badge("Failed")
        }
      })
      
      DT::datatable(services_df, 
                   selection = 'none',
                   options = list(
                     pageLength = 20,
                     scrollX = TRUE
                   ),
                   escape = FALSE,
                   rownames = FALSE)
    })
    
    output$disk_info <- DT::renderDataTable({
      data <- system_data()
      
      if (is.null(data)) {
        return(data.frame(提示 = "请选择主机查看磁盘信息"))
      }
      
      info <- jsonlite::fromJSON(data$info_json)
      disks <- info$disks
      
      if (is.null(disks) || length(disks) == 0) {
        return(data.frame(提示 = "暂无磁盘信息"))
      }
      
      disks_df <- do.call(rbind, lapply(disks, function(x) {
        data.frame(
          驱动器 = x$drive,
          文件系统 = x$filesystem,
          总容量 = x$total_size,
          已用空间 = x$used_space,
          可用空间 = x$free_space,
          使用率 = paste0(x$usage_percentage, "%"),
          stringsAsFactors = FALSE
        )
      }))
      
      DT::datatable(disks_df, 
                   selection = 'none',
                   options = list(
                     pageLength = 10,
                     scrollX = TRUE
                   ),
                   rownames = FALSE)
    })
    
    system_logs <- reactive({
      data <- system_data()
      
      if (is.null(data)) {
        return(data.frame())
      }
      
      info <- jsonlite::fromJSON(data$info_json)
      logs <- info$logs
      
      if (is.null(logs) || length(logs) == 0) {
        return(data.frame())
      }
      
      logs_df <- do.call(rbind, lapply(logs, function(x) {
        data.frame(
          时间 = x$time,
          类型 = x$type,
          来源 = x$source,
          事件ID = x$event_id,
          消息 = substr(x$message, 1, 200),
          stringsAsFactors = FALSE
        )
      }))
      
      return(logs_df)
    })
    
    output$system_logs <- DT::renderDataTable({
      logs <- system_logs()
      
      if (nrow(logs) == 0) {
        return(data.frame(提示 = "请选择主机查看系统日志"))
      }
      
      log_type <- input$log_type
      entries <- input$log_entries
      
      filtered_logs <- logs[logs$类型 == log_type, ]
      
      if (nrow(filtered_logs) > entries) {
        filtered_logs <- head(filtered_logs, entries)
      }
      
      DT::datatable(filtered_logs, 
                   selection = 'none',
                   options = list(
                     pageLength = 20,
                     scrollX = TRUE,
                     order = list(list(1, 'desc'))
                   ),
                   rownames = FALSE)
    })
    
    observeEvent(input$refresh_logs, {
      session$reload()
    })
  })
}