param(
    [string]$ExtensionId,
    [string]$UpdateUrl
)

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "Administrator rights are required. Re-run this script as Administrator."
}

$baseDir = $PSScriptRoot
$configPath = Join-Path $baseDir "release.config.json"
if (-not (Test-Path $configPath)) {
    throw "Missing release config: $configPath"
}

$release = Get-Content $configPath -Raw | ConvertFrom-Json

if (-not $ExtensionId) {
    $ExtensionId = $release.chrome.extensionId
}
if (-not $UpdateUrl) {
    $UpdateUrl = $release.chrome.updateUrl
}

if (-not $ExtensionId -or $ExtensionId -eq "REPLACE_WITH_CHROME_EXTENSION_ID") {
    throw "Chrome extension ID is not configured. Update deploy/release.config.json or pass -ExtensionId."
}
if (-not $UpdateUrl) {
    throw "Chrome update URL is required. Update deploy/release.config.json or pass -UpdateUrl."
}

$isDomainJoined = (Get-CimInstance Win32_ComputerSystem).PartOfDomain
$isWebStoreUrl = $UpdateUrl -like "https://clients2.google.com/*"
if (-not $isDomainJoined -and -not $isWebStoreUrl) {
    Write-Warning @"
This endpoint is not domain-joined and is using an off-store update URL:
  $UpdateUrl

Chrome may reject off-store force-install on unmanaged endpoints.
Fallback: publish the extension to Chrome Web Store private listing and
set update URL to https://clients2.google.com/service/update2/crx.
"@
}

$chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
if (-not (Test-Path $chromePolicyPath)) {
    New-Item -Path $chromePolicyPath -Force | Out-Null
}

$forceInstallEntry = "$ExtensionId;$UpdateUrl"
Set-ItemProperty -Path $chromePolicyPath -Name "ExtensionInstallForcelist" -Type MultiString -Value @($forceInstallEntry) -Force

$extensionSettingsJson = @{
    "*" = @{
        installation_mode = "allowed"
    }
}
$extensionSettingsJson[$ExtensionId] = @{
    installation_mode   = "force_installed"
    update_url          = $UpdateUrl
    override_update_url = $true
}
$extensionSettingsValue = ($extensionSettingsJson | ConvertTo-Json -Compress -Depth 10)
Set-ItemProperty -Path $chromePolicyPath -Name "ExtensionSettings" -Type String -Value $extensionSettingsValue -Force

Write-Host "Chrome enterprise policy applied successfully."
Write-Host "Force-installed extension: $ExtensionId"
Write-Host "Update URL: $UpdateUrl"
Write-Host "Restart Chrome and verify via chrome://policy."
