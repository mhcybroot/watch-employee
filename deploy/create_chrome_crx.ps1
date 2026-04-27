param(
    [Parameter(Mandatory = $true)]
    [string]$PrivateKeyPath,
    [string]$CrxBaseUrl,
    [string]$ChromeExePath
)

$ErrorActionPreference = "Stop"

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

$resolvedCrxBaseUrl = $CrxBaseUrl
if (-not $resolvedCrxBaseUrl) {
    $updateUrl = $release.chrome.updateUrl
    if (-not $updateUrl) {
        throw "CrxBaseUrl not provided and release.config.json chrome.updateUrl is missing."
    }

    $updateUri = $null
    if (-not [System.Uri]::TryCreate($updateUrl, [System.UriKind]::Absolute, [ref]$updateUri)) {
        throw "release.config.json chrome.updateUrl is not a valid absolute URL: $updateUrl"
    }

    $updateDirPath = [System.IO.Path]::GetDirectoryName($updateUri.AbsolutePath)
    if (-not $updateDirPath) {
        throw "Could not derive CRX base URL from chrome.updateUrl: $updateUrl"
    }

    $resolvedCrxBaseUrl = "$($updateUri.Scheme)://$($updateUri.Authority)$($updateDirPath.Replace('\','/'))"
    Write-Host "CrxBaseUrl not provided. Derived from chrome.updateUrl: $resolvedCrxBaseUrl"
}

$cleanBase = $resolvedCrxBaseUrl.TrimEnd("/")
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
