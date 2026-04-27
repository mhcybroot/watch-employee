$ErrorActionPreference = "Stop"

$baseDir = $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $baseDir "..")
$configPath = Join-Path $baseDir "release.config.json"

if (-not (Test-Path $configPath)) {
    throw "Missing release config: $configPath"
}

$release = Get-Content $configPath -Raw | ConvertFrom-Json

if (-not $release.backendUrl) {
    throw "release.config.json missing backendUrl"
}
if (-not $release.extensionApiKey) {
    throw "release.config.json missing extensionApiKey"
}

$backendUrl = $release.backendUrl.TrimEnd("/")
$apiKey = $release.extensionApiKey
$hostPermission = "$backendUrl/*"
$backendUri = [System.Uri]::new($backendUrl)
$connectSrc = "$($backendUri.Scheme)://$($backendUri.Host):$($backendUri.Port)/"

function Write-ConfigJs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ServerUrl,
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    $content = @"
const SERVER_URL = "$ServerUrl";
const EXTENSION_API_KEY = "$ApiKey";
"@

    Set-Content -Path $Path -Value $content -Encoding UTF8
}

function Set-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        $Object
    )
    $json = $Object | ConvertTo-Json -Depth 50
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

$firefoxConfigPath = Join-Path $repoRoot "extension\config.js"
$chromeConfigPath = Join-Path $repoRoot "extension-chrome\config.js"
Write-ConfigJs -Path $firefoxConfigPath -ServerUrl $backendUrl -ApiKey $apiKey
Write-ConfigJs -Path $chromeConfigPath -ServerUrl $backendUrl -ApiKey $apiKey

$firefoxManifestPath = Join-Path $repoRoot "extension\manifest.json"
$firefoxManifest = Get-Content $firefoxManifestPath -Raw | ConvertFrom-Json
$firefoxManifest.host_permissions = @($hostPermission)
if (-not $firefoxManifest.content_security_policy) {
    $firefoxManifest | Add-Member -MemberType NoteProperty -Name "content_security_policy" -Value ([pscustomobject]@{}) -Force
}
$firefoxManifest.content_security_policy.extension_pages = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self' $connectSrc"
Set-JsonFile -Path $firefoxManifestPath -Object $firefoxManifest

$chromeManifestPath = Join-Path $repoRoot "extension-chrome\manifest.json"
$chromeManifest = Get-Content $chromeManifestPath -Raw | ConvertFrom-Json
$chromeManifest.host_permissions = @($hostPermission)
Set-JsonFile -Path $chromeManifestPath -Object $chromeManifest

Write-Host "Synchronized extension configs and manifests for backend: $backendUrl"
