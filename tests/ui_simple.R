library(shiny)
library(shinydashboard)
library(shinydashboardPlus)
library(shinyWidgets)

login_ui <- function() {
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
          textInput("username", "用户名", placeholder = "请输入用户名")
        ),
        
        div(
          class = "form-group",
          style = "margin-bottom: 20px;",
          passwordInput("password", "密码", placeholder = "请输入密码")
        ),
        
        div(
          class = "form-group",
          style = "margin-bottom: 20px;",
          actionButton("login", "登录", 
                       style = "width: 100%; padding: 12px; background: #667eea; color: white; border: none; border-radius: 5px; font-size: 16px; cursor: pointer;")
        ),
        
        div(
          class = "login-message",
          style = "text-align: center; margin-top: 20px; min-height: 20px;",
          uiOutput("login_message")
        )
      )
    )
  )
}

main_ui <- function() {
  dashboardPage(
    dashboardHeader(
      title = "ITOM 管理控制台",
      titleWidth = 250,
      tags$li(
        class = "dropdown",
        style = "padding: 15px;",
        actionLink("logout", "退出登录", icon = icon("sign-out-alt"))
      )
    ),
    
    dashboardSidebar(
      width = 250,
      sidebarMenu(
        id = "sidebar_menu",
        menuItem(
          "主机状态监控",
          tabName = "host_status",
          icon = icon("server")
        ),
        menuItem(
          "批量操作",
          tabName = "batch_operations",
          icon = icon("tasks")
        ),
        menuItem(
          "操作记录",
          tabName = "operation_records",
          icon = icon("history")
        ),
        menuItem(
          "系统信息",
          tabName = "system_info",
          icon = icon("info-circle")
        ),
        menuItem(
          "脚本执行",
          tabName = "script_execution",
          icon = icon("code")
        )
      )
    ),
    
    dashboardBody(
      tabItems(
        tabItem(
          tabName = "host_status",
          box(
            title = "主机状态监控",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            "主机状态监控功能开发中..."
          )
        ),
        
        tabItem(
          tabName = "batch_operations",
          box(
            title = "批量操作",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            "批量操作功能开发中..."
          )
        ),
        
        tabItem(
          tabName = "operation_records",
          box(
            title = "操作记录",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            "操作记录功能开发中..."
          )
        ),
        
        tabItem(
          tabName = "system_info",
          box(
            title = "系统信息",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            "系统信息功能开发中..."
          )
        ),
        
        tabItem(
          tabName = "script_execution",
          box(
            title = "脚本执行",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            "脚本执行功能开发中..."
          )
        )
      )
    )
  )
}

ui <- function(req) {
  tagList(
    uiOutput("page_content")
  )
}
