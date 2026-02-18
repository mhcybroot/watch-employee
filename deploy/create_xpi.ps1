$ErrorActionPreference = "Stop"

$paramBaseDir = $PSScriptRoot
$extensionDir = Join-Path $paramBaseDir "..\extension"
$outputFile = Join-Path $paramBaseDir "watch-employee.xpi"

Write-Host "Packaging extension from $extensionDir to $outputFile..."

if (Test-Path $outputFile) {
    Remove-Item $outputFile -Force
}

# Compress-Archive requires the source to be the contents, not the folder itself, to avoid nested folders
# Getting all items in the extension folder
$files = Get-ChildItem -Path $extensionDir

if ($files.Count -eq 0) {
    Write-Error "Extension directory is empty!"
}

Compress-Archive -Path "$extensionDir\*" -DestinationPath $outputFile -Force

Write-Host "Success! XPI created at $outputFile"
