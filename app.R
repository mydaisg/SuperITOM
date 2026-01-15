library(shiny)
library(shinydashboard)

ui <- dashboardPage(
  dashboardHeader(title = "ITOM 管理控制台"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Git提交", tabName = "git_commit", icon = icon("upload")),
      menuItem("脚本管理", tabName = "script_management", icon = icon("code")),
      menuItem("系统信息", tabName = "system_info", icon = icon("server")),
      menuItem("操作记录", tabName = "operation_history", icon = icon("history")),
      menuItem("设置", tabName = "settings", icon = icon("cog"))
    )
  ),
  
  dashboardBody(
    tabItems(
      tabItem(tabName = "git_commit",
        fluidRow(
          box(
            title = "Git 提交配置",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            
            fluidRow(
              column(6,
                textInput("git_commit_message", "提交信息:", 
                          value = paste0("Auto commit: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
                          placeholder = "输入提交信息")
              ),
              column(6,
                textInput("git_branch", "分支:", 
                          value = "main",
                          placeholder = "输入分支名称")
              )
            ),
            
            fluidRow(
              column(6,
                checkboxInput("git_force", "强制推送", value = FALSE)
              ),
              column(6,
                actionButton("git_commit", "执行Git提交", 
                           icon = icon("upload"),
                           class = "btn-primary btn-lg",
                           style = "width: 100%;")
              )
            )
          )
        ),
        
        fluidRow(
          box(
            title = "执行过程和结果",
            status = "info",
            solidHeader = TRUE,
            width = 12,
            verbatimTextOutput("git_output", placeholder = TRUE)
          )
        )
      ),
      
      tabItem(tabName = "script_management",
        fluidRow(
          box(
            title = "脚本管理",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            h4("脚本管理功能开发中...")
          )
        )
      ),
      
      tabItem(tabName = "system_info",
        fluidRow(
          box(
            title = "系统信息",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            h4("系统信息功能开发中...")
          )
        )
      ),
      
      tabItem(tabName = "operation_history",
        fluidRow(
          box(
            title = "操作记录",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            h4("操作记录功能开发中...")
          )
        )
      ),
      
      tabItem(tabName = "settings",
        fluidRow(
          box(
            title = "应用设置",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            textInput("script_path", "脚本路径:", 
                      value = "D:/GitHub/SuperITOM/scripts/windows/git_auto_commit.ps1"),
            textInput("log_dir", "日志目录:", 
                      value = "D:/GitHub/SuperITOM/logs"),
            actionButton("save_settings", "保存设置", 
                       icon = icon("save"),
                       class = "btn-primary"),
            br(), br(),
            verbatimTextOutput("settings_output")
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  git_output <- reactiveVal("")
  
  observeEvent(input$git_commit, {
    script_path <- input$script_path
    commit_message <- input$git_commit_message
    branch <- input$git_branch
    force <- input$git_force
    log_dir <- input$log_dir
    
    if (!file.exists(script_path)) {
      git_output("错误: 脚本文件不存在")
      showNotification("脚本文件不存在", type = "error")
      return()
    }
    
    cmd_parts <- c("pwsh", sprintf("-File \"%s\"", script_path))
    
    if (!is.null(commit_message) && commit_message != "") {
      cmd_parts <- c(cmd_parts, sprintf("-CommitMessage \"%s\"", commit_message))
    }
    
    if (!is.null(branch) && branch != "") {
      cmd_parts <- c(cmd_parts, sprintf("-Branch \"%s\"", branch))
    }
    
    if (force) {
      cmd_parts <- c(cmd_parts, "-Force")
    }
    
    cmd <- paste(cmd_parts, collapse = " ")
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    log_file <- paste0(log_dir, "/git_commit_", timestamp, ".log")
    
    if (!dir.exists(log_dir)) {
      dir.create(log_dir, recursive = TRUE)
    }
    
    log_content <- c(
      paste("执行时间:", Sys.time()),
      paste("命令:", cmd),
      "",
      "执行过程和结果:",
      paste(rep("=", 50), collapse = "")
    )
    
    writeLines(log_content, log_file)
    
    output_lines <- c(log_content, "")
    
    tryCatch({
      result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
      result_text <- paste(result, collapse = "\n")
      
      output_lines <- c(output_lines, result_text, "", paste(rep("=", 50), collapse = ""), "执行完成！")
      
      cat(result_text, "\n", paste(rep("=", 50), collapse = ""), "\n执行完成！\n", file = log_file, append = TRUE)
      
      git_output(paste(output_lines, collapse = "\n"))
      
      showNotification(paste("日志已保存:", log_file), type = "message")
      
    }, error = function(e) {
      error_lines <- c("", paste("错误:", e$message), "", paste(rep("=", 50), collapse = ""), "执行失败！")
      
      output_lines <- c(output_lines, error_lines)
      
      cat("\n", paste("错误:", e$message), "\n", paste(rep("=", 50), collapse = ""), "\n执行失败！\n", file = log_file, append = TRUE)
      
      git_output(paste(output_lines, collapse = "\n"))
      
      showNotification("执行失败", type = "error")
    })
  })
  
  observeEvent(input$save_settings, {
    output$settings_output <- renderText({
      paste("设置已保存:\n",
             "脚本路径:", input$script_path, "\n",
             "日志目录:", input$log_dir)
    })
    showNotification("设置已保存", type = "message")
  })
  
  output$git_output <- renderText({
    git_output()
  })
}

shinyApp(ui, server)
