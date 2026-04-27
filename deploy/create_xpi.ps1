$ErrorActionPreference = "Stop"

$paramBaseDir = $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $paramBaseDir "..")
$syncScript = Join-Path $paramBaseDir "sync_extension_config.ps1"
& $syncScript

$extensionDir = Join-Path $paramBaseDir "..\extension"
$manifestPath = Join-Path $extensionDir "manifest.json"
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$version = $manifest.version

$artifactDir = Join-Path $paramBaseDir "artifacts\firefox"
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

$versionedOutput = Join-Path $artifactDir "watch-employee-firefox-v$version.xpi"
$compatOutput = Join-Path $paramBaseDir "watch-employee.xpi"

Write-Host "Packaging Firefox extension v$version from $extensionDir..."

$tempZip = Join-Path $paramBaseDir "watch-employee.zip"

if (Test-Path $tempZip) {
    Remove-Item $tempZip -Force
}

# Compress to .zip first (required by Compress-Archive)
# We compress the contents of the extension folder, not the folder itself, so it's at the root of the archive
Compress-Archive -Path "$extensionDir\*" -DestinationPath $tempZip -Force

# Rename to .xpi
if (Test-Path $versionedOutput) {
    Remove-Item $versionedOutput -Force
}
Move-Item -Path $tempZip -Destination $versionedOutput -Force
Copy-Item -Path $versionedOutput -Destination $compatOutput -Force

Write-Host "Success! Versioned XPI: $versionedOutput"
Write-Host "Compatibility copy: $compatOutput"
