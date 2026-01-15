library(shiny)
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

ui <- fluidPage(
  titlePanel("ITOM 管理控制台 - 登录测试"),
  
  fluidRow(
    column(
      width = 4,
      offset = 4,
      wellPanel(
        h4("用户登录"),
        textInput("username", "用户名", placeholder = "admin"),
        passwordInput("password", "密码", placeholder = "admin123"),
        actionButton("login", "登录", class = "btn-primary"),
        br(), br(),
        verbatimTextOutput("login_result")
      )
    )
  )
)

server <- function(input, output, session) {
  login_result <- reactiveVal("")
  
  observeEvent(input$login, {
    cat("Login button clicked\n")
    cat("Username:", input$username, "\n")
    cat("Password:", ifelse(is.null(input$password), "NULL", "***"), "\n")
    
    username <- input$username
    password <- input$password
    
    if (is.null(username) || username == "" || is.null(password) || password == "") {
      login_result("错误: 请输入用户名和密码")
      return()
    }
    
    cat("Querying database...\n")
    user <- get_user_by_username(username)
    cat("User found:", nrow(user), "rows\n")
    
    if (nrow(user) == 0) {
      login_result("错误: 用户名或密码错误")
      return()
    }
    
    cat("User data:\n")
    print(user)
    
    if (user$password == password) {
      login_result("登录成功！")
      showNotification("登录成功", type = "message")
    } else {
      login_result("错误: 用户名或密码错误")
    }
  })
  
  output$login_result <- renderText({
    login_result()
  })
}

shinyApp(ui, server)
