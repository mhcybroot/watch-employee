$ErrorActionPreference = "Stop"

# Check for Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "Administrator rights are required. Re-run this script as Administrator."
}

$policyPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
$legacyRegPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\ExtensionSettings"
$installDir = "C:\ProgramData\WatchEmployee\firefox"

Write-Host "Step 1/2: Removing Firefox enterprise policy..."

# Remove ExtensionSettings Policy
try {
    Remove-ItemProperty -Path $policyPath -Name "ExtensionSettings" -ErrorAction SilentlyContinue
    Write-Host "ExtensionSettings property removed."
}
catch {
    Write-Host "ExtensionSettings property not found."
}

try {
    if (Test-Path $legacyRegPath) {
        Remove-Item -Path $legacyRegPath -Recurse -Force -ErrorAction SilentlyContinue
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

# Cleanup Files (after policy removal)
Write-Host "Step 2/2: Cleaning Firefox package files..."
if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force
    Write-Host "Firefox installation directory removed."
}
else {
    Write-Host "Firefox installation directory not found."
}

Write-Host "Cleanup complete. Restart Firefox to apply policy changes."
