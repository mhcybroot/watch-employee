$ErrorActionPreference = "Stop"

$baseDir = $PSScriptRoot
$guiSource = Join-Path $baseDir "gui\InstallerGui.ps1"
$artifactDir = Join-Path $baseDir "artifacts\gui"
$iconPath = Join-Path $artifactDir "WatchEmployee-Installer.ico"
$exeOutput = Join-Path $artifactDir "WatchEmployee-Installer.exe"
$manifestPath = Join-Path (Join-Path $baseDir "..\extension") "manifest.json"

if (-not (Test-Path $guiSource)) {
    throw "GUI source script not found: $guiSource"
}

New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

function New-InstallerIcon {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    Add-Type -AssemblyName System.Drawing

    $size = 64
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(37, 99, 235))

    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString("WE", $font, $brush, (New-Object System.Drawing.RectangleF(0, 0, $size, $size)), $format)

    $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $stream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create)
    try {
        $icon.Save($stream)
    }
    finally {
        $stream.Close()
        $g.Dispose()
        $font.Dispose()
        $brush.Dispose()
        $bmp.Dispose()
        $icon.Dispose()
    }
}

if (-not (Test-Path $iconPath)) {
    New-InstallerIcon -OutputPath $iconPath
}

function Ensure-Ps2ExeModule {
    if (Get-Module -ListAvailable -Name ps2exe) {
        return
    }

    Write-Host "ps2exe module not found. Installing for current user..."

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    catch {
    }

    try {
        if (Get-Command Install-PackageProvider -ErrorAction SilentlyContinue) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -Confirm:$false | Out-Null
        }
    }
    catch {
        Write-Warning "NuGet provider bootstrap warning: $($_.Exception.Message)"
    }

    try {
        if (Get-Command Set-PSRepository -ErrorAction SilentlyContinue) {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Warning "PSGallery trust warning: $($_.Exception.Message)"
    }

    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber -Confirm:$false
    }
    catch {
        throw @"
Failed to install ps2exe automatically.
Try running once in an elevated PowerShell:
  Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber

Original error:
$($_.Exception.Message)
"@
    }
}

Ensure-Ps2ExeModule

Import-Module ps2exe -Force

$version = "1.0.0"
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.version) {
            $version = "$($manifest.version).0"
        }
    }
    catch {
        Write-Warning "Could not parse extension manifest version. Using default $version."
    }
}

if (Test-Path $exeOutput) {
    try {
        Remove-Item $exeOutput -Force
    }
    catch {
        throw @"
Cannot overwrite:
  $exeOutput

Close WatchEmployee-Installer.exe (and any process using this file), then run this build command again.
Original error:
$($_.Exception.Message)
"@
    }
}

Invoke-ps2exe `
    -inputFile $guiSource `
    -outputFile $exeOutput `
    -iconFile $iconPath `
    -title "WatchEmployee Installer" `
    -product "WatchEmployee Workstation Installer" `
    -company "WatchEmployee" `
    -copyright "Copyright (c) WatchEmployee" `
    -version $version `
    -noConsole

Write-Host "Build complete: $exeOutput"
