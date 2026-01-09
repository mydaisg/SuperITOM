param(
    [string]$ConfigPath = "D:\GitHub\SuperITOM\config\config.json",
    [string]$HostsCSVPath = "D:\GitHub\SuperITOM\config\hosts.csv",
    [string]$ScriptPath = "D:\GitHub\SuperITOM\scripts\windows",
    [string]$RScriptPath = "D:\GitHub\SuperITOM\scripts\R",
    [switch]$LocalMode,
    [switch]$SkipLinux,
    [switch]$SkipAnalysis,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

$scriptStartTime = Get-Date

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage
    
    if ($Verbose) {
        switch ($Level) {
            "INFO" { Write-Host $logMessage -ForegroundColor Green }
            "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
            "ERROR" { Write-Host $logMessage -ForegroundColor Red }
            default { Write-Host $logMessage }
        }
    }
}

function Get-Config {
    param([string]$Path)
    if (Test-Path $Path) {
        return Get-Content $Path | ConvertFrom-Json
    } else {
        Write-Log "Config file not found: $Path" "ERROR"
        exit 1
    }
}

function Get-Hosts {
    param([string]$CSVPath)
    
    try {
        if (-not (Test-Path $CSVPath)) {
            Write-Log "Hosts CSV file not found: $CSVPath" "ERROR"
            return $null
        }
        
        $hosts = Import-Csv -Path $CSVPath -ErrorAction Stop
        Write-Log "Loaded $($hosts.Count) hosts from CSV"
        return $hosts
    } catch {
        Write-Log "Failed to read hosts CSV: $_" "ERROR"
        return $null
    }
}

function Invoke-RemoteScript {
    param(
        [string]$Hostname,
        [string]$ScriptPath,
        [hashtable]$Parameters = @{}
    )
    
    try {
        Write-Log "Executing script on $Hostname: $ScriptPath"
        
        $scriptName = Split-Path $ScriptPath -Leaf
        
        if ($LocalMode) {
            Write-Log "Running in local mode (executing on localhost)"
            $result = & $ScriptPath @Parameters
            return @{
                Success = ($LASTEXITCODE -eq 0)
                Output = $result
                ExitCode = $LASTEXITCODE
            }
        } else {
            $credential = Get-Credential -Message "Enter credentials for $Hostname"
            
            $session = New-PSSession -ComputerName $Hostname -Credential $credential -ErrorAction Stop
            
            $scriptContent = Get-Content $ScriptPath -Raw
            
            $result = Invoke-Command -Session $session -ScriptBlock {
                param($scriptContent, $parameters)
                $scriptBlock = [scriptblock]::Create($scriptContent)
                & $scriptBlock @parameters
            } -ArgumentList $scriptContent, $Parameters
            
            Remove-PSSession -Session $session
            
            return @{
                Success = ($result.ExitCode -eq 0)
                Output = $result.Output
                ExitCode = $result.ExitCode
            }
        }
    } catch {
        Write-Log "Remote script execution failed for $Hostname : $_" "ERROR"
        return @{
            Success = $false
            Output = $_
            ExitCode = -1
        }
    }
}

function Invoke-ParallelExecution {
    param(
        [array]$Hosts,
        [string]$ScriptPath,
        [hashtable]$Parameters = @{},
        [int]$MaxConcurrent = 10
    )
    
    $results = @()
    $completed = 0
    $total = $Hosts.Count
    
    Write-Log "Starting parallel execution on $total hosts (max concurrent: $MaxConcurrent)"
    
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxConcurrent)
    $runspacePool.Open()
    
    $jobs = @()
    
    foreach ($hostEntry in $Hosts) {
        $powershell = [powershell]::Create()
        $powershell.RunspacePool = $runspacePool
        
        $powershell.AddScript({
            param($hostname, $scriptPath, $parameters, $localMode)
            
            try {
                $scriptName = Split-Path $scriptPath -Leaf
                
                if ($localMode) {
                    $result = & $scriptPath @parameters
                    return @{
                        Hostname = $hostname
                        Success = ($LASTEXITCODE -eq 0)
                        Output = $result
                        ExitCode = $LASTEXITCODE
                    }
                } else {
                    $credential = Get-Credential -Message "Enter credentials for $hostname"
                    
                    $session = New-PSSession -ComputerName $hostname -Credential $credential -ErrorAction Stop
                    
                    $scriptContent = Get-Content $scriptPath -Raw
                    
                    $result = Invoke-Command -Session $session -ScriptBlock {
                        param($scriptContent, $parameters)
                        $scriptBlock = [scriptblock]::Create($scriptContent)
                        & $scriptBlock @parameters
                    } -ArgumentList $scriptContent, $parameters
                    
                    Remove-PSSession -Session $session
                    
                    return @{
                        Hostname = $hostname
                        Success = ($result.ExitCode -eq 0)
                        Output = $result.Output
                        ExitCode = $result.ExitCode
                    }
                }
            } catch {
                return @{
                    Hostname = $hostname
                    Success = $false
                    Output = $_
                    ExitCode = -1
                }
            }
        }).AddArgument($hostEntry.Hostname).AddArgument($scriptPath).AddArgument($Parameters).AddArgument($LocalMode)
        
        $jobs += @{
            PowerShell = $powershell
            AsyncResult = $powershell.BeginInvoke()
            Hostname = $hostEntry.Hostname
        }
    }
    
    while ($jobs.Count -gt 0) {
        $completedJobs = $jobs | Where-Object { $_.AsyncResult.IsCompleted }
        
        foreach ($job in $completedJobs) {
            $result = $job.PowerShell.EndInvoke($job.AsyncResult)
            $results += $result
            $completed++
            
            $status = if ($result.Success) { "SUCCESS" } else { "FAILED" }
            Write-Log "[$completed/$total] $($job.Hostname): $status"
            
            $job.PowerShell.Dispose()
            $jobs = $jobs | Where-Object { $_ -ne $job }
        }
        
        Start-Sleep -Seconds 1
    }
    
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    Write-Log "Parallel execution completed: $completed/$total"
    return $results
}

function Invoke-RAnalysis {
    param(
        [string]$RScriptPath,
        [string]$ConfigPath
    )
    
    try {
        Write-Log "Running R analysis script..."
        
        $rPath = "C:\Program Files\R\R-*\bin\Rscript.exe"
        $rExecutable = Get-ChildItem -Path $rPath -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        
        if (-not $rExecutable) {
            Write-Log "R not found. Skipping analysis." "WARN"
            return $false
        }
        
        $arguments = @($RScriptPath)
        $process = Start-Process -FilePath $rExecutable -ArgumentList $arguments -NoNewWindow -Wait -PassThru
        
        $success = ($process.ExitCode -eq 0)
        
        if ($success) {
            Write-Log "R analysis completed successfully"
        } else {
            Write-Log "R analysis failed with exit code: $($process.ExitCode)" "ERROR"
        }
        
        return $success
    } catch {
        Write-Log "R analysis failed: $_" "ERROR"
        return $false
    }
}

function Write-MasterReport {
    param(
        [string]$OutputPath,
        [hashtable]$Summary,
        [array]$Results
    )
    
    try {
        $reportContent = @"
========================================
ITOM MASTER CONTROL REPORT
========================================
Start Time: $($scriptStartTime.ToString("yyyy-MM-dd HH:mm:ss"))
End Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Duration: $((Get-Date - $scriptStartTime).ToString("hh\:mm\:ss"))

========================================
EXECUTION SUMMARY
========================================
Total Hosts: $($Summary.TotalHosts)
Successful: $($Summary.SuccessfulHosts)
Failed: $($Summary.FailedHosts)
Success Rate: $($Summary.SuccessRate)%

========================================
STAGE RESULTS
========================================

Stage 1: Local Directory Creation
  Status: $($Summary.Stage1.Status)
  Details: $($Summary.Stage1.Details)

Stage 2: PowerShell 7 Installation
  Status: $($Summary.Stage2.Status)
  Details: $($Summary.Stage2.Details)

Stage 3: WinRM Configuration
  Status: $($Summary.Stage3.Status)
  Details: $($Summary.Stage3.Details)

Stage 4: Host Information Collection
  Status: $($Summary.Stage4.Status)
  Details: $($Summary.Stage4.Details)

Stage 5: DML Deployment
  Status: $($Summary.Stage5.Status)
  Details: $($Summary.Stage5.Details)

Stage 6: Host Renaming
  Status: $($Summary.Stage6.Status)
  Details: $($Summary.Stage6.Details)

Stage 7: Domain Joining
  Status: $($Summary.Stage7.Status)
  Details: $($Summary.Stage7.Details)

Stage 8: Local Admin Configuration
  Status: $($Summary.Stage8.Status)
  Details: $($Summary.Stage8.Details)

Stage 9: Tools Deployment
  Status: $($Summary.Stage9.Status)
  Details: $($Summary.Stage9.Details)

Stage 10: Linux Deployment
  Status: $($Summary.Stage10.Status)
  Details: $($Summary.Stage10.Details)

Stage 11: Health Check
  Status: $($Summary.Stage11.Status)
  Details: $($Summary.Stage11.Details)

Stage 12: Log Analysis
  Status: $($Summary.Stage12.Status)
  Details: $($Summary.Stage12.Details)

========================================
FAILED HOSTS
========================================
$($Results.Where({-not $_.Success}).Hostname -join "`n")

========================================
END OF REPORT
========================================
"@
        
        Set-Content -Path $OutputPath -Value $reportContent -Encoding UTF8
        Write-Log "Master report written to: $OutputPath"
        return $true
    } catch {
        Write-Log "Failed to write master report: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$hosts = Get-Hosts -CSVPath $HostsCSVPath

if (-not $hosts) {
    Write-Log "No hosts found. Exiting." "ERROR"
    exit 1
}

$windowsHosts = $hosts | Where-Object { $_.OSType -eq "Windows" }
$linuxHosts = $hosts | Where-Object { $_.OSType -eq "Linux" }

Write-Log "=== ITOM Master Control Script Started ==="
Write-Log "Windows Hosts: $($windowsHosts.Count)"
Write-Log "Linux Hosts: $($linuxHosts.Count)"
Write-Log "Local Mode: $LocalMode"
Write-Log "Skip Linux: $SkipLinux"
Write-Log "Skip Analysis: $SkipAnalysis"

$executionConfig = $config.execution
$maxConcurrent = $executionConfig.max_concurrent

$summary = @{
    TotalHosts = $hosts.Count
    SuccessfulHosts = 0
    FailedHosts = 0
    SuccessRate = 0
    Stage1 = @{Status = "Not Run"; Details = ""}
    Stage2 = @{Status = "Not Run"; Details = ""}
    Stage3 = @{Status = "Not Run"; Details = ""}
    Stage4 = @{Status = "Not Run"; Details = ""}
    Stage5 = @{Status = "Not Run"; Details = ""}
    Stage6 = @{Status = "Not Run"; Details = ""}
    Stage7 = @{Status = "Not Run"; Details = ""}
    Stage8 = @{Status = "Not Run"; Details = ""}
    Stage9 = @{Status = "Not Run"; Details = ""}
    Stage10 = @{Status = "Not Run"; Details = ""}
    Stage11 = @{Status = "Not Run"; Details = ""}
    Stage12 = @{Status = "Not Run"; Details = ""}
}

$allResults = @()

$script0_localdir = Join-Path $ScriptPath "0_localdir.ps1"
$script0_pwsh7 = Join-Path $ScriptPath "0_pwsh7.ps1"
$script0_winrm = Join-Path $ScriptPath "0_winrm.ps1"
$script1_hostinfo = Join-Path $ScriptPath "1_hostinfo.ps1"
$script2_deploy_dml = Join-Path $ScriptPath "2_deploy_dml.ps1"
$script2_rename_host = Join-Path $ScriptPath "2_rename_host.ps1"
$script3_join_domain = Join-Path $ScriptPath "3_JoinDomain_LVCC.ps1"
$script4_localadmin = Join-Path $ScriptPath "4_LocalAdmin.ps1"
$script5_deploy_tools = Join-Path $ScriptPath "5_deploy_tools.ps1"
$script6_linux = Join-Path $ScriptPath "6_linux_deploy.ps1"
$script7_healthcheck = Join-Path $ScriptPath "7_HealthCheck.ps1"
$script8_analyze = Join-Path $RScriptPath "8_analyze_logs.R"

Write-Log "=== Stage 1: Local Directory Creation ==="
$stage1Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script0_localdir -MaxConcurrent $maxConcurrent
$allResults += $stage1Results
$stage1Success = ($stage1Results | Where-Object { $_.Success }).Count
$summary.Stage1 = @{
    Status = if ($stage1Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage1Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 2: PowerShell 7 Installation ==="
$stage2Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script0_pwsh7 -MaxConcurrent $maxConcurrent
$allResults += $stage2Results
$stage2Success = ($stage2Results | Where-Object { $_.Success }).Count
$summary.Stage2 = @{
    Status = if ($stage2Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage2Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 3: WinRM Configuration ==="
$stage3Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script0_winrm -MaxConcurrent $maxConcurrent
$allResults += $stage3Results
$stage3Success = ($stage3Results | Where-Object { $_.Success }).Count
$summary.Stage3 = @{
    Status = if ($stage3Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage3Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 4: Host Information Collection ==="
$stage4Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script1_hostinfo -MaxConcurrent $maxConcurrent
$allResults += $stage4Results
$stage4Success = ($stage4Results | Where-Object { $_.Success }).Count
$summary.Stage4 = @{
    Status = if ($stage4Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage4Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 5: DML Deployment ==="
$stage5Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script2_deploy_dml -MaxConcurrent $maxConcurrent
$allResults += $stage5Results
$stage5Success = ($stage5Results | Where-Object { $_.Success }).Count
$summary.Stage5 = @{
    Status = if ($stage5Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage5Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 6: Host Renaming ==="
$stage6Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script2_rename_host -MaxConcurrent $maxConcurrent
$allResults += $stage6Results
$stage6Success = ($stage6Results | Where-Object { $_.Success }).Count
$summary.Stage6 = @{
    Status = if ($stage6Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage6Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 7: Domain Joining ==="
$stage7Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script3_join_domain -MaxConcurrent $maxConcurrent
$allResults += $stage7Results
$stage7Success = ($stage7Results | Where-Object { $_.Success }).Count
$summary.Stage7 = @{
    Status = if ($stage7Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage7Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 8: Local Admin Configuration ==="
$stage8Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script4_localadmin -MaxConcurrent $maxConcurrent
$allResults += $stage8Results
$stage8Success = ($stage8Results | Where-Object { $_.Success }).Count
$summary.Stage8 = @{
    Status = if ($stage8Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage8Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 9: Tools Deployment ==="
$stage9Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script5_deploy_tools -MaxConcurrent $maxConcurrent
$allResults += $stage9Results
$stage9Success = ($stage9Results | Where-Object { $_.Success }).Count
$summary.Stage9 = @{
    Status = if ($stage9Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage9Success/$($windowsHosts.Count) hosts succeeded"
}

if (-not $SkipLinux -and $linuxHosts.Count -gt 0) {
    Write-Log "=== Stage 10: Linux Deployment ==="
    $stage10Results = Invoke-ParallelExecution -Hosts $linuxHosts -ScriptPath $script6_linux -MaxConcurrent $maxConcurrent
    $allResults += $stage10Results
    $stage10Success = ($stage10Results | Where-Object { $_.Success }).Count
    $summary.Stage10 = @{
        Status = if ($stage10Success -eq $linuxHosts.Count) { "Success" } else { "Partial" }
        Details = "$stage10Success/$($linuxHosts.Count) hosts succeeded"
    }
} else {
    Write-Log "=== Stage 10: Linux Deployment (Skipped) ==="
    $summary.Stage10 = @{
        Status = "Skipped"
        Details = "Skipped by user request or no Linux hosts"
    }
}

Write-Log "=== Stage 11: Health Check ==="
$stage11Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script7_healthcheck -MaxConcurrent $maxConcurrent
$allResults += $stage11Results
$stage11Success = ($stage11Results | Where-Object { $_.Success }).Count
$summary.Stage11 = @{
    Status = if ($stage11Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage11Success/$($windowsHosts.Count) hosts succeeded"
}

if (-not $SkipAnalysis) {
    Write-Log "=== Stage 12: Log Analysis ==="
    $analysisSuccess = Invoke-RAnalysis -RScriptPath $script8_analyze -ConfigPath $ConfigPath
    $summary.Stage12 = @{
        Status = if ($analysisSuccess) { "Success" } else { "Failed" }
        Details = if ($analysisSuccess) { "Analysis completed successfully" } else { "Analysis failed" }
    }
} else {
    Write-Log "=== Stage 12: Log Analysis (Skipped) ==="
    $summary.Stage12 = @{
        Status = "Skipped"
        Details = "Skipped by user request"
    }
}

$summary.SuccessfulHosts = ($allResults | Where-Object { $_.Success }).Count
$summary.FailedHosts = ($allResults | Where-Object { -not $_.Success }).Count
$summary.SuccessRate = [math]::Round(($summary.SuccessfulHosts / $allResults.Count) * 100, 2)

$reportPath = Join-Path $config.paths.reports_dir "MasterReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Write-MasterReport -OutputPath $reportPath -Summary $summary -Results $allResults

Write-Log "=== ITOM Master Control Script Completed ==="
Write-Log "Overall Success Rate: $($summary.SuccessRate)%"
Write-Log "Master Report: $reportPath"

if ($summary.FailedHosts -gt 0) {
    Write-Log "Some hosts failed. Check the master report for details." "WARN"
    exit 1
} else {
    exit 0
}
.Name] = param(
    [string]$ConfigPath = "D:\GitHub\SuperITOM\config\config.json",
    [string]$HostsCSVPath = "D:\GitHub\SuperITOM\config\hosts.csv",
    [string]$ScriptPath = "D:\GitHub\SuperITOM\scripts\windows",
    [string]$RScriptPath = "D:\GitHub\SuperITOM\scripts\R",
    [switch]$LocalMode,
    [switch]$SkipLinux,
    [switch]$SkipAnalysis,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

$scriptStartTime = Get-Date

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage
    
    if ($Verbose) {
        switch ($Level) {
            "INFO" { Write-Host $logMessage -ForegroundColor Green }
            "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
            "ERROR" { Write-Host $logMessage -ForegroundColor Red }
            default { Write-Host $logMessage }
        }
    }
}

function Get-Config {
    param([string]$Path)
    if (Test-Path $Path) {
        return Get-Content $Path | ConvertFrom-Json
    } else {
        Write-Log "Config file not found: $Path" "ERROR"
        exit 1
    }
}

function Get-Hosts {
    param([string]$CSVPath)
    
    try {
        if (-not (Test-Path $CSVPath)) {
            Write-Log "Hosts CSV file not found: $CSVPath" "ERROR"
            return $null
        }
        
        $hosts = Import-Csv -Path $CSVPath -ErrorAction Stop
        Write-Log "Loaded $($hosts.Count) hosts from CSV"
        return $hosts
    } catch {
        Write-Log "Failed to read hosts CSV: $_" "ERROR"
        return $null
    }
}

function Invoke-RemoteScript {
    param(
        [string]$Hostname,
        [string]$ScriptPath,
        [hashtable]$Parameters = @{}
    )
    
    try {
        Write-Log "Executing script on $Hostname: $ScriptPath"
        
        $scriptName = Split-Path $ScriptPath -Leaf
        
        if ($LocalMode) {
            Write-Log "Running in local mode (executing on localhost)"
            $result = & $ScriptPath @Parameters
            return @{
                Success = ($LASTEXITCODE -eq 0)
                Output = $result
                ExitCode = $LASTEXITCODE
            }
        } else {
            $credential = Get-Credential -Message "Enter credentials for $Hostname"
            
            $session = New-PSSession -ComputerName $Hostname -Credential $credential -ErrorAction Stop
            
            $scriptContent = Get-Content $ScriptPath -Raw
            
            $result = Invoke-Command -Session $session -ScriptBlock {
                param($scriptContent, $parameters)
                $scriptBlock = [scriptblock]::Create($scriptContent)
                & $scriptBlock @parameters
            } -ArgumentList $scriptContent, $Parameters
            
            Remove-PSSession -Session $session
            
            return @{
                Success = ($result.ExitCode -eq 0)
                Output = $result.Output
                ExitCode = $result.ExitCode
            }
        }
    } catch {
        Write-Log "Remote script execution failed for $Hostname : $_" "ERROR"
        return @{
            Success = $false
            Output = $_
            ExitCode = -1
        }
    }
}

function Invoke-ParallelExecution {
    param(
        [array]$Hosts,
        [string]$ScriptPath,
        [hashtable]$Parameters = @{},
        [int]$MaxConcurrent = 10
    )
    
    $results = @()
    $completed = 0
    $total = $Hosts.Count
    
    Write-Log "Starting parallel execution on $total hosts (max concurrent: $MaxConcurrent)"
    
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxConcurrent)
    $runspacePool.Open()
    
    $jobs = @()
    
    foreach ($hostEntry in $Hosts) {
        $powershell = [powershell]::Create()
        $powershell.RunspacePool = $runspacePool
        
        $powershell.AddScript({
            param($hostname, $scriptPath, $parameters, $localMode)
            
            try {
                $scriptName = Split-Path $scriptPath -Leaf
                
                if ($localMode) {
                    $result = & $scriptPath @parameters
                    return @{
                        Hostname = $hostname
                        Success = ($LASTEXITCODE -eq 0)
                        Output = $result
                        ExitCode = $LASTEXITCODE
                    }
                } else {
                    $credential = Get-Credential -Message "Enter credentials for $hostname"
                    
                    $session = New-PSSession -ComputerName $hostname -Credential $credential -ErrorAction Stop
                    
                    $scriptContent = Get-Content $scriptPath -Raw
                    
                    $result = Invoke-Command -Session $session -ScriptBlock {
                        param($scriptContent, $parameters)
                        $scriptBlock = [scriptblock]::Create($scriptContent)
                        & $scriptBlock @parameters
                    } -ArgumentList $scriptContent, $parameters
                    
                    Remove-PSSession -Session $session
                    
                    return @{
                        Hostname = $hostname
                        Success = ($result.ExitCode -eq 0)
                        Output = $result.Output
                        ExitCode = $result.ExitCode
                    }
                }
            } catch {
                return @{
                    Hostname = $hostname
                    Success = $false
                    Output = $_
                    ExitCode = -1
                }
            }
        }).AddArgument($hostEntry.Hostname).AddArgument($scriptPath).AddArgument($Parameters).AddArgument($LocalMode)
        
        $jobs += @{
            PowerShell = $powershell
            AsyncResult = $powershell.BeginInvoke()
            Hostname = $hostEntry.Hostname
        }
    }
    
    while ($jobs.Count -gt 0) {
        $completedJobs = $jobs | Where-Object { $_.AsyncResult.IsCompleted }
        
        foreach ($job in $completedJobs) {
            $result = $job.PowerShell.EndInvoke($job.AsyncResult)
            $results += $result
            $completed++
            
            $status = if ($result.Success) { "SUCCESS" } else { "FAILED" }
            Write-Log "[$completed/$total] $($job.Hostname): $status"
            
            $job.PowerShell.Dispose()
            $jobs = $jobs | Where-Object { $_ -ne $job }
        }
        
        Start-Sleep -Seconds 1
    }
    
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    Write-Log "Parallel execution completed: $completed/$total"
    return $results
}

function Invoke-RAnalysis {
    param(
        [string]$RScriptPath,
        [string]$ConfigPath
    )
    
    try {
        Write-Log "Running R analysis script..."
        
        $rPath = "C:\Program Files\R\R-*\bin\Rscript.exe"
        $rExecutable = Get-ChildItem -Path $rPath -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        
        if (-not $rExecutable) {
            Write-Log "R not found. Skipping analysis." "WARN"
            return $false
        }
        
        $arguments = @($RScriptPath)
        $process = Start-Process -FilePath $rExecutable -ArgumentList $arguments -NoNewWindow -Wait -PassThru
        
        $success = ($process.ExitCode -eq 0)
        
        if ($success) {
            Write-Log "R analysis completed successfully"
        } else {
            Write-Log "R analysis failed with exit code: $($process.ExitCode)" "ERROR"
        }
        
        return $success
    } catch {
        Write-Log "R analysis failed: $_" "ERROR"
        return $false
    }
}

function Write-MasterReport {
    param(
        [string]$OutputPath,
        [hashtable]$Summary,
        [array]$Results
    )
    
    try {
        $reportContent = @"
========================================
ITOM MASTER CONTROL REPORT
========================================
Start Time: $($scriptStartTime.ToString("yyyy-MM-dd HH:mm:ss"))
End Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Duration: $((Get-Date - $scriptStartTime).ToString("hh\:mm\:ss"))

========================================
EXECUTION SUMMARY
========================================
Total Hosts: $($Summary.TotalHosts)
Successful: $($Summary.SuccessfulHosts)
Failed: $($Summary.FailedHosts)
Success Rate: $($Summary.SuccessRate)%

========================================
STAGE RESULTS
========================================

Stage 1: Local Directory Creation
  Status: $($Summary.Stage1.Status)
  Details: $($Summary.Stage1.Details)

Stage 2: PowerShell 7 Installation
  Status: $($Summary.Stage2.Status)
  Details: $($Summary.Stage2.Details)

Stage 3: WinRM Configuration
  Status: $($Summary.Stage3.Status)
  Details: $($Summary.Stage3.Details)

Stage 4: Host Information Collection
  Status: $($Summary.Stage4.Status)
  Details: $($Summary.Stage4.Details)

Stage 5: DML Deployment
  Status: $($Summary.Stage5.Status)
  Details: $($Summary.Stage5.Details)

Stage 6: Host Renaming
  Status: $($Summary.Stage6.Status)
  Details: $($Summary.Stage6.Details)

Stage 7: Domain Joining
  Status: $($Summary.Stage7.Status)
  Details: $($Summary.Stage7.Details)

Stage 8: Local Admin Configuration
  Status: $($Summary.Stage8.Status)
  Details: $($Summary.Stage8.Details)

Stage 9: Tools Deployment
  Status: $($Summary.Stage9.Status)
  Details: $($Summary.Stage9.Details)

Stage 10: Linux Deployment
  Status: $($Summary.Stage10.Status)
  Details: $($Summary.Stage10.Details)

Stage 11: Health Check
  Status: $($Summary.Stage11.Status)
  Details: $($Summary.Stage11.Details)

Stage 12: Log Analysis
  Status: $($Summary.Stage12.Status)
  Details: $($Summary.Stage12.Details)

========================================
FAILED HOSTS
========================================
$($Results.Where({-not $_.Success}).Hostname -join "`n")

========================================
END OF REPORT
========================================
"@
        
        Set-Content -Path $OutputPath -Value $reportContent -Encoding UTF8
        Write-Log "Master report written to: $OutputPath"
        return $true
    } catch {
        Write-Log "Failed to write master report: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$hosts = Get-Hosts -CSVPath $HostsCSVPath

if (-not $hosts) {
    Write-Log "No hosts found. Exiting." "ERROR"
    exit 1
}

$windowsHosts = $hosts | Where-Object { $_.OSType -eq "Windows" }
$linuxHosts = $hosts | Where-Object { $_.OSType -eq "Linux" }

Write-Log "=== ITOM Master Control Script Started ==="
Write-Log "Windows Hosts: $($windowsHosts.Count)"
Write-Log "Linux Hosts: $($linuxHosts.Count)"
Write-Log "Local Mode: $LocalMode"
Write-Log "Skip Linux: $SkipLinux"
Write-Log "Skip Analysis: $SkipAnalysis"

$executionConfig = $config.execution
$maxConcurrent = $executionConfig.max_concurrent

$summary = @{
    TotalHosts = $hosts.Count
    SuccessfulHosts = 0
    FailedHosts = 0
    SuccessRate = 0
    Stage1 = @{Status = "Not Run"; Details = ""}
    Stage2 = @{Status = "Not Run"; Details = ""}
    Stage3 = @{Status = "Not Run"; Details = ""}
    Stage4 = @{Status = "Not Run"; Details = ""}
    Stage5 = @{Status = "Not Run"; Details = ""}
    Stage6 = @{Status = "Not Run"; Details = ""}
    Stage7 = @{Status = "Not Run"; Details = ""}
    Stage8 = @{Status = "Not Run"; Details = ""}
    Stage9 = @{Status = "Not Run"; Details = ""}
    Stage10 = @{Status = "Not Run"; Details = ""}
    Stage11 = @{Status = "Not Run"; Details = ""}
    Stage12 = @{Status = "Not Run"; Details = ""}
}

$allResults = @()

$script0_localdir = Join-Path $ScriptPath "0_localdir.ps1"
$script0_pwsh7 = Join-Path $ScriptPath "0_pwsh7.ps1"
$script0_winrm = Join-Path $ScriptPath "0_winrm.ps1"
$script1_hostinfo = Join-Path $ScriptPath "1_hostinfo.ps1"
$script2_deploy_dml = Join-Path $ScriptPath "2_deploy_dml.ps1"
$script2_rename_host = Join-Path $ScriptPath "2_rename_host.ps1"
$script3_join_domain = Join-Path $ScriptPath "3_JoinDomain_LVCC.ps1"
$script4_localadmin = Join-Path $ScriptPath "4_LocalAdmin.ps1"
$script5_deploy_tools = Join-Path $ScriptPath "5_deploy_tools.ps1"
$script6_linux = Join-Path $ScriptPath "6_linux_deploy.ps1"
$script7_healthcheck = Join-Path $ScriptPath "7_HealthCheck.ps1"
$script8_analyze = Join-Path $RScriptPath "8_analyze_logs.R"

Write-Log "=== Stage 1: Local Directory Creation ==="
$stage1Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script0_localdir -MaxConcurrent $maxConcurrent
$allResults += $stage1Results
$stage1Success = ($stage1Results | Where-Object { $_.Success }).Count
$summary.Stage1 = @{
    Status = if ($stage1Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage1Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 2: PowerShell 7 Installation ==="
$stage2Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script0_pwsh7 -MaxConcurrent $maxConcurrent
$allResults += $stage2Results
$stage2Success = ($stage2Results | Where-Object { $_.Success }).Count
$summary.Stage2 = @{
    Status = if ($stage2Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage2Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 3: WinRM Configuration ==="
$stage3Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script0_winrm -MaxConcurrent $maxConcurrent
$allResults += $stage3Results
$stage3Success = ($stage3Results | Where-Object { $_.Success }).Count
$summary.Stage3 = @{
    Status = if ($stage3Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage3Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 4: Host Information Collection ==="
$stage4Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script1_hostinfo -MaxConcurrent $maxConcurrent
$allResults += $stage4Results
$stage4Success = ($stage4Results | Where-Object { $_.Success }).Count
$summary.Stage4 = @{
    Status = if ($stage4Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage4Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 5: DML Deployment ==="
$stage5Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script2_deploy_dml -MaxConcurrent $maxConcurrent
$allResults += $stage5Results
$stage5Success = ($stage5Results | Where-Object { $_.Success }).Count
$summary.Stage5 = @{
    Status = if ($stage5Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage5Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 6: Host Renaming ==="
$stage6Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script2_rename_host -MaxConcurrent $maxConcurrent
$allResults += $stage6Results
$stage6Success = ($stage6Results | Where-Object { $_.Success }).Count
$summary.Stage6 = @{
    Status = if ($stage6Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage6Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 7: Domain Joining ==="
$stage7Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script3_join_domain -MaxConcurrent $maxConcurrent
$allResults += $stage7Results
$stage7Success = ($stage7Results | Where-Object { $_.Success }).Count
$summary.Stage7 = @{
    Status = if ($stage7Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage7Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 8: Local Admin Configuration ==="
$stage8Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script4_localadmin -MaxConcurrent $maxConcurrent
$allResults += $stage8Results
$stage8Success = ($stage8Results | Where-Object { $_.Success }).Count
$summary.Stage8 = @{
    Status = if ($stage8Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage8Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 9: Tools Deployment ==="
$stage9Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script5_deploy_tools -MaxConcurrent $maxConcurrent
$allResults += $stage9Results
$stage9Success = ($stage9Results | Where-Object { $_.Success }).Count
$summary.Stage9 = @{
    Status = if ($stage9Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage9Success/$($windowsHosts.Count) hosts succeeded"
}

if (-not $SkipLinux -and $linuxHosts.Count -gt 0) {
    Write-Log "=== Stage 10: Linux Deployment ==="
    $stage10Results = Invoke-ParallelExecution -Hosts $linuxHosts -ScriptPath $script6_linux -MaxConcurrent $maxConcurrent
    $allResults += $stage10Results
    $stage10Success = ($stage10Results | Where-Object { $_.Success }).Count
    $summary.Stage10 = @{
        Status = if ($stage10Success -eq $linuxHosts.Count) { "Success" } else { "Partial" }
        Details = "$stage10Success/$($linuxHosts.Count) hosts succeeded"
    }
} else {
    Write-Log "=== Stage 10: Linux Deployment (Skipped) ==="
    $summary.Stage10 = @{
        Status = "Skipped"
        Details = "Skipped by user request or no Linux hosts"
    }
}

Write-Log "=== Stage 11: Health Check ==="
$stage11Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script7_healthcheck -MaxConcurrent $maxConcurrent
$allResults += $stage11Results
$stage11Success = ($stage11Results | Where-Object { $_.Success }).Count
$summary.Stage11 = @{
    Status = if ($stage11Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage11Success/$($windowsHosts.Count) hosts succeeded"
}

if (-not $SkipAnalysis) {
    Write-Log "=== Stage 12: Log Analysis ==="
    $analysisSuccess = Invoke-RAnalysis -RScriptPath $script8_analyze -ConfigPath $ConfigPath
    $summary.Stage12 = @{
        Status = if ($analysisSuccess) { "Success" } else { "Failed" }
        Details = if ($analysisSuccess) { "Analysis completed successfully" } else { "Analysis failed" }
    }
} else {
    Write-Log "=== Stage 12: Log Analysis (Skipped) ==="
    $summary.Stage12 = @{
        Status = "Skipped"
        Details = "Skipped by user request"
    }
}

$summary.SuccessfulHosts = ($allResults | Where-Object { $_.Success }).Count
$summary.FailedHosts = ($allResults | Where-Object { -not $_.Success }).Count
$summary.SuccessRate = [math]::Round(($summary.SuccessfulHosts / $allResults.Count) * 100, 2)

$reportPath = Join-Path $config.paths.reports_dir "MasterReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Write-MasterReport -OutputPath $reportPath -Summary $summary -Results $allResults

Write-Log "=== ITOM Master Control Script Completed ==="
Write-Log "Overall Success Rate: $($summary.SuccessRate)%"
Write-Log "Master Report: $reportPath"

if ($summary.FailedHosts -gt 0) {
    Write-Log "Some hosts failed. Check the master report for details." "WARN"
    exit 1
} else {
    exit 0
}


function Get-Hosts {
    param([string]$CSVPath)
    
    try {
        if (-not (Test-Path $CSVPath)) {
            Write-Log "Hosts CSV file not found: $CSVPath" "ERROR"
            return $null
        }
        
        $hosts = Import-Csv -Path $CSVPath -ErrorAction Stop
        Write-Log "Loaded $($hosts.Count) hosts from CSV"
        return $hosts
    } catch {
        Write-Log "Failed to read hosts CSV: $_" "ERROR"
        return $null
    }
}

function Invoke-RemoteScript {
    param(
        [string]$Hostname,
        [string]$ScriptPath,
        [hashtable]$Parameters = @{}
    )
    
    try {
        Write-Log "Executing script on $Hostname: $ScriptPath"
        
        $scriptName = Split-Path $ScriptPath -Leaf
        
        if ($LocalMode) {
            Write-Log "Running in local mode (executing on localhost)"
            $result = & $ScriptPath @Parameters
            return @{
                Success = ($LASTEXITCODE -eq 0)
                Output = $result
                ExitCode = $LASTEXITCODE
            }
        } else {
            $credential = Get-Credential -Message "Enter credentials for $Hostname"
            
            $session = New-PSSession -ComputerName $Hostname -Credential $credential -ErrorAction Stop
            
            $scriptContent = Get-Content $ScriptPath -Raw
            
            $result = Invoke-Command -Session $session -ScriptBlock {
                param($scriptContent, $parameters)
                $scriptBlock = [scriptblock]::Create($scriptContent)
                & $scriptBlock @parameters
            } -ArgumentList $scriptContent, $Parameters
            
            Remove-PSSession -Session $session
            
            return @{
                Success = ($result.ExitCode -eq 0)
                Output = $result.Output
                ExitCode = $result.ExitCode
            }
        }
    } catch {
        Write-Log "Remote script execution failed for $Hostname : $_" "ERROR"
        return @{
            Success = $false
            Output = $_
            ExitCode = -1
        }
    }
}

function Invoke-ParallelExecution {
    param(
        [array]$Hosts,
        [string]$ScriptPath,
        [hashtable]$Parameters = @{},
        [int]$MaxConcurrent = 10
    )
    
    $results = @()
    $completed = 0
    $total = $Hosts.Count
    
    Write-Log "Starting parallel execution on $total hosts (max concurrent: $MaxConcurrent)"
    
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxConcurrent)
    $runspacePool.Open()
    
    $jobs = @()
    
    foreach ($hostEntry in $Hosts) {
        $powershell = [powershell]::Create()
        $powershell.RunspacePool = $runspacePool
        
        $powershell.AddScript({
            param($hostname, $scriptPath, $parameters, $localMode)
            
            try {
                $scriptName = Split-Path $scriptPath -Leaf
                
                if ($localMode) {
                    $result = & $scriptPath @parameters
                    return @{
                        Hostname = $hostname
                        Success = ($LASTEXITCODE -eq 0)
                        Output = $result
                        ExitCode = $LASTEXITCODE
                    }
                } else {
                    $credential = Get-Credential -Message "Enter credentials for $hostname"
                    
                    $session = New-PSSession -ComputerName $hostname -Credential $credential -ErrorAction Stop
                    
                    $scriptContent = Get-Content $scriptPath -Raw
                    
                    $result = Invoke-Command -Session $session -ScriptBlock {
                        param($scriptContent, $parameters)
                        $scriptBlock = [scriptblock]::Create($scriptContent)
                        & $scriptBlock @parameters
                    } -ArgumentList $scriptContent, $parameters
                    
                    Remove-PSSession -Session $session
                    
                    return @{
                        Hostname = $hostname
                        Success = ($result.ExitCode -eq 0)
                        Output = $result.Output
                        ExitCode = $result.ExitCode
                    }
                }
            } catch {
                return @{
                    Hostname = $hostname
                    Success = $false
                    Output = $_
                    ExitCode = -1
                }
            }
        }).AddArgument($hostEntry.Hostname).AddArgument($scriptPath).AddArgument($Parameters).AddArgument($LocalMode)
        
        $jobs += @{
            PowerShell = $powershell
            AsyncResult = $powershell.BeginInvoke()
            Hostname = $hostEntry.Hostname
        }
    }
    
    while ($jobs.Count -gt 0) {
        $completedJobs = $jobs | Where-Object { $_.AsyncResult.IsCompleted }
        
        foreach ($job in $completedJobs) {
            $result = $job.PowerShell.EndInvoke($job.AsyncResult)
            $results += $result
            $completed++
            
            $status = if ($result.Success) { "SUCCESS" } else { "FAILED" }
            Write-Log "[$completed/$total] $($job.Hostname): $status"
            
            $job.PowerShell.Dispose()
            $jobs = $jobs | Where-Object { $_ -ne $job }
        }
        
        Start-Sleep -Seconds 1
    }
    
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    Write-Log "Parallel execution completed: $completed/$total"
    return $results
}

function Invoke-RAnalysis {
    param(
        [string]$RScriptPath,
        [string]$ConfigPath
    )
    
    try {
        Write-Log "Running R analysis script..."
        
        $rPath = "C:\Program Files\R\R-*\bin\Rscript.exe"
        $rExecutable = Get-ChildItem -Path $rPath -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        
        if (-not $rExecutable) {
            Write-Log "R not found. Skipping analysis." "WARN"
            return $false
        }
        
        $arguments = @($RScriptPath)
        $process = Start-Process -FilePath $rExecutable -ArgumentList $arguments -NoNewWindow -Wait -PassThru
        
        $success = ($process.ExitCode -eq 0)
        
        if ($success) {
            Write-Log "R analysis completed successfully"
        } else {
            Write-Log "R analysis failed with exit code: $($process.ExitCode)" "ERROR"
        }
        
        return $success
    } catch {
        Write-Log "R analysis failed: $_" "ERROR"
        return $false
    }
}

function Write-MasterReport {
    param(
        [string]$OutputPath,
        [hashtable]$Summary,
        [array]$Results
    )
    
    try {
        $reportContent = @"
========================================
ITOM MASTER CONTROL REPORT
========================================
Start Time: $($scriptStartTime.ToString("yyyy-MM-dd HH:mm:ss"))
End Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Duration: $((Get-Date - $scriptStartTime).ToString("hh\:mm\:ss"))

========================================
EXECUTION SUMMARY
========================================
Total Hosts: $($Summary.TotalHosts)
Successful: $($Summary.SuccessfulHosts)
Failed: $($Summary.FailedHosts)
Success Rate: $($Summary.SuccessRate)%

========================================
STAGE RESULTS
========================================

Stage 1: Local Directory Creation
  Status: $($Summary.Stage1.Status)
  Details: $($Summary.Stage1.Details)

Stage 2: PowerShell 7 Installation
  Status: $($Summary.Stage2.Status)
  Details: $($Summary.Stage2.Details)

Stage 3: WinRM Configuration
  Status: $($Summary.Stage3.Status)
  Details: $($Summary.Stage3.Details)

Stage 4: Host Information Collection
  Status: $($Summary.Stage4.Status)
  Details: $($Summary.Stage4.Details)

Stage 5: DML Deployment
  Status: $($Summary.Stage5.Status)
  Details: $($Summary.Stage5.Details)

Stage 6: Host Renaming
  Status: $($Summary.Stage6.Status)
  Details: $($Summary.Stage6.Details)

Stage 7: Domain Joining
  Status: $($Summary.Stage7.Status)
  Details: $($Summary.Stage7.Details)

Stage 8: Local Admin Configuration
  Status: $($Summary.Stage8.Status)
  Details: $($Summary.Stage8.Details)

Stage 9: Tools Deployment
  Status: $($Summary.Stage9.Status)
  Details: $($Summary.Stage9.Details)

Stage 10: Linux Deployment
  Status: $($Summary.Stage10.Status)
  Details: $($Summary.Stage10.Details)

Stage 11: Health Check
  Status: $($Summary.Stage11.Status)
  Details: $($Summary.Stage11.Details)

Stage 12: Log Analysis
  Status: $($Summary.Stage12.Status)
  Details: $($Summary.Stage12.Details)

========================================
FAILED HOSTS
========================================
$($Results.Where({-not $_.Success}).Hostname -join "`n")

========================================
END OF REPORT
========================================
"@
        
        Set-Content -Path $OutputPath -Value $reportContent -Encoding UTF8
        Write-Log "Master report written to: $OutputPath"
        return $true
    } catch {
        Write-Log "Failed to write master report: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$hosts = Get-Hosts -CSVPath $HostsCSVPath

if (-not $hosts) {
    Write-Log "No hosts found. Exiting." "ERROR"
    exit 1
}

$windowsHosts = $hosts | Where-Object { $_.OSType -eq "Windows" }
$linuxHosts = $hosts | Where-Object { $_.OSType -eq "Linux" }

Write-Log "=== ITOM Master Control Script Started ==="
Write-Log "Windows Hosts: $($windowsHosts.Count)"
Write-Log "Linux Hosts: $($linuxHosts.Count)"
Write-Log "Local Mode: $LocalMode"
Write-Log "Skip Linux: $SkipLinux"
Write-Log "Skip Analysis: $SkipAnalysis"

$executionConfig = $config.execution
$maxConcurrent = $executionConfig.max_concurrent

$summary = @{
    TotalHosts = $hosts.Count
    SuccessfulHosts = 0
    FailedHosts = 0
    SuccessRate = 0
    Stage1 = @{Status = "Not Run"; Details = ""}
    Stage2 = @{Status = "Not Run"; Details = ""}
    Stage3 = @{Status = "Not Run"; Details = ""}
    Stage4 = @{Status = "Not Run"; Details = ""}
    Stage5 = @{Status = "Not Run"; Details = ""}
    Stage6 = @{Status = "Not Run"; Details = ""}
    Stage7 = @{Status = "Not Run"; Details = ""}
    Stage8 = @{Status = "Not Run"; Details = ""}
    Stage9 = @{Status = "Not Run"; Details = ""}
    Stage10 = @{Status = "Not Run"; Details = ""}
    Stage11 = @{Status = "Not Run"; Details = ""}
    Stage12 = @{Status = "Not Run"; Details = ""}
}

$allResults = @()

$script0_localdir = Join-Path $ScriptPath "0_localdir.ps1"
$script0_pwsh7 = Join-Path $ScriptPath "0_pwsh7.ps1"
$script0_winrm = Join-Path $ScriptPath "0_winrm.ps1"
$script1_hostinfo = Join-Path $ScriptPath "1_hostinfo.ps1"
$script2_deploy_dml = Join-Path $ScriptPath "2_deploy_dml.ps1"
$script2_rename_host = Join-Path $ScriptPath "2_rename_host.ps1"
$script3_join_domain = Join-Path $ScriptPath "3_JoinDomain_LVCC.ps1"
$script4_localadmin = Join-Path $ScriptPath "4_LocalAdmin.ps1"
$script5_deploy_tools = Join-Path $ScriptPath "5_deploy_tools.ps1"
$script6_linux = Join-Path $ScriptPath "6_linux_deploy.ps1"
$script7_healthcheck = Join-Path $ScriptPath "7_HealthCheck.ps1"
$script8_analyze = Join-Path $RScriptPath "8_analyze_logs.R"

Write-Log "=== Stage 1: Local Directory Creation ==="
$stage1Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script0_localdir -MaxConcurrent $maxConcurrent
$allResults += $stage1Results
$stage1Success = ($stage1Results | Where-Object { $_.Success }).Count
$summary.Stage1 = @{
    Status = if ($stage1Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage1Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 2: PowerShell 7 Installation ==="
$stage2Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script0_pwsh7 -MaxConcurrent $maxConcurrent
$allResults += $stage2Results
$stage2Success = ($stage2Results | Where-Object { $_.Success }).Count
$summary.Stage2 = @{
    Status = if ($stage2Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage2Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 3: WinRM Configuration ==="
$stage3Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script0_winrm -MaxConcurrent $maxConcurrent
$allResults += $stage3Results
$stage3Success = ($stage3Results | Where-Object { $_.Success }).Count
$summary.Stage3 = @{
    Status = if ($stage3Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage3Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 4: Host Information Collection ==="
$stage4Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script1_hostinfo -MaxConcurrent $maxConcurrent
$allResults += $stage4Results
$stage4Success = ($stage4Results | Where-Object { $_.Success }).Count
$summary.Stage4 = @{
    Status = if ($stage4Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage4Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 5: DML Deployment ==="
$stage5Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script2_deploy_dml -MaxConcurrent $maxConcurrent
$allResults += $stage5Results
$stage5Success = ($stage5Results | Where-Object { $_.Success }).Count
$summary.Stage5 = @{
    Status = if ($stage5Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage5Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 6: Host Renaming ==="
$stage6Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script2_rename_host -MaxConcurrent $maxConcurrent
$allResults += $stage6Results
$stage6Success = ($stage6Results | Where-Object { $_.Success }).Count
$summary.Stage6 = @{
    Status = if ($stage6Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage6Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 7: Domain Joining ==="
$stage7Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script3_join_domain -MaxConcurrent $maxConcurrent
$allResults += $stage7Results
$stage7Success = ($stage7Results | Where-Object { $_.Success }).Count
$summary.Stage7 = @{
    Status = if ($stage7Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage7Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 8: Local Admin Configuration ==="
$stage8Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script4_localadmin -MaxConcurrent $maxConcurrent
$allResults += $stage8Results
$stage8Success = ($stage8Results | Where-Object { $_.Success }).Count
$summary.Stage8 = @{
    Status = if ($stage8Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage8Success/$($windowsHosts.Count) hosts succeeded"
}

Write-Log "=== Stage 9: Tools Deployment ==="
$stage9Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script5_deploy_tools -MaxConcurrent $maxConcurrent
$allResults += $stage9Results
$stage9Success = ($stage9Results | Where-Object { $_.Success }).Count
$summary.Stage9 = @{
    Status = if ($stage9Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage9Success/$($windowsHosts.Count) hosts succeeded"
}

if (-not $SkipLinux -and $linuxHosts.Count -gt 0) {
    Write-Log "=== Stage 10: Linux Deployment ==="
    $stage10Results = Invoke-ParallelExecution -Hosts $linuxHosts -ScriptPath $script6_linux -MaxConcurrent $maxConcurrent
    $allResults += $stage10Results
    $stage10Success = ($stage10Results | Where-Object { $_.Success }).Count
    $summary.Stage10 = @{
        Status = if ($stage10Success -eq $linuxHosts.Count) { "Success" } else { "Partial" }
        Details = "$stage10Success/$($linuxHosts.Count) hosts succeeded"
    }
} else {
    Write-Log "=== Stage 10: Linux Deployment (Skipped) ==="
    $summary.Stage10 = @{
        Status = "Skipped"
        Details = "Skipped by user request or no Linux hosts"
    }
}

Write-Log "=== Stage 11: Health Check ==="
$stage11Results = Invoke-ParallelExecution -Hosts $windowsHosts -ScriptPath $script7_healthcheck -MaxConcurrent $maxConcurrent
$allResults += $stage11Results
$stage11Success = ($stage11Results | Where-Object { $_.Success }).Count
$summary.Stage11 = @{
    Status = if ($stage11Success -eq $windowsHosts.Count) { "Success" } else { "Partial" }
    Details = "$stage11Success/$($windowsHosts.Count) hosts succeeded"
}

if (-not $SkipAnalysis) {
    Write-Log "=== Stage 12: Log Analysis ==="
    $analysisSuccess = Invoke-RAnalysis -RScriptPath $script8_analyze -ConfigPath $ConfigPath
    $summary.Stage12 = @{
        Status = if ($analysisSuccess) { "Success" } else { "Failed" }
        Details = if ($analysisSuccess) { "Analysis completed successfully" } else { "Analysis failed" }
    }
} else {
    Write-Log "=== Stage 12: Log Analysis (Skipped) ==="
    $summary.Stage12 = @{
        Status = "Skipped"
        Details = "Skipped by user request"
    }
}

$summary.SuccessfulHosts = ($allResults | Where-Object { $_.Success }).Count
$summary.FailedHosts = ($allResults | Where-Object { -not $_.Success }).Count
$summary.SuccessRate = [math]::Round(($summary.SuccessfulHosts / $allResults.Count) * 100, 2)

$reportPath = Join-Path $config.paths.reports_dir "MasterReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Write-MasterReport -OutputPath $reportPath -Summary $summary -Results $allResults

Write-Log "=== ITOM Master Control Script Completed ==="
Write-Log "Overall Success Rate: $($summary.SuccessRate)%"
Write-Log "Master Report: $reportPath"

if ($summary.FailedHosts -gt 0) {
    Write-Log "Some hosts failed. Check the master report for details." "WARN"
    exit 1
} else {
    exit 0
}



