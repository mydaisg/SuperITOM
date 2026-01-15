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

get_user_by_id <- function(user_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM users WHERE id = %d", user_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

update_user_last_login <- function(user_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = %d", user_id)
  dbExecute(db, query)
  
  return(TRUE)
}

get_all_hosts <- function() {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- "SELECT * FROM hosts ORDER BY hostname"
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_host_by_id <- function(host_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM hosts WHERE id = %d", host_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_host_by_hostname <- function(hostname) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM hosts WHERE hostname = '%s'", hostname)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_hosts_by_status <- function(status) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM hosts WHERE status = '%s'", status)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_host_status <- function(host_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM host_status WHERE host_id = %d", host_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_all_host_status <- function() {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- "
    SELECT h.id, h.hostname, h.ip_address, h.status as host_status,
           hs.ps7_installed, hs.winrm_enabled, hs.domain_joined,
           hs.local_admin_configured, hs.tools_deployed, hs.health_check_passed,
           hs.last_check
    FROM hosts h
    LEFT JOIN host_status hs ON h.id = hs.host_id
    ORDER BY h.hostname
  "
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_operations_by_host <- function(host_id, limit = 50) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    SELECT o.*, u.username as created_by_user
    FROM operations o
    LEFT JOIN users u ON o.created_by = u.id
    WHERE o.host_id = %d
    ORDER BY o.created_at DESC
    LIMIT %d
  ", host_id, limit)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_operations_by_type <- function(operation_type, limit = 100) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    SELECT o.*, h.hostname, u.username as created_by_user
    FROM operations o
    LEFT JOIN hosts h ON o.host_id = h.id
    LEFT JOIN users u ON o.created_by = u.id
    WHERE o.operation_type = '%s'
    ORDER BY o.created_at DESC
    LIMIT %d
  ", operation_type, limit)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_all_operations <- function(limit = 100) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    SELECT o.*, h.hostname, u.username as created_by_user
    FROM operations o
    LEFT JOIN hosts h ON o.host_id = h.id
    LEFT JOIN users u ON o.created_by = u.id
    ORDER BY o.created_at DESC
    LIMIT %d
  ", limit)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_operation_logs <- function(operation_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM operation_logs WHERE operation_id = %d ORDER BY timestamp", operation_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_system_info <- function(host_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM system_info WHERE host_id = %d ORDER BY collected_at DESC LIMIT 1", host_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_software_list <- function(host_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM software WHERE host_id = %d ORDER BY display_name", host_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_applications_list <- function(host_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM applications WHERE host_id = %d ORDER BY name", host_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_network_info <- function(host_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM network_info WHERE host_id = %d", host_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_processes_list <- function(host_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM processes WHERE host_id = %d ORDER BY process_name", host_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_services_list <- function(host_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM services WHERE host_id = %d ORDER BY display_name", host_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_scheduled_tasks <- function(host_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM scheduled_tasks WHERE host_id = %d ORDER BY task_name", host_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_task_logs <- function(host_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("SELECT * FROM task_logs WHERE host_id = %d ORDER BY timestamp DESC", host_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_batch_operations <- function(limit = 50) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    SELECT bo.*, u.username as created_by_user
    FROM batch_operations bo
    LEFT JOIN users u ON bo.created_by = u.id
    ORDER BY bo.created_at DESC
    LIMIT %d
  ", limit)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_batch_operation_details <- function(batch_operation_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    SELECT bod.*, h.hostname
    FROM batch_operation_details bod
    LEFT JOIN hosts h ON bod.host_id = h.id
    WHERE bod.batch_operation_id = %d
  ", batch_operation_id)
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_operation_statistics <- function() {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- "
    SELECT 
      operation_type,
      COUNT(*) as total_operations,
      SUM(CASE WHEN status = 'Success' THEN 1 ELSE 0 END) as success_count,
      SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) as failed_count,
      ROUND(SUM(CASE WHEN status = 'Success' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as success_rate
    FROM operations
    GROUP BY operation_type
    ORDER BY total_operations DESC
  "
  result <- dbGetQuery(db, query)
  
  return(result)
}

get_host_statistics <- function() {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- "
    SELECT 
      COUNT(*) as total_hosts,
      SUM(CASE WHEN status = 'Success' THEN 1 ELSE 0 END) as success_hosts,
      SUM(CASE WHEN status = 'Failed' THEN 1 ELSE 0 END) as failed_hosts,
      SUM(CASE WHEN status = 'Unknown' THEN 1 ELSE 0 END) as unknown_hosts,
      ROUND(SUM(CASE WHEN status = 'Success' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as success_rate
    FROM hosts
  "
  result <- dbGetQuery(db, query)
  
  return(result)
}