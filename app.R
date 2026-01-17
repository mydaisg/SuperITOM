library(shiny)
library(shinydashboard)
library(DBI)
library(RSQLite)
library(DT)

source("db/read_db.r")
source("db/write_db.r")

db_path <- "D:\\GitHub\\SuperITOM\\db\\GH_ITOM.db"

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
    tags$div(
      style = "text-align: center;",
      titlePanel("ITOM 管理控制台", windowTitle = "ITOM 管理控制台")
    ),
    
    mainPanel(
      width = 12,
      fluidRow(
        column(4, offset = 4,
          wellPanel(
            h3("管理员登录", align = "center"),
            br(),
            textInput("username", "用户名:", placeholder = "admin"),
            passwordInput("password", "密码:", placeholder = "admin123"),
            br(), br(),
            actionButton("login", "登录", 
                       icon = icon("sign-in-alt"),
                       class = "btn-primary btn-lg",
                       style = "width: 100%;"),
            br(), br(),
            textOutput("login_message")
          )
        )
      )
    )
  )
}

dashboard_ui <- function(user = NULL) {
  scripts_dir <- "D:/GitHub/SuperITOM/scripts/windows"
  script_files <- list.files(scripts_dir, pattern = "\\.ps1$", full.names = FALSE)
  script_choices <- c("请选择脚本...", script_files)
  
  is_admin <- !is.null(user) && user$role == "admin"
  
  dashboardPage(
    dashboardHeader(title = "ITOM", titleWidth = 100),
    
    dashboardSidebar(
      sidebarMenu(
        menuItem("Git提交", tabName = "git_commit", icon = icon("upload")),
        menuItem("LocalDir", tabName = "script_management", icon = icon("folder-plus")),
        menuItem("FirstWin", tabName = "firstwin", icon = icon("desktop")),
        menuItem("系统信息", tabName = "system_info", icon = icon("server")),
        menuItem("操作记录", tabName = "operation_history", icon = icon("history")),
        if (is_admin) {
          menuItem("授权管理", tabName = "user_management", icon = icon("users"))
        },
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
                            value = "D:\\GitHub\\SuperITOM\\config\\config.json",
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
                column(9,
                  DT::dataTableOutput("hosts_table", width = "100%")
                ),
                column(3,
                  actionButton("load_hosts", "加载主机列表", 
                             icon = icon("refresh"),
                             class = "btn-info")
                )
              ),
              
              hr(),
              
              fluidRow(
                column(3,
                  textInput("target_ip", "目标IP:", 
                            value = "",
                            placeholder = "输入目标IP")
                ),
                column(2,
                  textInput("target_user", "用户名:", 
                            value = "",
                            placeholder = "用户名")
                ),
                column(2,
                  passwordInput("target_password", "密码:", 
                              value = "",
                              placeholder = "密码")
                ),
                column(2,
                  textInput("new_computer_name", "新计算机名:", 
                            value = "",
                            placeholder = "新计算机名（可选）")
                ),
                column(3,
                  div(
                    style = "padding-top: 25px;",
                    actionButton("firstwin_test", "测试连接", 
                               icon = icon("plug"),
                               class = "btn-info")
                  )
                )
              )
            )
          ),
          
          fluidRow(
            box(
              status = "info",
              solidHeader = FALSE,
              width = 12,
              verbatimTextOutput("firstwin_output")
            )
          ),
          
          fluidRow(
            box(
              title = "远程脚本执行",
              status = "primary",
              solidHeader = TRUE,
              width = 12,
              
              fluidRow(
                column(10,
                  selectInput("remote_script", "远程脚本清单:", 
                             choices = script_choices,
                             selected = "请选择脚本...")
                ),
                column(2,
                  actionButton("execute_remote_script", "执行脚本", 
                             icon = icon("play"),
                             class = "btn-success")
                )
              )
            )
          ),
          
          fluidRow(
            box(
              title = "脚本执行过程和结果",
              status = "info",
              solidHeader = TRUE,
              width = 12,
              verbatimTextOutput("script_output")
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
        
        tabItem(tabName = "user_management",
          fluidRow(
            box(
              title = "创建用户",
              status = "primary",
              solidHeader = TRUE,
              width = 6,
              
              textInput("new_username", "用户名:", placeholder = "输入用户名"),
              passwordInput("new_password", "密码:", placeholder = "输入密码"),
              passwordInput("new_password_confirm", "确认密码:", placeholder = "再次输入密码"),
              textInput("new_email", "邮箱:", placeholder = "输入邮箱地址"),
              selectInput("new_role", "角色:", choices = c("user" = "user", "admin" = "admin"), selected = "user"),
              br(), br(),
              actionButton("create_user", "创建用户", 
                         icon = icon("user-plus"),
                         class = "btn-success"),
              br(), br(),
              textOutput("create_user_message")
            )
          ),
          
          fluidRow(
            box(
              title = "用户列表",
              status = "info",
              solidHeader = TRUE,
              width = 12,
              DT::dataTableOutput("users_table")
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
                        value = "D:\\GitHub\\SuperITOM\\scripts\\windows\\git_auto_commit.ps1",
                        placeholder = "输入脚本路径"),
              textInput("log_dir", "日志目录:", 
                        value = "D:\\GitHub\\SuperITOM\\logs",
                        placeholder = "输入日志目录"),
              br(), br(),
              fluidRow(
                column(6,
                  actionButton("save_settings", "保存设置", 
                             icon = icon("save"),
                             class = "btn-primary")
                ),
                column(6,
                  actionButton("logout", "退出", 
                             icon = icon("sign-out-alt"),
                             class = "btn-default")
                )
              ),
              br(), br(),
              verbatimTextOutput("settings_output")
            )
          )
        )
      )
    )
  )
}

ui <- uiOutput("app_ui")

server <- function(input, output, session) {
  logged_in <- reactiveVal(FALSE)
  current_user <- reactiveVal(NULL)
  login_message_val <- reactiveVal("")
  git_output_val <- reactiveVal("")
  localdir_output_val <- reactiveVal("")
  firstwin_output_val <- reactiveVal("")
  script_output_val <- reactiveVal("")
  settings_output_val <- reactiveVal("")
  
  hosts_data <- reactiveVal(data.frame(
    IPAddress = character(),
    User = character(),
    Password = character(),
    stringsAsFactors = FALSE
  ))
  
  output$app_ui <- renderUI({
    if (logged_in()) {
      dashboard_ui(current_user())
    } else {
      login_ui()
    }
  })
  
  output$login_message <- renderText({
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
    
    login_message_val(paste("登录成功！欢迎,", user$username))
    showNotification(paste("欢迎,", user$username), type = "message")
  })
  
  observeEvent(input$logout, {
    logged_in(FALSE)
    current_user(NULL)
    login_message_val("")
    
    updateTextInput(session, "username", value = "")
    updateTextInput(session, "password", value = "")
    
    showNotification("已退出登录", type = "message")
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
    
    localdir_script_path <- "D:\\GitHub\\SuperITOM\\scripts\\windows\\0_localdir.ps1"
    
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
  
  output$hosts_table <- DT::renderDataTable({
    DT::datatable(
      hosts_data(),
      selection = 'single',
      editable = TRUE,
      options = list(
        paging = FALSE,
        searching = FALSE,
        ordering = TRUE,
        info = FALSE
      ),
      rownames = FALSE
    )
  })
  
  observeEvent(input$load_hosts, {
    hosts_file <- "D:\\GitHub\\SuperITOM\\config\\hosts_new.csv"
    
    if (!file.exists(hosts_file)) {
      showNotification("主机列表文件不存在", type = "error")
      return()
    }
    
    tryCatch({
      hosts <- read.csv(hosts_file, stringsAsFactors = FALSE, header = TRUE, 
                    sep = ",", quote = "\"", na.strings = "")
      
      if (nrow(hosts) == 0) {
        showNotification("主机列表文件为空", type = "warning")
        return()
      }
      
      hosts_data(hosts)
      showNotification(sprintf("成功加载 %d 台主机", nrow(hosts)), type = "message")
      
    }, error = function(e) {
      showNotification(paste("加载主机列表失败:", e$message), type = "error")
    })
  })
  
  observeEvent(input$hosts_table_rows_selected, {
    selected_row <- input$hosts_table_rows_selected
    
    if (length(selected_row) > 0 && nrow(hosts_data()) >= selected_row) {
      host <- hosts_data()[selected_row, ]
      
      updateTextInput(session, "target_ip", value = host$IPAddress)
      updateTextInput(session, "target_user", value = host$User)
      updateTextInput(session, "target_password", value = host$Password)
      
      showNotification(sprintf("已选择主机: %s", host$IPAddress), type = "message")
    }
  })
  
  observeEvent(input$firstwin_test, {
    target_ip <- input$target_ip
    target_user <- input$target_user
    target_password <- input$target_password
    log_dir <- input$log_dir
    
    test_script_path <- "D:/GitHub/SuperITOM/scripts/common/0_Remote_WT_TEST.ps1"
    
    if (!file.exists(test_script_path)) {
      firstwin_output_val("错误: 测试脚本文件不存在")
      showNotification("测试脚本文件不存在", type = "error")
      return()
    }
    
    if (is.null(target_ip) || target_ip == "") {
      firstwin_output_val("错误: 需要输入目标IP")
      showNotification("需要输入目标IP", type = "error")
      return()
    }
    
    if (is.null(target_user) || target_user == "") {
      firstwin_output_val("错误: 需要输入用户名")
      showNotification("需要输入用户名", type = "error")
      return()
    }
    
    if (is.null(target_password) || target_password == "") {
      firstwin_output_val("错误: 需要输入密码")
      showNotification("需要输入密码", type = "error")
      return()
    }
    
    cmd_parts <- c("pwsh", sprintf("-File \"%s\"", test_script_path))
    cmd_parts <- c(cmd_parts, sprintf("-TargetIP \"%s\"", target_ip))
    cmd_parts <- c(cmd_parts, sprintf("-TargetUser \"%s\"", target_user))
    cmd_parts <- c(cmd_parts, sprintf("-TargetPassword \"%s\"", target_password))
    
    cmd <- paste(cmd_parts, collapse = " ")
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    log_file <- paste0(log_dir, "/firstwin_test_", timestamp, ".log")
    
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
  
  output$settings_output <- renderPrint({
    settings_output_val()
  })
  
  observeEvent(input$save_settings, {
    settings_output_val(paste("设置已保存:", Sys.time()))
    showNotification("设置已保存", type = "message")
  })
  
  output$script_output <- renderPrint({
    script_output_val()
  })
  
  observeEvent(input$execute_remote_script, {
    target_ip <- input$target_ip
    target_user <- input$target_user
    target_password <- input$target_password
    selected_script <- input$remote_script
    log_dir <- input$log_dir
    
    if (is.null(selected_script) || selected_script == "请选择脚本...") {
      script_output_val("错误: 请选择要执行的脚本")
      showNotification("请选择要执行的脚本", type = "error")
      return()
    }
    
    if (is.null(target_ip) || target_ip == "") {
      script_output_val("错误: 需要输入目标IP")
      showNotification("需要输入目标IP", type = "error")
      return()
    }
    
    if (is.null(target_user) || target_user == "") {
      script_output_val("错误: 需要输入用户名")
      showNotification("需要输入用户名", type = "error")
      return()
    }
    
    if (is.null(target_password) || target_password == "") {
      script_output_val("错误: 需要输入密码")
      showNotification("需要输入密码", type = "error")
      return()
    }
    
    script_path <- paste0("D:/GitHub/SuperITOM/scripts/windows/", selected_script)
    
    if (!file.exists(script_path)) {
      script_output_val("错误: 脚本文件不存在")
      showNotification("脚本文件不存在", type = "error")
      return()
    }
    
    cmd_parts <- c("pwsh", sprintf("-File \"%s\"", script_path))
    cmd_parts <- c(cmd_parts, sprintf("-TargetIP \"%s\"", target_ip))
    cmd_parts <- c(cmd_parts, sprintf("-TargetUser \"%s\"", target_user))
    cmd_parts <- c(cmd_parts, sprintf("-TargetPassword \"%s\"", target_password))
    
    cmd <- paste(cmd_parts, collapse = " ")
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    log_file <- paste0(log_dir, "/remote_script_", timestamp, ".log")
    
    if (!dir.exists(log_dir)) {
      dir.create(log_dir, recursive = TRUE)
    }
    
    log_content <- c(
      paste("执行时间:", Sys.time()),
      paste("命令:", cmd),
      "",
      "执行过程和结果:",
      "=================================================="
    )
    
    writeLines(log_content, log_file)
    
    script_output_val(paste(log_content, collapse = "\n"))
    
    tryCatch({
      result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
      
      cat(result, file = log_file, append = TRUE, sep = "\n")
      
      output_text <- paste(result, collapse = "\n")
      script_output_val(paste(script_output_val(), output_text, sep = "\n"))
      
      cat("\n==================================================\n", file = log_file, append = TRUE)
      cat("执行完成！\n", file = log_file, append = TRUE)
      
      script_output_val(paste(script_output_val(), "\n==================================================\n执行完成！"))
      
      showNotification("脚本执行完成", type = "message")
      
    }, error = function(e) {
      error_msg <- paste("执行失败:", e$message)
      cat(error_msg, file = log_file, append = TRUE, sep = "\n")
      script_output_val(paste(script_output_val(), error_msg, sep = "\n"))
      showNotification("执行失败", type = "error")
    })
  })
  
  users_data <- reactiveVal(data.frame())
  
  observe({
    req(current_user())
    if (current_user()$role == "admin") {
      users_data(get_all_users())
    }
  })
  
  output$users_table <- DT::renderDataTable({
    DT::datatable(
      users_data(),
      selection = 'single',
      editable = FALSE,
      options = list(
        paging = TRUE,
        searching = TRUE,
        ordering = TRUE,
        info = TRUE,
        pageLength = 10
      ),
      rownames = FALSE,
      colnames = c("ID", "用户名", "邮箱", "角色", "状态", "创建时间", "最后登录"),
      filter = 'top'
    ) %>%
      DT::formatStyle('is_active', 
        target = 'row',
        backgroundColor = DT::styleEqual(c(0, 1), c('#ffebee', '#e8f5e9')))
  })
  
  output$create_user_message <- renderText({
    create_user_message_val()
  })
  
  create_user_message_val <- reactiveVal("")
  
  observeEvent(input$create_user, {
    username <- input$new_username
    password <- input$new_password
    password_confirm <- input$new_password_confirm
    email <- input$new_email
    role <- input$new_role
    
    if (is.null(username) || username == "") {
      create_user_message_val("错误: 用户名不能为空")
      showNotification("用户名不能为空", type = "error")
      return()
    }
    
    if (is.null(password) || password == "") {
      create_user_message_val("错误: 密码不能为空")
      showNotification("密码不能为空", type = "error")
      return()
    }
    
    if (password != password_confirm) {
      create_user_message_val("错误: 两次输入的密码不一致")
      showNotification("两次输入的密码不一致", type = "error")
      return()
    }
    
    existing_user <- get_user_by_username(username)
    if (nrow(existing_user) > 0) {
      create_user_message_val("错误: 用户名已存在")
      showNotification("用户名已存在", type = "error")
      return()
    }
    
    tryCatch({
      create_user(username, password, email, role)
      create_user_message_val("成功: 用户创建成功")
      showNotification("用户创建成功", type = "message")
      users_data(get_all_users())
      
      updateTextInput(session, "new_username", value = "")
      updateTextInput(session, "new_password", value = "")
      updateTextInput(session, "new_password_confirm", value = "")
      updateTextInput(session, "new_email", value = "")
      
    }, error = function(e) {
      create_user_message_val(paste("错误:", e$message))
      showNotification(paste("创建用户失败:", e$message), type = "error")
    })
  })
}

shinyApp(ui = ui, server = server, options = list(port = 9000))
