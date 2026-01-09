param(
    [string]$ScriptsPath = "D:\GitHub\SuperITOM\scripts\windows"
)

$ErrorActionPreference = "Stop"

Write-Host "Fixing all corrupted script files..."

$files = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" | Where-Object { $_.Name -ne "fix_all_corrupted.ps1" }

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    
    if ($content -match '\.Value\s*\n\s*\}\s*\n\s*return \$hashtable\s*\n\s*\} else \{[\s\S]*?\} else \{[\s\S]*?\}\s*\}\s*\n\s*function ') {
        Write-Host "Found corrupted file: $($file.Name)"
        
        $oldPattern = '\.Value\s*\n\s*\}\s*\n\s*return \$hashtable\s*\n\s*\} else \{[\s\S]*?\} else \{[\s\S]*?\}\s*\}\s*\n\s*function '
        $newPattern = "`n`nfunction "
        
        $newContent = $content -replace $oldPattern, $newPattern
        
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
        Write-Host "Fixed: $($file.Name)"
    }
}

Write-Host "Done!"
