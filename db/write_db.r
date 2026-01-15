library(DBI)
library(RSQLite)

db_path <- "D:/GitHub/SuperITOM/db/GH_ITOM.db"

get_db_connection <- function() {
  dbConnect(SQLite(), db_path)
}

create_user <- function(username, password, email = NULL, role = 'user') {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO users (username, password, email, role, is_active)
    VALUES ('%s', '%s', '%s', '%s', 1)
  ", username, password, email, role)
  
  result <- dbExecute(db, query)
  return(result)
}

update_user_password <- function(user_id, new_password) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("UPDATE users SET password = '%s' WHERE id = %d", new_password, user_id)
  result <- dbExecute(db, query)
  
  return(result)
}

create_host <- function(hostname, ip_address, os_type, location = NULL, department = NULL, status = 'Unknown') {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT OR REPLACE INTO hosts (hostname, ip_address, os_type, location, department, status)
    VALUES ('%s', '%s', '%s', '%s', '%s', '%s')
  ", hostname, ip_address, os_type, location, department, status)
  
  result <- dbExecute(db, query)
  return(result)
}

update_host_status <- function(host_id, status) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("UPDATE hosts SET status = '%s', updated_at = CURRENT_TIMESTAMP WHERE id = %d", status, host_id)
  result <- dbExecute(db, query)
  
  return(result)
}

update_host_last_seen <- function(host_id) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("UPDATE hosts SET last_seen = CURRENT_TIMESTAMP WHERE id = %d", host_id)
  result <- dbExecute(db, query)
  
  return(result)
}

create_host_status <- function(host_id, ps7_installed = 0, winrm_enabled = 0, domain_joined = 0, 
                               local_admin_configured = 0, tools_deployed = 0, health_check_passed = 0) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT OR REPLACE INTO host_status 
    (host_id, ps7_installed, winrm_enabled, domain_joined, local_admin_configured, tools_deployed, health_check_passed, last_check)
    VALUES (%d, %d, %d, %d, %d, %d, %d, CURRENT_TIMESTAMP)
  ", host_id, ps7_installed, winrm_enabled, domain_joined, local_admin_configured, tools_deployed, health_check_passed)
  
  result <- dbExecute(db, query)
  return(result)
}

update_host_status_field <- function(host_id, field_name, value) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  valid_fields <- c('ps7_installed', 'winrm_enabled', 'domain_joined', 
                    'local_admin_configured', 'tools_deployed', 'health_check_passed')
  
  if (!(field_name %in% valid_fields)) {
    stop(paste("Invalid field name:", field_name))
  }
  
  query <- sprintf("
    UPDATE host_status 
    SET %s = %d, last_check = CURRENT_TIMESTAMP 
    WHERE host_id = %d
  ", field_name, value, host_id)
  
  result <- dbExecute(db, query)
  return(result)
}

create_operation <- function(host_id, operation_type, script_name = NULL, status = 'Pending', 
                            created_by = NULL, output = NULL, error_message = NULL) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO operations (host_id, operation_type, script_name, status, start_time, created_by, output, error_message)
    VALUES (%d, '%s', '%s', '%s', CURRENT_TIMESTAMP, %d, '%s', '%s')
  ", host_id, operation_type, script_name, status, 
     ifelse(is.null(created_by), 'NULL', created_by),
     ifelse(is.null(output), 'NULL', gsub("'", "''", output)),
     ifelse(is.null(error_message), 'NULL', gsub("'", "''", error_message)))
  
  result <- dbExecute(db, query)
  operation_id <- dbLastInsertId(db)
  
  return(operation_id)
}

update_operation_status <- function(operation_id, status, output = NULL, error_message = NULL) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  set_clauses <- sprintf("status = '%s'", status)
  
  if (!is.null(output)) {
    set_clauses <- paste0(set_clauses, sprintf(", output = '%s'", gsub("'", "''", output)))
  }
  
  if (!is.null(error_message)) {
    set_clauses <- paste0(set_clauses, sprintf(", error_message = '%s'", gsub("'", "''", error_message)))
  }
  
  if (status %in% c('Success', 'Failed')) {
    set_clauses <- paste0(set_clauses, ", end_time = CURRENT_TIMESTAMP")
  }
  
  query <- sprintf("UPDATE operations SET %s WHERE id = %d", set_clauses, operation_id)
  result <- dbExecute(db, query)
  
  return(result)
}

create_operation_log <- function(operation_id, log_level, log_message) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO operation_logs (operation_id, log_level, log_message)
    VALUES (%d, '%s', '%s')
  ", operation_id, log_level, gsub("'", "''", log_message))
  
  result <- dbExecute(db, query)
  return(result)
}

create_system_info <- function(host_id, os_name = NULL, os_version = NULL, os_build = NULL,
                               computer_name = NULL, manufacturer = NULL, model = NULL,
                               processor = NULL, total_memory = NULL, available_memory = NULL,
                               disk_info = NULL, bios_version = NULL, serial_number = NULL) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO system_info 
    (host_id, os_name, os_version, os_build, computer_name, manufacturer, model, 
     processor, total_memory, available_memory, disk_info, bios_version, serial_number)
    VALUES (%d, '%s', '%s', '%s', '%s', '%s', '%s', '%s', %d, %d, '%s', '%s', '%s')
  ", host_id,
     ifelse(is.null(os_name), 'NULL', os_name),
     ifelse(is.null(os_version), 'NULL', os_version),
     ifelse(is.null(os_build), 'NULL', os_build),
     ifelse(is.null(computer_name), 'NULL', computer_name),
     ifelse(is.null(manufacturer), 'NULL', manufacturer),
     ifelse(is.null(model), 'NULL', model),
     ifelse(is.null(processor), 'NULL', processor),
     ifelse(is.null(total_memory), 'NULL', total_memory),
     ifelse(is.null(available_memory), 'NULL', available_memory),
     ifelse(is.null(disk_info), 'NULL', gsub("'", "''", disk_info)),
     ifelse(is.null(bios_version), 'NULL', bios_version),
     ifelse(is.null(serial_number), 'NULL', serial_number))
  
  result <- dbExecute(db, query)
  return(result)
}

create_software_entry <- function(host_id, display_name, display_version = NULL, 
                                  publisher = NULL, install_date = NULL, install_location = NULL) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO software (host_id, display_name, display_version, publisher, install_date, install_location)
    VALUES (%d, '%s', '%s', '%s', '%s', '%s')
  ", host_id, display_name,
     ifelse(is.null(display_version), 'NULL', display_version),
     ifelse(is.null(publisher), 'NULL', publisher),
     ifelse(is.null(install_date), 'NULL', install_date),
     ifelse(is.null(install_location), 'NULL', install_location))
  
  result <- dbExecute(db, query)
  return(result)
}

create_application_entry <- function(host_id, name, version = NULL, publisher = NULL, install_location = NULL) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO applications (host_id, name, version, publisher, install_location)
    VALUES (%d, '%s', '%s', '%s', '%s')
  ", host_id, name,
     ifelse(is.null(version), 'NULL', version),
     ifelse(is.null(publisher), 'NULL', publisher),
     ifelse(is.null(install_location), 'NULL', install_location))
  
  result <- dbExecute(db, query)
  return(result)
}

create_network_info_entry <- function(host_id, adapter_name, interface_description = NULL, status = NULL,
                                      link_speed = NULL, ip_address = NULL, subnet_mask = NULL,
                                      gateway = NULL, dns_servers = NULL, mac_address = NULL) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO network_info 
    (host_id, adapter_name, interface_description, status, link_speed, ip_address, 
     subnet_mask, gateway, dns_servers, mac_address)
    VALUES (%d, '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')
  ", host_id, adapter_name,
     ifelse(is.null(interface_description), 'NULL', interface_description),
     ifelse(is.null(status), 'NULL', status),
     ifelse(is.null(link_speed), 'NULL', link_speed),
     ifelse(is.null(ip_address), 'NULL', ip_address),
     ifelse(is.null(subnet_mask), 'NULL', subnet_mask),
     ifelse(is.null(gateway), 'NULL', gateway),
     ifelse(is.null(dns_servers), 'NULL', dns_servers),
     ifelse(is.null(mac_address), 'NULL', mac_address))
  
  result <- dbExecute(db, query)
  return(result)
}

create_process_entry <- function(host_id, process_name, process_id, cpu_usage = NULL,
                                  memory_usage = NULL, start_time = NULL) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO processes (host_id, process_name, process_id, cpu_usage, memory_usage, start_time)
    VALUES (%d, '%s', %d, %f, %d, '%s')
  ", host_id, process_name, process_id,
     ifelse(is.null(cpu_usage), 0, cpu_usage),
     ifelse(is.null(memory_usage), 0, memory_usage),
     ifelse(is.null(start_time), 'NULL', start_time))
  
  result <- dbExecute(db, query)
  return(result)
}

create_service_entry <- function(host_id, service_name, display_name = NULL, 
                                  status = NULL, start_type = NULL) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO services (host_id, service_name, display_name, status, start_type)
    VALUES (%d, '%s', '%s', '%s', '%s')
  ", host_id, service_name,
     ifelse(is.null(display_name), 'NULL', display_name),
     ifelse(is.null(status), 'NULL', status),
     ifelse(is.null(start_type), 'NULL', start_type))
  
  result <- dbExecute(db, query)
  return(result)
}

create_scheduled_task_entry <- function(host_id, task_name, task_path = NULL, state = NULL,
                                         last_run_time = NULL, next_run_time = NULL) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO scheduled_tasks (host_id, task_name, task_path, state, last_run_time, next_run_time)
    VALUES (%d, '%s', '%s', '%s', '%s', '%s')
  ", host_id, task_name,
     ifelse(is.null(task_path), 'NULL', task_path),
     ifelse(is.null(state), 'NULL', state),
     ifelse(is.null(last_run_time), 'NULL', last_run_time),
     ifelse(is.null(next_run_time), 'NULL', next_run_time))
  
  result <- dbExecute(db, query)
  return(result)
}

create_task_log_entry <- function(host_id, task_name, log_level, log_message) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO task_logs (host_id, task_name, log_level, log_message)
    VALUES (%d, '%s', '%s', '%s')
  ", host_id, task_name, log_level, gsub("'", "''", log_message))
  
  result <- dbExecute(db, query)
  return(result)
}

create_batch_operation <- function(operation_type, script_name = NULL, target_hosts = NULL,
                                    created_by = NULL, total_hosts = 0) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO batch_operations (operation_type, script_name, target_hosts, start_time, created_by, total_hosts)
    VALUES ('%s', '%s', '%s', CURRENT_TIMESTAMP, %d, %d)
  ", operation_type,
     ifelse(is.null(script_name), 'NULL', script_name),
     ifelse(is.null(target_hosts), 'NULL', paste(target_hosts, collapse = ',')),
     ifelse(is.null(created_by), 'NULL', created_by),
     total_hosts)
  
  result <- dbExecute(db, query)
  batch_operation_id <- dbLastInsertId(db)
  
  return(batch_operation_id)
}

update_batch_operation_status <- function(batch_operation_id, status, success_hosts = NULL, failed_hosts = NULL) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  set_clauses <- sprintf("status = '%s'", status)
  
  if (!is.null(success_hosts)) {
    set_clauses <- paste0(set_clauses, sprintf(", success_hosts = %d", success_hosts))
  }
  
  if (!is.null(failed_hosts)) {
    set_clauses <- paste0(set_clauses, sprintf(", failed_hosts = %d", failed_hosts))
  }
  
  if (status %in% c('Completed', 'Failed')) {
    set_clauses <- paste0(set_clauses, ", end_time = CURRENT_TIMESTAMP")
  }
  
  query <- sprintf("UPDATE batch_operations SET %s WHERE id = %d", set_clauses, batch_operation_id)
  result <- dbExecute(db, query)
  
  return(result)
}

create_batch_operation_detail <- function(batch_operation_id, host_id, status = 'Pending') {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  query <- sprintf("
    INSERT INTO batch_operation_details (batch_operation_id, host_id, status, start_time)
    VALUES (%d, %d, '%s', CURRENT_TIMESTAMP)
  ", batch_operation_id, host_id, status)
  
  result <- dbExecute(db, query)
  return(result)
}

update_batch_operation_detail <- function(detail_id, status, output = NULL, error_message = NULL) {
  db <- get_db_connection()
  on.exit(dbDisconnect(db))
  
  set_clauses <- sprintf("status = '%s'", status)
  
  if (!is.null(output)) {
    set_clauses <- paste0(set_clauses, sprintf(", output = '%s'", gsub("'", "''", output)))
  }
  
  if (!is.null(error_message)) {
    set_clauses <- paste0(set_clauses, sprintf(", error_message = '%s'", gsub("'", "''", error_message)))
  }
  
  if (status %in% c('Success', 'Failed')) {
    set_clauses <- paste0(set_clauses, ", end_time = CURRENT_TIMESTAMP")
  }
  
  query <- sprintf("UPDATE batch_operation_details SET %s WHERE id = %d", set_clauses, detail_id)
  result <- dbExecute(db, query)
  
  return(result)
}