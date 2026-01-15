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

login_ui <- function() {
  authUI("login")
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
          hostStatusUI("host_status")
        ),
        
        tabItem(
          tabName = "batch_operations",
          batchOperationsUI("batch_operations")
        ),
        
        tabItem(
          tabName = "operation_records",
          operationRecordsUI("operation_records")
        ),
        
        tabItem(
          tabName = "system_info",
          systemInfoUI("system_info")
        ),
        
        tabItem(
          tabName = "script_execution",
          scriptExecutionUI("script_execution")
        )
      )
    )
  )
}

ui <- function(req) {
  tagList(
    useShinyjs(),
    tags$head(
      tags$style(HTML("
        .login-container {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        
        .login-box h2 {
          font-weight: 600;
        }
        
        .login-box input[type='text'],
        .login-box input[type='password'] {
          border: 1px solid #ddd;
          border-radius: 5px;
          padding: 10px;
          font-size: 14px;
          transition: border-color 0.3s;
        }
        
        .login-box input[type='text']:focus,
        .login-box input[type='password']:focus {
          border-color: #667eea;
          outline: none;
        }
        
        .login-box button {
          transition: background-color 0.3s;
        }
        
        .login-box button:hover {
          background-color: #5568d3;
        }
        
        .main-skin .main-header {
          background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
        }
        
        .main-skin .main-sidebar {
          background: #2c3e50;
        }
        
        .main-skin .sidebar-menu > li > a {
          color: #ffffff;
          font-weight: 500;
        }
        
        .main-skin .sidebar-menu > li > a:hover {
          background: #1e2b37;
          color: #ffffff;
        }
        
        .main-skin .sidebar-menu > li.active > a {
          background: #667eea;
          color: #ffffff;
          font-weight: 600;
        }
        
        .box.box-primary {
          border-top-color: #667eea;
        }
        
        .btn-success {
          background-color: #28a745;
          border-color: #28a745;
        }
        
        .btn-success:hover {
          background-color: #218838;
          border-color: #1e7e34;
        }
        
        .btn-info {
          background-color: #17a2b8;
          border-color: #17a2b8;
        }
        
        .btn-info:hover {
          background-color: #138496;
          border-color: #117a8b;
        }
        
        .btn-warning {
          background-color: #ffc107;
          border-color: #ffc107;
          color: #212529;
        }
        
        .btn-warning:hover {
          background-color: #e0a800;
          border-color: #d39e00;
        }
        
        .btn-danger {
          background-color: #dc3545;
          border-color: #dc3545;
        }
        
        .btn-danger:hover {
          background-color: #c82333;
          border-color: #bd2130;
        }
        
        .value-box {
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .box {
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .box-header.with-border {
          border-bottom: 1px solid #f4f4f4;
        }
        
        .table-responsive {
          border-radius: 5px;
        }
        
        .dataTables_wrapper .dataTables_length,
        .dataTables_wrapper .dataTables_filter {
          margin: 15px 0;
        }
        
        .progress {
          height: 25px;
          border-radius: 5px;
          background-color: #e9ecef;
        }
        
        .progress-bar {
          background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
        }
        
        .badge {
          padding: 5px 10px;
          border-radius: 4px;
          font-weight: 500;
        }
        
        .badge-success {
          background-color: #28a745;
        }
        
        .badge-danger {
          background-color: #dc3545;
        }
        
        .badge-warning {
          background-color: #ffc107;
          color: #212529;
        }
        
        .badge-info {
          background-color: #17a2b8;
        }
        
        .badge-secondary {
          background-color: #6c757d;
        }
      "))
    ),
    
    conditionalPanel(
      condition = "!output.logged_in",
      login_ui()
    ),
    
    conditionalPanel(
      condition = "output.logged_in",
      main_ui()
    )
  )
}