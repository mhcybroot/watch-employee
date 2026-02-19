$ErrorActionPreference = "Stop"

# Check for Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {  
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"   
    Break   
}

$paramBaseDir = $PSScriptRoot
$xpiSource = Join-Path $paramBaseDir "watch-employee.xpi"
$installDir = "C:\ProgramData\WatchEmployee"
$xpiDest = Join-Path $installDir "extension.xpi"
$extensionId = "it@skylink-ltd.com"

# 1. Prepare Installation Directory
Write-Host "Creating installation directory: $installDir"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir | Out-Null
}

# 2. Copy XPI File
Write-Host "Copying extension package..."
if (-not (Test-Path $xpiSource)) {
    Write-Error "XPI file not found at $xpiSource. Run create_xpi.ps1 first."
}
Copy-Item -Path $xpiSource -Destination $xpiDest -Force

# 3. Configure Registry Policy
Write-Host "Applying Registry Policy..."
# 3. Configure Registry Policy
Write-Host "Applying Registry Policy..."
$firefoxPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
$extensionSettingsKey = Join-Path $firefoxPath "ExtensionSettings"

if (-not (Test-Path $firefoxPath)) {
    New-Item -Path $firefoxPath -Force | Out-Null
}

# cleanup conflicting key if it exists (from previous run)
if (Test-Path $extensionSettingsKey) {
    Remove-Item -Path $extensionSettingsKey -Recurse -Force
}

# JSON Configuration for ExtensionSettings
# force_installed: Automatically installs the extension and prevents user removal.
$jsonPolicy = @"
{
    "$extensionId": {
        "installation_mode": "force_installed",
        "install_url": "file:///$($xpiDest.Replace('\', '/'))"
    }
}
"@

# Disable Developer Tools (Optional, but recommended for security)
Set-ItemProperty -Path $firefoxPath -Name "DisableDeveloperTools" -Value 1 -Type DWord -Force

# Set the ExtensionSettings JSON string value under the Firefox key
# Note: ExtensionSettings CAN be a subkey if using GPO templates, but raw registry usually expects flattened JSON string
Set-ItemProperty -Path $firefoxPath -Name "ExtensionSettings" -Value $jsonPolicy -Type String -Force

Write-Host "Policy applied successfully!"
Write-Host "Please restart Firefox to see the changes."
Write-Host "To remove the policy, run remove_policy.ps1"
