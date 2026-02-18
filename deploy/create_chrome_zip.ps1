$ErrorActionPreference = "Stop"

$paramBaseDir = $PSScriptRoot
$extensionDir = Join-Path $paramBaseDir "..\extension-chrome"
$outputFile = Join-Path $paramBaseDir "watch-employee-chrome.zip"

Write-Host "Packaging Chrome extension from $extensionDir to $outputFile..."

if (Test-Path $outputFile) {
    Remove-Item $outputFile -Force
}

# Getting all items in the extension folder
$files = Get-ChildItem -Path $extensionDir

if ($files.Count -eq 0) {
    Write-Error "Chrome Extension directory is empty!"
}

# Compress contents to ZIP
Compress-Archive -Path "$extensionDir\*" -DestinationPath $outputFile -Force

Write-Host "Success! Chrome ZIP created at $outputFile"
Write-Host "You can load this unpacked in chrome://extensions or upload to Web Store."
