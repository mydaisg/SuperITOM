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
        $config = Get-Content $Path | ConvertFrom-Json
        $hashtable = @{}
        $config.PSObject.Properties | ForEach-Object {
            $hashtable[$_.Name] = $_.Value
        }
        return $hashtable
    } else {
        Write-Log "Config file not found: $Path" "ERROR"
        exit 1
    }
}

function Copy-FromSource {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$ItemName
    )
    
    try {
        $sourceItem = Join-Path $SourcePath $ItemName
        
        if (-not (Test-Path $sourceItem)) {
            Write-Log "Source item not found: $sourceItem" "WARN"
            return $false
        }
        
        $destItem = Join-Path $DestPath $ItemName
        
        if (Test-Path $sourceItem -PathType Container) {
            if (Test-Path $destItem) {
                Remove-Item -Path $destItem -Recurse -Force -ErrorAction Stop
            }
            Copy-Item -Path $sourceItem -Destination $destPath -Recurse -Force -ErrorAction Stop
            Write-Log "Copied directory: $ItemName"
        } else {
            Copy-Item -Path $sourceItem -Destination $destPath -Force -ErrorAction Stop
            Write-Log "Copied file: $ItemName"
        }
        
        return $true
    } catch {
        Write-Log "Failed to copy $ItemName : $_" "ERROR"
        return $false
    }
}

function Deploy-Tools {
    param(
        [hashtable]$Config,
        [string]$LocalDir
    )
    
    try {
        Write-Log "Starting tools deployment..."
        
        $dfsShare = $Config.paths.dfs_share
        $localBackup = $Config.paths.local_dfs_backup
        
        $toolsDir = Join-Path $LocalDir "tools"
        if (-not (Test-Path $toolsDir)) {
            New-Item -Path $toolsDir -ItemType Directory -Force | Out-Null
            Write-Log "Created tools directory: $toolsDir"
        }
        
        $scriptsDir = Join-Path $LocalDir "scripts"
        if (-not (Test-Path $scriptsDir)) {
            New-Item -Path $scriptsDir -ItemType Directory -Force | Out-Null
            Write-Log "Created scripts directory: $scriptsDir"
        }
        
        $sourcePath = ""
        if (Test-DFSAccess -DFSPath $dfsShare) {
            $sourcePath = $dfsShare
            Write-Log "Using DFS share as source"
        } elseif (Test-Path $localBackup) {
            $sourcePath = $localBackup
            Write-Log "Using local backup as source"
        } else {
            Write-Log "No source available for deployment" "ERROR"
            return $false
        }
        
        $itemsToDeploy = @(
            $Config.paths.putty_tools,
            $Config.paths.sysinternals,
            "scripts"
        )
        
        $successCount = 0
        $failCount = 0
        
        foreach ($item in $itemsToDeploy) {
            $result = Copy-FromSource -SourcePath $sourcePath -DestPath $toolsDir -ItemName $item
            if ($result) {
                $successCount++
            } else {
                $failCount++
            }
        }
        
        Write-Log "Deployment summary: $successCount succeeded, $failCount failed"
        
        return $failCount -eq 0
    } catch {
        Write-Log "Tools deployment failed: $_" "ERROR"
        return $false
    }
}

function Verify-Deployment {
    param(
        [string]$LocalDir,
        [hashtable]$Config
    )
    
    try {
        Write-Log "Verifying deployment..."
        
        $toolsDir = Join-Path $LocalDir "tools"
        
        $puttyPath = Join-Path $toolsDir $Config.paths.putty_tools
        $sysinternalsPath = Join-Path $toolsDir $Config.paths.sysinternals
        
        $verificationResults = @()
        
        if (Test-Path $puttyPath) {
            Write-Log "PuTTY tools verified: $puttyPath"
            $verificationResults += "PuTTY: OK"
        } else {
            Write-Log "PuTTY tools not found" "WARN"
            $verificationResults += "PuTTY: MISSING"
        }
        
        if (Test-Path $sysinternalsPath) {
            Write-Log "Sysinternals tools verified: $sysinternalsPath"
            $verificationResults += "Sysinternals: OK"
        } else {
            Write-Log "Sysinternals tools not found" "WARN"
            $verificationResults += "Sysinternals: MISSING"
        }
        
        $scriptsDir = Join-Path $LocalDir "scripts"
        if (Test-Path $scriptsDir) {
            Write-Log "Scripts directory verified: $scriptsDir"
            $verificationResults += "Scripts: OK"
        } else {
            Write-Log "Scripts directory not found" "WARN"
            $verificationResults += "Scripts: MISSING"
        }
        
        return $verificationResults -join "; "
    } catch {
        Write-Log "Deployment verification failed: $_" "ERROR"
        return "Verification failed"
    }
}

function Write-DeploymentLog {
    param(
        [string]$LogPath,
        [string]$VerificationResult
    )
    
    try {
        $logContent = @"
DML Deployment Log
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Deployment Status: Success
Verification Result: $VerificationResult
"@
        
        Set-Content -Path $LogPath -Value $logContent
        Write-Log "Deployment log written to: $LogPath"
        return $true
    } catch {
        Write-Log "Failed to write deployment log: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$localDir = $config.paths.local_work_dir

Write-Log "=== Starting DML Deployment ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$deployResult = Deploy-Tools -Config $config -LocalDir $localDir

if ($deployResult) {
    $verificationResult = Verify-Deployment -LocalDir $localDir -Config $config
    
    $logFile = Join-Path $localDir "2_deploy.log"
    Write-DeploymentLog -LogPath $logFile -VerificationResult $verificationResult
    
    Write-Log "=== DML Deployment Completed Successfully ==="
    exit 0
} else {
    Write-Log "=== DML Deployment Failed ===" "ERROR"
    exit 1
}

