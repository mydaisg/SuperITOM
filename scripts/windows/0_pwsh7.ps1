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

function Test-DFSAccess {
    param([string]$DFSPath)
    
    try {
        if (Test-Path $DFSPath) {
            Write-Log "DFS share accessible: $DFSPath"
            return $true
        } else {
            Write-Log "DFS share not accessible: $DFSPath" "WARN"
            return $false
        }
    } catch {
        Write-Log "DFS access test failed: $_" "WARN"
        return $false
    }
}

function Install-PowerShell7 {
    param(
        [string]$InstallerPath,
        [string]$LogPath
    )
    
    try {
        if (-not (Test-Path $InstallerPath)) {
            Write-Log "Installer not found: $InstallerPath" "ERROR"
            return $false
        }
        
        $pwshVersion = pwsh -Version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "PowerShell 7 already installed: $pwshVersion"
            return $true
        }
        
        Write-Log "Installing PowerShell 7 from: $InstallerPath"
        
        $logFile = Join-Path $LogPath "pwsh7_install.log"
        $arguments = "/i `"$InstallerPath`" /quiet /norestart /L*V `"$logFile`""
        
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Log "PowerShell 7 installation completed successfully"
            
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            Start-Sleep -Seconds 5
            
            $pwshVersion = pwsh -Version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "PowerShell 7 installed successfully: $pwshVersion"
                return $true
            } else {
                Write-Log "PowerShell 7 installation verification failed" "ERROR"
                return $false
            }
        } else {
            Write-Log "PowerShell 7 installation failed with exit code: $($process.ExitCode)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "PowerShell 7 installation error: $_" "ERROR"
        return $false
    }
}

function Test-PowerShell7 {
    try {
        $version = pwsh -Version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "PowerShell 7 test passed: $version"
            
            $modules = pwsh -Command "Get-Module -ListAvailable | Select-Object Name, Version | ConvertTo-Json"
            Write-Log "Available modules: $modules"
            
            return $true
        } else {
            Write-Log "PowerShell 7 test failed" "ERROR"
            return $false
        }
    } catch {
        Write-Log "PowerShell 7 test error: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$localDir = $config.paths.local_work_dir

Write-Log "=== Starting PowerShell 7 Installation ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$dfsShare = $config.paths.dfs_share
$localBackup = $config.paths.local_dfs_backup
$installerName = $config.paths.pwsh7_installer

$installerPath = ""

if (Test-DFSAccess -DFSPath $dfsShare) {
    $installerPath = Join-Path $dfsShare $installerName
    Write-Log "Using DFS share for installer"
} elseif (Test-Path $localBackup) {
    $installerPath = Join-Path $localBackup $installerName
    Write-Log "Using local backup for installer"
} else {
    Write-Log "No installer source available" "ERROR"
    exit 1
}

$installResult = Install-PowerShell7 -InstallerPath $installerPath -LogPath $localDir

if ($installResult) {
    $testResult = Test-PowerShell7
    
    $logFile = Join-Path $localDir "1_ps.log"
    $logContent = @"
PowerShell 7 Installation Log
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Installer: $installerPath
Installation Status: Success
PowerShell Version: $(pwsh -Version 2>&1)
"@
    Set-Content -Path $logFile -Value $logContent
    Write-Log "Installation log written to: $logFile"
    
    if ($testResult) {
        Write-Log "=== PowerShell 7 Installation Completed Successfully ==="
        exit 0
    } else {
        Write-Log "=== PowerShell 7 Installation Completed but Tests Failed ===" "ERROR"
        exit 1
    }
} else {
    Write-Log "=== PowerShell 7 Installation Failed ===" "ERROR"
    exit 1
}
.Name] = param(
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

function Test-DFSAccess {
    param([string]$DFSPath)
    
    try {
        if (Test-Path $DFSPath) {
            Write-Log "DFS share accessible: $DFSPath"
            return $true
        } else {
            Write-Log "DFS share not accessible: $DFSPath" "WARN"
            return $false
        }
    } catch {
        Write-Log "DFS access test failed: $_" "WARN"
        return $false
    }
}

function Install-PowerShell7 {
    param(
        [string]$InstallerPath,
        [string]$LogPath
    )
    
    try {
        if (-not (Test-Path $InstallerPath)) {
            Write-Log "Installer not found: $InstallerPath" "ERROR"
            return $false
        }
        
        $pwshVersion = pwsh -Version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "PowerShell 7 already installed: $pwshVersion"
            return $true
        }
        
        Write-Log "Installing PowerShell 7 from: $InstallerPath"
        
        $logFile = Join-Path $LogPath "pwsh7_install.log"
        $arguments = "/i `"$InstallerPath`" /quiet /norestart /L*V `"$logFile`""
        
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Log "PowerShell 7 installation completed successfully"
            
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            Start-Sleep -Seconds 5
            
            $pwshVersion = pwsh -Version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "PowerShell 7 installed successfully: $pwshVersion"
                return $true
            } else {
                Write-Log "PowerShell 7 installation verification failed" "ERROR"
                return $false
            }
        } else {
            Write-Log "PowerShell 7 installation failed with exit code: $($process.ExitCode)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "PowerShell 7 installation error: $_" "ERROR"
        return $false
    }
}

function Test-PowerShell7 {
    try {
        $version = pwsh -Version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "PowerShell 7 test passed: $version"
            
            $modules = pwsh -Command "Get-Module -ListAvailable | Select-Object Name, Version | ConvertTo-Json"
            Write-Log "Available modules: $modules"
            
            return $true
        } else {
            Write-Log "PowerShell 7 test failed" "ERROR"
            return $false
        }
    } catch {
        Write-Log "PowerShell 7 test error: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$localDir = $config.paths.local_work_dir

Write-Log "=== Starting PowerShell 7 Installation ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$dfsShare = $config.paths.dfs_share
$localBackup = $config.paths.local_dfs_backup
$installerName = $config.paths.pwsh7_installer

$installerPath = ""

if (Test-DFSAccess -DFSPath $dfsShare) {
    $installerPath = Join-Path $dfsShare $installerName
    Write-Log "Using DFS share for installer"
} elseif (Test-Path $localBackup) {
    $installerPath = Join-Path $localBackup $installerName
    Write-Log "Using local backup for installer"
} else {
    Write-Log "No installer source available" "ERROR"
    exit 1
}

$installResult = Install-PowerShell7 -InstallerPath $installerPath -LogPath $localDir

if ($installResult) {
    $testResult = Test-PowerShell7
    
    $logFile = Join-Path $localDir "1_ps.log"
    $logContent = @"
PowerShell 7 Installation Log
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Installer: $installerPath
Installation Status: Success
PowerShell Version: $(pwsh -Version 2>&1)
"@
    Set-Content -Path $logFile -Value $logContent
    Write-Log "Installation log written to: $logFile"
    
    if ($testResult) {
        Write-Log "=== PowerShell 7 Installation Completed Successfully ==="
        exit 0
    } else {
        Write-Log "=== PowerShell 7 Installation Completed but Tests Failed ===" "ERROR"
        exit 1
    }
} else {
    Write-Log "=== PowerShell 7 Installation Failed ===" "ERROR"
    exit 1
}

function Test-DFSAccess {
    param([string]$DFSPath)
    
    try {
        if (Test-Path $DFSPath) {
            Write-Log "DFS share accessible: $DFSPath"
            return $true
        } else {
            Write-Log "DFS share not accessible: $DFSPath" "WARN"
            return $false
        }
    } catch {
        Write-Log "DFS access test failed: $_" "WARN"
        return $false
    }
}

function Install-PowerShell7 {
    param(
        [string]$InstallerPath,
        [string]$LogPath
    )
    
    try {
        if (-not (Test-Path $InstallerPath)) {
            Write-Log "Installer not found: $InstallerPath" "ERROR"
            return $false
        }
        
        $pwshVersion = pwsh -Version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "PowerShell 7 already installed: $pwshVersion"
            return $true
        }
        
        Write-Log "Installing PowerShell 7 from: $InstallerPath"
        
        $logFile = Join-Path $LogPath "pwsh7_install.log"
        $arguments = "/i `"$InstallerPath`" /quiet /norestart /L*V `"$logFile`""
        
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Log "PowerShell 7 installation completed successfully"
            
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            Start-Sleep -Seconds 5
            
            $pwshVersion = pwsh -Version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "PowerShell 7 installed successfully: $pwshVersion"
                return $true
            } else {
                Write-Log "PowerShell 7 installation verification failed" "ERROR"
                return $false
            }
        } else {
            Write-Log "PowerShell 7 installation failed with exit code: $($process.ExitCode)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "PowerShell 7 installation error: $_" "ERROR"
        return $false
    }
}

function Test-PowerShell7 {
    try {
        $version = pwsh -Version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "PowerShell 7 test passed: $version"
            
            $modules = pwsh -Command "Get-Module -ListAvailable | Select-Object Name, Version | ConvertTo-Json"
            Write-Log "Available modules: $modules"
            
            return $true
        } else {
            Write-Log "PowerShell 7 test failed" "ERROR"
            return $false
        }
    } catch {
        Write-Log "PowerShell 7 test error: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$localDir = $config.paths.local_work_dir

Write-Log "=== Starting PowerShell 7 Installation ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$dfsShare = $config.paths.dfs_share
$localBackup = $config.paths.local_dfs_backup
$installerName = $config.paths.pwsh7_installer

$installerPath = ""

if (Test-DFSAccess -DFSPath $dfsShare) {
    $installerPath = Join-Path $dfsShare $installerName
    Write-Log "Using DFS share for installer"
} elseif (Test-Path $localBackup) {
    $installerPath = Join-Path $localBackup $installerName
    Write-Log "Using local backup for installer"
} else {
    Write-Log "No installer source available" "ERROR"
    exit 1
}

$installResult = Install-PowerShell7 -InstallerPath $installerPath -LogPath $localDir

if ($installResult) {
    $testResult = Test-PowerShell7
    
    $logFile = Join-Path $localDir "1_ps.log"
    $logContent = @"
PowerShell 7 Installation Log
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Installer: $installerPath
Installation Status: Success
PowerShell Version: $(pwsh -Version 2>&1)
"@
    Set-Content -Path $logFile -Value $logContent
    Write-Log "Installation log written to: $logFile"
    
    if ($testResult) {
        Write-Log "=== PowerShell 7 Installation Completed Successfully ==="
        exit 0
    } else {
        Write-Log "=== PowerShell 7 Installation Completed but Tests Failed ===" "ERROR"
        exit 1
    }
} else {
    Write-Log "=== PowerShell 7 Installation Failed ===" "ERROR"
    exit 1
}


