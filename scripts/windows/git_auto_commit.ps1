param(
    [string]$CommitMessage = "",
    [string]$Branch = "main",
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
}

function Get-ChangesSummary {
    $status = git status --porcelain
    if (-not $status) {
        return $null
    }
    
    $summary = @{
        Modified = @()
        Added = @()
        Deleted = @()
        Untracked = @()
    }
    
    foreach ($line in $status) {
        $statusChar = $line[0]
        $filename = $line.Substring(3)
        
        switch ($statusChar) {
            "M" { $summary.Modified += $filename }
            "A" { $summary.Added += $filename }
            "D" { $summary.Deleted += $filename }
            "?" { $summary.Untracked += $filename }
        }
    }
    
    return $summary
}

function Format-CommitMessage {
    param(
        [string]$CustomMessage,
        [hashtable]$Changes
    )
    
    if ($CustomMessage) {
        return $CustomMessage
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $message = "Auto commit: $timestamp"
    
    if ($Changes.Modified.Count -gt 0) {
        $message += "`nModified: $($Changes.Modified.Count) file(s)"
    }
    if ($Changes.Added.Count -gt 0) {
        $message += "`nAdded: $($Changes.Added.Count) file(s)"
    }
    if ($Changes.Deleted.Count -gt 0) {
        $message += "`nDeleted: $($Changes.Deleted.Count) file(s)"
    }
    if ($Changes.Untracked.Count -gt 0) {
        $message += "`nNew: $($Changes.Untracked.Count) file(s)"
    }
    
    return $message
}

Write-Log "=== Git Auto Commit and Push ==="
Write-Log "Repository: $(Get-Location)"
Write-Log "Branch: $Branch"

try {
    $currentBranch = git rev-parse --abbrev-ref HEAD
    Write-Log "Current branch: $currentBranch"
    
    if ($currentBranch -ne $Branch) {
        Write-Log "Switching to branch: $Branch"
        git checkout $Branch
    }
    
    $changes = Get-ChangesSummary
    
    if (-not $changes) {
        Write-Log "No changes detected. Nothing to commit."
        Write-Log "=== Completed ==="
        exit 0
    }
    
    Write-Log "Changes detected:"
    if ($changes.Modified.Count -gt 0) {
        Write-Log "  Modified: $($changes.Modified.Count) file(s)"
        foreach ($file in $changes.Modified) {
            Write-Log "    - $file"
        }
    }
    if ($changes.Added.Count -gt 0) {
        Write-Log "  Added: $($changes.Added.Count) file(s)"
        foreach ($file in $changes.Added) {
            Write-Log "    - $file"
        }
    }
    if ($changes.Deleted.Count -gt 0) {
        Write-Log "  Deleted: $($changes.Deleted.Count) file(s)"
        foreach ($file in $changes.Deleted) {
            Write-Log "    - $file"
        }
    }
    if ($changes.Untracked.Count -gt 0) {
        Write-Log "  Untracked: $($changes.Untracked.Count) file(s)"
        foreach ($file in $changes.Untracked) {
            Write-Log "    - $file"
        }
    }
    
    Write-Log "Adding all changes..."
    git add .
    
    $commitMessage = Format-CommitMessage -CustomMessage $CommitMessage -Changes $changes
    Write-Log "Committing with message: $commitMessage"
    git commit -m $commitMessage
    
    Write-Log "Pushing to origin/$Branch..."
    
    if ($Force) {
        git push origin $Branch --force
    } else {
        git push origin $Branch
    }
    
    Write-Log "=== Successfully committed and pushed ==="
    exit 0
    
} catch {
    Write-Log "Error: $_" "ERROR"
    Write-Log "=== Failed ===" "ERROR"
    exit 1
}