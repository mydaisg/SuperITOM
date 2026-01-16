# Test remote Windows client connectivity and login
param(
    [string]$HostsFile = "D:\GitHub\SuperITOM\config\hosts_new.csv",
    [string]$TargetIP = "",
    [string]$TargetUser = "",
    [string]$TargetPassword = ""
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
            Remove-PSSession -Session $session
            return $true
        } else {
            Write-Log "Failed to create session to $ComputerName" "ERROR"
            return $false
        }
    } catch {
        Write-Log "WinRM connection test failed for $ComputerName : $_" "ERROR"
        return $false
    }
}

function Test-WinRMService {
    param([string]$ComputerName)
    
    try {
        Write-Log "Checking WinRM service on $ComputerName"
        
        $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
        
        $serviceStatus = Invoke-Command -ComputerName $ComputerName -SessionOption $sessionOption -ScriptBlock {
            Get-Service WinRM | Select-Object Status, StartType
        } -ErrorAction SilentlyContinue
        
        if ($serviceStatus) {
            Write-Log "WinRM Service Status: $($serviceStatus.Status), StartType: $($serviceStatus.StartType)"
            return $true
        } else {
            Write-Log "Could not retrieve WinRM service status" "WARN"
            return $false
        }
    } catch {
        Write-Log "Failed to check WinRM service: $_" "WARN"
        return $false
    }
}

function Test-WinRMListener {
    param([string]$ComputerName)
    
    try {
        Write-Log "Checking WinRM listener on $ComputerName"
        
        $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
        
        $listener = Invoke-Command -ComputerName $ComputerName -SessionOption $sessionOption -ScriptBlock {
            Get-ChildItem WSMan:\localhost\Listener -ErrorAction SilentlyContinue | Select-Object Name, Enabled
        } -ErrorAction SilentlyContinue
        
        if ($listener) {
            Write-Log "WinRM Listeners: $($listener.Name -join ', '), Enabled: $($listener.Enabled -join ', ')"
            return $true
        } else {
            Write-Log "No WinRM listeners found" "WARN"
            return $false
        }
    } catch {
        Write-Log "Failed to check WinRM listeners: $_" "WARN"
        return $false
    }
}

function Test-Ping {
    param([string]$ComputerName)
    
    try {
        Write-Log "Pinging $ComputerName"
        $ping = Test-Connection -ComputerName $ComputerName -Count 2 -Quiet
        
        if ($ping) {
            Write-Log "Ping successful for $ComputerName"
            return $true
        } else {
            Write-Log "Ping failed for $ComputerName" "WARN"
            return $false
        }
    } catch {
        Write-Log "Ping test failed for $ComputerName : $_" "ERROR"
        return $false
    }
}

Write-Log "=== Starting Remote Windows Client Test ==="

if ($TargetIP -and $TargetUser -and $TargetPassword) {
    Write-Log "Testing single target: $TargetIP"
    
    $pingResult = Test-Ping -ComputerName $TargetIP
    
    if ($pingResult) {
        $winrmResult = Test-WinRMConnection -ComputerName $TargetIP -Username $TargetUser -Password $TargetPassword
        
        if ($winrmResult) {
            Write-Log "=== Test Completed Successfully ==="
            exit 0
        } else {
            Write-Log "=== Test Failed (WinRM Connection) ===" "ERROR"
            exit 1
        }
    } else {
        Write-Log "=== Test Failed (Ping) ===" "ERROR"
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
        Write-Log "Testing host: $($host.IPAddress)"
        
        $pingResult = Test-Ping -ComputerName $host.IPAddress
        
        if ($pingResult) {
            Write-Log "Ping successful, checking WinRM configuration..."
            
            $serviceResult = Test-WinRMService -ComputerName $host.IPAddress
            $listenerResult = Test-WinRMListener -ComputerName $host.IPAddress
            
            $winrmResult = Test-WinRMConnection -ComputerName $host.IPAddress -Username $host.User -Password $host.Password
            
            if ($winrmResult) {
                $successCount++
                Write-Log "Host $($host.IPAddress): SUCCESS"
            } else {
                $failCount++
                Write-Log "Host $($host.IPAddress): FAILED (WinRM)" "ERROR"
                Write-Log "  - Service Check: $(if ($serviceResult) { 'PASSED' } else { 'FAILED' })"
                Write-Log "  - Listener Check: $(if ($listenerResult) { 'PASSED' } else { 'FAILED' })"
            }
        } else {
            $failCount++
            Write-Log "Host $($host.IPAddress): FAILED (Ping)" "ERROR"
        }
        
        Write-Log ""
    }
    
    Write-Log "=== Test Summary ==="
    Write-Log "Total hosts: $($hosts.Count)"
    Write-Log "Successful: $successCount"
    Write-Log "Failed: $failCount"
    
    if ($failCount -eq 0) {
        Write-Log "=== All Tests Completed Successfully ==="
        exit 0
    } else {
        Write-Log "=== Some Tests Failed ===" "ERROR"
        exit 1
    }
} else {
    Write-Log "Hosts file not found: $HostsFile" "ERROR"
    exit 1
}
