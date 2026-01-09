library(tidyverse)
library(lubridate)
library(stringr)
library(jsonlite)

config_path <- "D:/GitHub/SuperITOM/config/config.json"
config <- fromJSON(config_path)

log_dir <- config$paths$log_upload_path
output_dir <- config$paths$reports_dir
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

log_files <- list.files(log_dir, pattern = "\\.log$", full.names = TRUE)

cat("Found", length(log_files), "log files\n")

if (length(log_files) == 0) {
  cat("No log files found in", log_dir, "\n")
  stop("No log files to analyze")
}

parse_log_file <- function(file_path) {
  tryCatch({
    lines <- readLines(file_path, warn = FALSE)
    filename <- basename(file_path)
    
    hostname <- str_extract(filename, "^[^_]+")
    if (is.na(hostname)) {
      hostname <- str_extract(filename, "^[^.]+")
    }
    
    log_type <- NA
    if (grepl("1_ps\\.log", filename)) {
      log_type <- "PowerShell_Installation"
    } else if (grepl("1_host\\.log", filename)) {
      log_type <- "Host_Information"
    } else if (grepl("2_host\\.log", filename)) {
      log_type <- "Host_Renaming"
    } else if (grepl("3_JoingDomain\\.log", filename)) {
      log_type <- "Domain_Joining"
    } else if (grepl("4_LocalAdmin\\.log", filename)) {
      log_type <- "Local_Admin"
    } else if (grepl("5_Tools\\.log", filename)) {
      log_type <- "Tools_Deployment"
    } else if (grepl("6_Linux_.*\\.log", filename)) {
      log_type <- "Linux_Deployment"
    } else if (grepl("7_HealthCheck\\.log", filename)) {
      log_type <- "Health_Check"
    }
    
    timestamps <- str_extract(lines, "\\[\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\]")
    timestamps <- str_replace_all(timestamps, "[\\[\\]]", "")
    
    timestamps_parsed <- parse_date_time(timestamps, orders = "ymd HMS")
    
    error_count <- sum(grepl("\\[ERROR\\]", lines, ignore.case = TRUE))
    warning_count <- sum(grepl("\\[WARN\\]", lines, ignore.case = TRUE))
    info_count <- sum(grepl("\\[INFO\\]", lines, ignore.case = TRUE))
    
    success_indicators <- c("Success", "Completed", "OK", "Successfully")
    failure_indicators <- c("Failed", "Error", "Failed to", "Unable to")
    
    success_count <- sum(str_detect(lines, regex(paste(success_indicators, collapse = "|"), ignore_case = TRUE)))
    failure_count <- sum(str_detect(lines, regex(paste(failure_indicators, collapse = "|"), ignore_case = TRUE)))
    
    status <- ifelse(failure_count > 0, "Failed", ifelse(success_count > 0, "Success", "Unknown"))
    
    data.frame(
      hostname = hostname,
      log_type = log_type,
      file_path = file_path,
      filename = filename,
      line_count = length(lines),
      error_count = error_count,
      warning_count = warning_count,
      info_count = info_count,
      success_count = success_count,
      failure_count = failure_count,
      status = status,
      first_timestamp = min(timestamps_parsed, na.rm = TRUE),
      last_timestamp = max(timestamps_parsed, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    cat("Error parsing file:", file_path, "-", e$message, "\n")
    return(NULL)
  })
}

log_summary <- bind_rows(lapply(log_files, parse_log_file))

log_summary <- log_summary %>%
  mutate(
    duration = as.numeric(difftime(last_timestamp, first_timestamp, units = "mins")),
    duration = ifelse(is.na(duration), 0, duration)
  )

cat("Parsed", nrow(log_summary), "log files\n")

summary_stats <- log_summary %>%
  group_by(log_type) %>%
  summarise(
    total_hosts = n(),
    success_hosts = sum(status == "Success"),
    failed_hosts = sum(status == "Failed"),
    success_rate = round(success_hosts / total_hosts * 100, 2),
    total_errors = sum(error_count),
    total_warnings = sum(warning_count),
    avg_duration = round(mean(duration, na.rm = TRUE), 2),
    .groups = "drop"
  )

cat("\n=== Summary Statistics ===\n")
print(summary_stats)

host_summary <- log_summary %>%
  group_by(hostname) %>%
  summarise(
    total_logs = n(),
    success_logs = sum(status == "Success"),
    failed_logs = sum(status == "Failed"),
    total_errors = sum(error_count),
    total_warnings = sum(warning_count),
    .groups = "drop"
  ) %>%
  arrange(desc(failed_logs), desc(total_errors))

cat("\n=== Host Summary (Top 10 by failures) ===\n")
print(head(host_summary, 10))

error_analysis <- log_summary %>%
  filter(error_count > 0 | failure_count > 0) %>%
  select(hostname, log_type, status, error_count, failure_count, filename) %>%
  arrange(desc(error_count), desc(failure_count))

cat("\n=== Error Analysis ===\n")
print(error_analysis)

plot_summary <- function(data, output_path) {
  p1 <- ggplot(data, aes(x = log_type, y = total_hosts, fill = status)) +
    geom_bar(stat = "identity", position = "dodge") +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "bottom"
    ) +
    labs(
      title = "Log Files by Type and Status",
      x = "Log Type",
      y = "Number of Hosts",
      fill = "Status"
    )
  
  p2 <- ggplot(data, aes(x = log_type, y = success_rate)) +
    geom_bar(stat = "identity", fill = "steelblue") +
    geom_hline(yintercept = 80, linetype = "dashed", color = "red") +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1)
    ) +
    labs(
      title = "Success Rate by Log Type",
      x = "Log Type",
      y = "Success Rate (%)"
    )
  
  p3 <- ggplot(data, aes(x = log_type, y = total_errors)) +
    geom_bar(stat = "identity", fill = "coral") +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1)
    ) +
    labs(
      title = "Total Errors by Log Type",
      x = "Log Type",
      y = "Number of Errors"
    )
  
  p4 <- ggplot(data, aes(x = log_type, y = avg_duration)) +
    geom_bar(stat = "identity", fill = "forestgreen") +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1)
    ) +
    labs(
      title = "Average Duration by Log Type",
      x = "Log Type",
      y = "Duration (minutes)"
    )
  
  ggsave(file.path(output_dir, paste0("summary_plots_", timestamp, ".png")), 
         plot = p1, width = 12, height = 6, dpi = 300)
  ggsave(file.path(output_dir, paste0("success_rate_", timestamp, ".png")), 
         plot = p2, width = 10, height = 6, dpi = 300)
  ggsave(file.path(output_dir, paste0("error_analysis_", timestamp, ".png")), 
         plot = p3, width = 10, height = 6, dpi = 300)
  ggsave(file.path(output_dir, paste0("duration_analysis_", timestamp, ".png")), 
         plot = p4, width = 10, height = 6, dpi = 300)
}

plot_summary(summary_stats, output_dir)

plot_host_summary <- function(data, output_path, top_n = 15) {
  top_hosts <- head(data, top_n)
  
  p1 <- ggplot(top_hosts, aes(x = reorder(hostname, total_errors), y = total_errors)) +
    geom_bar(stat = "identity", fill = "coral") +
    coord_flip() +
    theme_minimal() +
    labs(
      title = paste("Top", top_n, "Hosts by Error Count"),
      x = "Hostname",
      y = "Number of Errors"
    )
  
  p2 <- ggplot(top_hosts, aes(x = reorder(hostname, failed_logs), y = failed_logs)) +
    geom_bar(stat = "identity", fill = "red") +
    coord_flip() +
    theme_minimal() +
    labs(
      title = paste("Top", top_n, "Hosts by Failed Logs"),
      x = "Hostname",
      y = "Number of Failed Logs"
    )
  
  ggsave(file.path(output_dir, paste0("host_errors_", timestamp, ".png")), 
         plot = p1, width = 10, height = 8, dpi = 300)
  ggsave(file.path(output_dir, paste0("host_failures_", timestamp, ".png")), 
         plot = p2, width = 10, height = 8, dpi = 300)
}

plot_host_summary(host_summary, output_dir)

generate_report <- function(summary_data, host_data, error_data, output_path) {
  report_content <- sprintf("
========================================
ITOM LOG ANALYSIS REPORT
========================================
Generated: %s
Log Directory: %s

========================================
EXECUTIVE SUMMARY
========================================
Total Log Files Analyzed: %d
Total Unique Hosts: %d
Overall Success Rate: %.2f%%

========================================
DETAILED STATISTICS BY LOG TYPE
========================================
", 
    Sys.time(),
    log_dir,
    nrow(summary_data),
    length(unique(summary_data$hostname)),
    round(sum(summary_data$success_hosts) / sum(summary_data$total_hosts) * 100, 2)
  )
  
  for (i in 1:nrow(summary_data)) {
    row <- summary_data[i, ]
    report_content <- paste0(report_content, sprintf("
%s:
  Total Hosts: %d
  Success: %d (%.2f%%)
  Failed: %d (%.2f%%)
  Total Errors: %d
  Total Warnings: %d
  Avg Duration: %.2f minutes
", 
      row$log_type,
      row$total_hosts,
      row$success_hosts, row$success_rate,
      row$failed_hosts, 100 - row$success_rate,
      row$total_errors,
      row$total_warnings,
      row$avg_duration
    ))
  }
  
  report_content <- paste0(report_content, "
========================================
TOP 10 HOSTS WITH ISSUES
========================================
")
  
  top_issue_hosts <- head(host_data, 10)
  for (i in 1:nrow(top_issue_hosts)) {
    row <- top_issue_hosts[i, ]
    report_content <- paste0(report_content, sprintf("
%d. %s
   Total Logs: %d
   Failed Logs: %d
   Total Errors: %d
   Total Warnings: %d
", 
      i,
      row$hostname,
      row$total_logs,
      row$failed_logs,
      row$total_errors,
      row$total_warnings
    ))
  }
  
  report_content <- paste0(report_content, "
========================================
RECOMMENDATIONS
========================================
")
  
  if (any(summary_data$success_rate < 80)) {
    low_success <- summary_data %>% filter(success_rate < 80)
    for (i in 1:nrow(low_success)) {
      report_content <- paste0(report_content, sprintf("- %s has low success rate (%.2f%%). Review failed logs and address issues.\n", 
        low_success$log_type[i], low_success$success_rate[i]))
    }
  }
  
  if (any(host_data$failed_logs > 0)) {
    report_content <- paste0(report_content, sprintf("- %d hosts have failed logs. Review individual host logs for specific issues.\n", 
      sum(host_data$failed_logs > 0)))
  }
  
  if (any(host_data$total_errors > 10)) {
    report_content <- paste0(report_content, sprintf("- %d hosts have more than 10 errors. Prioritize investigation of these hosts.\n", 
      sum(host_data$total_errors > 10)))
  }
  
  report_content <- paste0(report_content, "
========================================
END OF REPORT
========================================
")
  
  writeLines(report_content, output_path)
  cat("Report generated:", output_path, "\n")
}

report_path <- file.path(output_dir, paste0("analysis_report_", timestamp, ".txt"))
generate_report(summary_stats, host_summary, error_analysis, report_path)

csv_output_path <- file.path(output_dir, paste0("log_summary_", timestamp, ".csv"))
write.csv(log_summary, csv_output_path, row.names = FALSE)
cat("CSV summary saved:", csv_output_path, "\n")

host_csv_output_path <- file.path(output_dir, paste0("host_summary_", timestamp, ".csv"))
write.csv(host_summary, host_csv_output_path, row.names = FALSE)
cat("Host summary CSV saved:", host_csv_output_path, "\n")

error_csv_output_path <- file.path(output_dir, paste0("error_analysis_", timestamp, ".csv"))
write.csv(error_analysis, error_csv_output_path, row.names = FALSE)
cat("Error analysis CSV saved:", error_csv_output_path, "\n")

cat("\n=== Analysis Complete ===\n")
cat("All outputs saved to:", output_dir, "\n")
