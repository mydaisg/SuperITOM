library(shiny)
library(shinydashboard)

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        margin: 0;
        padding: 0;
      }
      .login-container {
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100vh;
      }
      .login-box {
        background: white;
        padding: 40px;
        border-radius: 10px;
        box-shadow: 0 10px 25px rgba(0,0,0,0.1);
        width: 400px;
      }
    "))
  ),
  uiOutput("app_ui")
)

server <- function(input, output, session) {
  
  vals <- reactiveValues(logged_in = FALSE, user = NULL)
  
  output$app_ui <- renderUI({
    if (!vals$logged_in) {
      div(class = "login-container",
        div(class = "login-box",
          h2("ITOM 管理控制台", style = "text-align: center; color: #333; margin-bottom: 30px;"),
          textInput("username", "用户名", placeholder = "请输入用户名"),
          passwordInput("password", "密码", placeholder = "请输入密码"),
          actionButton("login", "登录", style = "width: 100%; margin-top: 20px; padding: 12px; background: #667eea; color: white; border: none; border-radius: 5px;"),
          div(textOutput("login_message"), style = "text-align: center; margin-top: 20px; color: red;")
        )
      )
    } else {
      dashboardPage(
        dashboardHeader(title = "ITOM 管理控制台"),
        dashboardSidebar(
          sidebarMenu(
            menuItem("主机状态", tabName = "host", icon = icon("server")),
            menuItem("批量操作", tabName = "batch", icon = icon("tasks")),
            menuItem("操作记录", tabName = "records", icon = icon("history")),
            menuItem("系统信息", tabName = "system", icon = icon("info-circle")),
            menuItem("脚本执行", tabName = "scripts", icon = icon("code"))
          )
        ),
        dashboardBody(
          tabItems(
            tabItem(tabName = "host", box(title = "主机状态监控", status = "primary", solidHeader = TRUE, width = 12, "主机状态监控功能开发中...")),
            tabItem(tabName = "batch", box(title = "批量操作", status = "primary", solidHeader = TRUE, width = 12, "批量操作功能开发中...")),
            tabItem(tabName = "records", box(title = "操作记录", status = "primary", solidHeader = TRUE, width = 12, "操作记录功能开发中...")),
            tabItem(tabName = "system", box(title = "系统信息", status = "primary", solidHeader = TRUE, width = 12, "系统信息功能开发中...")),
            tabItem(tabName = "scripts",
              box(
                title = "Git 自动提交",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                
                fluidRow(
                  column(4,
                    textInput("git_commit_message", "提交信息", placeholder = "留空则自动生成", value = "")
                  ),
                  column(4,
                    textInput("git_branch", "分支", placeholder = "默认: main", value = "main")
                  ),
                  column(4,
                    checkboxInput("git_force", "强制推送", value = FALSE)
                  )
                ),
                
                fluidRow(
                  column(12,
                    actionButton("git_commit", "执行 Git 提交", class = "btn-success", style = "width: 100%; margin-top: 20px; padding: 12px;")
                  )
                ),
                
                fluidRow(
                  column(12,
                    div(
                      class = "git-message-box",
                      style = "margin-top: 20px; padding: 15px; background: #f8f9fa; border-radius: 5px; border: 1px solid #dee2e6;",
                      h4("运行过程和结果", style = "margin-top: 0; color: #495057;"),
                      verbatimTextOutput("git_output")
                    )
                  )
                )
              )
            )
          )
        )
      )
    }
  })
  
  output$login_message <- renderText({
    if (!is.null(input$login_message)) {
      input$login_message
    } else {
      ""
    }
  })
  
  observeEvent(input$login, {
    cat("Login button clicked\n")
    cat("Username:", input$username, "\n")
    cat("Password:", input$password, "\n")
    
    if (input$username == "admin" && input$password == "admin123") {
      vals$logged_in <- TRUE
      vals$user <- "admin"
      showNotification("登录成功！", type = "message")
      cat("Login successful\n")
    } else if (input$username == "user" && input$password == "user123") {
      vals$logged_in <- TRUE
      vals$user <- "user"
      showNotification("登录成功！", type = "message")
      cat("Login successful\n")
    } else {
      showNotification("用户名或密码错误", type = "error")
      cat("Login failed\n")
    }
  })
  
  observeEvent(input$git_commit, {
    cat("Git commit button clicked\n")
    
    script_path <- "D:/GitHub/SuperITOM/scripts/windows/git_auto_commit.ps1"
    commit_message <- input$git_commit_message
    branch <- input$git_branch
    
    if (!file.exists(script_path)) {
      output$git_output <- "错误: 脚本文件不存在"
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
    
    if (input$git_force) {
      cmd_parts <- c(cmd_parts, "-Force")
    }
    
    cmd <- paste(cmd_parts, collapse = " ")
    
    cat("Executing:", cmd, "\n")
    
    output$git_output <- renderPrint({
      tryCatch({
        result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
        cat(paste(result, collapse = "\n"))
        showNotification("Git 提交完成", type = "message")
        cat("Git commit completed\n")
      }, error = function(e) {
        cat(paste("错误:", e$message))
        showNotification("Git 提交失败", type = "error")
        cat("Git commit failed:", e$message, "\n")
      })
    })
  })
}

shinyApp(ui = ui, server = server)
