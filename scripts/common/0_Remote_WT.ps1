# Remote Windows client initial installation and management
param(
    [string]$HostsFile = "D:\GitHub\SuperITOM\config\hosts_new.csv",
    [string]$TargetIP = "",
    [string]$TargetUser = "",
    [string]$TargetPassword = "",
    [string]$NewComputerName = "",
    [string]$ToolsPath = "D:\GitHub\SuperITOM\tools"
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

function Test-WinRMConnection {
    param(
        [string]$ComputerName,
        [string]$Username,
        [string]$Password
    )
    
    try {
        Write-Log "Testing WinRM connection to $ComputerName"
        
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)
        
        $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
        
        $session = New-PSSession -ComputerName $ComputerName -Credential $credential -SessionOption $sessionOption -ErrorAction Stop
        
        if ($session) {
            Write-Log "Successfully connected to $ComputerName"
            return $session
        } else {
            Write-Log "Failed to create session to $ComputerName" "ERROR"
            return $null
        }
    } catch {
        Write-Log "WinRM connection failed for $ComputerName : $_" "ERROR"
        return $null
    }
}

function Get-SystemInfo {
    param([System.Management.Automation.Runspaces.PSSession]$Session)
    
    try {
        Write-Log "Getting system information"
        
        $systemInfo = Invoke-Command -Session $Session -ScriptBlock {
            Get-CimInstance Win32_ComputerSystem | Select-Object Name, Domain, Manufacturer, Model, NumberOfProcessors, TotalPhysicalMemory
        }
        
        $osInfo = Invoke-Command -Session $Session -ScriptBlock {
            Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, InstallDate
        }
        
        $networkInfo = Invoke-Command -Session $Session -ScriptBlock {
            Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } | Select-Object IPAddress, InterfaceAlias
        }
        
        $userInfo = Invoke-Command -Session $Session -ScriptBlock {
            Get-LocalUser | Select-Object Name, Enabled, Description
        }
        
        Write-Log "System Name: $($systemInfo.Name)"
        Write-Log "Domain: $($systemInfo.Domain)"
        Write-Log "OS: $($osInfo.Caption) $($osInfo.Version)"
        Write-Log "IP Addresses: $($networkInfo.IPAddress -join ', ')"
        
        return @{
            SystemInfo = $systemInfo
            OSInfo = $osInfo
            NetworkInfo = $networkInfo
            UserInfo = $userInfo
        }
    } catch {
        Write-Log "Failed to get system information: $_" "ERROR"
        return $null
    }
}

function Set-ComputerName {
    param(
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [string]$NewName
    )
    
    try {
        Write-Log "Setting computer name to: $NewName"
        
        $result = Invoke-Command -Session $Session -ScriptBlock {
            param($NewName)
            Rename-Computer -NewName $NewName -Force -ErrorAction Stop
        } -ArgumentList $NewName
        
        Write-Log "Computer name changed successfully. Restart required."
        return $true
    } catch {
        Write-Log "Failed to set computer name: $_" "ERROR"
        return $false
    }
}

function Push-Tools {
    param(
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [string]$LocalToolsPath,
        [string]$RemoteToolsPath = "C:\windows\system32\tools"
    )
    
    try {
        Write-Log "Pushing tools to remote system"
        
        if (-not (Test-Path $LocalToolsPath)) {
            Write-Log "Local tools path not found: $LocalToolsPath" "WARN"
            return $false
        }
        
        Invoke-Command -Session $Session -ScriptBlock {
            param($RemoteToolsPath)
            if (-not (Test-Path $RemoteToolsPath)) {
                New-Item -Path $RemoteToolsPath -ItemType Directory -Force | Out-Null
                Write-Output "Created remote tools directory: $RemoteToolsPath"
            } else {
                Write-Output "Remote tools directory already exists: $RemoteToolsPath"
            }
        } -ArgumentList $RemoteToolsPath
        
        $sysinternalsPath = Join-Path $LocalToolsPath "SysinternalsSuite"
        if (Test-Path $sysinternalsPath) {
            Write-Log "Pushing SysinternalsSuite..."
            Copy-Item -Path "$sysinternalsPath\*" -Destination "$RemoteToolsPath\SysinternalsSuite" -Recurse -Force -ToSession $Session
            Write-Log "SysinternalsSuite pushed successfully"
        }
        
        $puttyPath = Join-Path $LocalToolsPath "PuTTY"
        if (Test-Path $puttyPath) {
            Write-Log "Pushing PuTTY tools..."
            Copy-Item -Path "$puttyPath\*" -Destination "$RemoteToolsPath\PuTTY" -Recurse -Force -ToSession $Session
            Write-Log "PuTTY tools pushed successfully"
        }
        
        return $true
    } catch {
        Write-Log "Failed to push tools: $_" "ERROR"
        return $false
    }
}

function Push-Scripts {
    param(
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [string]$LocalScriptsPath = "D:\GitHub\SuperITOM\scripts\windows",
        [string]$RemoteScriptsPath = "C:\windows\system32\scripts"
    )
    
    try {
        Write-Log "Pushing scripts to remote system"
        
        if (-not (Test-Path $LocalScriptsPath)) {
            Write-Log "Local scripts path not found: $LocalScriptsPath" "WARN"
            return $false
        }
        
        Invoke-Command -Session $Session -ScriptBlock {
            param($RemoteScriptsPath)
            if (-not (Test-Path $RemoteScriptsPath)) {
                New-Item -Path $RemoteScriptsPath -ItemType Directory -Force | Out-Null
                Write-Output "Created remote scripts directory: $RemoteScriptsPath"
            } else {
                Write-Output "Remote scripts directory already exists: $RemoteScriptsPath"
            }
        } -ArgumentList $RemoteScriptsPath
        
        $scripts = Get-ChildItem -Path $LocalScriptsPath -Filter "*.ps1" -Exclude "*_TEST.ps1"
        
        foreach ($script in $scripts) {
            Write-Log "Pushing script: $($script.Name)"
            Copy-Item -Path $script.FullName -Destination "$RemoteScriptsPath\$($script.Name)" -Force -ToSession $Session
            Write-Log "Script pushed: $($script.Name)"
        }
        
        return $true
    } catch {
        Write-Log "Failed to push scripts: $_" "ERROR"
        return $false
    }
}

Write-Log "=== Starting Remote Windows Client Management ==="

if ($TargetIP -and $TargetUser -and $TargetPassword) {
    Write-Log "Processing single target: $TargetIP"
    
    $session = Test-WinRMConnection -ComputerName $TargetIP -Username $TargetUser -Password $TargetPassword
    
    if ($session) {
        $systemInfo = Get-SystemInfo -Session $session
        
        if ($NewComputerName) {
            $nameResult = Set-ComputerName -Session $session -NewName $NewComputerName
            if ($nameResult) {
                Write-Log "Computer name changed. Please restart the remote system."
            }
        }
        
        $toolsResult = Push-Tools -Session $session -LocalToolsPath $ToolsPath
        if ($toolsResult) {
            Write-Log "Tools pushed successfully"
        }
        
        $scriptsResult = Push-Scripts -Session $session
        if ($scriptsResult) {
            Write-Log "Scripts pushed successfully"
        }
        
        Remove-PSSession -Session $session
        Write-Log "=== Single Target Completed Successfully ==="
        exit 0
    } else {
        Write-Log "=== Single Target Failed ===" "ERROR"
        exit 1
    }
} elseif (Test-Path $HostsFile) {
    Write-Log "Reading hosts from: $HostsFile"
    
    $hosts = Import-Csv $HostsFile
    
    if ($hosts.Count -eq 0) {
        Write-Log "No hosts found in file" "ERROR"
        exit 1
    }
    
    $successCount = 0
    $failCount = 0
    
    foreach ($host in $hosts) {
        Write-Log "Processing host: $($host.IPAddress)"
        
        $session = Test-WinRMConnection -ComputerName $host.IPAddress -Username $host.User -Password $host.Password
        
        if ($session) {
            $systemInfo = Get-SystemInfo -Session $session
            
            if ($NewComputerName) {
                $nameResult = Set-ComputerName -Session $session -NewName $NewComputerName
                if ($nameResult) {
                    Write-Log "Computer name changed for $($host.IPAddress)"
                }
            }
            
            $toolsResult = Push-Tools -Session $session -LocalToolsPath $ToolsPath
            if ($toolsResult) {
                Write-Log "Tools pushed to $($host.IPAddress)"
            }
            
            $scriptsResult = Push-Scripts -Session $session
            if ($scriptsResult) {
                Write-Log "Scripts pushed to $($host.IPAddress)"
            }
            
            Remove-PSSession -Session $session
            $successCount++
            Write-Log "Host $($host.IPAddress): SUCCESS"
        } else {
            $failCount++
            Write-Log "Host $($host.IPAddress): FAILED" "ERROR"
        }
        
        Write-Log ""
    }
    
    Write-Log "=== Batch Processing Summary ==="
    Write-Log "Total hosts: $($hosts.Count)"
    Write-Log "Successful: $successCount"
    Write-Log "Failed: $failCount"
    
    if ($failCount -eq 0) {
        Write-Log "=== All Hosts Processed Successfully ==="
        exit 0
    } else {
        Write-Log "=== Some Hosts Failed ===" "ERROR"
        exit 1
    }
} else {
    Write-Log "Hosts file not found: $HostsFile" "ERROR"
    exit 1
}
