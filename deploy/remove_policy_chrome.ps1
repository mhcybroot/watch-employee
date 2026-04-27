$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "Administrator rights are required. Re-run this script as Administrator."
}

$chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"

Write-Host "Removing Chrome enterprise extension policies..."

if (Test-Path $chromePolicyPath) {
    Remove-ItemProperty -Path $chromePolicyPath -Name "ExtensionInstallForcelist" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $chromePolicyPath -Name "ExtensionSettings" -ErrorAction SilentlyContinue
    Write-Host "Removed ExtensionInstallForcelist and ExtensionSettings values."
}
else {
    Write-Host "Chrome policy registry path not found."
}

Write-Host "Done. Restart Chrome to apply changes."
