$ErrorActionPreference = "Stop"

$baseDir = $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $baseDir "..")
$configPath = Join-Path $baseDir "release.config.json"
$syncScript = Join-Path $baseDir "sync_extension_config.ps1"

if (-not (Test-Path $configPath)) {
    throw "Missing release config: $configPath"
}

$release = Get-Content $configPath -Raw | ConvertFrom-Json
$backendUrl = $release.backendUrl.TrimEnd("/")
$backendWithWildcard = "$backendUrl/*"
$backendUri = [System.Uri]::new($backendUrl)
$connectSrcExpected = "$($backendUri.Scheme)://$($backendUri.Host):$($backendUri.Port)/"

& $syncScript

$failures = New-Object System.Collections.Generic.List[string]

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        $failures.Add($Message)
    }
}

$fxManifestPath = Join-Path $repoRoot "extension\manifest.json"
$chManifestPath = Join-Path $repoRoot "extension-chrome\manifest.json"
$fxManifest = Get-Content $fxManifestPath -Raw | ConvertFrom-Json
$chManifest = Get-Content $chManifestPath -Raw | ConvertFrom-Json

Assert-True ($fxManifest.host_permissions -contains $backendWithWildcard) "Firefox host_permissions do not contain $backendWithWildcard"
Assert-True ($chManifest.host_permissions -contains $backendWithWildcard) "Chrome host_permissions do not contain $backendWithWildcard"
Assert-True ($fxManifest.content_security_policy.extension_pages -like "*$connectSrcExpected*") "Firefox CSP connect-src does not contain $connectSrcExpected"

$forbiddenHosts = @("10.10.10.10", "127.0.0.1:8565", "localhost:8565")
$scanPaths = @(
    (Join-Path $repoRoot "extension"),
    (Join-Path $repoRoot "extension-chrome")
)

foreach ($path in $scanPaths) {
    $files = Get-ChildItem -Path $path -Recurse -File
    foreach ($forbiddenHost in $forbiddenHosts) {
        $matches = $files | Select-String -Pattern $forbiddenHost -SimpleMatch -ErrorAction SilentlyContinue
        if ($matches) {
            $failures.Add("Found forbidden host '$forbiddenHost' under $path")
        }
    }
}

if (Get-Command node -ErrorAction SilentlyContinue) {
    $jsFiles = Get-ChildItem -Path (Join-Path $repoRoot "extension"), (Join-Path $repoRoot "extension-chrome") -Recurse -File -Filter *.js
    foreach ($jsFile in $jsFiles) {
        & node --check $jsFile.FullName 2>$null
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("JavaScript syntax check failed: $($jsFile.FullName)")
        }
    }
}
else {
    Write-Warning "node not found; skipped JS syntax checks."
}

Assert-True (Test-Path (Join-Path $repoRoot "extension\background.js")) "Missing Firefox background.js"
Assert-True (Test-Path (Join-Path $repoRoot "extension-chrome\background.js")) "Missing Chrome background.js"
Assert-True (Test-Path (Join-Path $repoRoot "extension\credentials.html")) "Missing Firefox credentials UI"
Assert-True (Test-Path (Join-Path $repoRoot "extension-chrome\credentials.html")) "Missing Chrome credentials UI"

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Release validation failed:" -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host " - $f"
    }
    exit 1
}

Write-Host "Release validation passed."
