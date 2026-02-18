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

# Remove ExtensionSettings Policy
try {
    # 1. Try to remove the Property (New method)
    Remove-ItemProperty -Path $policyPath -Name "ExtensionSettings" -ErrorAction SilentlyContinue
    Write-Host "ExtensionSettings property removed."
}
catch {
    Write-Host "ExtensionSettings property not found."
}

try {
    # 2. Try to remove the Subkey (Old method/Cleanup)
    if (Test-Path $regPath) {
        Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Legacy ExtensionSettings key removed."
    }
}
catch {
    Write-Host "Legacy ExtensionSettings key not found."
}

# Remove Developer Tools restriction
try {
    Remove-ItemProperty -Path $policyPath -Name "DisableDeveloperTools" -ErrorAction SilentlyContinue
    Write-Host "Developer Tools restriction removed."
}
catch {
    Write-Host "Developer Tools restriction not found."
}

# Cleanup Files
Write-Host "Cleaning up files..."
if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force
    Write-Host "Installation directory removed."
}

Write-Host "Cleanup complete. Restart Firefox to revert changes."
