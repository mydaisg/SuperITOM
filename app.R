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
        menuItem("LocalDir", tabName = "script_management", icon = icon("folder-plus")),
        menuItem("FirstWin", tabName = "firstwin", icon = icon("desktop")),
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
              title = "LocalDir - 本地工作目录创建",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              
              fluidRow(
                column(6,
                  textInput("config_path", "配置文件路径:", 
                            value = "D:/GitHub/SuperITOM/config/config.json",
                            placeholder = "输入配置文件路径")
                ),
                column(6,
                  textInput("local_dir", "本地工作目录:", 
                            value = "D:/LVCC_LOCAL_DML",
                            placeholder = "输入本地工作目录路径")
                )
              ),
              
              fluidRow(
                column(6,
                  checkboxInput("force_create", "强制重新创建", value = FALSE)
                ),
                column(6,
                  actionButton("localdir_create", "创建本地目录", 
                             icon = icon("folder-plus"),
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
              verbatimTextOutput("localdir_output")
            )
          )
        ),
        
        tabItem(tabName = "firstwin",
          fluidRow(
            box(
              title = "FirstWin - 远程Windows客户端管理",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              
              fluidRow(
                column(6,
                  textInput("hosts_file", "主机列表文件:", 
                            value = "D:/GitHub/SuperITOM/config/hosts_new.csv",
                            placeholder = "输入主机列表文件路径")
                ),
                column(6,
                  textInput("target_ip", "目标IP:", 
                            value = "",
                            placeholder = "输入目标IP（单机模式）")
                )
              ),
              
              fluidRow(
                column(4,
                  textInput("target_user", "用户名:", 
                            value = "",
                            placeholder = "输入用户名（单机模式）")
                ),
                column(4,
                  passwordInput("target_password", "密码:", 
                              value = "",
                              placeholder = "输入密码（单机模式）")
                ),
                column(4,
                  textInput("new_computer_name", "新计算机名:", 
                            value = "",
                            placeholder = "输入新计算机名（可选）")
                )
              ),
              
              fluidRow(
                column(6,
                  textInput("tools_path", "工具路径:", 
                            value = "D:/GitHub/SuperITOM/tools",
                            placeholder = "输入本地工具路径")
                ),
                column(6,
                  checkboxInput("batch_mode", "批量模式（使用主机列表）", value = TRUE)
                )
              ),
              
              fluidRow(
                column(6,
                  actionButton("firstwin_test", "测试连接", 
                             icon = icon("plug"),
                             class = "btn-info btn-lg",
                             style = "width: 100%;")
                ),
                column(6,
                  actionButton("firstwin_execute", "执行管理", 
                             icon = icon("cogs"),
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
              verbatimTextOutput("firstwin_output")
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
  localdir_output_val <- reactiveVal("")
  firstwin_output_val <- reactiveVal("")
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
  
  output$localdir_output <- renderPrint({
    cat(localdir_output_val())
  })
  
  observeEvent(input$localdir_create, {
    script_path <- input$script_path
    config_path <- input$config_path
    local_dir <- input$local_dir
    force <- input$force_create
    log_dir <- input$log_dir
    
    localdir_script_path <- "D:/GitHub/SuperITOM/scripts/windows/0_localdir.ps1"
    
    if (!file.exists(localdir_script_path)) {
      localdir_output_val("错误: LocalDir脚本文件不存在")
      showNotification("LocalDir脚本文件不存在", type = "error")
      return()
    }
    
    if (!file.exists(config_path)) {
      localdir_output_val("错误: 配置文件不存在")
      showNotification("配置文件不存在", type = "error")
      return()
    }
    
    cmd_parts <- c("pwsh", sprintf("-File \"%s\"", localdir_script_path))
    cmd_parts <- c(cmd_parts, sprintf("-ConfigPath \"%s\"", config_path))
    
    cmd <- paste(cmd_parts, collapse = " ")
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    log_file <- paste0(log_dir, "/localdir_", timestamp, ".log")
    
    if (!dir.exists(log_dir)) {
      dir.create(log_dir, recursive = TRUE)
    }
    
    log_content <- c(
      paste("执行时间:", Sys.time()),
      paste("命令:", cmd),
      paste("配置文件:", config_path),
      paste("本地工作目录:", local_dir),
      paste("强制重新创建:", ifelse(force, "是", "否")),
      "",
      "执行过程和结果:",
      paste(rep("=", 50), collapse = "")
    )
    
    writeLines(log_content, log_file)
    
    localdir_output_val(paste(log_content, collapse = "\n"))
    
    tryCatch({
      result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
      result_text <- paste(result, collapse = "\n")
      
      final_output <- paste(
        localdir_output_val(),
        result_text,
        "",
        paste(rep("=", 50), collapse = ""),
        "执行完成！",
        sep = "\n"
      )
      
      localdir_output_val(final_output)
      
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
        localdir_output_val(),
        paste("错误:", e$message),
        "",
        paste(rep("=", 50), collapse = ""),
        "执行失败！",
        sep = "\n"
      )
      
      localdir_output_val(final_output)
      
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
  
  output$firstwin_output <- renderPrint({
    cat(firstwin_output_val())
  })
  
  observeEvent(input$firstwin_test, {
    hosts_file <- input$hosts_file
    target_ip <- input$target_ip
    target_user <- input$target_user
    target_password <- input$target_password
    batch_mode <- input$batch_mode
    log_dir <- input$log_dir
    
    test_script_path <- "D:/GitHub/SuperITOM/scripts/common/0_Remote_WT_TEST.ps1"
    
    if (!file.exists(test_script_path)) {
      firstwin_output_val("错误: 测试脚本文件不存在")
      showNotification("测试脚本文件不存在", type = "error")
      return()
    }
    
    if (batch_mode && !file.exists(hosts_file)) {
      firstwin_output_val("错误: 主机列表文件不存在")
      showNotification("主机列表文件不存在", type = "error")
      return()
    }
    
    if (!batch_mode && (is.null(target_ip) || target_ip == "")) {
      firstwin_output_val("错误: 单机模式下需要输入目标IP")
      showNotification("单机模式下需要输入目标IP", type = "error")
      return()
    }
    
    cmd_parts <- c("pwsh", sprintf("-File \"%s\"", test_script_path))
    
    if (batch_mode) {
      cmd_parts <- c(cmd_parts, sprintf("-HostsFile \"%s\"", hosts_file))
    } else {
      cmd_parts <- c(cmd_parts, sprintf("-TargetIP \"%s\"", target_ip))
      cmd_parts <- c(cmd_parts, sprintf("-TargetUser \"%s\"", target_user))
      cmd_parts <- c(cmd_parts, sprintf("-TargetPassword \"%s\"", target_password))
    }
    
    cmd <- paste(cmd_parts, collapse = " ")
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    log_file <- paste0(log_dir, "/firstwin_test_", timestamp, ".log")
    
    if (!dir.exists(log_dir)) {
      dir.create(log_dir, recursive = TRUE)
    }
    
    log_content <- c(
      paste("执行时间:", Sys.time()),
      paste("命令:", cmd),
      paste("模式:", ifelse(batch_mode, "批量模式", "单机模式")),
      "",
      "执行过程和结果:",
      paste(rep("=", 50), collapse = "")
    )
    
    writeLines(log_content, log_file)
    
    firstwin_output_val(paste(log_content, collapse = "\n"))
    
    tryCatch({
      result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
      result_text <- paste(result, collapse = "\n")
      
      final_output <- paste(
        firstwin_output_val(),
        result_text,
        "",
        paste(rep("=", 50), collapse = ""),
        "测试完成！",
        sep = "\n"
      )
      
      firstwin_output_val(final_output)
      
      append_content <- c(
        "",
        result_text,
        "",
        paste(rep("=", 50), collapse = ""),
        "测试完成！"
      )
      
      cat(paste(append_content, collapse = "\n"), file = log_file, append = TRUE, sep = "\n")
      
      showNotification(paste("日志已保存:", log_file), type = "message")
      
    }, error = function(e) {
      final_output <- paste(
        firstwin_output_val(),
        paste("错误:", e$message),
        "",
        paste(rep("=", 50), collapse = ""),
        "测试失败！",
        sep = "\n"
      )
      
      firstwin_output_val(final_output)
      
      error_content <- c(
        "",
        paste("错误:", e$message),
        "",
        paste(rep("=", 50), collapse = ""),
        "测试失败！"
      )
      
      cat(paste(error_content, collapse = "\n"), file = log_file, append = TRUE, sep = "\n")
      
      showNotification("测试失败", type = "error")
    })
  })
  
  observeEvent(input$firstwin_execute, {
    hosts_file <- input$hosts_file
    target_ip <- input$target_ip
    target_user <- input$target_user
    target_password <- input$target_password
    new_computer_name <- input$new_computer_name
    tools_path <- input$tools_path
    batch_mode <- input$batch_mode
    log_dir <- input$log_dir
    
    main_script_path <- "D:/GitHub/SuperITOM/scripts/common/0_Remote_WT.ps1"
    
    if (!file.exists(main_script_path)) {
      firstwin_output_val("错误: 主脚本文件不存在")
      showNotification("主脚本文件不存在", type = "error")
      return()
    }
    
    if (batch_mode && !file.exists(hosts_file)) {
      firstwin_output_val("错误: 主机列表文件不存在")
      showNotification("主机列表文件不存在", type = "error")
      return()
    }
    
    if (!batch_mode && (is.null(target_ip) || target_ip == "")) {
      firstwin_output_val("错误: 单机模式下需要输入目标IP")
      showNotification("单机模式下需要输入目标IP", type = "error")
      return()
    }
    
    cmd_parts <- c("pwsh", sprintf("-File \"%s\"", main_script_path))
    
    if (batch_mode) {
      cmd_parts <- c(cmd_parts, sprintf("-HostsFile \"%s\"", hosts_file))
    } else {
      cmd_parts <- c(cmd_parts, sprintf("-TargetIP \"%s\"", target_ip))
      cmd_parts <- c(cmd_parts, sprintf("-TargetUser \"%s\"", target_user))
      cmd_parts <- c(cmd_parts, sprintf("-TargetPassword \"%s\"", target_password))
    }
    
    if (!is.null(new_computer_name) && new_computer_name != "") {
      cmd_parts <- c(cmd_parts, sprintf("-NewComputerName \"%s\"", new_computer_name))
    }
    
    cmd_parts <- c(cmd_parts, sprintf("-ToolsPath \"%s\"", tools_path))
    
    cmd <- paste(cmd_parts, collapse = " ")
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    log_file <- paste0(log_dir, "/firstwin_execute_", timestamp, ".log")
    
    if (!dir.exists(log_dir)) {
      dir.create(log_dir, recursive = TRUE)
    }
    
    log_content <- c(
      paste("执行时间:", Sys.time()),
      paste("命令:", cmd),
      paste("模式:", ifelse(batch_mode, "批量模式", "单机模式")),
      paste("新计算机名:", ifelse(is.null(new_computer_name) || new_computer_name == "", "不修改", new_computer_name)),
      paste("工具路径:", tools_path),
      "",
      "执行过程和结果:",
      paste(rep("=", 50), collapse = "")
    )
    
    writeLines(log_content, log_file)
    
    firstwin_output_val(paste(log_content, collapse = "\n"))
    
    tryCatch({
      result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
      result_text <- paste(result, collapse = "\n")
      
      final_output <- paste(
        firstwin_output_val(),
        result_text,
        "",
        paste(rep("=", 50), collapse = ""),
        "执行完成！",
        sep = "\n"
      )
      
      firstwin_output_val(final_output)
      
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
        firstwin_output_val(),
        paste("错误:", e$message),
        "",
        paste(rep("=", 50), collapse = ""),
        "执行失败！",
        sep = "\n"
      )
      
      firstwin_output_val(final_output)
      
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
