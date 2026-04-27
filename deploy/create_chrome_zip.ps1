$ErrorActionPreference = "Stop"

$paramBaseDir = $PSScriptRoot
$syncScript = Join-Path $paramBaseDir "sync_extension_config.ps1"
& $syncScript

$extensionDir = Join-Path $paramBaseDir "..\extension-chrome"
$manifestPath = Join-Path $extensionDir "manifest.json"
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$version = $manifest.version

$artifactDir = Join-Path $paramBaseDir "artifacts\chrome"
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

$versionedOutput = Join-Path $artifactDir "watch-employee-chrome-v$version.zip"
$compatOutput = Join-Path $paramBaseDir "watch-employee-chrome.zip"

Write-Host "Packaging Chrome extension v$version from $extensionDir..."

if (Test-Path $versionedOutput) {
    Remove-Item $versionedOutput -Force
}

# Getting all items in the extension folder
$files = Get-ChildItem -Path $extensionDir

if ($files.Count -eq 0) {
    Write-Error "Chrome Extension directory is empty!"
}

# Compress contents to ZIP
Compress-Archive -Path "$extensionDir\*" -DestinationPath $versionedOutput -Force
Copy-Item -Path $versionedOutput -Destination $compatOutput -Force

Write-Host "Success! Versioned ZIP: $versionedOutput"
Write-Host "Compatibility copy: $compatOutput"
Write-Host "You can load this unpacked in chrome://extensions or upload to Web Store."
