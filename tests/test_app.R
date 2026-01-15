library(shiny)

ui <- fluidPage(
  titlePanel("ITOM 管理控制台"),
  sidebarLayout(
    sidebarPanel(
      textInput("username", "用户名", placeholder = "请输入用户名"),
      passwordInput("password", "密码", placeholder = "请输入密码"),
      actionButton("login", "登录"),
      width = 4
    ),
    mainPanel(
      h3("欢迎"),
      textOutput("message"),
      width = 8
    )
  )
)

server <- function(input, output, session) {
  
  output$message <- renderText({
    if (!is.null(input$username) && !is.null(input$password)) {
      paste("当前用户:", input$username)
    } else {
      "请登录"
    }
  })
  
  observeEvent(input$login, {
    cat("Login button clicked!\n")
    cat("Username:", input$username, "\n")
    cat("Password:", input$password, "\n")
    
    if (input$username == "admin" && input$password == "admin123") {
      showNotification("登录成功！", type = "message")
    } else {
      showNotification("用户名或密码错误", type = "error")
    }
  })
}

shinyApp(ui = ui, server = server)
