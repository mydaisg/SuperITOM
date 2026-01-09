param(
    [string]$ConfigPath = "D:\GitHub\SuperITOM\config\config.json",
    [string]$HostsCSVPath = "D:\GitHub\SuperITOM\config\hosts.csv"
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

function Get-LinuxHosts {
    param([string]$CSVPath)
    
    try {
        if (-not (Test-Path $CSVPath)) {
            Write-Log "Hosts CSV file not found: $CSVPath" "ERROR"
            return $null
        }
        
        $hosts = Import-Csv -Path $CSVPath -ErrorAction Stop
        $linuxHosts = $hosts | Where-Object { $_.OSType -eq "Linux" }
        
        Write-Log "Found $($linuxHosts.Count) Linux hosts"
        return $linuxHosts
    } catch {
        Write-Log "Failed to read hosts CSV: $_" "ERROR"
        return $null
    }
}

function Test-SSHConnection {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Testing SSH connection to $Hostname..."
        
        $testCommand = "echo 'SSH connection test successful'"
        $sshCommand = "ssh -p $Port -o ConnectTimeout=10 -o StrictHostKeyChecking=no $Username@$Hostname `"$testCommand`""
        
        $result = Invoke-Expression $sshCommand 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "SSH connection test successful"
            return $true
        } else {
            Write-Log "SSH connection test failed: $result" "ERROR"
            return $false
        }
    } catch {
        Write-Log "SSH connection test error: $_" "ERROR"
        return $false
    }
}

function Execute-SSHCommand {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username,
        [string]$Command
    )
    
    try {
        Write-Log "Executing command on $Hostname: $Command"
        
        $sshCommand = "ssh -p $Port -o ConnectTimeout=30 -o StrictHostKeyChecking=no $Username@$Hostname `"$Command`""
        $result = Invoke-Expression $sshCommand 2>&1
        
        return @{
            Success = ($LASTEXITCODE -eq 0)
            Output = $result
            ExitCode = $LASTEXITCODE
        }
    } catch {
        Write-Log "SSH command execution error: $_" "ERROR"
        return @{
            Success = $false
            Output = $_
            ExitCode = -1
        }
    }
}

function Install-LinuxPackages {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username,
        [string[]]$Packages
    )
    
    try {
        Write-Log "Installing packages on $Hostname: $($Packages -join ', ')"
        
        $packageList = $Packages -join " "
        $command = "sudo apt-get update && sudo apt-get install -y $packageList"
        
        $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $command
        
        if ($result.Success) {
            Write-Log "Packages installed successfully"
            return $true
        } else {
            Write-Log "Package installation failed: $($result.Output)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Package installation error: $_" "ERROR"
        return $false
    }
}

function Configure-SSHKey {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username,
        [string]$PublicKeyPath
    )
    
    try {
        Write-Log "Configuring SSH key authentication for $Hostname..."
        
        if (-not (Test-Path $PublicKeyPath)) {
            Write-Log "Public key file not found: $PublicKeyPath" "ERROR"
            return $false
        }
        
        $publicKey = Get-Content $PublicKeyPath -Raw
        $command = "mkdir -p ~/.ssh && echo '$publicKey' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
        
        $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $command
        
        if ($result.Success) {
            Write-Log "SSH key configured successfully"
            return $true
        } else {
            Write-Log "SSH key configuration failed: $($result.Output)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "SSH key configuration error: $_" "ERROR"
        return $false
    }
}

function Configure-Sudoers {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Configuring sudoers on $Hostname..."
        
        $command = "echo '$Username ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$Username && sudo chmod 440 /etc/sudoers.d/$Username"
        
        $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $command
        
        if ($result.Success) {
            Write-Log "Sudoers configured successfully"
            return $true
        } else {
            Write-Log "Sudoers configuration failed: $($result.Output)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Sudoers configuration error: $_" "ERROR"
        return $false
    }
}

function Configure-Firewall {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Configuring firewall on $Hostname..."
        
        $commands = @(
            "sudo ufw allow $Port/tcp",
            "sudo ufw --force enable"
        )
        
        foreach ($cmd in $commands) {
            $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $cmd
            if (-not $result.Success) {
                Write-Log "Firewall command failed: $cmd" "WARN"
            }
        }
        
        Write-Log "Firewall configuration completed"
        return $true
    } catch {
        Write-Log "Firewall configuration error: $_" "ERROR"
        return $false
    }
}

function Get-LinuxSystemInfo {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Collecting system information from $Hostname..."
        
        $commands = @{
            "OS Version" = "cat /etc/os-release"
            "Kernel Version" = "uname -r"
            "Hostname" = "hostname"
            "Uptime" = "uptime"
            "CPU Info" = "lscpu"
            "Memory Info" = "free -h"
            "Disk Info" = "df -h"
            "Network Info" = "ip addr show"
        }
        
        $systemInfo = @{}
        
        foreach ($key in $commands.Keys) {
            $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $commands[$key]
            $systemInfo[$key] = $result.Output
        }
        
        return $systemInfo
    } catch {
        Write-Log "Failed to collect system information: $_" "ERROR"
        return $null
    }
}

function Write-LinuxDeploymentLog {
    param(
        [string]$LogPath,
        [hashtable]$Data
    )
    
    try {
        $logContent = @"
========================================
LINUX CLIENT DEPLOYMENT LOG
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

========================================
HOST INFORMATION
========================================
Hostname: $($Data.Hostname)
IP Address: $($Data.IPAddress)
Username: $($Data.Username)

========================================
DEPLOYMENT STATUS
========================================
SSH Connection: $($Data.SSHConnectionStatus)
Package Installation: $($Data.PackageInstallationStatus)
SSH Key Configuration: $($Data.SSHKeyStatus)
Sudoers Configuration: $($Data.SudoersStatus)
Firewall Configuration: $($Data.FirewallStatus)

========================================
SYSTEM INFORMATION
========================================
OS Version:
$($Data.SystemInfo["OS Version"])

Kernel Version:
$($Data.SystemInfo["Kernel Version"])

Hostname:
$($Data.SystemInfo["Hostname"])

Uptime:
$($Data.SystemInfo["Uptime"])

CPU Info:
$($Data.SystemInfo["CPU Info"])

Memory Info:
$($Data.SystemInfo["Memory Info"])

Disk Info:
$($Data.SystemInfo["Disk Info"])

Network Info:
$($Data.SystemInfo["Network Info"])

========================================
END OF LOG
========================================
"@
        
        Set-Content -Path $LogPath -Value $logContent -Encoding UTF8
        Write-Log "Linux deployment log written to: $LogPath"
        return $true
    } catch {
        Write-Log "Failed to write Linux deployment log: $_" "ERROR"
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

Write-Log "=== Starting Linux Client Deployment ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$linuxHosts = Get-LinuxHosts -CSVPath $HostsCSVPath

if (-not $linuxHosts -or $linuxHosts.Count -eq 0) {
    Write-Log "No Linux hosts found in hosts.csv" "WARN"
    exit 0
}

$linuxConfig = $config.linux
$sshPort = $linuxConfig.ssh_port
$sshUser = $linuxConfig.ssh_user
$requiredPackages = $linuxConfig.required_packages

$successCount = 0
$failCount = 0

foreach ($hostEntry in $linuxHosts) {
    $hostname = $hostEntry.Hostname
    $ipAddress = $hostEntry.IPAddress
    
    Write-Log "Processing Linux host: $hostname ($ipAddress)"
    
    $linuxDeploymentLog = Join-Path $localDir "6_Linux_${hostname}.log"
    
    $sshConnectionStatus = "Failed"
    $packageInstallationStatus = "Failed"
    $sshKeyStatus = "Failed"
    $sudoersStatus = "Failed"
    $firewallStatus = "Failed"
    $systemInfo = @{}
    
    $sshTest = Test-SSHConnection -Hostname $ipAddress -Port $sshPort -Username $sshUser
    if ($sshTest) {
        $sshConnectionStatus = "Success"
        
        $packageResult = Install-LinuxPackages -Hostname $ipAddress -Port $sshPort -Username $sshUser -Packages $requiredPackages
        if ($packageResult) {
            $packageInstallationStatus = "Success"
        }
        
        $sshKeyPath = $linuxConfig.ssh_key_path
        if (Test-Path $sshKeyPath) {
            $sshKeyResult = Configure-SSHKey -Hostname $ipAddress -Port $sshPort -Username $sshUser -PublicKeyPath "${sshKeyPath}.pub"
            if ($sshKeyResult) {
                $sshKeyStatus = "Success"
            }
        }
        
        $sudoersResult = Configure-Sudoers -Hostname $ipAddress -Port $sshPort -Username $sshUser
        if ($sudoersResult) {
            $sudoersStatus = "Success"
        }
        
        $firewallResult = Configure-Firewall -Hostname $ipAddress -Port $sshPort -Username $sshUser
        if ($firewallResult) {
            $firewallStatus = "Success"
        }
        
        $systemInfo = Get-LinuxSystemInfo -Hostname $ipAddress -Port $sshPort -Username $sshUser
    }
    
    $logData = @{
        Hostname = $hostname
        IPAddress = $ipAddress
        Username = $sshUser
        SSHConnectionStatus = $sshConnectionStatus
        PackageInstallationStatus = $packageInstallationStatus
        SSHKeyStatus = $sshKeyStatus
        SudoersStatus = $sudoersStatus
        FirewallStatus = $firewallStatus
        SystemInfo = $systemInfo
    }
    
    Write-LinuxDeploymentLog -LogPath $linuxDeploymentLog -Data $logData
    
    $logUploadPath = $config.paths.log_upload_path
    $uploadResult = Upload-Log -SourcePath $linuxDeploymentLog -DestPath $logUploadPath -Prefix $hostname
    
    if ($uploadResult) {
        $successCount++
    } else {
        $failCount++
    }
}

Write-Log "=== Linux Client Deployment Completed ==="
Write-Log "Summary: $successCount succeeded, $failCount failed"

if ($failCount -eq 0) {
    exit 0
} else {
    exit 1
}
.Name] = param(
    [string]$ConfigPath = "D:\GitHub\SuperITOM\config\config.json",
    [string]$HostsCSVPath = "D:\GitHub\SuperITOM\config\hosts.csv"
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

function Get-LinuxHosts {
    param([string]$CSVPath)
    
    try {
        if (-not (Test-Path $CSVPath)) {
            Write-Log "Hosts CSV file not found: $CSVPath" "ERROR"
            return $null
        }
        
        $hosts = Import-Csv -Path $CSVPath -ErrorAction Stop
        $linuxHosts = $hosts | Where-Object { $_.OSType -eq "Linux" }
        
        Write-Log "Found $($linuxHosts.Count) Linux hosts"
        return $linuxHosts
    } catch {
        Write-Log "Failed to read hosts CSV: $_" "ERROR"
        return $null
    }
}

function Test-SSHConnection {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Testing SSH connection to $Hostname..."
        
        $testCommand = "echo 'SSH connection test successful'"
        $sshCommand = "ssh -p $Port -o ConnectTimeout=10 -o StrictHostKeyChecking=no $Username@$Hostname `"$testCommand`""
        
        $result = Invoke-Expression $sshCommand 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "SSH connection test successful"
            return $true
        } else {
            Write-Log "SSH connection test failed: $result" "ERROR"
            return $false
        }
    } catch {
        Write-Log "SSH connection test error: $_" "ERROR"
        return $false
    }
}

function Execute-SSHCommand {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username,
        [string]$Command
    )
    
    try {
        Write-Log "Executing command on $Hostname: $Command"
        
        $sshCommand = "ssh -p $Port -o ConnectTimeout=30 -o StrictHostKeyChecking=no $Username@$Hostname `"$Command`""
        $result = Invoke-Expression $sshCommand 2>&1
        
        return @{
            Success = ($LASTEXITCODE -eq 0)
            Output = $result
            ExitCode = $LASTEXITCODE
        }
    } catch {
        Write-Log "SSH command execution error: $_" "ERROR"
        return @{
            Success = $false
            Output = $_
            ExitCode = -1
        }
    }
}

function Install-LinuxPackages {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username,
        [string[]]$Packages
    )
    
    try {
        Write-Log "Installing packages on $Hostname: $($Packages -join ', ')"
        
        $packageList = $Packages -join " "
        $command = "sudo apt-get update && sudo apt-get install -y $packageList"
        
        $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $command
        
        if ($result.Success) {
            Write-Log "Packages installed successfully"
            return $true
        } else {
            Write-Log "Package installation failed: $($result.Output)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Package installation error: $_" "ERROR"
        return $false
    }
}

function Configure-SSHKey {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username,
        [string]$PublicKeyPath
    )
    
    try {
        Write-Log "Configuring SSH key authentication for $Hostname..."
        
        if (-not (Test-Path $PublicKeyPath)) {
            Write-Log "Public key file not found: $PublicKeyPath" "ERROR"
            return $false
        }
        
        $publicKey = Get-Content $PublicKeyPath -Raw
        $command = "mkdir -p ~/.ssh && echo '$publicKey' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
        
        $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $command
        
        if ($result.Success) {
            Write-Log "SSH key configured successfully"
            return $true
        } else {
            Write-Log "SSH key configuration failed: $($result.Output)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "SSH key configuration error: $_" "ERROR"
        return $false
    }
}

function Configure-Sudoers {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Configuring sudoers on $Hostname..."
        
        $command = "echo '$Username ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$Username && sudo chmod 440 /etc/sudoers.d/$Username"
        
        $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $command
        
        if ($result.Success) {
            Write-Log "Sudoers configured successfully"
            return $true
        } else {
            Write-Log "Sudoers configuration failed: $($result.Output)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Sudoers configuration error: $_" "ERROR"
        return $false
    }
}

function Configure-Firewall {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Configuring firewall on $Hostname..."
        
        $commands = @(
            "sudo ufw allow $Port/tcp",
            "sudo ufw --force enable"
        )
        
        foreach ($cmd in $commands) {
            $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $cmd
            if (-not $result.Success) {
                Write-Log "Firewall command failed: $cmd" "WARN"
            }
        }
        
        Write-Log "Firewall configuration completed"
        return $true
    } catch {
        Write-Log "Firewall configuration error: $_" "ERROR"
        return $false
    }
}

function Get-LinuxSystemInfo {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Collecting system information from $Hostname..."
        
        $commands = @{
            "OS Version" = "cat /etc/os-release"
            "Kernel Version" = "uname -r"
            "Hostname" = "hostname"
            "Uptime" = "uptime"
            "CPU Info" = "lscpu"
            "Memory Info" = "free -h"
            "Disk Info" = "df -h"
            "Network Info" = "ip addr show"
        }
        
        $systemInfo = @{}
        
        foreach ($key in $commands.Keys) {
            $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $commands[$key]
            $systemInfo[$key] = $result.Output
        }
        
        return $systemInfo
    } catch {
        Write-Log "Failed to collect system information: $_" "ERROR"
        return $null
    }
}

function Write-LinuxDeploymentLog {
    param(
        [string]$LogPath,
        [hashtable]$Data
    )
    
    try {
        $logContent = @"
========================================
LINUX CLIENT DEPLOYMENT LOG
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

========================================
HOST INFORMATION
========================================
Hostname: $($Data.Hostname)
IP Address: $($Data.IPAddress)
Username: $($Data.Username)

========================================
DEPLOYMENT STATUS
========================================
SSH Connection: $($Data.SSHConnectionStatus)
Package Installation: $($Data.PackageInstallationStatus)
SSH Key Configuration: $($Data.SSHKeyStatus)
Sudoers Configuration: $($Data.SudoersStatus)
Firewall Configuration: $($Data.FirewallStatus)

========================================
SYSTEM INFORMATION
========================================
OS Version:
$($Data.SystemInfo["OS Version"])

Kernel Version:
$($Data.SystemInfo["Kernel Version"])

Hostname:
$($Data.SystemInfo["Hostname"])

Uptime:
$($Data.SystemInfo["Uptime"])

CPU Info:
$($Data.SystemInfo["CPU Info"])

Memory Info:
$($Data.SystemInfo["Memory Info"])

Disk Info:
$($Data.SystemInfo["Disk Info"])

Network Info:
$($Data.SystemInfo["Network Info"])

========================================
END OF LOG
========================================
"@
        
        Set-Content -Path $LogPath -Value $logContent -Encoding UTF8
        Write-Log "Linux deployment log written to: $LogPath"
        return $true
    } catch {
        Write-Log "Failed to write Linux deployment log: $_" "ERROR"
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

Write-Log "=== Starting Linux Client Deployment ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$linuxHosts = Get-LinuxHosts -CSVPath $HostsCSVPath

if (-not $linuxHosts -or $linuxHosts.Count -eq 0) {
    Write-Log "No Linux hosts found in hosts.csv" "WARN"
    exit 0
}

$linuxConfig = $config.linux
$sshPort = $linuxConfig.ssh_port
$sshUser = $linuxConfig.ssh_user
$requiredPackages = $linuxConfig.required_packages

$successCount = 0
$failCount = 0

foreach ($hostEntry in $linuxHosts) {
    $hostname = $hostEntry.Hostname
    $ipAddress = $hostEntry.IPAddress
    
    Write-Log "Processing Linux host: $hostname ($ipAddress)"
    
    $linuxDeploymentLog = Join-Path $localDir "6_Linux_${hostname}.log"
    
    $sshConnectionStatus = "Failed"
    $packageInstallationStatus = "Failed"
    $sshKeyStatus = "Failed"
    $sudoersStatus = "Failed"
    $firewallStatus = "Failed"
    $systemInfo = @{}
    
    $sshTest = Test-SSHConnection -Hostname $ipAddress -Port $sshPort -Username $sshUser
    if ($sshTest) {
        $sshConnectionStatus = "Success"
        
        $packageResult = Install-LinuxPackages -Hostname $ipAddress -Port $sshPort -Username $sshUser -Packages $requiredPackages
        if ($packageResult) {
            $packageInstallationStatus = "Success"
        }
        
        $sshKeyPath = $linuxConfig.ssh_key_path
        if (Test-Path $sshKeyPath) {
            $sshKeyResult = Configure-SSHKey -Hostname $ipAddress -Port $sshPort -Username $sshUser -PublicKeyPath "${sshKeyPath}.pub"
            if ($sshKeyResult) {
                $sshKeyStatus = "Success"
            }
        }
        
        $sudoersResult = Configure-Sudoers -Hostname $ipAddress -Port $sshPort -Username $sshUser
        if ($sudoersResult) {
            $sudoersStatus = "Success"
        }
        
        $firewallResult = Configure-Firewall -Hostname $ipAddress -Port $sshPort -Username $sshUser
        if ($firewallResult) {
            $firewallStatus = "Success"
        }
        
        $systemInfo = Get-LinuxSystemInfo -Hostname $ipAddress -Port $sshPort -Username $sshUser
    }
    
    $logData = @{
        Hostname = $hostname
        IPAddress = $ipAddress
        Username = $sshUser
        SSHConnectionStatus = $sshConnectionStatus
        PackageInstallationStatus = $packageInstallationStatus
        SSHKeyStatus = $sshKeyStatus
        SudoersStatus = $sudoersStatus
        FirewallStatus = $firewallStatus
        SystemInfo = $systemInfo
    }
    
    Write-LinuxDeploymentLog -LogPath $linuxDeploymentLog -Data $logData
    
    $logUploadPath = $config.paths.log_upload_path
    $uploadResult = Upload-Log -SourcePath $linuxDeploymentLog -DestPath $logUploadPath -Prefix $hostname
    
    if ($uploadResult) {
        $successCount++
    } else {
        $failCount++
    }
}

Write-Log "=== Linux Client Deployment Completed ==="
Write-Log "Summary: $successCount succeeded, $failCount failed"

if ($failCount -eq 0) {
    exit 0
} else {
    exit 1
}


function Get-LinuxHosts {
    param([string]$CSVPath)
    
    try {
        if (-not (Test-Path $CSVPath)) {
            Write-Log "Hosts CSV file not found: $CSVPath" "ERROR"
            return $null
        }
        
        $hosts = Import-Csv -Path $CSVPath -ErrorAction Stop
        $linuxHosts = $hosts | Where-Object { $_.OSType -eq "Linux" }
        
        Write-Log "Found $($linuxHosts.Count) Linux hosts"
        return $linuxHosts
    } catch {
        Write-Log "Failed to read hosts CSV: $_" "ERROR"
        return $null
    }
}

function Test-SSHConnection {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Testing SSH connection to $Hostname..."
        
        $testCommand = "echo 'SSH connection test successful'"
        $sshCommand = "ssh -p $Port -o ConnectTimeout=10 -o StrictHostKeyChecking=no $Username@$Hostname `"$testCommand`""
        
        $result = Invoke-Expression $sshCommand 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "SSH connection test successful"
            return $true
        } else {
            Write-Log "SSH connection test failed: $result" "ERROR"
            return $false
        }
    } catch {
        Write-Log "SSH connection test error: $_" "ERROR"
        return $false
    }
}

function Execute-SSHCommand {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username,
        [string]$Command
    )
    
    try {
        Write-Log "Executing command on $Hostname: $Command"
        
        $sshCommand = "ssh -p $Port -o ConnectTimeout=30 -o StrictHostKeyChecking=no $Username@$Hostname `"$Command`""
        $result = Invoke-Expression $sshCommand 2>&1
        
        return @{
            Success = ($LASTEXITCODE -eq 0)
            Output = $result
            ExitCode = $LASTEXITCODE
        }
    } catch {
        Write-Log "SSH command execution error: $_" "ERROR"
        return @{
            Success = $false
            Output = $_
            ExitCode = -1
        }
    }
}

function Install-LinuxPackages {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username,
        [string[]]$Packages
    )
    
    try {
        Write-Log "Installing packages on $Hostname: $($Packages -join ', ')"
        
        $packageList = $Packages -join " "
        $command = "sudo apt-get update && sudo apt-get install -y $packageList"
        
        $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $command
        
        if ($result.Success) {
            Write-Log "Packages installed successfully"
            return $true
        } else {
            Write-Log "Package installation failed: $($result.Output)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Package installation error: $_" "ERROR"
        return $false
    }
}

function Configure-SSHKey {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username,
        [string]$PublicKeyPath
    )
    
    try {
        Write-Log "Configuring SSH key authentication for $Hostname..."
        
        if (-not (Test-Path $PublicKeyPath)) {
            Write-Log "Public key file not found: $PublicKeyPath" "ERROR"
            return $false
        }
        
        $publicKey = Get-Content $PublicKeyPath -Raw
        $command = "mkdir -p ~/.ssh && echo '$publicKey' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
        
        $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $command
        
        if ($result.Success) {
            Write-Log "SSH key configured successfully"
            return $true
        } else {
            Write-Log "SSH key configuration failed: $($result.Output)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "SSH key configuration error: $_" "ERROR"
        return $false
    }
}

function Configure-Sudoers {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Configuring sudoers on $Hostname..."
        
        $command = "echo '$Username ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$Username && sudo chmod 440 /etc/sudoers.d/$Username"
        
        $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $command
        
        if ($result.Success) {
            Write-Log "Sudoers configured successfully"
            return $true
        } else {
            Write-Log "Sudoers configuration failed: $($result.Output)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Sudoers configuration error: $_" "ERROR"
        return $false
    }
}

function Configure-Firewall {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Configuring firewall on $Hostname..."
        
        $commands = @(
            "sudo ufw allow $Port/tcp",
            "sudo ufw --force enable"
        )
        
        foreach ($cmd in $commands) {
            $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $cmd
            if (-not $result.Success) {
                Write-Log "Firewall command failed: $cmd" "WARN"
            }
        }
        
        Write-Log "Firewall configuration completed"
        return $true
    } catch {
        Write-Log "Firewall configuration error: $_" "ERROR"
        return $false
    }
}

function Get-LinuxSystemInfo {
    param(
        [string]$Hostname,
        [int]$Port,
        [string]$Username
    )
    
    try {
        Write-Log "Collecting system information from $Hostname..."
        
        $commands = @{
            "OS Version" = "cat /etc/os-release"
            "Kernel Version" = "uname -r"
            "Hostname" = "hostname"
            "Uptime" = "uptime"
            "CPU Info" = "lscpu"
            "Memory Info" = "free -h"
            "Disk Info" = "df -h"
            "Network Info" = "ip addr show"
        }
        
        $systemInfo = @{}
        
        foreach ($key in $commands.Keys) {
            $result = Execute-SSHCommand -Hostname $Hostname -Port $Port -Username $Username -Command $commands[$key]
            $systemInfo[$key] = $result.Output
        }
        
        return $systemInfo
    } catch {
        Write-Log "Failed to collect system information: $_" "ERROR"
        return $null
    }
}

function Write-LinuxDeploymentLog {
    param(
        [string]$LogPath,
        [hashtable]$Data
    )
    
    try {
        $logContent = @"
========================================
LINUX CLIENT DEPLOYMENT LOG
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

========================================
HOST INFORMATION
========================================
Hostname: $($Data.Hostname)
IP Address: $($Data.IPAddress)
Username: $($Data.Username)

========================================
DEPLOYMENT STATUS
========================================
SSH Connection: $($Data.SSHConnectionStatus)
Package Installation: $($Data.PackageInstallationStatus)
SSH Key Configuration: $($Data.SSHKeyStatus)
Sudoers Configuration: $($Data.SudoersStatus)
Firewall Configuration: $($Data.FirewallStatus)

========================================
SYSTEM INFORMATION
========================================
OS Version:
$($Data.SystemInfo["OS Version"])

Kernel Version:
$($Data.SystemInfo["Kernel Version"])

Hostname:
$($Data.SystemInfo["Hostname"])

Uptime:
$($Data.SystemInfo["Uptime"])

CPU Info:
$($Data.SystemInfo["CPU Info"])

Memory Info:
$($Data.SystemInfo["Memory Info"])

Disk Info:
$($Data.SystemInfo["Disk Info"])

Network Info:
$($Data.SystemInfo["Network Info"])

========================================
END OF LOG
========================================
"@
        
        Set-Content -Path $LogPath -Value $logContent -Encoding UTF8
        Write-Log "Linux deployment log written to: $LogPath"
        return $true
    } catch {
        Write-Log "Failed to write Linux deployment log: $_" "ERROR"
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

Write-Log "=== Starting Linux Client Deployment ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$linuxHosts = Get-LinuxHosts -CSVPath $HostsCSVPath

if (-not $linuxHosts -or $linuxHosts.Count -eq 0) {
    Write-Log "No Linux hosts found in hosts.csv" "WARN"
    exit 0
}

$linuxConfig = $config.linux
$sshPort = $linuxConfig.ssh_port
$sshUser = $linuxConfig.ssh_user
$requiredPackages = $linuxConfig.required_packages

$successCount = 0
$failCount = 0

foreach ($hostEntry in $linuxHosts) {
    $hostname = $hostEntry.Hostname
    $ipAddress = $hostEntry.IPAddress
    
    Write-Log "Processing Linux host: $hostname ($ipAddress)"
    
    $linuxDeploymentLog = Join-Path $localDir "6_Linux_${hostname}.log"
    
    $sshConnectionStatus = "Failed"
    $packageInstallationStatus = "Failed"
    $sshKeyStatus = "Failed"
    $sudoersStatus = "Failed"
    $firewallStatus = "Failed"
    $systemInfo = @{}
    
    $sshTest = Test-SSHConnection -Hostname $ipAddress -Port $sshPort -Username $sshUser
    if ($sshTest) {
        $sshConnectionStatus = "Success"
        
        $packageResult = Install-LinuxPackages -Hostname $ipAddress -Port $sshPort -Username $sshUser -Packages $requiredPackages
        if ($packageResult) {
            $packageInstallationStatus = "Success"
        }
        
        $sshKeyPath = $linuxConfig.ssh_key_path
        if (Test-Path $sshKeyPath) {
            $sshKeyResult = Configure-SSHKey -Hostname $ipAddress -Port $sshPort -Username $sshUser -PublicKeyPath "${sshKeyPath}.pub"
            if ($sshKeyResult) {
                $sshKeyStatus = "Success"
            }
        }
        
        $sudoersResult = Configure-Sudoers -Hostname $ipAddress -Port $sshPort -Username $sshUser
        if ($sudoersResult) {
            $sudoersStatus = "Success"
        }
        
        $firewallResult = Configure-Firewall -Hostname $ipAddress -Port $sshPort -Username $sshUser
        if ($firewallResult) {
            $firewallStatus = "Success"
        }
        
        $systemInfo = Get-LinuxSystemInfo -Hostname $ipAddress -Port $sshPort -Username $sshUser
    }
    
    $logData = @{
        Hostname = $hostname
        IPAddress = $ipAddress
        Username = $sshUser
        SSHConnectionStatus = $sshConnectionStatus
        PackageInstallationStatus = $packageInstallationStatus
        SSHKeyStatus = $sshKeyStatus
        SudoersStatus = $sudoersStatus
        FirewallStatus = $firewallStatus
        SystemInfo = $systemInfo
    }
    
    Write-LinuxDeploymentLog -LogPath $linuxDeploymentLog -Data $logData
    
    $logUploadPath = $config.paths.log_upload_path
    $uploadResult = Upload-Log -SourcePath $linuxDeploymentLog -DestPath $logUploadPath -Prefix $hostname
    
    if ($uploadResult) {
        $successCount++
    } else {
        $failCount++
    }
}

Write-Log "=== Linux Client Deployment Completed ==="
Write-Log "Summary: $successCount succeeded, $failCount failed"

if ($failCount -eq 0) {
    exit 0
} else {
    exit 1
}



