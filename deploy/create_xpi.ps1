$ErrorActionPreference = "Stop"

$paramBaseDir = $PSScriptRoot
$extensionDir = Join-Path $paramBaseDir "..\extension"
$outputFile = Join-Path $paramBaseDir "watch-employee.xpi"

Write-Host "Packaging extension from $extensionDir to $outputFile..."

$tempZip = Join-Path $paramBaseDir "watch-employee.zip"

if (Test-Path $tempZip) {
    Remove-Item $tempZip -Force
}

# Compress to .zip first (required by Compress-Archive)
# We compress the contents of the extension folder, not the folder itself, so it's at the root of the archive
Compress-Archive -Path "$extensionDir\*" -DestinationPath $tempZip -Force

# Rename to .xpi
Move-Item -Path $tempZip -Destination $outputFile -Force

Write-Host "Success! XPI created at $outputFile"
