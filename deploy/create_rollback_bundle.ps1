$ErrorActionPreference = "Stop"

param(
    [Parameter(Mandatory = $true)]
    [string]$PreviousFirefoxXpiPath,
    [string]$PreviousChromeExtensionId,
    [string]$PreviousChromeUpdateUrl
)

$baseDir = $PSScriptRoot
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bundleDir = Join-Path $baseDir "rollback\rollback-$stamp"
New-Item -ItemType Directory -Path $bundleDir -Force | Out-Null

if (-not (Test-Path $PreviousFirefoxXpiPath)) {
    throw "Previous Firefox XPI not found: $PreviousFirefoxXpiPath"
}

$firefoxXpiName = Split-Path $PreviousFirefoxXpiPath -Leaf
Copy-Item -Path $PreviousFirefoxXpiPath -Destination (Join-Path $bundleDir $firefoxXpiName) -Force

$restoreFirefoxScript = @"
`$ErrorActionPreference = "Stop"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "Run as Administrator."
}
`$policyPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
`$installDir = "C:\ProgramData\WatchEmployee\firefox"
`$xpiDest = Join-Path `$installDir "$firefoxXpiName"
New-Item -ItemType Directory -Path `$installDir -Force | Out-Null
Copy-Item -Path (Join-Path `$PSScriptRoot "$firefoxXpiName") -Destination `$xpiDest -Force
`$json = "{`"it@skylink-ltd.com`":{`"installation_mode`":`"force_installed`",`"install_url`":`"file:///" + (`$xpiDest.Replace('\','/')) + "`"}}"
Set-ItemProperty -Path `$policyPath -Name "ExtensionSettings" -Type MultiString -Value @(`$json) -Force
Write-Host "Firefox rollback policy restored."
"@
Set-Content -Path (Join-Path $bundleDir "restore_firefox_policy.ps1") -Value $restoreFirefoxScript -Encoding UTF8

if ($PreviousChromeExtensionId -and $PreviousChromeUpdateUrl) {
    $restoreChromeScript = @"
`$ErrorActionPreference = "Stop"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "Run as Administrator."
}
`$policyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
New-Item -Path `$policyPath -Force | Out-Null
Set-ItemProperty -Path `$policyPath -Name "ExtensionInstallForcelist" -Type MultiString -Value @("$PreviousChromeExtensionId;$PreviousChromeUpdateUrl") -Force
`$settings = "{`"$PreviousChromeExtensionId`":{`"installation_mode`":`"force_installed`",`"update_url`":`"$PreviousChromeUpdateUrl`",`"override_update_url`":true}}"
Set-ItemProperty -Path `$policyPath -Name "ExtensionSettings" -Type String -Value `$settings -Force
Write-Host "Chrome rollback policy restored."
"@
    Set-Content -Path (Join-Path $bundleDir "restore_chrome_policy.ps1") -Value $restoreChromeScript -Encoding UTF8
}

Write-Host "Rollback bundle created at: $bundleDir"
