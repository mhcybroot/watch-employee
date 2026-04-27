$ErrorActionPreference = "Stop"

$baseDir = $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $baseDir "..")
$artifactDir = Join-Path $baseDir "artifacts\chrome"
$targetDir = Join-Path $repoRoot "src\main\resources\static\extensions\chrome"
$configPath = Join-Path $baseDir "release.config.json"

if (-not (Test-Path $artifactDir)) {
    throw "Chrome artifact directory not found: $artifactDir"
}
if (-not (Test-Path $configPath)) {
    throw "Missing release config: $configPath"
}

New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

$latestCrx = Get-ChildItem -Path $artifactDir -Filter "watch-employee-chrome-v*.crx" -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latestCrx) {
    throw "No CRX found in $artifactDir. Generate it first (create_chrome_crx.ps1)."
}

$release = Get-Content $configPath -Raw | ConvertFrom-Json
$extensionId = $release.chrome.extensionId
$updateUrl = $release.chrome.updateUrl

if (-not $extensionId -or $extensionId -eq "REPLACE_WITH_CHROME_EXTENSION_ID") {
    throw "release.config.json chrome.extensionId must be set."
}
if (-not $updateUrl) {
    throw "release.config.json chrome.updateUrl must be set."
}

$updateUri = $null
if (-not [System.Uri]::TryCreate($updateUrl, [System.UriKind]::Absolute, [ref]$updateUri)) {
    throw "release.config.json chrome.updateUrl is not a valid absolute URL: $updateUrl"
}

$updateDirPath = [System.IO.Path]::GetDirectoryName($updateUri.AbsolutePath)
if (-not $updateDirPath) {
    throw "Could not derive update directory path from chrome.updateUrl: $updateUrl"
}
$baseUrl = "$($updateUri.Scheme)://$($updateUri.Authority)$($updateDirPath.Replace('\','/').TrimEnd('/'))"
$crxUrl = "$baseUrl/$($latestCrx.Name)"
$version = ($latestCrx.BaseName -replace '^watch-employee-chrome-v', '')

$xml = @"
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='$extensionId'>
    <updatecheck codebase='$crxUrl' version='$version' />
  </app>
</gupdate>
"@

$updateXmlSource = Join-Path $artifactDir "updates.xml"
Set-Content -Path $updateXmlSource -Value $xml -Encoding UTF8
Copy-Item -Path $updateXmlSource -Destination (Join-Path $targetDir "updates.xml") -Force
Copy-Item -Path $latestCrx.FullName -Destination (Join-Path $targetDir $latestCrx.Name) -Force

Write-Host "Published Chrome update assets to Spring Boot static folder:"
Write-Host "  $(Join-Path $targetDir 'updates.xml')"
Write-Host "  $(Join-Path $targetDir $latestCrx.Name)"
Write-Host ""
Write-Host "Published URLs:"
Write-Host "  $updateUrl"
Write-Host "  $crxUrl"
