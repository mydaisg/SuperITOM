library(shiny)
library(shinydashboard)
library(shinydashboardPlus)
library(shinyWidgets)
library(shinyjs)

source("auth_module.R")
source("host_status_module.R")
source("batch_operations_module.R")
source("operation_records_module.R")
source("system_info_module.R")
source("script_execution_module.R")

server <- function(input, output, session) {
  
  session$userData <- reactiveValues(
    user = NULL,
    is_logged_in = FALSE
  )
  
  logged_in <- reactive({
    session$userData$is_logged_in
  })
  
  output$logged_in <- reactive({
    logged_in()
  })
  
  outputOptions(output, "logged_in", suspendWhenHidden = FALSE)
  
  auth_result <- authServer("login", session)
  
  observe({
    if (auth_result$is_logged_in()) {
      session$userData$is_logged_in <- TRUE
      session$userData$user <- auth_result$user_info()$user
    }
  })
  
  observeEvent(input$logout, {
    session$userData$user <- NULL
    session$userData$is_logged_in <- FALSE
    
    showNotification("已退出登录", type = "message")
  })
  
  hostStatusServer("host_status")
  batchOperationsServer("batch_operations")
  operationRecordsServer("operation_records")
  systemInfoServer("system_info")
  scriptExecutionServer("script_execution")
  
  observe({
    if (logged_in()) {
      user <- session$userData$user
      if (!is.null(user)) {
        showNotification(sprintf("欢迎, %s!", user$username), type = "message", duration = 3)
      }
    }
  })
  
  observe({
    req(logged_in())
    
    invalidateLater(60000, session)
    
    host_stats <- get_all_host_status()
    if (nrow(host_stats) > 0) {
      for (i in 1:nrow(host_stats)) {
        host_id <- host_stats$id[i]
        hostname <- host_stats$hostname[i]
        
        last_check <- host_stats$last_check[i]
        if (!is.na(last_check)) {
          last_check_time <- as.POSIXct(last_check)
          time_diff <- as.numeric(difftime(Sys.time(), last_check_time, units = "mins"))
          
          if (time_diff > 60) {
            update_host_status(host_id, "Unknown")
          }
        }
      }
    }
  })
}