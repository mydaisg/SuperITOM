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

function Create-LocalDirectory {
    param(
        [string]$Path,
        [string]$Description
    )
    
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-Log "Created directory: $Path"
            
            $readmePath = Join-Path $Path "README.txt"
            $readmeContent = @"
$Description
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Purpose: Local working directory for DML deployment and management

Directory Structure:
- Logs: Deployment and operation logs
- Scripts: Local execution scripts
- Temp: Temporary files

DO NOT DELETE THIS DIRECTORY
"@
            Set-Content -Path $readmePath -Value $readmeContent
            Write-Log "Created README.txt in $Path"
            
            $hidden = Get-Item $Path
            $hidden.Attributes = $hidden.Attributes -bor [System.IO.FileAttributes]::Hidden
            Write-Log "Set directory as hidden"
            
            return $true
        } else {
            Write-Log "Directory already exists: $Path" "WARN"
            return $false
        }
    } catch {
        Write-Log "Failed to create directory: $_" "ERROR"
        return $false
    }
}

function Test-DirectoryAccess {
    param([string]$Path)
    
    try {
        $testFile = Join-Path $Path "test_access.tmp"
        Set-Content -Path $testFile -Value "test"
        Remove-Item -Path $testFile -Force
        Write-Log "Directory access test passed: $Path"
        return $true
    } catch {
        Write-Log "Directory access test failed: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$localDir = $config.paths.local_work_dir

Write-Log "=== Starting Local Directory Creation ==="
Write-Log "Target directory: $localDir"

$result = Create-LocalDirectory -Path $localDir -Description "LVCC DML Local Working Directory"

if ($result) {
    $testResult = Test-DirectoryAccess -Path $localDir
    
    if ($testResult) {
        Write-Log "=== Local Directory Creation Completed Successfully ==="
        exit 0
    } else {
        Write-Log "=== Local Directory Creation Failed (Access Test) ===" "ERROR"
        exit 1
    }
} else {
    Write-Log "=== Local Directory Creation Failed ===" "ERROR"
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

function Create-LocalDirectory {
    param(
        [string]$Path,
        [string]$Description
    )
    
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-Log "Created directory: $Path"
            
            $readmePath = Join-Path $Path "README.txt"
            $readmeContent = @"
$Description
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Purpose: Local working directory for DML deployment and management

Directory Structure:
- Logs: Deployment and operation logs
- Scripts: Local execution scripts
- Temp: Temporary files

DO NOT DELETE THIS DIRECTORY
"@
            Set-Content -Path $readmePath -Value $readmeContent
            Write-Log "Created README.txt in $Path"
            
            $hidden = Get-Item $Path
            $hidden.Attributes = $hidden.Attributes -bor [System.IO.FileAttributes]::Hidden
            Write-Log "Set directory as hidden"
            
            return $true
        } else {
            Write-Log "Directory already exists: $Path" "WARN"
            return $false
        }
    } catch {
        Write-Log "Failed to create directory: $_" "ERROR"
        return $false
    }
}

function Test-DirectoryAccess {
    param([string]$Path)
    
    try {
        $testFile = Join-Path $Path "test_access.tmp"
        Set-Content -Path $testFile -Value "test"
        Remove-Item -Path $testFile -Force
        Write-Log "Directory access test passed: $Path"
        return $true
    } catch {
        Write-Log "Directory access test failed: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$localDir = $config.paths.local_work_dir

Write-Log "=== Starting Local Directory Creation ==="
Write-Log "Target directory: $localDir"

$result = Create-LocalDirectory -Path $localDir -Description "LVCC DML Local Working Directory"

if ($result) {
    $testResult = Test-DirectoryAccess -Path $localDir
    
    if ($testResult) {
        Write-Log "=== Local Directory Creation Completed Successfully ==="
        exit 0
    } else {
        Write-Log "=== Local Directory Creation Failed (Access Test) ===" "ERROR"
        exit 1
    }
} else {
    Write-Log "=== Local Directory Creation Failed ===" "ERROR"
    exit 1
}


function Create-LocalDirectory {
    param(
        [string]$Path,
        [string]$Description
    )
    
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-Log "Created directory: $Path"
            
            $readmePath = Join-Path $Path "README.txt"
            $readmeContent = @"
$Description
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Purpose: Local working directory for DML deployment and management

Directory Structure:
- Logs: Deployment and operation logs
- Scripts: Local execution scripts
- Temp: Temporary files

DO NOT DELETE THIS DIRECTORY
"@
            Set-Content -Path $readmePath -Value $readmeContent
            Write-Log "Created README.txt in $Path"
            
            $hidden = Get-Item $Path
            $hidden.Attributes = $hidden.Attributes -bor [System.IO.FileAttributes]::Hidden
            Write-Log "Set directory as hidden"
            
            return $true
        } else {
            Write-Log "Directory already exists: $Path" "WARN"
            return $false
        }
    } catch {
        Write-Log "Failed to create directory: $_" "ERROR"
        return $false
    }
}

function Test-DirectoryAccess {
    param([string]$Path)
    
    try {
        $testFile = Join-Path $Path "test_access.tmp"
        Set-Content -Path $testFile -Value "test"
        Remove-Item -Path $testFile -Force
        Write-Log "Directory access test passed: $Path"
        return $true
    } catch {
        Write-Log "Directory access test failed: $_" "ERROR"
        return $false
    }
}

$config = Get-Config -Path $ConfigPath
$localDir = $config.paths.local_work_dir

Write-Log "=== Starting Local Directory Creation ==="
Write-Log "Target directory: $localDir"

$result = Create-LocalDirectory -Path $localDir -Description "LVCC DML Local Working Directory"

if ($result) {
    $testResult = Test-DirectoryAccess -Path $localDir
    
    if ($testResult) {
        Write-Log "=== Local Directory Creation Completed Successfully ==="
        exit 0
    } else {
        Write-Log "=== Local Directory Creation Failed (Access Test) ===" "ERROR"
        exit 1
    }
} else {
    Write-Log "=== Local Directory Creation Failed ===" "ERROR"
    exit 1
}


