library(shiny)
library(shinydashboard)
library(shinythemes)
library(DBI)
library(RSQLite)

db_path <- "D:/GitHub/SuperITOM/db/GH_ITOM.db"

get_db_connection <- function() {
  dbConnect(SQLite(), db_path)
}

get_user_by_username <- function(username) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM users WHERE username = '%s'", username)
  result <- dbGetQuery(db, query)
  
  return(result)
}

update_user_last_login <- function(user_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = %d", user_id)
  dbExecute(db, query)
  
  return(TRUE)
}

login_ui <- function() {
  fluidPage(
    theme = shinytheme("flatly"),
    titlePanel("ITOM 管理控制台 - 用户登录"),
    
    mainPanel(
      width = 12,
      fluidRow(
        column(4, offset = 4,
          wellPanel(
            h3("用户登录", align = "center"),
            br(),
            textInput("username", "用户名:", placeholder = "admin"),
            passwordInput("password", "密码:", placeholder = "admin123"),
            br(), br(),
            actionButton("login", "登录", 
                       icon = icon("sign-in-alt"),
                       class = "btn-primary btn-lg",
                       style = "width: 100%;"),
            br(), br(),
            verbatimTextOutput("login_message")
          )
        )
      )
    )
  )
}

dashboard_ui <- function() {
  dashboardPage(
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
              verbatimTextOutput("git_output")
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
              h4("脚本管理功能开发中..."),
              p("这里将提供脚本上传、编辑、执行等功能")
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
              h4("系统信息功能开发中..."),
              p("这里将显示系统配置、运行状态等信息")
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
              h4("操作记录功能开发中..."),
              p("这里将显示历史操作记录和日志")
            )
          )
        ),
        
        tabItem(tabName = "settings",
          fluidRow(
            box(
              title = "设置",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              
              textInput("script_path", "脚本路径:", 
                        value = "D:/GitHub/SuperITOM/scripts/windows/git_auto_commit.ps1",
                        placeholder = "输入脚本路径"),
              textInput("log_dir", "日志目录:", 
                        value = "D:/GitHub/SuperITOM/logs",
                        placeholder = "输入日志目录"),
              br(), br(),
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
}

ui <- fluidPage(
  uiOutput("app_ui")
)

server <- function(input, output, session) {
  logged_in <- reactiveVal(FALSE)
  current_user <- reactiveVal(NULL)
  login_message_val <- reactiveVal("")
  git_output_val <- reactiveVal("")
  settings_output_val <- reactiveVal("")
  
  output$app_ui <- renderUI({
    if (logged_in()) {
      dashboard_ui()
    } else {
      login_ui()
    }
  })
  
  output$login_message <- renderPrint({
    login_message_val()
  })
  
  observeEvent(input$login, {
    username <- input$username
    password <- input$password
    
    if (is.null(username) || username == "" || is.null(password) || password == "") {
      login_message_val("错误: 用户名和密码不能为空")
      showNotification("用户名和密码不能为空", type = "error")
      return()
    }
    
    user <- get_user_by_username(username)
    
    if (nrow(user) == 0) {
      login_message_val("错误: 用户不存在")
      showNotification("用户不存在", type = "error")
      return()
    }
    
    if (user$password != password) {
      login_message_val("错误: 密码错误")
      showNotification("密码错误", type = "error")
      return()
    }
    
    if (!user$is_active) {
      login_message_val("错误: 账户已被禁用")
      showNotification("账户已被禁用", type = "error")
      return()
    }
    
    logged_in(TRUE)
    current_user(user)
    update_user_last_login(user$id)
    
    login_message_val(paste("登录成功！欢迎,", user$display_name))
    showNotification(paste("欢迎,", user$display_name), type = "message")
  })
  
  output$git_output <- renderPrint({
    cat(git_output_val())
  })
  
  observeEvent(input$git_commit, {
    script_path <- input$script_path
    commit_message <- input$git_commit_message
    branch <- input$git_branch
    force <- input$git_force
    log_dir <- input$log_dir
    
    if (!file.exists(script_path)) {
      git_output_val("错误: 脚本文件不存在")
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
    
    git_output_val(paste(log_content, collapse = "\n"))
    
    tryCatch({
      result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
      result_text <- paste(result, collapse = "\n")
      
      final_output <- paste(
        git_output_val(),
        result_text,
        "",
        paste(rep("=", 50), collapse = ""),
        "执行完成！",
        sep = "\n"
      )
      
      git_output_val(final_output)
      
      append_content <- c(
        "",
        result_text,
        "",
        paste(rep("=", 50), collapse = ""),
        "执行完成！"
      )
      
      cat(paste(append_content, collapse = "\n"), file = log_file, append = TRUE, sep = "\n")
      
      showNotification(paste("日志已保存:", log_file), type = "message")
      
    }, error = function(e) {
      final_output <- paste(
        git_output_val(),
        paste("错误:", e$message),
        "",
        paste(rep("=", 50), collapse = ""),
        "执行失败！",
        sep = "\n"
      )
      
      git_output_val(final_output)
      
      error_content <- c(
        "",
        paste("错误:", e$message),
        "",
        paste(rep("=", 50), collapse = ""),
        "执行失败！"
      )
      
      cat(paste(error_content, collapse = "\n"), file = log_file, append = TRUE, sep = "\n")
      
      showNotification("执行失败", type = "error")
    })
  })
  
  output$settings_output <- renderPrint({
    settings_output_val()
  })
  
  observeEvent(input$save_settings, {
    settings_output_val(paste("设置已保存:", Sys.time()))
    showNotification("设置已保存", type = "message")
  })
}

shinyApp(ui = ui, server = server)
