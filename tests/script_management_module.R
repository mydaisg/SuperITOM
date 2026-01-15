library(shiny)
library(shinydashboard)
library(shinyWidgets)

scriptManagementUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    fluidRow(
      box(
        title = "脚本管理",
        status = "primary",
        solidHeader = TRUE,
        width = 12,
        
        fluidRow(
          column(
            width = 4,
            wellPanel(
              h4("脚本选择"),
              selectInput(
                ns("script_category"),
                "脚本类别:",
                choices = c(
                  "客户端准备" = "client_prep",
                  "配置管理" = "config_mgmt",
                  "工具部署" = "tools_deploy",
                  "系统维护" = "system_maint"
                ),
                selected = "client_prep"
              ),
              
              conditionalPanel(
                condition = sprintf("input['%s'] == 'client_prep'", ns("script_category")),
                selectInput(
                  ns("client_prep_script"),
                  "选择脚本:",
                  choices = c(
                    "部署PowerShell 7" = "0_pwsh7.ps1",
                    "配置WinRM" = "0_winrm.ps1",
                    "收集主机信息" = "1_hostinfo.ps1",
                    "部署DML" = "2_deploy_dml.ps1",
                    "重命名主机" = "2_rename_host.ps1",
                    "加入域" = "3_JoinDomain_LVCC.ps1",
                    "配置本地管理员" = "4_LocalAdmin.ps1",
                    "部署工具" = "5_deploy_tools.ps1",
                    "Linux部署" = "6_linux_deploy.ps1",
                    "健康检查" = "7_HealthCheck.ps1"
                  ),
                  selected = "0_pwsh7.ps1"
                )
              ),
              
              conditionalPanel(
                condition = sprintf("input['%s'] == 'config_mgmt'", ns("script_category")),
                selectInput(
                  ns("config_mgmt_script"),
                  "选择脚本:",
                  choices = c(
                    "本地目录配置" = "0_localdir.ps1",
                    "主控脚本" = "0_master.ps1"
                  ),
                  selected = "0_localdir.ps1"
                )
              ),
              
              conditionalPanel(
                condition = sprintf("input['%s'] == 'tools_deploy'", ns("script_category")),
                selectInput(
                  ns("tools_deploy_script"),
                  "选择脚本:",
                  choices = c(
                    "部署工具" = "5_deploy_tools.ps1"
                  ),
                  selected = "5_deploy_tools.ps1"
                )
              ),
              
              conditionalPanel(
                condition = sprintf("input['%s'] == 'system_maint'", ns("script_category")),
                selectInput(
                  ns("system_maint_script"),
                  "选择脚本:",
                  choices = c(
                    "修复所有损坏" = "fix_all_corrupted.ps1",
                    "测试所有" = "test_all.ps1"
                  ),
                  selected = "fix_all_corrupted.ps1"
                )
              ),
              
              hr(),
              
              h4("脚本参数"),
              textInput(
                ns("script_params"),
                "配置文件路径:",
                value = "D:\\GitHub\\SuperITOM\\config\\config.json",
                placeholder = "输入配置文件路径"
              ),
              
              textAreaInput(
                ns("additional_params"),
                "额外参数:",
                value = "",
                placeholder = "输入其他参数（每行一个）",
                rows = 3
              ),
              
              hr(),
              
              h4("执行选项"),
              checkboxInput(
                ns("dry_run"),
                "试运行（不实际执行）:",
                value = FALSE
              ),
              
              checkboxInput(
                ns("verbose"),
                "详细输出:",
                value = TRUE
              ),
              
              hr(),
              
              actionButton(
                ns("execute_script"),
                "执行脚本",
                icon = icon("play"),
                class = "btn-success",
                style = "width: 100%;"
              )
            )
          ),
          
          column(
            width = 8,
            wellPanel(
              h4("执行结果"),
              div(
                style = "background-color: #f8f9fa; padding: 15px; border-radius: 5px; min-height: 400px; max-height: 600px; overflow-y: auto;",
                verbatimTextOutput(ns("script_output"))
              )
            )
          )
        )
      )
    )
  )
}

scriptManagementServer <- function(id, session = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    script_output <- reactiveVal("")
    
    getScriptPath <- function() {
      category <- input$script_category
      
      switch(category,
        "client_prep" = paste0("D:/GitHub/SuperITOM/scripts/windows/", input$client_prep_script),
        "config_mgmt" = paste0("D:/GitHub/SuperITOM/scripts/windows/", input$config_mgmt_script),
        "tools_deploy" = paste0("D:/GitHub/SuperITOM/scripts/windows/", input$tools_deploy_script),
        "system_maint" = paste0("D:/GitHub/SuperITOM/scripts/windows/", input$system_maint_script),
        ""
      )
    }
    
    observeEvent(input$execute_script, {
      script_path <- getScriptPath()
      config_path <- input$script_params
      additional_params <- input$additional_params
      dry_run <- input$dry_run
      verbose <- input$verbose
      
      if (!file.exists(script_path)) {
        script_output(paste("错误: 脚本文件不存在:", script_path))
        showNotification("脚本文件不存在", type = "error")
        return()
      }
      
      if (!file.exists(config_path)) {
        script_output(paste("警告: 配置文件不存在:", config_path))
      }
      
      cmd_parts <- c("pwsh", sprintf("-File \"%s\"", script_path))
      
      if (!is.null(config_path) && config_path != "") {
        cmd_parts <- c(cmd_parts, sprintf("-ConfigPath \"%s\"", config_path))
      }
      
      if (dry_run) {
        cmd_parts <- c(cmd_parts, "-DryRun")
      }
      
      if (!verbose) {
        cmd_parts <- c(cmd_parts, "-Quiet")
      }
      
      cmd <- paste(cmd_parts, collapse = " ")
      
      script_output(paste("执行命令:", cmd, "\n"))
      script_output(paste("开始执行脚本...\n", rep("=", 50), "\n", sep = ""))
      
      tryCatch({
        result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
        script_output(paste(result, collapse = "\n"))
        script_output(paste("\n", rep("=", 50), "\n", "脚本执行完成！", sep = ""))
        showNotification("脚本执行完成", type = "message")
      }, error = function(e) {
        script_output(paste("\n错误:", e$message))
        showNotification("脚本执行失败", type = "error")
      })
    })
    
    output$script_output <- renderPrint({
      script_output()
    })
  })
}
