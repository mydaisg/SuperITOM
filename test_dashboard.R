library(shiny)
library(shinydashboard)

ui <- dashboardPage(
  dashboardHeader(title = "ITOM 管理控制台"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("主机状态", tabName = "host", icon = icon("server")),
      menuItem("批量操作", tabName = "batch", icon = icon("tasks")),
      menuItem("操作记录", tabName = "records", icon = icon("history"))
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "host", h3("主机状态监控")),
      tabItem(tabName = "batch", h3("批量操作")),
      tabItem(tabName = "records", h3("操作记录"))
    )
  )
)

server <- function(input, output, session) {
  
}

shinyApp(ui = ui, server = server)
