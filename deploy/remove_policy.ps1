$ErrorActionPreference = "Stop"

# Check for Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {  
  Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"   
  Break   
}

$extensionId = "productivity-tracker@example.com"
$regPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\ExtensionSettings"
$policyPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
$installDir = "C:\ProgramData\WatchEmployee"

Write-Host "Removing Registry Policy..."

# Remove Validation Entry
try {
    Remove-ItemProperty -Path $regPath -Name $extensionId -ErrorAction SilentlyContinue
    Write-Host "Extension policy removed."
} catch {
    Write-Host "Extension policy not found or already removed."
}

# Remove Developer Tools restriction
try {
    Remove-ItemProperty -Path $policyPath -Name "DisableDeveloperTools" -ErrorAction SilentlyContinue
    Write-Host "Developer Tools restriction removed."
} catch {
    Write-Host "Developer Tools restriction not found."
}

# Cleanup Files
Write-Host "Cleaning up files..."
if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force
    Write-Host "Installation directory removed."
}

Write-Host "Cleanup complete. Restart Firefox to revert changes."
