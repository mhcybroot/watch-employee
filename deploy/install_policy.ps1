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
$extensionId = "productivity-tracker@example.com"

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
$regPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\ExtensionSettings"

if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
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
$policyPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
Set-ItemProperty -Path $policyPath -Name "DisableDeveloperTools" -Value 1 -Type DWord -Force

# Set the ExtensionSettings JSON
Set-ItemProperty -Path $regPath -Name $extensionId -Value $jsonPolicy -Type String -Force

Write-Host "Policy applied successfully!"
Write-Host "Please restart Firefox to see the changes."
Write-Host "To remove the policy, run remove_policy.ps1"
