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

function Write-Plain {
    param([string]$Message)
    Write-Host $Message
}

function Test-WinRMConnection {
    param(
        [string]$ComputerName,
        [string]$Username,
        [string]$Password
    )
    
    try {
        Write-Log "Testing WinRM connection to $ComputerName with user $Username"
        
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)
        
        $sessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
        
        Write-Log "  - Creating PSSession..."
        $session = New-PSSession -ComputerName $ComputerName -Credential $credential -SessionOption $sessionOption -ErrorAction Stop
        
        if ($session) {
            Write-Log "  - Session created successfully: $($session.Name)"
            Write-Log "  - Session state: $($session.State)"
            Write-Log "  - Session availability: $($session.Availability)"
            
            Write-Log "Testing command execution..."
            $testResult = Invoke-Command -Session $session -ScriptBlock {
                return "Connection test successful"
            } -ErrorAction Stop
            
            Write-Log "  - Command execution result: $testResult"
            
            Write-Log "Successfully connected to $ComputerName"
            Remove-PSSession -Session $session
            Write-Log "  - Session closed"
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
            Get-Service WinRM | Select-Object Status, StartType, DisplayName
        } -ErrorAction SilentlyContinue
        
        if ($serviceStatus) {
            Write-Log "  - Service Name: WinRM"
            Write-Log "  - Display Name: $($serviceStatus.DisplayName)"
            Write-Log "  - Status: $($serviceStatus.Status)"
            Write-Log "  - Start Type: $($serviceStatus.StartType)"
            
            if ($serviceStatus.Status -eq "Running") {
                Write-Log "WinRM Service Status: Running"
                return $true
            } else {
                Write-Log "WinRM Service is not running (Current: $($serviceStatus.Status))" "WARN"
                return $false
            }
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
            Get-ChildItem WSMan:\localhost\Listener -ErrorAction SilentlyContinue | 
                Select-Object Name, Enabled, @{Name='Transport'; Expression={$_.PSChildName}}
        } -ErrorAction SilentlyContinue
        
        if ($listener) {
            Write-Log "  - Found $($listener.Count) listener(s)"
            foreach ($l in $listener) {
                Write-Log "    - Listener: $($l.Name)"
                Write-Log "      Transport: $($l.Transport)"
                Write-Log "      Enabled: $($l.Enabled)"
            }
            
            $enabledListeners = $listener | Where-Object { $_.Enabled -eq $true }
            if ($enabledListeners) {
                Write-Log "WinRM Listeners: $($enabledListeners.Transport -join ', '), Enabled: Yes"
                return $true
            } else {
                Write-Log "No enabled WinRM listeners found" "WARN"
                return $false
            }
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
        $pingOutput = ping $ComputerName 2>&1 | Out-String
        
        Write-Plain $pingOutput
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Ping successful"
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
        Write-Log "Ping successful, checking WinRM configuration..."
        
        $serviceResult = Test-WinRMService -ComputerName $TargetIP
        $listenerResult = Test-WinRMListener -ComputerName $TargetIP
        
        Write-Log "  - Service Check: $(if ($serviceResult) { 'PASSED' } else { 'FAILED' })"
        Write-Log "  - Listener Check: $(if ($listenerResult) { 'PASSED' } else { 'FAILED' })"
        
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
    
    foreach ($hostEntry in $hosts) {
        Write-Log "Testing host: $($hostEntry.IPAddress)"
        
        $pingResult = Test-Ping -ComputerName $hostEntry.IPAddress
        
        if ($pingResult) {
            Write-Log "Ping successful, checking WinRM configuration..."
            
            $serviceResult = Test-WinRMService -ComputerName $hostEntry.IPAddress
            $listenerResult = Test-WinRMListener -ComputerName $hostEntry.IPAddress
            
            Write-Log "  - Service Check: $(if ($serviceResult) { 'PASSED' } else { 'FAILED' })"
            Write-Log "  - Listener Check: $(if ($listenerResult) { 'PASSED' } else { 'FAILED' })"
            
            $winrmResult = Test-WinRMConnection -ComputerName $hostEntry.IPAddress -Username $hostEntry.User -Password $hostEntry.Password
            
            if ($winrmResult) {
                $successCount++
                Write-Log "Host $($hostEntry.IPAddress): SUCCESS"
            } else {
                $failCount++
                Write-Log "Host $($hostEntry.IPAddress): FAILED (WinRM)" "ERROR"
            }
        } else {
            $failCount++
            Write-Log "Host $($hostEntry.IPAddress): FAILED (Ping)" "ERROR"
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
