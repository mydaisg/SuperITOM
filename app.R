library(shiny)

ui <- fluidPage(
  titlePanel("ITOM Git 自动提交工具"),
  
  sidebarLayout(
    sidebarPanel(
      width = 4,
      h4("Git 提交配置"),
      
      textInput("git_commit_message", "提交信息:", 
                value = paste0("Auto commit: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
                placeholder = "输入提交信息"),
      
      textInput("git_branch", "分支:", 
                value = "main",
                placeholder = "输入分支名称"),
      
      checkboxInput("git_force", "强制推送", value = FALSE),
      
      actionButton("git_commit", "执行Git提交", 
                 class = "btn-primary",
                 style = "width: 100%; padding: 10px;"),
      
      hr(),
      
      h5("执行过程和结果"),
      verbatimTextOutput("git_output", placeholder = TRUE)
    ),
    
    mainPanel(
      width = 8,
      h4("使用说明"),
      helpText(
        "1. 输入提交信息和分支名称",
        "2. 点击'执行Git提交'按钮",
        "3. 查看执行过程和结果",
        "4. 日志文件将保存到logs/目录，文件名包含时间戳"
      )
    )
  )
)

server <- function(input, output, session) {
  git_output <- reactiveVal("")
  
  observeEvent(input$git_commit, {
    script_path <- "D:/GitHub/SuperITOM/scripts/windows/git_auto_commit.ps1"
    commit_message <- input$git_commit_message
    branch <- input$git_branch
    force <- input$git_force
    
    if (!file.exists(script_path)) {
      git_output("错误: 脚本文件不存在")
      return()
    }
    
    cmd_parts <- c("pwsh", sprintf("-File \"%s\"", script_path))
    
    if (!is.null(commit_message) && commit_message != "") {
      cmd_parts <- c(cmd_parts, sprintf("-CommitMessage \"%s\"", commit_message))
    }
    
    if (!is.null(branch) && branch != "") {
      cmd_parts <- c(cmd_parts, sprintf("-Branch \"%s\"", branch))
    }
    
    if (force) {
      cmd_parts <- c(cmd_parts, "-Force")
    }
    
    cmd <- paste(cmd_parts, collapse = " ")
    
    git_output(paste("执行命令:", cmd, "\n"))
    git_output(paste("开始执行...\n", paste(rep("=", 50), collapse = ""), "\n"))
    
    tryCatch({
      result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
      output_text <- paste(result, collapse = "\n")
      git_output(output_text)
      git_output(paste("\n", paste(rep("=", 50), collapse = ""), "\n", "执行完成！\n"))
      
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      log_file <- paste0("logs/git_commit_", timestamp, ".log")
      
      if (!dir.exists("logs")) {
        dir.create("logs")
      }
      
      writeLines(c(paste("执行时间:", Sys.time()), 
                 paste("命令:", cmd),
                 "",
                 result), 
                log_file)
      
      showNotification(paste("日志已保存:", log_file), type = "message")
      
    }, error = function(e) {
      git_output(paste("\n错误:", e$message))
      showNotification("执行失败", type = "error")
    })
  })
  
  output$git_output <- renderText({
    git_output()
  })
}

shinyApp(ui, server)
