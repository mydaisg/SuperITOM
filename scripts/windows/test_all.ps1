param(
    [string]$ConfigPath = "D:\GitHub\SuperITOM\config\config.json"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage
    
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "TEST" { Write-Host $logMessage -ForegroundColor Cyan }
        default { Write-Host $logMessage }
    }
}

function Test-ScriptExecution {
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters = @{},
        [string]$TestName
    )
    
    Write-Log "=== Testing: $TestName ===" "TEST"
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Log "Script not found: $ScriptPath" "ERROR"
        return @{
            TestName = $TestName
            Success = $false
            Message = "Script not found"
        }
    }
    
    try {
        $startTime = Get-Date
        Write-Log "Executing script: $ScriptPath"
        
        $result = & $ScriptPath @Parameters
        $exitCode = $LASTEXITCODE
        
        $duration = (Get-Date) - $startTime
        
        if ($exitCode -eq 0) {
            Write-Log "Test PASSED: $TestName (Duration: $($duration.TotalSeconds.ToString('0.00'))s)" "TEST"
            return @{
                TestName = $TestName
                Success = $true
                Message = "Script executed successfully"
                Duration = $duration.TotalSeconds
                ExitCode = $exitCode
            }
        } else {
            Write-Log "Test FAILED: $TestName (Exit Code: $exitCode)" "TEST"
            return @{
                TestName = $TestName
                Success = $false
                Message = "Script failed with exit code: $exitCode"
                Duration = $duration.TotalSeconds
                ExitCode = $exitCode
            }
        }
    } catch {
        Write-Log "Test ERROR: $TestName - $_" "TEST"
        return @{
            TestName = $TestName
            Success = $false
            Message = "Exception: $_"
            Duration = 0
            ExitCode = -1
        }
    }
}

function Test-ConfigFile {
    param([string]$ConfigPath)
    
    Write-Log "=== Testing: Configuration File ===" "TEST"
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            Write-Log "Config file not found: $ConfigPath" "ERROR"
            return @{
                TestName = "Configuration File"
                Success = $false
                Message = "Config file not found"
            }
        }
        
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        
        $requiredSections = @("domain", "local_admin", "paths", "winrm", "execution", "linux", "naming")
        $missingSections = @()
        
        foreach ($section in $requiredSections) {
            if (-not $config.PSObject.Properties.Name -contains $section) {
                $missingSections += $section
            }
        }
        
        if ($missingSections.Count -gt 0) {
            Write-Log "Missing config sections: $($missingSections -join ', ')" "WARN"
            return @{
                TestName = "Configuration File"
                Success = $false
                Message = "Missing sections: $($missingSections -join ', ')"
            }
        }
        
        Write-Log "Config file structure is valid" "TEST"
        return @{
            TestName = "Configuration File"
            Success = $true
            Message = "Config file structure is valid"
        }
    } catch {
        Write-Log "Config file test failed: $_" "ERROR"
        return @{
            TestName = "Configuration File"
            Success = $false
            Message = "Exception: $_"
        }
    }
}

function Test-HostsCSV {
    param([string]$HostsCSVPath)
    
    Write-Log "=== Testing: Hosts CSV File ===" "TEST"
    
    try {
        if (-not (Test-Path $HostsCSVPath)) {
            Write-Log "Hosts CSV file not found: $HostsCSVPath" "ERROR"
            return @{
                TestName = "Hosts CSV File"
                Success = $false
                Message = "Hosts CSV file not found"
            }
        }
        
        $hosts = Import-Csv $HostsCSVPath
        
        if ($hosts.Count -eq 0) {
            Write-Log "No hosts found in CSV file" "WARN"
            return @{
                TestName = "Hosts CSV File"
                Success = $false
                Message = "No hosts found"
            }
        }
        
        Write-Log "Hosts CSV file is valid ($($hosts.Count) hosts)" "TEST"
        return @{
            TestName = "Hosts CSV File"
            Success = $true
            Message = "Hosts CSV file is valid ($($hosts.Count) hosts)"
        }
    } catch {
        Write-Log "Hosts CSV test failed: $_" "ERROR"
        return @{
            TestName = "Hosts CSV File"
            Success = $false
            Message = "Exception: $_"
        }
    }
}

function Test-LocalDirectory {
    param([string]$ConfigPath)
    
    Write-Log "=== Testing: Local Directory ===" "TEST"
    
    try {
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        $localDir = $config.paths.local_work_dir
        
        if (Test-Path $localDir) {
            Write-Log "Local directory exists: $localDir" "TEST"
            return @{
                TestName = "Local Directory"
                Success = $true
                Message = "Local directory exists"
            }
        } else {
            Write-Log "Local directory not found: $localDir" "WARN"
            return @{
                TestName = "Local Directory"
                Success = $false
                Message = "Local directory not found"
            }
        }
    } catch {
        Write-Log "Local directory test failed: $_" "ERROR"
        return @{
            TestName = "Local Directory"
            Success = $false
            Message = "Exception: $_"
        }
    }
}

function Test-AdminPrivileges {
    Write-Log "=== Testing: Administrator Privileges ===" "TEST"
    
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
        
        if ($isAdmin) {
            Write-Log "Running with administrator privileges" "TEST"
            return @{
                TestName = "Administrator Privileges"
                Success = $true
                Message = "Running with administrator privileges"
            }
        } else {
            Write-Log "Not running with administrator privileges" "WARN"
            return @{
                TestName = "Administrator Privileges"
                Success = $false
                Message = "Not running with administrator privileges"
            }
        }
    } catch {
        Write-Log "Admin privileges test failed: $_" "ERROR"
        return @{
            TestName = "Administrator Privileges"
            Success = $false
            Message = "Exception: $_"
        }
    }
}

function Test-PowerShell7 {
    Write-Log "=== Testing: PowerShell 7 ===" "TEST"
    
    try {
        $pwsh7Path = "C:\Program Files\PowerShell\7\pwsh.exe"
        
        if (Test-Path $pwsh7Path) {
            $version = & $pwsh7Path --version
            Write-Log "PowerShell 7 is installed: $version" "TEST"
            return @{
                TestName = "PowerShell 7"
                Success = $true
                Message = "PowerShell 7 is installed: $version"
            }
        } else {
            Write-Log "PowerShell 7 is not installed" "WARN"
            return @{
                TestName = "PowerShell 7"
                Success = $false
                Message = "PowerShell 7 is not installed"
            }
        }
    } catch {
        Write-Log "PowerShell 7 test failed: $_" "ERROR"
        return @{
            TestName = "PowerShell 7"
            Success = $false
            Message = "Exception: $_"
        }
    }
}

function Test-WinRM {
    Write-Log "=== Testing: WinRM ===" "TEST"
    
    try {
        $winrmService = Get-Service -Name WinRM -ErrorAction SilentlyContinue
        
        if ($winrmService -and $winrmService.Status -eq "Running") {
            Write-Log "WinRM service is running" "TEST"
            return @{
                TestName = "WinRM"
                Success = $true
                Message = "WinRM service is running"
            }
        } else {
            Write-Log "WinRM service is not running" "WARN"
            return @{
                TestName = "WinRM"
                Success = $false
                Message = "WinRM service is not running"
            }
        }
    } catch {
        Write-Log "WinRM test failed: $_" "ERROR"
        return @{
            TestName = "WinRM"
            Success = $false
            Message = "Exception: $_"
        }
    }
}

function Write-TestReport {
    param(
        [string]$OutputPath,
        [array]$Results
    )
    
    try {
        $totalTests = $Results.Count
        $passedTests = ($Results | Where-Object { $_.Success }).Count
        $failedTests = ($Results | Where-Object { -not $_.Success }).Count
        $successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
        
        $reportContent = @"

========================================
ITOM TEST REPORT
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

========================================
TEST SUMMARY
========================================
Total Tests: $totalTests
Passed: $passedTests
Failed: $failedTests
Success Rate: $successRate%

========================================
DETAILED RESULTS
========================================
"@
        
        foreach ($result in $Results) {
            $status = if ($result.Success) { "[PASS]" } else { "[FAIL]" }
            $message = if ($result.Message) { $result.Message } else { "" }
            $duration = if ($result.Duration) { "  Duration: $($result.Duration.ToString('0.00'))s" } else { "" }
            $exitCode = if ($result.ExitCode -ne $null -and $result.ExitCode -ne 0) { "  Exit Code: $($result.ExitCode)" } else { "" }
            
            $reportContent += "$status $($result.TestName)`n"
            if ($message) {
                $reportContent += "  Message: $message`n"
            }
            if ($duration) {
                $reportContent += "$duration`n"
            }
            if ($exitCode) {
                $reportContent += "$exitCode`n"
            }
            $reportContent += "`n"
        }
        
        $reportContent += @"

========================================
FAILED TESTS
========================================
"@
        
        $failedTestsList = $Results | Where-Object { -not $_.Success }
        foreach ($test in $failedTestsList) {
            $message = if ($test.Message) { $test.Message } else { "" }
            $reportContent += "- $($test.TestName): $message`n"
        }
        
        $reportContent += @"

========================================
RECOMMENDATIONS
========================================
"@
        
        if ($failedTests.Count -gt 0) {
            $reportContent += "Please review and fix the failed tests before proceeding with deployment.`n"
        } else {
            $reportContent += "All tests passed! You can proceed with the deployment.`n"
        }
        
        $reportContent += @"

========================================
END OF REPORT
========================================
"@
        
        Set-Content -Path $OutputPath -Value $reportContent -Encoding UTF8
        Write-Log "Test report written to: $OutputPath" "TEST"
        return $true
    } catch {
        Write-Log "Failed to write test report: $_" "ERROR"
        return $false
    }
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$hostsCSVPath = Join-Path $scriptPath "..\..\config\hosts.csv"
$reportPath = Join-Path $scriptPath "..\..\reports"
$reportFile = Join-Path $reportPath "TestReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

Write-Log "=== ITOM Test Suite Started ==="
Write-Log "Config Path: $ConfigPath"
Write-Log "Script Path: $scriptPath"
Write-Log "Hosts CSV Path: $hostsCSVPath"

if (-not (Test-Path $reportPath)) {
    New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
    Write-Log "Created reports directory: $reportPath"
}

$testResults = @()

$testResults += Test-ConfigFile -ConfigPath $ConfigPath
$testResults += Test-HostsCSV -HostsCSVPath $hostsCSVPath
$testResults += Test-LocalDirectory -ConfigPath $ConfigPath
$testResults += Test-AdminPrivileges
$testResults += Test-PowerShell7
$testResults += Test-WinRM

$scriptTests = @{
    "Local Directory Creation" = Join-Path $scriptPath "0_localdir.ps1"
    "PowerShell 7 Installation" = Join-Path $scriptPath "0_pwsh7.ps1"
    "WinRM Configuration" = Join-Path $scriptPath "0_winrm.ps1"
    "Host Information Collection" = Join-Path $scriptPath "1_hostinfo.ps1"
    "DML Deployment" = Join-Path $scriptPath "2_deploy_dml.ps1"
    "Host Renaming" = Join-Path $scriptPath "2_rename_host.ps1"
    "Domain Joining" = Join-Path $scriptPath "3_JoinDomain_LVCC.ps1"
    "Local Admin Configuration" = Join-Path $scriptPath "4_LocalAdmin.ps1"
    "Tools Deployment" = Join-Path $scriptPath "5_deploy_tools.ps1"
    "Health Check" = Join-Path $scriptPath "7_HealthCheck.ps1"
}

Write-Log "=== Running Script Tests ==="

foreach ($testName in $scriptTests.Keys) {
    $scriptFilePath = $scriptTests[$testName]
    $testResults += Test-ScriptExecution -ScriptPath $scriptFilePath -Parameters @{ConfigPath = $ConfigPath} -TestName $testName
}

Write-Log "=== Writing Test Report ==="

Write-TestReport -OutputPath $reportFile -Results $testResults

Write-Log "=== ITOM Test Suite Completed ==="

$totalTests = $testResults.Count
$passedTests = ($testResults | Where-Object { $_.Success }).Count
$failedTests = ($testResults | Where-Object { -not $_.Success }).Count

Write-Log "Total Tests: $totalTests"
Write-Log "Passed: $passedTests"
Write-Log "Failed: $failedTests"

if ($failedTests -eq 0) {
    Write-Log "All tests passed!" "TEST"
    exit 0
} else {
    Write-Log "Some tests failed. Please review the report." "WARN"
    exit 1
}
