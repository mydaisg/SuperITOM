library(shiny)
library(shinydashboard)
library(shinydashboardPlus)
library(shinyWidgets)

server <- function(input, output, session) {
  
  session$userData <- reactiveValues(
    user = NULL,
    is_logged_in = FALSE
  )
  
  user_info <- reactiveVal(NULL)
  
  output$page_content <- renderUI({
    if (session$userData$is_logged_in) {
      main_ui()
    } else {
      login_ui()
    }
  })
  
  output$login_message <- renderUI({
    msg <- user_info()
    if (!is.null(msg) && msg$error) {
      tags$div(style = "color: red; font-weight: bold;", msg$message)
    } else if (!is.null(msg) && !msg$error) {
      tags$div(style = "color: green; font-weight: bold;", msg$message)
    } else {
      NULL
    }
  })
  
  observeEvent(input$login, {
    cat("Login button clicked\n")
    username <- input$username
    password <- input$password
    
    cat("Username:", username, "\n")
    cat("Password:", password, "\n")
    
    if (is.null(username) || username == "" || is.null(password) || password == "") {
      user_info(list(error = TRUE, message = "请输入用户名和密码"))
      return()
    }
    
    if (username == "admin" && password == "admin123") {
      cat("Admin login successful\n")
      user_info(list(
        error = FALSE,
        message = "登录成功！正在跳转...",
        user = list(username = "admin", role = "admin")
      ))
      
      session$userData$user <- list(username = "admin", role = "admin")
      session$userData$is_logged_in <- TRUE
      
      cat("Session user set\n")
    } else if (username == "user" && password == "user123") {
      cat("User login successful\n")
      user_info(list(
        error = FALSE,
        message = "登录成功！正在跳转...",
        user = list(username = "user", role = "user")
      ))
      
      session$userData$user <- list(username = "user", role = "user")
      session$userData$is_logged_in <- TRUE
      
      cat("Session user set\n")
    } else {
      cat("Login failed\n")
      user_info(list(error = TRUE, message = "用户名或密码错误"))
    }
  })
  
  observeEvent(input$logout, {
    session$userData$user <- NULL
    session$userData$is_logged_in <- FALSE
    
    showNotification("已退出登录", type = "message")
  })
}
