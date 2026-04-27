$ErrorActionPreference = "Stop"

param(
    [Parameter(Mandatory = $true)]
    [string]$PrivateKeyPath,
    [Parameter(Mandatory = $true)]
    [string]$CrxBaseUrl,
    [string]$ChromeExePath
)

$baseDir = $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $baseDir "..")
$extensionDir = Join-Path $repoRoot "extension-chrome"
$manifestPath = Join-Path $extensionDir "manifest.json"
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$version = $manifest.version

$syncScript = Join-Path $baseDir "sync_extension_config.ps1"
& $syncScript

if (-not (Test-Path $PrivateKeyPath)) {
    throw "Private key file not found: $PrivateKeyPath"
}

if (-not $ChromeExePath) {
    $candidates = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    )
    $ChromeExePath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $ChromeExePath -or -not (Test-Path $ChromeExePath)) {
    throw "Chrome executable not found. Pass -ChromeExePath explicitly."
}

$artifactsDir = Join-Path $baseDir "artifacts\chrome"
New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null

$tempCrxPath = Join-Path $repoRoot "extension-chrome.crx"
if (Test-Path $tempCrxPath) {
    Remove-Item $tempCrxPath -Force
}

Write-Host "Packing CRX with Chrome..."
& $ChromeExePath "--pack-extension=$extensionDir" "--pack-extension-key=$PrivateKeyPath" | Out-Null

if (-not (Test-Path $tempCrxPath)) {
    throw "Chrome pack command did not produce extension-chrome.crx."
}

$versionedCrx = Join-Path $artifactsDir "watch-employee-chrome-v$version.crx"
Move-Item -Path $tempCrxPath -Destination $versionedCrx -Force

$configPath = Join-Path $baseDir "release.config.json"
$release = Get-Content $configPath -Raw | ConvertFrom-Json
$extensionId = $release.chrome.extensionId
if (-not $extensionId -or $extensionId -eq "REPLACE_WITH_CHROME_EXTENSION_ID") {
    throw "release.config.json chrome.extensionId must be set before generating update metadata."
}

$cleanBase = $CrxBaseUrl.TrimEnd("/")
$crxUrl = "$cleanBase/watch-employee-chrome-v$version.crx"
$updateXmlPath = Join-Path $artifactsDir "updates.xml"

$xml = @"
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='$extensionId'>
    <updatecheck codebase='$crxUrl' version='$version' />
  </app>
</gupdate>
"@
Set-Content -Path $updateXmlPath -Value $xml -Encoding UTF8

Write-Host "Success! Versioned CRX: $versionedCrx"
Write-Host "Update metadata: $updateXmlPath"
Write-Host "Publish both files to your self-hosted Chrome update endpoint."
