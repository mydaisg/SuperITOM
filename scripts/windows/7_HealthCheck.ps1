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

function Test-PowerShell7 {
    try {
        Write-Log "Checking PowerShell 7 installation..."
        
        $pwsh7Path = "C:\Program Files\PowerShell\7\pwsh.exe"
        if (Test-Path $pwsh7Path) {
            $version = & $pwsh7Path --version
            Write-Log "PowerShell 7 installed: $version"
            return @{
                Installed = $true
                Version = $version
                Path = $pwsh7Path
            }
        } else {
            Write-Log "PowerShell 7 not found" "WARN"
            return @{
                Installed = $false
                Version = "N/A"
                Path = "N/A"
            }
        }
    } catch {
        Write-Log "PowerShell 7 check failed: $_" "ERROR"
        return @{
            Installed = $false
            Version = "Error"
            Path = "N/A"
        }
    }
}

function Test-WinRM {
    try {
        Write-Log "Checking WinRM status..."
        
        $winrmService = Get-Service -Name WinRM -ErrorAction SilentlyContinue
        if ($winrmService) {
            $status = $winrmService.Status
            $startType = $winrmService.StartType
            
            if ($status -eq "Running") {
                Write-Log "WinRM service is running"
                
                $listener = winrm enumerate winrm/config/listener 2>&1
                $listenerEnabled = $listener -match "Transport.*HTTP"
                
                return @{
                    ServiceStatus = $status
                    StartType = $startType
                    ListenerEnabled = $listenerEnabled
                    OverallStatus = "OK"
                }
            } else {
                Write-Log "WinRM service is not running: $status" "WARN"
                return @{
                    ServiceStatus = $status
                    StartType = $startType
                    ListenerEnabled = $false
                    OverallStatus = "Not Running"
                }
            }
        } else {
            Write-Log "WinRM service not found" "WARN"
            return @{
                ServiceStatus = "Not Found"
                StartType = "N/A"
                ListenerEnabled = $false
                OverallStatus = "Not Installed"
            }
        }
    } catch {
        Write-Log "WinRM check failed: $_" "ERROR"
        return @{
            ServiceStatus = "Error"
            StartType = "N/A"
            ListenerEnabled = $false
            OverallStatus = "Error"
        }
    }
}

function Test-DomainMembership {
    try {
        Write-Log "Checking domain membership..."
        
        $computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
        $domain = $computerInfo.CsDomain
        $workgroup = $computerInfo.CsWorkgroup
        $partOfDomain = $computerInfo.CsPartOfDomain
        
        if ($partOfDomain) {
            Write-Log "Computer is joined to domain: $domain"
            return @{
                Domain = $domain
                Workgroup = $workgroup
                PartOfDomain = $true
                Status = "OK"
            }
        } else {
            Write-Log "Computer is not joined to domain (Workgroup: $workgroup)" "WARN"
            return @{
                Domain = "N/A"
                Workgroup = $workgroup
                PartOfDomain = $false
                Status = "Workgroup"
            }
        }
    } catch {
        Write-Log "Domain membership check failed: $_" "ERROR"
        return @{
            Domain = "Error"
            Workgroup = "Error"
            PartOfDomain = $false
            Status = "Error"
        }
    }
}

function Test-LocalAdmin {
    try {
        Write-Log "Checking local administrator configuration..."
        
        $adminGroup = Get-LocalGroup -Name "Administrators" -ErrorAction Stop
        $adminMembers = Get-LocalGroupMember -Group $adminGroup -ErrorAction Stop
        
        $adminUsers = @()
        foreach ($member in $adminMembers) {
            if ($member.ObjectClass -eq "User") {
                $adminUsers += $member.Name
            }
        }
        
        $dmlAdminsGroup = Get-LocalGroup -Name "DML_Admins" -ErrorAction SilentlyContinue
        $dmlAdminsExists = $dmlAdminsGroup -ne $null
        
        $defaultAdmin = Get-LocalUser -Name "Administrator" -ErrorAction SilentlyContinue
        $defaultAdminEnabled = $defaultAdmin -and $defaultAdmin.Enabled
        
        Write-Log "Found $($adminUsers.Count) administrator users"
        
        return @{
            AdminUsers = $adminUsers
            DMLAdminsGroupExists = $dmlAdminsExists
            DefaultAdminEnabled = $defaultAdminEnabled
            Status = "OK"
        }
    } catch {
        Write-Log "Local admin check failed: $_" "ERROR"
        return @{
            AdminUsers = @()
            DMLAdminsGroupExists = $false
            DefaultAdminEnabled = $false
            Status = "Error"
        }
    }
}

function Test-ToolsDeployment {
    try {
        Write-Log "Checking tools deployment..."
        
        $toolsToCheck = @(
            @{Name = "putty.exe"; Path = "C:\Windows\System32\putty.exe"},
            @{Name = "pscp.exe"; Path = "C:\Windows\System32\pscp.exe"},
            @{Name = "plink.exe"; Path = "C:\Windows\System32\plink.exe"}
        )
        
        $toolsStatus = @()
        
        foreach ($tool in $toolsToCheck) {
            $exists = Test-Path $tool.Path
            $toolsStatus += @{
                Name = $tool.Name
                Path = $tool.Path
                Exists = $exists
            }
            
            if ($exists) {
                Write-Log "Tool found: $($tool.Name)"
            } else {
                Write-Log "Tool not found: $($tool.Name)" "WARN"
            }
        }
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        $sysinternalsExists = Test-Path $sysinternalsPath
        $sysinternalsCount = 0
        
        if ($sysinternalsExists) {
            $sysinternalsCount = (Get-ChildItem -Path $sysinternalsPath -File).Count
            Write-Log "Sysinternals tools found: $sysinternalsCount tools"
        } else {
            Write-Log "Sysinternals tools not found" "WARN"
        }
        
        return @{
            Tools = $toolsStatus
            SysinternalsExists = $sysinternalsExists
            SysinternalsCount = $sysinternalsCount
            Status = "OK"
        }
    } catch {
        Write-Log "Tools deployment check failed: $_" "ERROR"
        return @{
            Tools = @()
            SysinternalsExists = $false
            SysinternalsCount = 0
            Status = "Error"
        }
    }
}

function Test-SystemResources {
    try {
        Write-Log "Checking system resources..."
        
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $cpu = Get-CimInstance -ClassName Win32_Processor
        $memory = Get-CimInstance -ClassName Win32_ComputerSystem
        $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
        
        $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
        $freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $memoryUsagePercent = [math]::Round((($totalMemoryGB - $freeMemoryGB) / $totalMemoryGB) * 100, 2)
        
        $diskInfo = @()
        foreach ($disk in $disks) {
            $totalSizeGB = [math]::Round($disk.Size / 1GB, 2)
            $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $usagePercent = [math]::Round((($totalSizeGB - $freeSpaceGB) / $totalSizeGB) * 100, 2)
            
            $diskInfo += @{
                Drive = $disk.DeviceID
                TotalSizeGB = $totalSizeGB
                FreeSpaceGB = $freeSpaceGB
                UsagePercent = $usagePercent
            }
        }
        
        $cpuLoad = $os.LoadPercentage
        
        Write-Log "CPU Load: $cpuLoad%"
        Write-Log "Memory Usage: $memoryUsagePercent% ($freeMemoryGB GB free)"
        
        return @{
            CPUName = $cpu.Name
            CPULoad = $cpuLoad
            TotalMemoryGB = $totalMemoryGB
            FreeMemoryGB = $freeMemoryGB
            MemoryUsagePercent = $memoryUsagePercent
            Disks = $diskInfo
            Status = "OK"
        }
    } catch {
        Write-Log "System resources check failed: $_" "ERROR"
        return @{
            CPUName = "Error"
            CPULoad = 0
            TotalMemoryGB = 0
            FreeMemoryGB = 0
            MemoryUsagePercent = 0
            Disks = @()
            Status = "Error"
        }
    }
}

function Test-NetworkConnectivity {
    try {
        Write-Log "Checking network connectivity..."
        
        $networkAdapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
        
        $adapterInfo = @()
        foreach ($adapter in $networkAdapters) {
            $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            
            $adapterInfo += @{
                Name = $adapter.Name
                Description = $adapter.InterfaceDescription
                IPAddress = $ipConfig.IPAddress
                SubnetMask = $ipConfig.PrefixLength
                DNSServers = $dnsServers.ServerAddresses
            }
        }
        
        $defaultGateway = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
        $gatewayIP = $defaultGateway.NextHop
        
        $dnsTest = Test-NetConnection -ComputerName "8.8.8.8" -InformationLevel Quiet -ErrorAction SilentlyContinue
        
        Write-Log "Network adapters: $($adapterInfo.Count)"
        Write-Log "DNS connectivity: $dnsTest"
        
        return @{
            Adapters = $adapterInfo
            DefaultGateway = $gatewayIP
            DNSConnectivity = $dnsTest
            Status = "OK"
        }
    } catch {
        Write-Log "Network connectivity check failed: $_" "ERROR"
        return @{
            Adapters = @()
            DefaultGateway = "Error"
            DNSConnectivity = $false
            Status = "Error"
        }
    }
}

function Test-CriticalServices {
    try {
        Write-Log "Checking critical services..."
        
        $criticalServices = @(
            @{Name = "WinRM"; DisplayName = "Windows Remote Management"},
            @{Name = "LanmanServer"; DisplayName = "Server"},
            @{Name = "Schedule"; DisplayName = "Task Scheduler"},
            @{Name = "W32Time"; DisplayName = "Windows Time"}
        )
        
        $servicesStatus = @()
        
        foreach ($service in $criticalServices) {
            $svc = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
            if ($svc) {
                $servicesStatus += @{
                    Name = $service.Name
                    DisplayName = $service.DisplayName
                    Status = $svc.Status
                    StartType = $svc.StartType
                }
                
                if ($svc.Status -eq "Running") {
                    Write-Log "Service OK: $($service.DisplayName)"
                } else {
                    Write-Log "Service not running: $($service.DisplayName) - $($svc.Status)" "WARN"
                }
            } else {
                $servicesStatus += @{
                    Name = $service.Name
                    DisplayName = $service.DisplayName
                    Status = "Not Found"
                    StartType = "N/A"
                }
                Write-Log "Service not found: $($service.DisplayName)" "WARN"
            }
        }
        
        return @{
            Services = $servicesStatus
            Status = "OK"
        }
    } catch {
        Write-Log "Critical services check failed: $_" "ERROR"
        return @{
            Services = @()
            Status = "Error"
        }
    }
}

function Write-HealthCheckLog {
    param(
        [string]$LogPath,
        [hashtable]$Data
    )
    
    try {
        $logContent = @"
========================================
HEALTH CHECK REPORT
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Hostname: $env:COMPUTERNAME

========================================
HEALTH SUMMARY
========================================
Overall Status: $($Data.OverallStatus)
Critical Issues: $($Data.CriticalIssues.Count)

========================================
DETAILED CHECKS
========================================

1. POWERSHELL 7
---------------------------
Installed: $($Data.PowerShell7.Installed)
Version: $($Data.PowerShell7.Version)
Path: $($Data.PowerShell7.Path)
Status: $($Data.PowerShell7.Status)

2. WINRM STATUS
---------------------------
Service Status: $($Data.WinRM.ServiceStatus)
Start Type: $($Data.WinRM.StartType)
Listener Enabled: $($Data.WinRM.ListenerEnabled)
Overall Status: $($Data.WinRM.OverallStatus)

3. DOMAIN MEMBERSHIP
---------------------------
Domain: $($Data.Domain.Domain)
Workgroup: $($Data.Domain.Workgroup)
Part of Domain: $($Data.Domain.PartOfDomain)
Status: $($Data.Domain.Status)

4. LOCAL ADMIN CONFIGURATION
---------------------------
DML Admins Group Exists: $($Data.LocalAdmin.DMLAdminsGroupExists)
Default Admin Enabled: $($Data.LocalAdmin.DefaultAdminEnabled)
Admin Users: $($Data.LocalAdmin.AdminUsers -join ", ")
Status: $($Data.LocalAdmin.Status)

5. TOOLS DEPLOYMENT
---------------------------
PuTTY Tools: $($Data.Tools.Tools.Where({$_.Exists}).Count)/$($Data.Tools.Tools.Count)
Sysinternals Exists: $($Data.Tools.SysinternalsExists)
Sysinternals Count: $($Data.Tools.SysinternalsCount)
Status: $($Data.Tools.Status)

6. SYSTEM RESOURCES
---------------------------
CPU: $($Data.SystemResources.CPUName)
CPU Load: $($Data.SystemResources.CPULoad)%
Memory: $($Data.SystemResources.TotalMemoryGB) GB Total, $($Data.SystemResources.FreeMemoryGB) GB Free
Memory Usage: $($Data.SystemResources.MemoryUsagePercent)%

Disk Usage:
$($Data.SystemResources.Disks | ForEach-Object { "  $($_.Drive): $([math]::Round($_.UsagePercent, 1))% used ($([math]::Round($_.FreeSpaceGB, 2)) GB free)" })

Status: $($Data.SystemResources.Status)

7. NETWORK CONNECTIVITY
---------------------------
Active Adapters: $($Data.Network.Adapters.Count)
Default Gateway: $($Data.Network.DefaultGateway)
DNS Connectivity: $($Data.Network.DNSConnectivity)

Adapters:
$($Data.Network.Adapters | ForEach-Object { "  $($_.Name): $($_.IPAddress)" })

Status: $($Data.Network.Status)

8. CRITICAL SERVICES
---------------------------
$($Data.CriticalServices.Services | ForEach-Object { "$($_.DisplayName): $($_.Status) ($($_.StartType))" })

Status: $($Data.CriticalServices.Status)

========================================
CRITICAL ISSUES
========================================
$($Data.CriticalIssues -join "`n")

========================================
RECOMMENDATIONS
========================================
$($Data.Recommendations -join "`n")

========================================
END OF REPORT
========================================
"@
        
        Set-Content -Path $LogPath -Value $logContent -Encoding UTF8
        Write-Log "Health check report written to: $LogPath"
        return $true
    } catch {
        Write-Log "Failed to write health check report: $_" "ERROR"
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

Write-Log "=== Starting Health Check ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$healthCheckLog = Join-Path $localDir "7_HealthCheck.log"

$powerShell7 = Test-PowerShell7
$winrm = Test-WinRM
$domain = Test-DomainMembership
$localAdmin = Test-LocalAdmin
$tools = Test-ToolsDeployment
$systemResources = Test-SystemResources
$network = Test-NetworkConnectivity
$criticalServices = Test-CriticalServices

$criticalIssues = @()
$recommendations = @()

if (-not $powerShell7.Installed) {
    $criticalIssues += "PowerShell 7 is not installed"
    $recommendations += "Install PowerShell 7 using 0_pwsh7.ps1"
}

if ($winrm.OverallStatus -ne "OK") {
    $criticalIssues += "WinRM is not properly configured"
    $recommendations += "Configure WinRM using 0_winrm.ps1"
}

if (-not $domain.PartOfDomain) {
    $criticalIssues += "Computer is not joined to domain"
    $recommendations += "Join domain using 3_JoinDomain_LVCC.ps1"
}

if (-not $localAdmin.DMLAdminsGroupExists) {
    $criticalIssues += "DML_Admins group does not exist"
    $recommendations += "Configure local admin using 4_LocalAdmin.ps1"
}

if ($tools.Tools.Where({$_.Exists}).Count -lt $tools.Tools.Count) {
    $criticalIssues += "Some tools are not deployed"
    $recommendations += "Deploy tools using 5_deploy_tools.ps1"
}

if ($systemResources.MemoryUsagePercent -gt 90) {
    $criticalIssues += "High memory usage: $($systemResources.MemoryUsagePercent)%"
    $recommendations += "Investigate memory usage and free up resources"
}

foreach ($disk in $systemResources.Disks) {
    if ($disk.UsagePercent -gt 90) {
        $criticalIssues += "High disk usage on $($disk.Drive): $([math]::Round($disk.UsagePercent, 1))%"
        $recommendations += "Free up disk space on $($disk.Drive)"
    }
}

if (-not $network.DNSConnectivity) {
    $criticalIssues += "DNS connectivity issue detected"
    $recommendations += "Check network configuration and DNS settings"
}

$stoppedServices = $criticalServices.Services.Where({$_.Status -ne "Running"})
if ($stoppedServices.Count -gt 0) {
    $criticalIssues += "Some critical services are not running"
    $recommendations += "Start stopped services: $($stoppedServices.DisplayName -join ', ')"
}

$overallStatus = if ($criticalIssues.Count -eq 0) { "HEALTHY" } elseif ($criticalIssues.Count -le 3) { "WARNING" } else { "CRITICAL" }

$healthData = @{
    OverallStatus = $overallStatus
    CriticalIssues = $criticalIssues
    Recommendations = $recommendations
    PowerShell7 = $powerShell7
    WinRM = $winrm
    Domain = $domain
    LocalAdmin = $localAdmin
    Tools = $tools
    SystemResources = $systemResources
    Network = $network
    CriticalServices = $criticalServices
}

Write-HealthCheckLog -LogPath $healthCheckLog -Data $healthData

$logUploadPath = $config.paths.log_upload_path
$uploadResult = Upload-Log -SourcePath $healthCheckLog -DestPath $logUploadPath -Prefix $env:COMPUTERNAME

if ($uploadResult) {
    Write-Log "=== Health Check Completed ==="
    Write-Log "Overall Status: $overallStatus"
    Write-Log "Critical Issues: $($criticalIssues.Count)"
    
    if ($criticalIssues.Count -gt 0) {
        exit 1
    } else {
        exit 0
    }
} else {
    Write-Log "=== Health Check Completed but Upload Failed ===" "ERROR"
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

function Test-PowerShell7 {
    try {
        Write-Log "Checking PowerShell 7 installation..."
        
        $pwsh7Path = "C:\Program Files\PowerShell\7\pwsh.exe"
        if (Test-Path $pwsh7Path) {
            $version = & $pwsh7Path --version
            Write-Log "PowerShell 7 installed: $version"
            return @{
                Installed = $true
                Version = $version
                Path = $pwsh7Path
            }
        } else {
            Write-Log "PowerShell 7 not found" "WARN"
            return @{
                Installed = $false
                Version = "N/A"
                Path = "N/A"
            }
        }
    } catch {
        Write-Log "PowerShell 7 check failed: $_" "ERROR"
        return @{
            Installed = $false
            Version = "Error"
            Path = "N/A"
        }
    }
}

function Test-WinRM {
    try {
        Write-Log "Checking WinRM status..."
        
        $winrmService = Get-Service -Name WinRM -ErrorAction SilentlyContinue
        if ($winrmService) {
            $status = $winrmService.Status
            $startType = $winrmService.StartType
            
            if ($status -eq "Running") {
                Write-Log "WinRM service is running"
                
                $listener = winrm enumerate winrm/config/listener 2>&1
                $listenerEnabled = $listener -match "Transport.*HTTP"
                
                return @{
                    ServiceStatus = $status
                    StartType = $startType
                    ListenerEnabled = $listenerEnabled
                    OverallStatus = "OK"
                }
            } else {
                Write-Log "WinRM service is not running: $status" "WARN"
                return @{
                    ServiceStatus = $status
                    StartType = $startType
                    ListenerEnabled = $false
                    OverallStatus = "Not Running"
                }
            }
        } else {
            Write-Log "WinRM service not found" "WARN"
            return @{
                ServiceStatus = "Not Found"
                StartType = "N/A"
                ListenerEnabled = $false
                OverallStatus = "Not Installed"
            }
        }
    } catch {
        Write-Log "WinRM check failed: $_" "ERROR"
        return @{
            ServiceStatus = "Error"
            StartType = "N/A"
            ListenerEnabled = $false
            OverallStatus = "Error"
        }
    }
}

function Test-DomainMembership {
    try {
        Write-Log "Checking domain membership..."
        
        $computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
        $domain = $computerInfo.CsDomain
        $workgroup = $computerInfo.CsWorkgroup
        $partOfDomain = $computerInfo.CsPartOfDomain
        
        if ($partOfDomain) {
            Write-Log "Computer is joined to domain: $domain"
            return @{
                Domain = $domain
                Workgroup = $workgroup
                PartOfDomain = $true
                Status = "OK"
            }
        } else {
            Write-Log "Computer is not joined to domain (Workgroup: $workgroup)" "WARN"
            return @{
                Domain = "N/A"
                Workgroup = $workgroup
                PartOfDomain = $false
                Status = "Workgroup"
            }
        }
    } catch {
        Write-Log "Domain membership check failed: $_" "ERROR"
        return @{
            Domain = "Error"
            Workgroup = "Error"
            PartOfDomain = $false
            Status = "Error"
        }
    }
}

function Test-LocalAdmin {
    try {
        Write-Log "Checking local administrator configuration..."
        
        $adminGroup = Get-LocalGroup -Name "Administrators" -ErrorAction Stop
        $adminMembers = Get-LocalGroupMember -Group $adminGroup -ErrorAction Stop
        
        $adminUsers = @()
        foreach ($member in $adminMembers) {
            if ($member.ObjectClass -eq "User") {
                $adminUsers += $member.Name
            }
        }
        
        $dmlAdminsGroup = Get-LocalGroup -Name "DML_Admins" -ErrorAction SilentlyContinue
        $dmlAdminsExists = $dmlAdminsGroup -ne $null
        
        $defaultAdmin = Get-LocalUser -Name "Administrator" -ErrorAction SilentlyContinue
        $defaultAdminEnabled = $defaultAdmin -and $defaultAdmin.Enabled
        
        Write-Log "Found $($adminUsers.Count) administrator users"
        
        return @{
            AdminUsers = $adminUsers
            DMLAdminsGroupExists = $dmlAdminsExists
            DefaultAdminEnabled = $defaultAdminEnabled
            Status = "OK"
        }
    } catch {
        Write-Log "Local admin check failed: $_" "ERROR"
        return @{
            AdminUsers = @()
            DMLAdminsGroupExists = $false
            DefaultAdminEnabled = $false
            Status = "Error"
        }
    }
}

function Test-ToolsDeployment {
    try {
        Write-Log "Checking tools deployment..."
        
        $toolsToCheck = @(
            @{Name = "putty.exe"; Path = "C:\Windows\System32\putty.exe"},
            @{Name = "pscp.exe"; Path = "C:\Windows\System32\pscp.exe"},
            @{Name = "plink.exe"; Path = "C:\Windows\System32\plink.exe"}
        )
        
        $toolsStatus = @()
        
        foreach ($tool in $toolsToCheck) {
            $exists = Test-Path $tool.Path
            $toolsStatus += @{
                Name = $tool.Name
                Path = $tool.Path
                Exists = $exists
            }
            
            if ($exists) {
                Write-Log "Tool found: $($tool.Name)"
            } else {
                Write-Log "Tool not found: $($tool.Name)" "WARN"
            }
        }
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        $sysinternalsExists = Test-Path $sysinternalsPath
        $sysinternalsCount = 0
        
        if ($sysinternalsExists) {
            $sysinternalsCount = (Get-ChildItem -Path $sysinternalsPath -File).Count
            Write-Log "Sysinternals tools found: $sysinternalsCount tools"
        } else {
            Write-Log "Sysinternals tools not found" "WARN"
        }
        
        return @{
            Tools = $toolsStatus
            SysinternalsExists = $sysinternalsExists
            SysinternalsCount = $sysinternalsCount
            Status = "OK"
        }
    } catch {
        Write-Log "Tools deployment check failed: $_" "ERROR"
        return @{
            Tools = @()
            SysinternalsExists = $false
            SysinternalsCount = 0
            Status = "Error"
        }
    }
}

function Test-SystemResources {
    try {
        Write-Log "Checking system resources..."
        
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $cpu = Get-CimInstance -ClassName Win32_Processor
        $memory = Get-CimInstance -ClassName Win32_ComputerSystem
        $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
        
        $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
        $freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $memoryUsagePercent = [math]::Round((($totalMemoryGB - $freeMemoryGB) / $totalMemoryGB) * 100, 2)
        
        $diskInfo = @()
        foreach ($disk in $disks) {
            $totalSizeGB = [math]::Round($disk.Size / 1GB, 2)
            $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $usagePercent = [math]::Round((($totalSizeGB - $freeSpaceGB) / $totalSizeGB) * 100, 2)
            
            $diskInfo += @{
                Drive = $disk.DeviceID
                TotalSizeGB = $totalSizeGB
                FreeSpaceGB = $freeSpaceGB
                UsagePercent = $usagePercent
            }
        }
        
        $cpuLoad = $os.LoadPercentage
        
        Write-Log "CPU Load: $cpuLoad%"
        Write-Log "Memory Usage: $memoryUsagePercent% ($freeMemoryGB GB free)"
        
        return @{
            CPUName = $cpu.Name
            CPULoad = $cpuLoad
            TotalMemoryGB = $totalMemoryGB
            FreeMemoryGB = $freeMemoryGB
            MemoryUsagePercent = $memoryUsagePercent
            Disks = $diskInfo
            Status = "OK"
        }
    } catch {
        Write-Log "System resources check failed: $_" "ERROR"
        return @{
            CPUName = "Error"
            CPULoad = 0
            TotalMemoryGB = 0
            FreeMemoryGB = 0
            MemoryUsagePercent = 0
            Disks = @()
            Status = "Error"
        }
    }
}

function Test-NetworkConnectivity {
    try {
        Write-Log "Checking network connectivity..."
        
        $networkAdapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
        
        $adapterInfo = @()
        foreach ($adapter in $networkAdapters) {
            $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            
            $adapterInfo += @{
                Name = $adapter.Name
                Description = $adapter.InterfaceDescription
                IPAddress = $ipConfig.IPAddress
                SubnetMask = $ipConfig.PrefixLength
                DNSServers = $dnsServers.ServerAddresses
            }
        }
        
        $defaultGateway = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
        $gatewayIP = $defaultGateway.NextHop
        
        $dnsTest = Test-NetConnection -ComputerName "8.8.8.8" -InformationLevel Quiet -ErrorAction SilentlyContinue
        
        Write-Log "Network adapters: $($adapterInfo.Count)"
        Write-Log "DNS connectivity: $dnsTest"
        
        return @{
            Adapters = $adapterInfo
            DefaultGateway = $gatewayIP
            DNSConnectivity = $dnsTest
            Status = "OK"
        }
    } catch {
        Write-Log "Network connectivity check failed: $_" "ERROR"
        return @{
            Adapters = @()
            DefaultGateway = "Error"
            DNSConnectivity = $false
            Status = "Error"
        }
    }
}

function Test-CriticalServices {
    try {
        Write-Log "Checking critical services..."
        
        $criticalServices = @(
            @{Name = "WinRM"; DisplayName = "Windows Remote Management"},
            @{Name = "LanmanServer"; DisplayName = "Server"},
            @{Name = "Schedule"; DisplayName = "Task Scheduler"},
            @{Name = "W32Time"; DisplayName = "Windows Time"}
        )
        
        $servicesStatus = @()
        
        foreach ($service in $criticalServices) {
            $svc = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
            if ($svc) {
                $servicesStatus += @{
                    Name = $service.Name
                    DisplayName = $service.DisplayName
                    Status = $svc.Status
                    StartType = $svc.StartType
                }
                
                if ($svc.Status -eq "Running") {
                    Write-Log "Service OK: $($service.DisplayName)"
                } else {
                    Write-Log "Service not running: $($service.DisplayName) - $($svc.Status)" "WARN"
                }
            } else {
                $servicesStatus += @{
                    Name = $service.Name
                    DisplayName = $service.DisplayName
                    Status = "Not Found"
                    StartType = "N/A"
                }
                Write-Log "Service not found: $($service.DisplayName)" "WARN"
            }
        }
        
        return @{
            Services = $servicesStatus
            Status = "OK"
        }
    } catch {
        Write-Log "Critical services check failed: $_" "ERROR"
        return @{
            Services = @()
            Status = "Error"
        }
    }
}

function Write-HealthCheckLog {
    param(
        [string]$LogPath,
        [hashtable]$Data
    )
    
    try {
        $logContent = @"
========================================
HEALTH CHECK REPORT
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Hostname: $env:COMPUTERNAME

========================================
HEALTH SUMMARY
========================================
Overall Status: $($Data.OverallStatus)
Critical Issues: $($Data.CriticalIssues.Count)

========================================
DETAILED CHECKS
========================================

1. POWERSHELL 7
---------------------------
Installed: $($Data.PowerShell7.Installed)
Version: $($Data.PowerShell7.Version)
Path: $($Data.PowerShell7.Path)
Status: $($Data.PowerShell7.Status)

2. WINRM STATUS
---------------------------
Service Status: $($Data.WinRM.ServiceStatus)
Start Type: $($Data.WinRM.StartType)
Listener Enabled: $($Data.WinRM.ListenerEnabled)
Overall Status: $($Data.WinRM.OverallStatus)

3. DOMAIN MEMBERSHIP
---------------------------
Domain: $($Data.Domain.Domain)
Workgroup: $($Data.Domain.Workgroup)
Part of Domain: $($Data.Domain.PartOfDomain)
Status: $($Data.Domain.Status)

4. LOCAL ADMIN CONFIGURATION
---------------------------
DML Admins Group Exists: $($Data.LocalAdmin.DMLAdminsGroupExists)
Default Admin Enabled: $($Data.LocalAdmin.DefaultAdminEnabled)
Admin Users: $($Data.LocalAdmin.AdminUsers -join ", ")
Status: $($Data.LocalAdmin.Status)

5. TOOLS DEPLOYMENT
---------------------------
PuTTY Tools: $($Data.Tools.Tools.Where({$_.Exists}).Count)/$($Data.Tools.Tools.Count)
Sysinternals Exists: $($Data.Tools.SysinternalsExists)
Sysinternals Count: $($Data.Tools.SysinternalsCount)
Status: $($Data.Tools.Status)

6. SYSTEM RESOURCES
---------------------------
CPU: $($Data.SystemResources.CPUName)
CPU Load: $($Data.SystemResources.CPULoad)%
Memory: $($Data.SystemResources.TotalMemoryGB) GB Total, $($Data.SystemResources.FreeMemoryGB) GB Free
Memory Usage: $($Data.SystemResources.MemoryUsagePercent)%

Disk Usage:
$($Data.SystemResources.Disks | ForEach-Object { "  $($_.Drive): $([math]::Round($_.UsagePercent, 1))% used ($([math]::Round($_.FreeSpaceGB, 2)) GB free)" })

Status: $($Data.SystemResources.Status)

7. NETWORK CONNECTIVITY
---------------------------
Active Adapters: $($Data.Network.Adapters.Count)
Default Gateway: $($Data.Network.DefaultGateway)
DNS Connectivity: $($Data.Network.DNSConnectivity)

Adapters:
$($Data.Network.Adapters | ForEach-Object { "  $($_.Name): $($_.IPAddress)" })

Status: $($Data.Network.Status)

8. CRITICAL SERVICES
---------------------------
$($Data.CriticalServices.Services | ForEach-Object { "$($_.DisplayName): $($_.Status) ($($_.StartType))" })

Status: $($Data.CriticalServices.Status)

========================================
CRITICAL ISSUES
========================================
$($Data.CriticalIssues -join "`n")

========================================
RECOMMENDATIONS
========================================
$($Data.Recommendations -join "`n")

========================================
END OF REPORT
========================================
"@
        
        Set-Content -Path $LogPath -Value $logContent -Encoding UTF8
        Write-Log "Health check report written to: $LogPath"
        return $true
    } catch {
        Write-Log "Failed to write health check report: $_" "ERROR"
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

Write-Log "=== Starting Health Check ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$healthCheckLog = Join-Path $localDir "7_HealthCheck.log"

$powerShell7 = Test-PowerShell7
$winrm = Test-WinRM
$domain = Test-DomainMembership
$localAdmin = Test-LocalAdmin
$tools = Test-ToolsDeployment
$systemResources = Test-SystemResources
$network = Test-NetworkConnectivity
$criticalServices = Test-CriticalServices

$criticalIssues = @()
$recommendations = @()

if (-not $powerShell7.Installed) {
    $criticalIssues += "PowerShell 7 is not installed"
    $recommendations += "Install PowerShell 7 using 0_pwsh7.ps1"
}

if ($winrm.OverallStatus -ne "OK") {
    $criticalIssues += "WinRM is not properly configured"
    $recommendations += "Configure WinRM using 0_winrm.ps1"
}

if (-not $domain.PartOfDomain) {
    $criticalIssues += "Computer is not joined to domain"
    $recommendations += "Join domain using 3_JoinDomain_LVCC.ps1"
}

if (-not $localAdmin.DMLAdminsGroupExists) {
    $criticalIssues += "DML_Admins group does not exist"
    $recommendations += "Configure local admin using 4_LocalAdmin.ps1"
}

if ($tools.Tools.Where({$_.Exists}).Count -lt $tools.Tools.Count) {
    $criticalIssues += "Some tools are not deployed"
    $recommendations += "Deploy tools using 5_deploy_tools.ps1"
}

if ($systemResources.MemoryUsagePercent -gt 90) {
    $criticalIssues += "High memory usage: $($systemResources.MemoryUsagePercent)%"
    $recommendations += "Investigate memory usage and free up resources"
}

foreach ($disk in $systemResources.Disks) {
    if ($disk.UsagePercent -gt 90) {
        $criticalIssues += "High disk usage on $($disk.Drive): $([math]::Round($disk.UsagePercent, 1))%"
        $recommendations += "Free up disk space on $($disk.Drive)"
    }
}

if (-not $network.DNSConnectivity) {
    $criticalIssues += "DNS connectivity issue detected"
    $recommendations += "Check network configuration and DNS settings"
}

$stoppedServices = $criticalServices.Services.Where({$_.Status -ne "Running"})
if ($stoppedServices.Count -gt 0) {
    $criticalIssues += "Some critical services are not running"
    $recommendations += "Start stopped services: $($stoppedServices.DisplayName -join ', ')"
}

$overallStatus = if ($criticalIssues.Count -eq 0) { "HEALTHY" } elseif ($criticalIssues.Count -le 3) { "WARNING" } else { "CRITICAL" }

$healthData = @{
    OverallStatus = $overallStatus
    CriticalIssues = $criticalIssues
    Recommendations = $recommendations
    PowerShell7 = $powerShell7
    WinRM = $winrm
    Domain = $domain
    LocalAdmin = $localAdmin
    Tools = $tools
    SystemResources = $systemResources
    Network = $network
    CriticalServices = $criticalServices
}

Write-HealthCheckLog -LogPath $healthCheckLog -Data $healthData

$logUploadPath = $config.paths.log_upload_path
$uploadResult = Upload-Log -SourcePath $healthCheckLog -DestPath $logUploadPath -Prefix $env:COMPUTERNAME

if ($uploadResult) {
    Write-Log "=== Health Check Completed ==="
    Write-Log "Overall Status: $overallStatus"
    Write-Log "Critical Issues: $($criticalIssues.Count)"
    
    if ($criticalIssues.Count -gt 0) {
        exit 1
    } else {
        exit 0
    }
} else {
    Write-Log "=== Health Check Completed but Upload Failed ===" "ERROR"
    exit 1
}


function Test-PowerShell7 {
    try {
        Write-Log "Checking PowerShell 7 installation..."
        
        $pwsh7Path = "C:\Program Files\PowerShell\7\pwsh.exe"
        if (Test-Path $pwsh7Path) {
            $version = & $pwsh7Path --version
            Write-Log "PowerShell 7 installed: $version"
            return @{
                Installed = $true
                Version = $version
                Path = $pwsh7Path
            }
        } else {
            Write-Log "PowerShell 7 not found" "WARN"
            return @{
                Installed = $false
                Version = "N/A"
                Path = "N/A"
            }
        }
    } catch {
        Write-Log "PowerShell 7 check failed: $_" "ERROR"
        return @{
            Installed = $false
            Version = "Error"
            Path = "N/A"
        }
    }
}

function Test-WinRM {
    try {
        Write-Log "Checking WinRM status..."
        
        $winrmService = Get-Service -Name WinRM -ErrorAction SilentlyContinue
        if ($winrmService) {
            $status = $winrmService.Status
            $startType = $winrmService.StartType
            
            if ($status -eq "Running") {
                Write-Log "WinRM service is running"
                
                $listener = winrm enumerate winrm/config/listener 2>&1
                $listenerEnabled = $listener -match "Transport.*HTTP"
                
                return @{
                    ServiceStatus = $status
                    StartType = $startType
                    ListenerEnabled = $listenerEnabled
                    OverallStatus = "OK"
                }
            } else {
                Write-Log "WinRM service is not running: $status" "WARN"
                return @{
                    ServiceStatus = $status
                    StartType = $startType
                    ListenerEnabled = $false
                    OverallStatus = "Not Running"
                }
            }
        } else {
            Write-Log "WinRM service not found" "WARN"
            return @{
                ServiceStatus = "Not Found"
                StartType = "N/A"
                ListenerEnabled = $false
                OverallStatus = "Not Installed"
            }
        }
    } catch {
        Write-Log "WinRM check failed: $_" "ERROR"
        return @{
            ServiceStatus = "Error"
            StartType = "N/A"
            ListenerEnabled = $false
            OverallStatus = "Error"
        }
    }
}

function Test-DomainMembership {
    try {
        Write-Log "Checking domain membership..."
        
        $computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
        $domain = $computerInfo.CsDomain
        $workgroup = $computerInfo.CsWorkgroup
        $partOfDomain = $computerInfo.CsPartOfDomain
        
        if ($partOfDomain) {
            Write-Log "Computer is joined to domain: $domain"
            return @{
                Domain = $domain
                Workgroup = $workgroup
                PartOfDomain = $true
                Status = "OK"
            }
        } else {
            Write-Log "Computer is not joined to domain (Workgroup: $workgroup)" "WARN"
            return @{
                Domain = "N/A"
                Workgroup = $workgroup
                PartOfDomain = $false
                Status = "Workgroup"
            }
        }
    } catch {
        Write-Log "Domain membership check failed: $_" "ERROR"
        return @{
            Domain = "Error"
            Workgroup = "Error"
            PartOfDomain = $false
            Status = "Error"
        }
    }
}

function Test-LocalAdmin {
    try {
        Write-Log "Checking local administrator configuration..."
        
        $adminGroup = Get-LocalGroup -Name "Administrators" -ErrorAction Stop
        $adminMembers = Get-LocalGroupMember -Group $adminGroup -ErrorAction Stop
        
        $adminUsers = @()
        foreach ($member in $adminMembers) {
            if ($member.ObjectClass -eq "User") {
                $adminUsers += $member.Name
            }
        }
        
        $dmlAdminsGroup = Get-LocalGroup -Name "DML_Admins" -ErrorAction SilentlyContinue
        $dmlAdminsExists = $dmlAdminsGroup -ne $null
        
        $defaultAdmin = Get-LocalUser -Name "Administrator" -ErrorAction SilentlyContinue
        $defaultAdminEnabled = $defaultAdmin -and $defaultAdmin.Enabled
        
        Write-Log "Found $($adminUsers.Count) administrator users"
        
        return @{
            AdminUsers = $adminUsers
            DMLAdminsGroupExists = $dmlAdminsExists
            DefaultAdminEnabled = $defaultAdminEnabled
            Status = "OK"
        }
    } catch {
        Write-Log "Local admin check failed: $_" "ERROR"
        return @{
            AdminUsers = @()
            DMLAdminsGroupExists = $false
            DefaultAdminEnabled = $false
            Status = "Error"
        }
    }
}

function Test-ToolsDeployment {
    try {
        Write-Log "Checking tools deployment..."
        
        $toolsToCheck = @(
            @{Name = "putty.exe"; Path = "C:\Windows\System32\putty.exe"},
            @{Name = "pscp.exe"; Path = "C:\Windows\System32\pscp.exe"},
            @{Name = "plink.exe"; Path = "C:\Windows\System32\plink.exe"}
        )
        
        $toolsStatus = @()
        
        foreach ($tool in $toolsToCheck) {
            $exists = Test-Path $tool.Path
            $toolsStatus += @{
                Name = $tool.Name
                Path = $tool.Path
                Exists = $exists
            }
            
            if ($exists) {
                Write-Log "Tool found: $($tool.Name)"
            } else {
                Write-Log "Tool not found: $($tool.Name)" "WARN"
            }
        }
        
        $sysinternalsPath = Join-Path $env:ProgramFiles "SysinternalsSuite"
        $sysinternalsExists = Test-Path $sysinternalsPath
        $sysinternalsCount = 0
        
        if ($sysinternalsExists) {
            $sysinternalsCount = (Get-ChildItem -Path $sysinternalsPath -File).Count
            Write-Log "Sysinternals tools found: $sysinternalsCount tools"
        } else {
            Write-Log "Sysinternals tools not found" "WARN"
        }
        
        return @{
            Tools = $toolsStatus
            SysinternalsExists = $sysinternalsExists
            SysinternalsCount = $sysinternalsCount
            Status = "OK"
        }
    } catch {
        Write-Log "Tools deployment check failed: $_" "ERROR"
        return @{
            Tools = @()
            SysinternalsExists = $false
            SysinternalsCount = 0
            Status = "Error"
        }
    }
}

function Test-SystemResources {
    try {
        Write-Log "Checking system resources..."
        
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $cpu = Get-CimInstance -ClassName Win32_Processor
        $memory = Get-CimInstance -ClassName Win32_ComputerSystem
        $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
        
        $totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
        $freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $memoryUsagePercent = [math]::Round((($totalMemoryGB - $freeMemoryGB) / $totalMemoryGB) * 100, 2)
        
        $diskInfo = @()
        foreach ($disk in $disks) {
            $totalSizeGB = [math]::Round($disk.Size / 1GB, 2)
            $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $usagePercent = [math]::Round((($totalSizeGB - $freeSpaceGB) / $totalSizeGB) * 100, 2)
            
            $diskInfo += @{
                Drive = $disk.DeviceID
                TotalSizeGB = $totalSizeGB
                FreeSpaceGB = $freeSpaceGB
                UsagePercent = $usagePercent
            }
        }
        
        $cpuLoad = $os.LoadPercentage
        
        Write-Log "CPU Load: $cpuLoad%"
        Write-Log "Memory Usage: $memoryUsagePercent% ($freeMemoryGB GB free)"
        
        return @{
            CPUName = $cpu.Name
            CPULoad = $cpuLoad
            TotalMemoryGB = $totalMemoryGB
            FreeMemoryGB = $freeMemoryGB
            MemoryUsagePercent = $memoryUsagePercent
            Disks = $diskInfo
            Status = "OK"
        }
    } catch {
        Write-Log "System resources check failed: $_" "ERROR"
        return @{
            CPUName = "Error"
            CPULoad = 0
            TotalMemoryGB = 0
            FreeMemoryGB = 0
            MemoryUsagePercent = 0
            Disks = @()
            Status = "Error"
        }
    }
}

function Test-NetworkConnectivity {
    try {
        Write-Log "Checking network connectivity..."
        
        $networkAdapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
        
        $adapterInfo = @()
        foreach ($adapter in $networkAdapters) {
            $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            
            $adapterInfo += @{
                Name = $adapter.Name
                Description = $adapter.InterfaceDescription
                IPAddress = $ipConfig.IPAddress
                SubnetMask = $ipConfig.PrefixLength
                DNSServers = $dnsServers.ServerAddresses
            }
        }
        
        $defaultGateway = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
        $gatewayIP = $defaultGateway.NextHop
        
        $dnsTest = Test-NetConnection -ComputerName "8.8.8.8" -InformationLevel Quiet -ErrorAction SilentlyContinue
        
        Write-Log "Network adapters: $($adapterInfo.Count)"
        Write-Log "DNS connectivity: $dnsTest"
        
        return @{
            Adapters = $adapterInfo
            DefaultGateway = $gatewayIP
            DNSConnectivity = $dnsTest
            Status = "OK"
        }
    } catch {
        Write-Log "Network connectivity check failed: $_" "ERROR"
        return @{
            Adapters = @()
            DefaultGateway = "Error"
            DNSConnectivity = $false
            Status = "Error"
        }
    }
}

function Test-CriticalServices {
    try {
        Write-Log "Checking critical services..."
        
        $criticalServices = @(
            @{Name = "WinRM"; DisplayName = "Windows Remote Management"},
            @{Name = "LanmanServer"; DisplayName = "Server"},
            @{Name = "Schedule"; DisplayName = "Task Scheduler"},
            @{Name = "W32Time"; DisplayName = "Windows Time"}
        )
        
        $servicesStatus = @()
        
        foreach ($service in $criticalServices) {
            $svc = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
            if ($svc) {
                $servicesStatus += @{
                    Name = $service.Name
                    DisplayName = $service.DisplayName
                    Status = $svc.Status
                    StartType = $svc.StartType
                }
                
                if ($svc.Status -eq "Running") {
                    Write-Log "Service OK: $($service.DisplayName)"
                } else {
                    Write-Log "Service not running: $($service.DisplayName) - $($svc.Status)" "WARN"
                }
            } else {
                $servicesStatus += @{
                    Name = $service.Name
                    DisplayName = $service.DisplayName
                    Status = "Not Found"
                    StartType = "N/A"
                }
                Write-Log "Service not found: $($service.DisplayName)" "WARN"
            }
        }
        
        return @{
            Services = $servicesStatus
            Status = "OK"
        }
    } catch {
        Write-Log "Critical services check failed: $_" "ERROR"
        return @{
            Services = @()
            Status = "Error"
        }
    }
}

function Write-HealthCheckLog {
    param(
        [string]$LogPath,
        [hashtable]$Data
    )
    
    try {
        $logContent = @"
========================================
HEALTH CHECK REPORT
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Hostname: $env:COMPUTERNAME

========================================
HEALTH SUMMARY
========================================
Overall Status: $($Data.OverallStatus)
Critical Issues: $($Data.CriticalIssues.Count)

========================================
DETAILED CHECKS
========================================

1. POWERSHELL 7
---------------------------
Installed: $($Data.PowerShell7.Installed)
Version: $($Data.PowerShell7.Version)
Path: $($Data.PowerShell7.Path)
Status: $($Data.PowerShell7.Status)

2. WINRM STATUS
---------------------------
Service Status: $($Data.WinRM.ServiceStatus)
Start Type: $($Data.WinRM.StartType)
Listener Enabled: $($Data.WinRM.ListenerEnabled)
Overall Status: $($Data.WinRM.OverallStatus)

3. DOMAIN MEMBERSHIP
---------------------------
Domain: $($Data.Domain.Domain)
Workgroup: $($Data.Domain.Workgroup)
Part of Domain: $($Data.Domain.PartOfDomain)
Status: $($Data.Domain.Status)

4. LOCAL ADMIN CONFIGURATION
---------------------------
DML Admins Group Exists: $($Data.LocalAdmin.DMLAdminsGroupExists)
Default Admin Enabled: $($Data.LocalAdmin.DefaultAdminEnabled)
Admin Users: $($Data.LocalAdmin.AdminUsers -join ", ")
Status: $($Data.LocalAdmin.Status)

5. TOOLS DEPLOYMENT
---------------------------
PuTTY Tools: $($Data.Tools.Tools.Where({$_.Exists}).Count)/$($Data.Tools.Tools.Count)
Sysinternals Exists: $($Data.Tools.SysinternalsExists)
Sysinternals Count: $($Data.Tools.SysinternalsCount)
Status: $($Data.Tools.Status)

6. SYSTEM RESOURCES
---------------------------
CPU: $($Data.SystemResources.CPUName)
CPU Load: $($Data.SystemResources.CPULoad)%
Memory: $($Data.SystemResources.TotalMemoryGB) GB Total, $($Data.SystemResources.FreeMemoryGB) GB Free
Memory Usage: $($Data.SystemResources.MemoryUsagePercent)%

Disk Usage:
$($Data.SystemResources.Disks | ForEach-Object { "  $($_.Drive): $([math]::Round($_.UsagePercent, 1))% used ($([math]::Round($_.FreeSpaceGB, 2)) GB free)" })

Status: $($Data.SystemResources.Status)

7. NETWORK CONNECTIVITY
---------------------------
Active Adapters: $($Data.Network.Adapters.Count)
Default Gateway: $($Data.Network.DefaultGateway)
DNS Connectivity: $($Data.Network.DNSConnectivity)

Adapters:
$($Data.Network.Adapters | ForEach-Object { "  $($_.Name): $($_.IPAddress)" })

Status: $($Data.Network.Status)

8. CRITICAL SERVICES
---------------------------
$($Data.CriticalServices.Services | ForEach-Object { "$($_.DisplayName): $($_.Status) ($($_.StartType))" })

Status: $($Data.CriticalServices.Status)

========================================
CRITICAL ISSUES
========================================
$($Data.CriticalIssues -join "`n")

========================================
RECOMMENDATIONS
========================================
$($Data.Recommendations -join "`n")

========================================
END OF REPORT
========================================
"@
        
        Set-Content -Path $LogPath -Value $logContent -Encoding UTF8
        Write-Log "Health check report written to: $LogPath"
        return $true
    } catch {
        Write-Log "Failed to write health check report: $_" "ERROR"
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

Write-Log "=== Starting Health Check ==="

if (-not (Test-Path $localDir)) {
    Write-Log "Local directory not found: $localDir" "ERROR"
    exit 1
}

$healthCheckLog = Join-Path $localDir "7_HealthCheck.log"

$powerShell7 = Test-PowerShell7
$winrm = Test-WinRM
$domain = Test-DomainMembership
$localAdmin = Test-LocalAdmin
$tools = Test-ToolsDeployment
$systemResources = Test-SystemResources
$network = Test-NetworkConnectivity
$criticalServices = Test-CriticalServices

$criticalIssues = @()
$recommendations = @()

if (-not $powerShell7.Installed) {
    $criticalIssues += "PowerShell 7 is not installed"
    $recommendations += "Install PowerShell 7 using 0_pwsh7.ps1"
}

if ($winrm.OverallStatus -ne "OK") {
    $criticalIssues += "WinRM is not properly configured"
    $recommendations += "Configure WinRM using 0_winrm.ps1"
}

if (-not $domain.PartOfDomain) {
    $criticalIssues += "Computer is not joined to domain"
    $recommendations += "Join domain using 3_JoinDomain_LVCC.ps1"
}

if (-not $localAdmin.DMLAdminsGroupExists) {
    $criticalIssues += "DML_Admins group does not exist"
    $recommendations += "Configure local admin using 4_LocalAdmin.ps1"
}

if ($tools.Tools.Where({$_.Exists}).Count -lt $tools.Tools.Count) {
    $criticalIssues += "Some tools are not deployed"
    $recommendations += "Deploy tools using 5_deploy_tools.ps1"
}

if ($systemResources.MemoryUsagePercent -gt 90) {
    $criticalIssues += "High memory usage: $($systemResources.MemoryUsagePercent)%"
    $recommendations += "Investigate memory usage and free up resources"
}

foreach ($disk in $systemResources.Disks) {
    if ($disk.UsagePercent -gt 90) {
        $criticalIssues += "High disk usage on $($disk.Drive): $([math]::Round($disk.UsagePercent, 1))%"
        $recommendations += "Free up disk space on $($disk.Drive)"
    }
}

if (-not $network.DNSConnectivity) {
    $criticalIssues += "DNS connectivity issue detected"
    $recommendations += "Check network configuration and DNS settings"
}

$stoppedServices = $criticalServices.Services.Where({$_.Status -ne "Running"})
if ($stoppedServices.Count -gt 0) {
    $criticalIssues += "Some critical services are not running"
    $recommendations += "Start stopped services: $($stoppedServices.DisplayName -join ', ')"
}

$overallStatus = if ($criticalIssues.Count -eq 0) { "HEALTHY" } elseif ($criticalIssues.Count -le 3) { "WARNING" } else { "CRITICAL" }

$healthData = @{
    OverallStatus = $overallStatus
    CriticalIssues = $criticalIssues
    Recommendations = $recommendations
    PowerShell7 = $powerShell7
    WinRM = $winrm
    Domain = $domain
    LocalAdmin = $localAdmin
    Tools = $tools
    SystemResources = $systemResources
    Network = $network
    CriticalServices = $criticalServices
}

Write-HealthCheckLog -LogPath $healthCheckLog -Data $healthData

$logUploadPath = $config.paths.log_upload_path
$uploadResult = Upload-Log -SourcePath $healthCheckLog -DestPath $logUploadPath -Prefix $env:COMPUTERNAME

if ($uploadResult) {
    Write-Log "=== Health Check Completed ==="
    Write-Log "Overall Status: $overallStatus"
    Write-Log "Critical Issues: $($criticalIssues.Count)"
    
    if ($criticalIssues.Count -gt 0) {
        exit 1
    } else {
        exit 0
    }
} else {
    Write-Log "=== Health Check Completed but Upload Failed ===" "ERROR"
    exit 1
}



