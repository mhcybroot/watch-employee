$ErrorActionPreference = "Stop"

$baseDir = $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $baseDir "..")
$artifactDir = Join-Path $baseDir "artifacts\chrome"
$targetDir = Join-Path $repoRoot "src\main\resources\static\extensions\chrome"

if (-not (Test-Path $artifactDir)) {
    throw "Chrome artifact directory not found: $artifactDir"
}

New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

$updateXmlSource = Join-Path $artifactDir "updates.xml"
if (-not (Test-Path $updateXmlSource)) {
    throw "updates.xml not found. Generate it first (create_chrome_crx.ps1). Expected: $updateXmlSource"
}

$latestCrx = Get-ChildItem -Path $artifactDir -Filter "watch-employee-chrome-v*.crx" -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latestCrx) {
    throw "No CRX found in $artifactDir. Generate it first (create_chrome_crx.ps1)."
}

Copy-Item -Path $updateXmlSource -Destination (Join-Path $targetDir "updates.xml") -Force
Copy-Item -Path $latestCrx.FullName -Destination (Join-Path $targetDir $latestCrx.Name) -Force

Write-Host "Published Chrome update assets to Spring Boot static folder:"
Write-Host "  $(Join-Path $targetDir 'updates.xml')"
Write-Host "  $(Join-Path $targetDir $latestCrx.Name)"
Write-Host ""
Write-Host "After app restart, URLs will be:"
Write-Host "  http://<host>:8565/extensions/chrome/updates.xml"
Write-Host "  http://<host>:8565/extensions/chrome/$($latestCrx.Name)"
