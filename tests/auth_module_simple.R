library(shiny)

authUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    div(
      class = "login-container",
      style = "display: flex; justify-content: center; align-items: center; height: 100vh; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);",
      
      div(
        class = "login-box",
        style = "background: white; padding: 40px; border-radius: 10px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); width: 400px;",
        
        h2("ITOM 管理控制台", style = "text-align: center; color: #333; margin-bottom: 30px;"),
        
        div(
          class = "form-group",
          style = "margin-bottom: 20px;",
          textInput(ns("username"), "用户名", placeholder = "请输入用户名")
        ),
        
        div(
          class = "form-group",
          style = "margin-bottom: 20px;",
          passwordInput(ns("password"), "密码", placeholder = "请输入密码")
        ),
        
        div(
          class = "form-group",
          style = "margin-bottom: 20px;",
          actionButton(ns("login"), "登录", 
                       style = "width: 100%; padding: 12px; background: #667eea; color: white; border: none; border-radius: 5px; font-size: 16px; cursor: pointer;")
        ),
        
        div(
          class = "login-message",
          style = "text-align: center; margin-top: 20px; min-height: 20px;",
          uiOutput(ns("login_message"))
        )
      )
    )
  )
}

authServer <- function(id, session) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    user_info <- reactiveVal(NULL)
    is_logged_in <- reactiveVal(FALSE)
    
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
      username <- input$username
      password <- input$password
      
      cat("Login button clicked\n")
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
        
        is_logged_in(TRUE)
        
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
        
        is_logged_in(TRUE)
        
        session$userData$user <- list(username = "user", role = "user")
        session$userData$is_logged_in <- TRUE
        
        cat("Session user set\n")
      } else {
        cat("Login failed\n")
        user_info(list(error = TRUE, message = "用户名或密码错误"))
      }
    })
    
    return(list(
      user_info = user_info,
      is_logged_in = is_logged_in
    ))
  })
}
