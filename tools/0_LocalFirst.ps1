# Local first-time setup for Windows client
param(
    [string]$ToolsPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($ToolsPath)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptDir = Split-Path -Parent $scriptPath
    $ToolsPath = $scriptDir
}

$logDir = Join-Path $scriptDir "logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $logDir "local_first_setup_$timestamp.log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

function Disable-Firewall {
    try {
        Write-Log "Disabling Windows Firewall..."
        
        $profiles = Get-NetFirewallProfile | Where-Object { $_.Enabled -eq $true }
        
        foreach ($profile in $profiles) {
            Set-NetFirewallProfile -Name $profile.Name -Enabled False -ErrorAction Stop
            Write-Log "Disabled firewall profile: $($profile.Name)"
        }
        
        Write-Log "Windows Firewall disabled successfully"
        return $true
    } catch {
        Write-Log "Failed to disable firewall: $_" "ERROR"
        return $false
    }
}

function Enable-WinRM {
    try {
        Write-Log "Enabling WinRM for remote management..."
        
        $winrmService = Get-Service WinRM
        
        if ($winrmService.Status -ne "Running") {
            Start-Service WinRM -ErrorAction Stop
            Write-Log "WinRM service started"
        } else {
            Write-Log "WinRM service already running"
        }
        
        $winrmService = Get-Service WinRM
        Set-Service WinRM -StartupType Automatic -ErrorAction Stop
        Write-Log "WinRM service set to automatic startup"
        
        Write-Log "Configuring WinRM for remote access..."
        
        Enable-PSRemoting -Force -ErrorAction Stop
        Write-Log "PowerShell remoting enabled"
        
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction Stop
        Write-Log "All hosts added to trusted hosts"
        
        Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 1024 -Force -ErrorAction Stop
        Write-Log "Max memory per shell set to 1024MB"
        
        Set-Item WSMan:\localhost\Shell\MaxShellsPerUser -Value 10 -Force -ErrorAction Stop
        Write-Log "Max shells per user set to 10"
        
        Write-Log "WinRM configuration completed successfully"
        return $true
    } catch {
        Write-Log "Failed to enable WinRM: $_" "ERROR"
        return $false
    }
}

function Deploy-Tools {
    param(
        [string]$SourcePath,
        [string]$DestinationPath = "C:\windows\system32"
    )
    
    try {
        Write-Log "Deploying tools from $SourcePath to $DestinationPath"
        
        if (-not (Test-Path $SourcePath)) {
            Write-Log "Source tools path not found: $SourcePath" "WARN"
            return $false
        }
        
        if (-not (Test-Path $DestinationPath)) {
            Write-Log "Destination path not found: $DestinationPath" "ERROR"
            return $false
        }
        
        $sysinternalsPath = Join-Path $SourcePath "SysinternalsSuite"
        if (Test-Path $sysinternalsPath) {
            Write-Log "Deploying SysinternalsSuite..."
            Copy-Item -Path "$sysinternalsPath\*" -Destination "$DestinationPath\" -Recurse -Force -ErrorAction Stop
            Write-Log "SysinternalsSuite deployed successfully"
        } else {
            Write-Log "SysinternalsSuite not found in source path" "WARN"
        }
        
        $puttyPath = Join-Path $SourcePath "PuTTY"
        if (Test-Path $puttyPath) {
            Write-Log "Deploying PuTTY tools..."
            Copy-Item -Path "$puttyPath\*" -Destination "$DestinationPath\" -Recurse -Force -ErrorAction Stop
            Write-Log "PuTTY tools deployed successfully"
        } else {
            Write-Log "PuTTY not found in source path" "WARN"
        }
        
        Write-Log "Tools deployment completed"
        return $true
    } catch {
        Write-Log "Failed to deploy tools: $_" "ERROR"
        return $false
    }
}

function Get-SystemInfo {
    try {
        Write-Log "Gathering system information..."
        
        $computerSystem = Get-CimInstance Win32_ComputerSystem
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $networkInfo = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" }
        
        Write-Log "Computer Name: $($computerSystem.Name)"
        Write-Log "Domain: $($computerSystem.Domain)"
        Write-Log "OS: $($osInfo.Caption) $($osInfo.Version)"
        Write-Log "IP Addresses: $($networkInfo.IPAddress -join ', ')"
        Write-Log "Manufacturer: $($computerSystem.Manufacturer)"
        Write-Log "Model: $($computerSystem.Model)"
        
        return @{
            ComputerName = $computerSystem.Name
            Domain = $computerSystem.Domain
            OS = "$($osInfo.Caption) $($osInfo.Version)"
            IPAddresses = $networkInfo.IPAddress -join ', '
            Manufacturer = $computerSystem.Manufacturer
            Model = $computerSystem.Model
        }
    } catch {
        Write-Log "Failed to gather system information: $_" "ERROR"
        return $null
    }
}

Write-Log "=== Starting Local First-Time Setup ==="
Write-Log "Tools Path: $ToolsPath"

$firewallResult = Disable-Firewall
if (-not $firewallResult) {
    Write-Log "=== Setup Failed (Firewall) ===" "ERROR"
    exit 1
}

$winrmResult = Enable-WinRM
if (-not $winrmResult) {
    Write-Log "=== Setup Failed (WinRM) ===" "ERROR"
    exit 1
}

$toolsResult = Deploy-Tools -SourcePath $ToolsPath -DestinationPath "C:\windows\system32"
if (-not $toolsResult) {
    Write-Log "=== Setup Failed (Tools) ===" "ERROR"
    exit 1
}

$systemInfo = Get-SystemInfo
if ($systemInfo) {
    Write-Log "=== System Information ==="
    Write-Log "Computer Name: $($systemInfo.ComputerName)"
    Write-Log "Domain: $($systemInfo.Domain)"
    Write-Log "OS: $($systemInfo.OS)"
    Write-Log "IP Addresses: $($systemInfo.IPAddresses)"
    Write-Log "Manufacturer: $($systemInfo.Manufacturer)"
    Write-Log "Model: $($systemInfo.Model)"
    
    Write-Log "=== Setup Completed Successfully ==="
    Write-Log "This computer is now ready for remote management via ITOM"
    Write-Log "Please restart the computer to apply all changes"
    exit 0
} else {
    Write-Log "=== Setup Failed (System Info) ===" "ERROR"
    exit 1
}
