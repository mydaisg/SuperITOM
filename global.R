library(shiny)
library(shinydashboard)
library(shinydashboardPlus)
library(shinyWidgets)
library(DT)
library(plotly)
library(DBI)
library(RSQLite)
library(jsonlite)

options(warn = -1)

source("db/read_db.r")
source("db/write_db.r")

project_root <- "D:/GitHub/SuperITOM"
db_path <- file.path(project_root, "db/GH_ITOM.db")
scripts_path <- file.path(project_root, "scripts/windows")
logs_path <- file.path(project_root, "logs")
reports_path <- file.path(project_root, "reports")

available_scripts <- list(
  list(
    name = "安装PowerShell 7",
    script = "0_pwsh7.ps1",
    description = "在目标主机上安装PowerShell 7",
    operation_type = "PowerShell_Installation"
  ),
  list(
    name = "配置WinRM",
    script = "0_winrm.ps1",
    description = "启用和配置WinRM远程管理",
    operation_type = "WinRM_Configuration"
  ),
  list(
    name = "收集主机信息",
    script = "1_hostinfo.ps1",
    description = "收集系统信息、软件列表、网络信息等",
    operation_type = "Host_Information"
  ),
  list(
    name = "重命名主机",
    script = "2_rename_host.ps1",
    description = "标准化计算机名称",
    operation_type = "Host_Renaming"
  ),
  list(
    name = "加入域",
    script = "3_JoinDomain_LVCC.ps1",
    description = "将计算机加入指定域",
    operation_type = "Domain_Joining"
  ),
  list(
    name = "配置本地管理员",
    script = "4_LocalAdmin.ps1",
    description = "标准化本地管理员账户",
    operation_type = "Local_Admin_Configuration"
  ),
  list(
    name = "部署工具",
    script = "5_deploy_tools.ps1",
    description = "部署工具到System32目录",
    operation_type = "Tools_Deployment"
  ),
  list(
    name = "Linux部署",
    script = "6_linux_deploy.ps1",
    description = "Linux客户端部署和配置",
    operation_type = "Linux_Deployment"
  ),
  list(
    name = "健康检查",
    script = "7_HealthCheck.ps1",
    description = "执行系统健康检查",
    operation_type = "Health_Check"
  )
)

status_colors <- list(
  "Success" = "success",
  "Failed" = "danger",
  "Pending" = "warning",
  "Unknown" = "secondary",
  "Running" = "info"
)

get_status_badge <- function(status) {
  color <- status_colors[[status]]
  if (is.null(color)) {
    color <- "secondary"
  }
  return(tags$span(class = paste0("badge badge-", color), status))
}

execute_powershell_script <- function(script_path, hostname, parameters = list()) {
  tryCatch({
    cmd <- sprintf("pwsh -File '%s'", script_path)
    
    if (length(parameters) > 0) {
      param_string <- paste(names(parameters), sapply(parameters, function(x) sprintf("'%s'", x)), sep = " ", collapse = " ")
      cmd <- paste(cmd, param_string)
    }
    
    result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
    
    return(list(
      success = TRUE,
      output = paste(result, collapse = "\n"),
      error = NULL
    ))
  }, error = function(e) {
    return(list(
      success = FALSE,
      output = NULL,
      error = as.character(e$message)
    ))
  })
}

initialize_database <- function() {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  tables <- dbListTables(db)
  
  if (length(tables) == 0) {
    sql_script <- file.path(project_root, "db/create_db.sql")
    if (file.exists(sql_script)) {
      sql <- readLines(sql_script)
      dbExecute(db, paste(sql, collapse = "\n"))
      cat("Database initialized successfully\n")
    }
  }
}

initialize_database()