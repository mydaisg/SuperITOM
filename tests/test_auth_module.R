library(shiny)
library(shinydashboard)
library(shinydashboardPlus)
library(shinyWidgets)
library(shinyjs)

source("../auth_module.R")

ui <- fluidPage(
  titlePanel("测试 - 仅登录模块"),
  authUI("login")
)

server <- function(input, output, session) {
  authServer("login")
}

shinyApp(ui, server)
