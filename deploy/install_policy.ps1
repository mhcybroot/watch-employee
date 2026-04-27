$ErrorActionPreference = "Stop"

# Check for Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "Administrator rights are required. Re-run this script as Administrator."
}

$paramBaseDir = $PSScriptRoot
$manifestPath = Join-Path $paramBaseDir "..\extension\manifest.json"
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$version = $manifest.version

$xpiSource = Join-Path $paramBaseDir "artifacts\firefox\watch-employee-firefox-v$version.xpi"
if (-not (Test-Path $xpiSource)) {
    $xpiSource = Join-Path $paramBaseDir "watch-employee.xpi"
}

$installDir = "C:\ProgramData\WatchEmployee\firefox"
$xpiDest = Join-Path $installDir "watch-employee-firefox-v$version.xpi"
$extensionId = "it@skylink-ltd.com"
$firefoxPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
$legacyExtensionSettingsKey = Join-Path $firefoxPath "ExtensionSettings"

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
if (-not (Test-Path $firefoxPath)) {
    New-Item -Path $firefoxPath -Force | Out-Null
}

# cleanup conflicting key if it exists (from previous run)
if (Test-Path $legacyExtensionSettingsKey) {
    Remove-Item -Path $legacyExtensionSettingsKey -Recurse -Force
}

# JSON Configuration for ExtensionSettings
# force_installed: Automatically installs the extension and prevents user removal.
$jsonPolicy = @'
{
  "__EXTENSION_ID__": {
    "installation_mode": "force_installed",
    "install_url": "__INSTALL_URL__"
  }
}
'@
$installUrl = "file:///$($xpiDest.Replace('\', '/'))"
$jsonPolicy = $jsonPolicy.Replace("__EXTENSION_ID__", $extensionId).Replace("__INSTALL_URL__", $installUrl)

# Disable Developer Tools (Optional, but recommended for security)
Set-ItemProperty -Path $firefoxPath -Name "DisableDeveloperTools" -Value 1 -Type DWord -Force

# Set ExtensionSettings as REG_MULTI_SZ
Set-ItemProperty -Path $firefoxPath -Name "ExtensionSettings" -Value @($jsonPolicy) -Type MultiString -Force

Write-Host "Policy applied successfully!"
Write-Host "Please restart Firefox to see the changes."
Write-Host "Installed package: $xpiDest"
Write-Host "To remove the policy, run remove_policy.ps1"
