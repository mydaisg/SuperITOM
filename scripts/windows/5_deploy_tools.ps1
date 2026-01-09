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

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    
    if ($isAdmin) {
        Write-Log "Running with administrator privileges"
        return $true
    } else {
        Write-Log "Not running with administrator privileges" "ERROR"
        return $false
    }
}

function Copy-ToolsToSystem32 {
    param(
        [string]$SourcePath,
        [string]$LogPath
    )
    
    try {
        Write-Log "Deploying tools to System32..."
        
        $system32Path = $env:SystemRoot + "\System32"
        
        if (-not (Test-Path $SourcePath)) {
            Write-Log "Source path not found: $SourcePath" "ERROR"
            return $false
        }
        
        $toolFiles = Get-ChildItem -Path $SourcePath -File -ErrorAction Stop
        
        $successCount = 0
        $failCount = 0
        
        foreach ($tool in $toolFiles) {
            try {
                $destPath = Join-Path $system32Path $tool.Name
                
                if (Test-Path $destPath) {
                    Write-Log "Tool already exists, overwriting: $($tool.Name)"
                    Remove-Item -Path $destPath -Force -ErrorAction Stop
                }
                
                Copy-Item -Path $tool.FullName -Destination $destPath -Force -ErrorAction Stop
                Write-Log "Deployed tool: $($tool.Name)"
                $successCount++
                
                $logEntry = @"
Tool Deployment
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Tool: $($tool.Name)
Source: $($tool.FullName)
Destination: $destPath
Status: Success
"@
                
                Add-Content -Path $LogPath -Value $logEntry
            } catch {
                Write-Log "Failed to deploy tool $($tool.Name): $_" "ERROR"
                $failCount++
            }
        }
        
        Write-Log "Tool deployment summary: $successCount succeeded, $failCount failed"
        return $failCount -eq 0
    } catch {
        Write-Log "Tool deployment failed: $_" "ERROR"
        return $false
    }
}

function Copy-SysinternalsTools {
    param(
        [string]$SourcePath,
        [string]$LogPath
    )
    
    try {
        Write-Log "Deploying Sysinternals tools..."
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        
        if (-not (Test-Path $sysinternalsPath)) {
            New-Item -Path $sysinternalsPath -ItemType Directory -Force | Out-Null
            Write-Log "Created Sysinternals directory: $sysinternalsPath"
        }
        
        if (-not (Test-Path $SourcePath)) {
            Write-Log "Source path not found: $SourcePath" "ERROR"
            return $false
        }
        
        Copy-Item -Path "$SourcePath\*" -Destination $sysinternalsPath -Recurse -Force -ErrorAction Stop
        Write-Log "Deployed Sysinternals tools to: $sysinternalsPath"
        
        $logEntry = @"
Sysinternals Deployment
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Source: $SourcePath
Destination: $sysinternalsPath
Status: Success
"@
        
        Add-Content -Path $LogPath -Value $logEntry
        return $true
    } catch {
        Write-Log "Sysinternals deployment failed: $_" "ERROR"
        return $false
    }
}

function Update-PathEnvironment {
    param(
        [string]$PathToAdd,
        [string]$LogPath
    )
    
    try {
        Write-Log "Updating PATH environment variable..."
        
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        
        if ($currentPath -notlike "*$PathToAdd*") {
            $newPath = $currentPath + ";" + $PathToAdd
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            Write-Log "Added to PATH: $PathToAdd"
            
            $logEntry = @"
PATH Update
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Path Added: $PathToAdd
Status: Success
"@
            
            Add-Content -Path $LogPath -Value $logEntry
            return $true
        } else {
            Write-Log "Path already exists in PATH: $PathToAdd" "WARN"
            return $true
        }
    } catch {
        Write-Log "Failed to update PATH: $_" "ERROR"
        return $false
    }
}

function Test-ToolDeployment {
    param(
        [string]$ToolName
    )
    
    try {
        $result = Get-Command $ToolName -ErrorAction SilentlyContinue
        if ($result) {
            Write-Log "Tool verified: $ToolName at $($result.Source)"
            return $true
        } else {
            Write-Log "Tool not found: $ToolName" "WARN"
            return $false
        }
    } catch {
        Write-Log "Tool verification failed for $ToolName : $_" "ERROR"
        return $false
    }
}

function Verify-Deployment {
    param(
        [string]$LogPath
    )
    
    try {
        Write-Log "Verifying tool deployment..."
        
        $toolsToVerify = @(
            "putty.exe",
            "pscp.exe",
            "plink.exe"
        )
        
        $verificationResults = @()
        
        foreach ($tool in $toolsToVerify) {
            $result = Test-ToolDeployment -ToolName $tool
            if ($result) {
                $verificationResults += "${tool}: OK"
            } else {
                $verificationResults += "${tool}: MISSING"
            }
        }
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        if (Test-Path $sysinternalsPath) {
            $sysinternalsCount = (Get-ChildItem -Path $sysinternalsPath -File).Count
            Write-Log "Sysinternals tools verified: $sysinternalsCount tools"
            $verificationResults += "Sysinternals: OK ($sysinternalsCount tools)"
        } else {
            $verificationResults += "Sysinternals: MISSING"
        }
        
        $logEntry = @"

========================================
DEPLOYMENT VERIFICATION
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Verification Results:
$($verificationResults -join "`n")

========================================
END OF VERIFICATION
========================================
"@
        
        Add-Content -Path $LogPath -Value $logEntry
        Write-Log "Deployment verification completed"
        return $verificationResults
    } catch {
        Write-Log "Deployment verification failed: $_" "ERROR"
        return $null
    }
}

function Write-ToolsDeploymentLog {
    param(
        [string]$LogPath,
        [hashtable]$Data
    )
    
    try {
        $logContent = @"
========================================
TOOLS DEPLOYMENT LOG
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Hostname: $env:COMPUTERNAME

========================================
DEPLOYMENT SUMMARY
========================================
PuTTY Tools: $($Data.PuttyToolsStatus)
Sysinternals Tools: $($Data.SysinternalsStatus)
PATH Update: $($Data.PathUpdateStatus)

========================================
DEPLOYMENT DETAILS
========================================
PuTTY Source: $($Data.PuttySource)
Sysinternals Source: $($Data.SysinternalsSource)
System32 Path: $($Data.System32Path)

========================================
VERIFICATION RESULTS
========================================
$($Data.VerificationResults -join "`n")

========================================
END OF LOG
========================================
"@
        
        Set-Content -Path $LogPath -Value $logContent -Encoding UTF8
        Write-Log "Tools deployment log written to: $LogPath"
        return $true
    } catch {
        Write-Log "Failed to write tools deployment log: $_" "ERROR"
        return $false
    }
}

function Upload-Log {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$Prefix
    )
    
    try {
        if (-not (Test-Path $SourcePath)) {
            Write-Log "Source file not found: $SourcePath" "ERROR"
            return $false
        }
        
        if (-not (Test-Path $DestPath)) {
            Write-Log "Destination path not found: $DestPath" "ERROR"
            return $false
        }
        
        $filename = Split-Path $SourcePath -Leaf
        $destFile = Join-Path $DestPath "${Prefix}_${filename}"
        
        Copy-Item -Path $SourcePath -Destination $destFile -Force -ErrorAction Stop
        Write-Log "Log uploaded to: $destFile"
        return $true
    } catch {
        Write-Log "Failed to upload log: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$localDir = $config.paths.local_work_dir

Write-Log "=== Starting Tools Deployment ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$adminCheck = Test-AdminPrivileges
if (-not $adminCheck) {
    Write-Log "This script requires administrator privileges" "ERROR"
    Write-Log "Please run as administrator" "ERROR"
    exit 1
}

$toolsDir = Join-Path $localDir "tools"
$puttyToolsPath = Join-Path $toolsDir $config.paths.putty_tools
$sysinternalsPath = Join-Path $toolsDir $config.paths.sysinternals

$toolsDeploymentLog = Join-Path $localDir "5_Tools.log"

$puttyToolsStatus = "Failed"
$sysinternalsStatus = "Failed"
$pathUpdateStatus = "Failed"

if (Test-Path $puttyToolsPath) {
    $puttyResult = Copy-ToolsToSystem32 -SourcePath $puttyToolsPath -LogPath $toolsDeploymentLog
    if ($puttyResult) {
        $puttyToolsStatus = "Success"
    }
} else {
    Write-Log "PuTTY tools not found at: $puttyToolsPath" "WARN"
}

if (Test-Path $sysinternalsPath) {
    $sysinternalsResult = Copy-SysinternalsTools -SourcePath $sysinternalsPath -LogPath $toolsDeploymentLog
    if ($sysinternalsResult) {
        $sysinternalsStatus = "Success"
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        $pathResult = Update-PathEnvironment -PathToAdd $sysinternalsPath -LogPath $toolsDeploymentLog
        if ($pathResult) {
            $pathUpdateStatus = "Success"
        }
    }
} else {
    Write-Log "Sysinternals tools not found at: $sysinternalsPath" "WARN"
}

$verificationResults = Verify-Deployment -LogPath $toolsDeploymentLog

$logData = @{
    PuttyToolsStatus = $puttyToolsStatus
    SysinternalsStatus = $sysinternalsStatus
    PathUpdateStatus = $pathUpdateStatus
    PuttySource = $puttyToolsPath
    SysinternalsSource = $sysinternalsPath
    System32Path = $env:SystemRoot + "\System32"
    VerificationResults = $verificationResults
}

Write-ToolsDeploymentLog -LogPath $toolsDeploymentLog -Data $logData

$logUploadPath = $config.paths.log_upload_path
$uploadResult = Upload-Log -SourcePath $toolsDeploymentLog -DestPath $logUploadPath -Prefix $env:COMPUTERNAME

if ($uploadResult) {
    Write-Log "=== Tools Deployment Completed ==="
    exit 0
} else {
    Write-Log "=== Tools Deployment Completed but Upload Failed ===" "ERROR"
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

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    
    if ($isAdmin) {
        Write-Log "Running with administrator privileges"
        return $true
    } else {
        Write-Log "Not running with administrator privileges" "ERROR"
        return $false
    }
}

function Copy-ToolsToSystem32 {
    param(
        [string]$SourcePath,
        [string]$LogPath
    )
    
    try {
        Write-Log "Deploying tools to System32..."
        
        $system32Path = $env:SystemRoot + "\System32"
        
        if (-not (Test-Path $SourcePath)) {
            Write-Log "Source path not found: $SourcePath" "ERROR"
            return $false
        }
        
        $toolFiles = Get-ChildItem -Path $SourcePath -File -ErrorAction Stop
        
        $successCount = 0
        $failCount = 0
        
        foreach ($tool in $toolFiles) {
            try {
                $destPath = Join-Path $system32Path $tool.Name
                
                if (Test-Path $destPath) {
                    Write-Log "Tool already exists, overwriting: $($tool.Name)"
                    Remove-Item -Path $destPath -Force -ErrorAction Stop
                }
                
                Copy-Item -Path $tool.FullName -Destination $destPath -Force -ErrorAction Stop
                Write-Log "Deployed tool: $($tool.Name)"
                $successCount++
                
                $logEntry = @"
Tool Deployment
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Tool: $($tool.Name)
Source: $($tool.FullName)
Destination: $destPath
Status: Success
"@
                
                Add-Content -Path $LogPath -Value $logEntry
            } catch {
                Write-Log "Failed to deploy tool $($tool.Name): $_" "ERROR"
                $failCount++
            }
        }
        
        Write-Log "Tool deployment summary: $successCount succeeded, $failCount failed"
        return $failCount -eq 0
    } catch {
        Write-Log "Tool deployment failed: $_" "ERROR"
        return $false
    }
}

function Copy-SysinternalsTools {
    param(
        [string]$SourcePath,
        [string]$LogPath
    )
    
    try {
        Write-Log "Deploying Sysinternals tools..."
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        
        if (-not (Test-Path $sysinternalsPath)) {
            New-Item -Path $sysinternalsPath -ItemType Directory -Force | Out-Null
            Write-Log "Created Sysinternals directory: $sysinternalsPath"
        }
        
        if (-not (Test-Path $SourcePath)) {
            Write-Log "Source path not found: $SourcePath" "ERROR"
            return $false
        }
        
        Copy-Item -Path "$SourcePath\*" -Destination $sysinternalsPath -Recurse -Force -ErrorAction Stop
        Write-Log "Deployed Sysinternals tools to: $sysinternalsPath"
        
        $logEntry = @"
Sysinternals Deployment
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Source: $SourcePath
Destination: $sysinternalsPath
Status: Success
"@
        
        Add-Content -Path $LogPath -Value $logEntry
        return $true
    } catch {
        Write-Log "Sysinternals deployment failed: $_" "ERROR"
        return $false
    }
}

function Update-PathEnvironment {
    param(
        [string]$PathToAdd,
        [string]$LogPath
    )
    
    try {
        Write-Log "Updating PATH environment variable..."
        
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        
        if ($currentPath -notlike "*$PathToAdd*") {
            $newPath = $currentPath + ";" + $PathToAdd
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            Write-Log "Added to PATH: $PathToAdd"
            
            $logEntry = @"
PATH Update
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Path Added: $PathToAdd
Status: Success
"@
            
            Add-Content -Path $LogPath -Value $logEntry
            return $true
        } else {
            Write-Log "Path already exists in PATH: $PathToAdd" "WARN"
            return $true
        }
    } catch {
        Write-Log "Failed to update PATH: $_" "ERROR"
        return $false
    }
}

function Test-ToolDeployment {
    param(
        [string]$ToolName
    )
    
    try {
        $result = Get-Command $ToolName -ErrorAction SilentlyContinue
        if ($result) {
            Write-Log "Tool verified: $ToolName at $($result.Source)"
            return $true
        } else {
            Write-Log "Tool not found: $ToolName" "WARN"
            return $false
        }
    } catch {
        Write-Log "Tool verification failed for $ToolName : $_" "ERROR"
        return $false
    }
}

function Verify-Deployment {
    param(
        [string]$LogPath
    )
    
    try {
        Write-Log "Verifying tool deployment..."
        
        $toolsToVerify = @(
            "putty.exe",
            "pscp.exe",
            "plink.exe"
        )
        
        $verificationResults = @()
        
        foreach ($tool in $toolsToVerify) {
            $result = Test-ToolDeployment -ToolName $tool
            if ($result) {
                $verificationResults += "${tool}: OK"
            } else {
                $verificationResults += "${tool}: MISSING"
            }
        }
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        if (Test-Path $sysinternalsPath) {
            $sysinternalsCount = (Get-ChildItem -Path $sysinternalsPath -File).Count
            Write-Log "Sysinternals tools verified: $sysinternalsCount tools"
            $verificationResults += "Sysinternals: OK ($sysinternalsCount tools)"
        } else {
            $verificationResults += "Sysinternals: MISSING"
        }
        
        $logEntry = @"

========================================
DEPLOYMENT VERIFICATION
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Verification Results:
$($verificationResults -join "`n")

========================================
END OF VERIFICATION
========================================
"@
        
        Add-Content -Path $LogPath -Value $logEntry
        Write-Log "Deployment verification completed"
        return $verificationResults
    } catch {
        Write-Log "Deployment verification failed: $_" "ERROR"
        return $null
    }
}

function Write-ToolsDeploymentLog {
    param(
        [string]$LogPath,
        [hashtable]$Data
    )
    
    try {
        $logContent = @"
========================================
TOOLS DEPLOYMENT LOG
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Hostname: $env:COMPUTERNAME

========================================
DEPLOYMENT SUMMARY
========================================
PuTTY Tools: $($Data.PuttyToolsStatus)
Sysinternals Tools: $($Data.SysinternalsStatus)
PATH Update: $($Data.PathUpdateStatus)

========================================
DEPLOYMENT DETAILS
========================================
PuTTY Source: $($Data.PuttySource)
Sysinternals Source: $($Data.SysinternalsSource)
System32 Path: $($Data.System32Path)

========================================
VERIFICATION RESULTS
========================================
$($Data.VerificationResults -join "`n")

========================================
END OF LOG
========================================
"@
        
        Set-Content -Path $LogPath -Value $logContent -Encoding UTF8
        Write-Log "Tools deployment log written to: $LogPath"
        return $true
    } catch {
        Write-Log "Failed to write tools deployment log: $_" "ERROR"
        return $false
    }
}

function Upload-Log {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$Prefix
    )
    
    try {
        if (-not (Test-Path $SourcePath)) {
            Write-Log "Source file not found: $SourcePath" "ERROR"
            return $false
        }
        
        if (-not (Test-Path $DestPath)) {
            Write-Log "Destination path not found: $DestPath" "ERROR"
            return $false
        }
        
        $filename = Split-Path $SourcePath -Leaf
        $destFile = Join-Path $DestPath "${Prefix}_${filename}"
        
        Copy-Item -Path $SourcePath -Destination $destFile -Force -ErrorAction Stop
        Write-Log "Log uploaded to: $destFile"
        return $true
    } catch {
        Write-Log "Failed to upload log: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$localDir = $config.paths.local_work_dir

Write-Log "=== Starting Tools Deployment ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$adminCheck = Test-AdminPrivileges
if (-not $adminCheck) {
    Write-Log "This script requires administrator privileges" "ERROR"
    Write-Log "Please run as administrator" "ERROR"
    exit 1
}

$toolsDir = Join-Path $localDir "tools"
$puttyToolsPath = Join-Path $toolsDir $config.paths.putty_tools
$sysinternalsPath = Join-Path $toolsDir $config.paths.sysinternals

$toolsDeploymentLog = Join-Path $localDir "5_Tools.log"

$puttyToolsStatus = "Failed"
$sysinternalsStatus = "Failed"
$pathUpdateStatus = "Failed"

if (Test-Path $puttyToolsPath) {
    $puttyResult = Copy-ToolsToSystem32 -SourcePath $puttyToolsPath -LogPath $toolsDeploymentLog
    if ($puttyResult) {
        $puttyToolsStatus = "Success"
    }
} else {
    Write-Log "PuTTY tools not found at: $puttyToolsPath" "WARN"
}

if (Test-Path $sysinternalsPath) {
    $sysinternalsResult = Copy-SysinternalsTools -SourcePath $sysinternalsPath -LogPath $toolsDeploymentLog
    if ($sysinternalsResult) {
        $sysinternalsStatus = "Success"
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        $pathResult = Update-PathEnvironment -PathToAdd $sysinternalsPath -LogPath $toolsDeploymentLog
        if ($pathResult) {
            $pathUpdateStatus = "Success"
        }
    }
} else {
    Write-Log "Sysinternals tools not found at: $sysinternalsPath" "WARN"
}

$verificationResults = Verify-Deployment -LogPath $toolsDeploymentLog

$logData = @{
    PuttyToolsStatus = $puttyToolsStatus
    SysinternalsStatus = $sysinternalsStatus
    PathUpdateStatus = $pathUpdateStatus
    PuttySource = $puttyToolsPath
    SysinternalsSource = $sysinternalsPath
    System32Path = $env:SystemRoot + "\System32"
    VerificationResults = $verificationResults
}

Write-ToolsDeploymentLog -LogPath $toolsDeploymentLog -Data $logData

$logUploadPath = $config.paths.log_upload_path
$uploadResult = Upload-Log -SourcePath $toolsDeploymentLog -DestPath $logUploadPath -Prefix $env:COMPUTERNAME

if ($uploadResult) {
    Write-Log "=== Tools Deployment Completed ==="
    exit 0
} else {
    Write-Log "=== Tools Deployment Completed but Upload Failed ===" "ERROR"
    exit 1
}


function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    
    if ($isAdmin) {
        Write-Log "Running with administrator privileges"
        return $true
    } else {
        Write-Log "Not running with administrator privileges" "ERROR"
        return $false
    }
}

function Copy-ToolsToSystem32 {
    param(
        [string]$SourcePath,
        [string]$LogPath
    )
    
    try {
        Write-Log "Deploying tools to System32..."
        
        $system32Path = $env:SystemRoot + "\System32"
        
        if (-not (Test-Path $SourcePath)) {
            Write-Log "Source path not found: $SourcePath" "ERROR"
            return $false
        }
        
        $toolFiles = Get-ChildItem -Path $SourcePath -File -ErrorAction Stop
        
        $successCount = 0
        $failCount = 0
        
        foreach ($tool in $toolFiles) {
            try {
                $destPath = Join-Path $system32Path $tool.Name
                
                if (Test-Path $destPath) {
                    Write-Log "Tool already exists, overwriting: $($tool.Name)"
                    Remove-Item -Path $destPath -Force -ErrorAction Stop
                }
                
                Copy-Item -Path $tool.FullName -Destination $destPath -Force -ErrorAction Stop
                Write-Log "Deployed tool: $($tool.Name)"
                $successCount++
                
                $logEntry = @"
Tool Deployment
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Tool: $($tool.Name)
Source: $($tool.FullName)
Destination: $destPath
Status: Success
"@
                
                Add-Content -Path $LogPath -Value $logEntry
            } catch {
                Write-Log "Failed to deploy tool $($tool.Name): $_" "ERROR"
                $failCount++
            }
        }
        
        Write-Log "Tool deployment summary: $successCount succeeded, $failCount failed"
        return $failCount -eq 0
    } catch {
        Write-Log "Tool deployment failed: $_" "ERROR"
        return $false
    }
}

function Copy-SysinternalsTools {
    param(
        [string]$SourcePath,
        [string]$LogPath
    )
    
    try {
        Write-Log "Deploying Sysinternals tools..."
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        
        if (-not (Test-Path $sysinternalsPath)) {
            New-Item -Path $sysinternalsPath -ItemType Directory -Force | Out-Null
            Write-Log "Created Sysinternals directory: $sysinternalsPath"
        }
        
        if (-not (Test-Path $SourcePath)) {
            Write-Log "Source path not found: $SourcePath" "ERROR"
            return $false
        }
        
        Copy-Item -Path "$SourcePath\*" -Destination $sysinternalsPath -Recurse -Force -ErrorAction Stop
        Write-Log "Deployed Sysinternals tools to: $sysinternalsPath"
        
        $logEntry = @"
Sysinternals Deployment
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Source: $SourcePath
Destination: $sysinternalsPath
Status: Success
"@
        
        Add-Content -Path $LogPath -Value $logEntry
        return $true
    } catch {
        Write-Log "Sysinternals deployment failed: $_" "ERROR"
        return $false
    }
}

function Update-PathEnvironment {
    param(
        [string]$PathToAdd,
        [string]$LogPath
    )
    
    try {
        Write-Log "Updating PATH environment variable..."
        
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        
        if ($currentPath -notlike "*$PathToAdd*") {
            $newPath = $currentPath + ";" + $PathToAdd
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            Write-Log "Added to PATH: $PathToAdd"
            
            $logEntry = @"
PATH Update
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Path Added: $PathToAdd
Status: Success
"@
            
            Add-Content -Path $LogPath -Value $logEntry
            return $true
        } else {
            Write-Log "Path already exists in PATH: $PathToAdd" "WARN"
            return $true
        }
    } catch {
        Write-Log "Failed to update PATH: $_" "ERROR"
        return $false
    }
}

function Test-ToolDeployment {
    param(
        [string]$ToolName
    )
    
    try {
        $result = Get-Command $ToolName -ErrorAction SilentlyContinue
        if ($result) {
            Write-Log "Tool verified: $ToolName at $($result.Source)"
            return $true
        } else {
            Write-Log "Tool not found: $ToolName" "WARN"
            return $false
        }
    } catch {
        Write-Log "Tool verification failed for $ToolName : $_" "ERROR"
        return $false
    }
}

function Verify-Deployment {
    param(
        [string]$LogPath
    )
    
    try {
        Write-Log "Verifying tool deployment..."
        
        $toolsToVerify = @(
            "putty.exe",
            "pscp.exe",
            "plink.exe"
        )
        
        $verificationResults = @()
        
        foreach ($tool in $toolsToVerify) {
            $result = Test-ToolDeployment -ToolName $tool
            if ($result) {
                $verificationResults += "${tool}: OK"
            } else {
                $verificationResults += "${tool}: MISSING"
            }
        }
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        if (Test-Path $sysinternalsPath) {
            $sysinternalsCount = (Get-ChildItem -Path $sysinternalsPath -File).Count
            Write-Log "Sysinternals tools verified: $sysinternalsCount tools"
            $verificationResults += "Sysinternals: OK ($sysinternalsCount tools)"
        } else {
            $verificationResults += "Sysinternals: MISSING"
        }
        
        $logEntry = @"

========================================
DEPLOYMENT VERIFICATION
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Verification Results:
$($verificationResults -join "`n")

========================================
END OF VERIFICATION
========================================
"@
        
        Add-Content -Path $LogPath -Value $logEntry
        Write-Log "Deployment verification completed"
        return $verificationResults
    } catch {
        Write-Log "Deployment verification failed: $_" "ERROR"
        return $null
    }
}

function Write-ToolsDeploymentLog {
    param(
        [string]$LogPath,
        [hashtable]$Data
    )
    
    try {
        $logContent = @"
========================================
TOOLS DEPLOYMENT LOG
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Hostname: $env:COMPUTERNAME

========================================
DEPLOYMENT SUMMARY
========================================
PuTTY Tools: $($Data.PuttyToolsStatus)
Sysinternals Tools: $($Data.SysinternalsStatus)
PATH Update: $($Data.PathUpdateStatus)

========================================
DEPLOYMENT DETAILS
========================================
PuTTY Source: $($Data.PuttySource)
Sysinternals Source: $($Data.SysinternalsSource)
System32 Path: $($Data.System32Path)

========================================
VERIFICATION RESULTS
========================================
$($Data.VerificationResults -join "`n")

========================================
END OF LOG
========================================
"@
        
        Set-Content -Path $LogPath -Value $logContent -Encoding UTF8
        Write-Log "Tools deployment log written to: $LogPath"
        return $true
    } catch {
        Write-Log "Failed to write tools deployment log: $_" "ERROR"
        return $false
    }
}

function Upload-Log {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$Prefix
    )
    
    try {
        if (-not (Test-Path $SourcePath)) {
            Write-Log "Source file not found: $SourcePath" "ERROR"
            return $false
        }
        
        if (-not (Test-Path $DestPath)) {
            Write-Log "Destination path not found: $DestPath" "ERROR"
            return $false
        }
        
        $filename = Split-Path $SourcePath -Leaf
        $destFile = Join-Path $DestPath "${Prefix}_${filename}"
        
        Copy-Item -Path $SourcePath -Destination $destFile -Force -ErrorAction Stop
        Write-Log "Log uploaded to: $destFile"
        return $true
    } catch {
        Write-Log "Failed to upload log: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$localDir = $config.paths.local_work_dir

Write-Log "=== Starting Tools Deployment ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$adminCheck = Test-AdminPrivileges
if (-not $adminCheck) {
    Write-Log "This script requires administrator privileges" "ERROR"
    Write-Log "Please run as administrator" "ERROR"
    exit 1
}

$toolsDir = Join-Path $localDir "tools"
$puttyToolsPath = Join-Path $toolsDir $config.paths.putty_tools
$sysinternalsPath = Join-Path $toolsDir $config.paths.sysinternals

$toolsDeploymentLog = Join-Path $localDir "5_Tools.log"

$puttyToolsStatus = "Failed"
$sysinternalsStatus = "Failed"
$pathUpdateStatus = "Failed"

if (Test-Path $puttyToolsPath) {
    $puttyResult = Copy-ToolsToSystem32 -SourcePath $puttyToolsPath -LogPath $toolsDeploymentLog
    if ($puttyResult) {
        $puttyToolsStatus = "Success"
    }
} else {
    Write-Log "PuTTY tools not found at: $puttyToolsPath" "WARN"
}

if (Test-Path $sysinternalsPath) {
    $sysinternalsResult = Copy-SysinternalsTools -SourcePath $sysinternalsPath -LogPath $toolsDeploymentLog
    if ($sysinternalsResult) {
        $sysinternalsStatus = "Success"
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        $pathResult = Update-PathEnvironment -PathToAdd $sysinternalsPath -LogPath $toolsDeploymentLog
        if ($pathResult) {
            $pathUpdateStatus = "Success"
        }
    }
} else {
    Write-Log "Sysinternals tools not found at: $sysinternalsPath" "WARN"
}

$verificationResults = Verify-Deployment -LogPath $toolsDeploymentLog

$logData = @{
    PuttyToolsStatus = $puttyToolsStatus
    SysinternalsStatus = $sysinternalsStatus
    PathUpdateStatus = $pathUpdateStatus
    PuttySource = $puttyToolsPath
    SysinternalsSource = $sysinternalsPath
    System32Path = $env:SystemRoot + "\System32"
    VerificationResults = $verificationResults
}

Write-ToolsDeploymentLog -LogPath $toolsDeploymentLog -Data $logData

$logUploadPath = $config.paths.log_upload_path
$uploadResult = Upload-Log -SourcePath $toolsDeploymentLog -DestPath $logUploadPath -Prefix $env:COMPUTERNAME

if ($uploadResult) {
    Write-Log "=== Tools Deployment Completed ==="
    exit 0
} else {
    Write-Log "=== Tools Deployment Completed but Upload Failed ===" "ERROR"
    exit 1
}



