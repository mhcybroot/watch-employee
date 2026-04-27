$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Find-DeployRootFrom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartPath
    )

    $current = Resolve-Path -LiteralPath $StartPath -ErrorAction SilentlyContinue
    if (-not $current) {
        return $null
    }

    for ($i = 0; $i -lt 8; $i++) {
        $candidate = $current.Path
        $installScript = Join-Path $candidate "install_policy.ps1"
        $removeScript = Join-Path $candidate "remove_policy.ps1"
        $configFile = Join-Path $candidate "release.config.json"
        if ((Test-Path $installScript) -and (Test-Path $removeScript) -and (Test-Path $configFile)) {
            return $candidate
        }
        $parent = Split-Path -Parent $candidate
        if (-not $parent -or $parent -eq $candidate) {
            break
        }
        $current = Resolve-Path -LiteralPath $parent -ErrorAction SilentlyContinue
        if (-not $current) {
            break
        }
    }

    return $null
}

function Resolve-DeployRoot {
    $candidates = @()

    if ($PSScriptRoot) {
        $candidates += $PSScriptRoot
    }
    if ($MyInvocation.MyCommand.Path) {
        $candidates += (Split-Path -Parent $MyInvocation.MyCommand.Path)
    }
    $candidates += [Environment]::CurrentDirectory
    $candidates += (Get-Location).Path

    foreach ($path in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        $found = Find-DeployRootFrom -StartPath $path
        if ($found) {
            return $found
        }
    }

    return $null
}

if (-not (Test-IsAdministrator)) {
    $selfPath = $MyInvocation.MyCommand.Path
    if ($selfPath -and $selfPath.EndsWith(".ps1", [System.StringComparison]::OrdinalIgnoreCase)) {
        $args = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", "`"$selfPath`""
        )
        Start-Process -FilePath "powershell.exe" -ArgumentList ($args -join " ") -Verb RunAs
    }
    else {
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        Start-Process -FilePath $exePath -Verb RunAs
    }
    exit
}

$deployRoot = Resolve-DeployRoot
if (-not $deployRoot) {
    [System.Windows.MessageBox]::Show(
        "Could not locate deploy scripts (install_policy.ps1/remove_policy.ps1/release.config.json).`n`nStart this app from inside the project deploy directory tree.",
        "WatchEmployee Installer",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
    exit 1
}

$logsDir = Join-Path $deployRoot "logs"
New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WatchEmployee Installer"
        Height="680"
        Width="980"
        MinHeight="620"
        MinWidth="900"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Padding="12" CornerRadius="8" Background="#1f2937">
            <StackPanel>
                <TextBlock x:Name="TxtTitle" Text="WatchEmployee Workstation Installer" FontSize="22" FontWeight="Bold" Foreground="White"/>
                <TextBlock x:Name="TxtSubtitle" Margin="0,6,0,0" FontSize="12" Foreground="#d1d5db" TextWrapping="Wrap"/>
            </StackPanel>
        </Border>

        <Grid Grid.Row="1" Margin="0,14,0,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="2*"/>
                <ColumnDefinition Width="2*"/>
                <ColumnDefinition Width="2*"/>
                <ColumnDefinition Width="2*"/>
            </Grid.ColumnDefinitions>

            <Button x:Name="BtnPreflight" Grid.Column="0" Margin="0,0,10,0" Padding="12" FontWeight="SemiBold" Content="Preflight Check"/>
            <Button x:Name="BtnInstallFx" Grid.Column="1" Margin="0,0,10,0" Padding="12" FontWeight="SemiBold" Background="#2563eb" Foreground="White" Content="Install Firefox Policy"/>
            <Button x:Name="BtnRemoveFx" Grid.Column="2" Margin="0,0,10,0" Padding="12" FontWeight="SemiBold" Background="#b91c1c" Foreground="White" Content="Remove Firefox Policy"/>
            <Button x:Name="BtnOpenLogs" Grid.Column="3" Padding="12" FontWeight="SemiBold" Content="Open Log Folder"/>
        </Grid>

        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="2.2*"/>
                <ColumnDefinition Width="4*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" BorderBrush="#d1d5db" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,0,12,0">
                <StackPanel>
                    <TextBlock Text="Status" FontWeight="Bold" FontSize="16"/>
                    <TextBlock x:Name="TxtStatus" Margin="0,8,0,10" Foreground="#374151" TextWrapping="Wrap"/>
                    <TextBlock Text="Chrome Settings (Global for all PCs)" FontWeight="Bold" Margin="0,10,0,8"/>
                    <TextBlock Text="Extension ID" FontSize="12" Foreground="#374151"/>
                    <TextBox x:Name="TxtChromeExtensionId" Margin="0,4,0,8" Padding="8" IsReadOnly="True"/>
                    <TextBlock Text="Update URL" FontSize="12" Foreground="#374151"/>
                    <TextBox x:Name="TxtChromeUpdateUrl" Margin="0,4,0,8" Padding="8" IsReadOnly="True"/>
                    <Grid Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="BtnEditChromeSettings" Grid.Column="0" Margin="0,0,6,0" Padding="10" Content="Edit Chrome Settings"/>
                        <Button x:Name="BtnSaveChromeSettings" Grid.Column="1" Margin="6,0,0,0" Padding="10" Content="Save Chrome Settings"/>
                    </Grid>
                    <TextBlock x:Name="TxtChromeValidation" Margin="0,0,0,8" Foreground="#6b7280" TextWrapping="Wrap"/>
                    <Button x:Name="BtnInstallChrome" Margin="0,0,0,8" Padding="10" Background="#059669" Foreground="White" Content="Install Chrome Policy"/>
                    <Button x:Name="BtnRemoveChrome" Padding="10" Background="#b45309" Foreground="White" Content="Remove Chrome Policy"/>
                    <Separator Margin="0,12,0,12"/>
                    <TextBlock Text="Current Action Log File" FontWeight="Bold"/>
                    <TextBlock x:Name="TxtLogFile" Margin="0,6,0,0" Foreground="#6b7280" TextWrapping="Wrap"/>
                </StackPanel>
            </Border>

            <Border Grid.Column="1" BorderBrush="#d1d5db" BorderThickness="1" CornerRadius="8">
                <DockPanel>
                    <Border DockPanel.Dock="Top" Background="#f3f4f6" Padding="10">
                        <TextBlock Text="Execution Log" FontWeight="Bold"/>
                    </Border>
                    <TextBox x:Name="TxtLog"
                             BorderThickness="0"
                             Background="White"
                             Foreground="#111827"
                             FontFamily="Consolas"
                             FontSize="13"
                             IsReadOnly="True"
                             TextWrapping="Wrap"
                             AcceptsReturn="True"
                             VerticalScrollBarVisibility="Auto"/>
                </DockPanel>
            </Border>
        </Grid>

        <StatusBar Grid.Row="3" Margin="0,12,0,0">
            <StatusBarItem>
                <TextBlock x:Name="TxtFooterLeft"/>
            </StatusBarItem>
            <Separator/>
            <StatusBarItem>
                <TextBlock x:Name="TxtFooterRight"/>
            </StatusBarItem>
        </StatusBar>
    </Grid>
</Window>
"@

[xml]$xamlXml = $xaml
$reader = New-Object System.Xml.XmlNodeReader($xamlXml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$txtSubtitle = $window.FindName("TxtSubtitle")
$txtStatus = $window.FindName("TxtStatus")
$txtLog = $window.FindName("TxtLog")
$txtLogFile = $window.FindName("TxtLogFile")
$txtFooterLeft = $window.FindName("TxtFooterLeft")
$txtFooterRight = $window.FindName("TxtFooterRight")

$btnPreflight = $window.FindName("BtnPreflight")
$btnInstallFx = $window.FindName("BtnInstallFx")
$btnRemoveFx = $window.FindName("BtnRemoveFx")
$btnOpenLogs = $window.FindName("BtnOpenLogs")
$btnInstallChrome = $window.FindName("BtnInstallChrome")
$btnRemoveChrome = $window.FindName("BtnRemoveChrome")
$btnSaveChromeSettings = $window.FindName("BtnSaveChromeSettings")
$btnEditChromeSettings = $window.FindName("BtnEditChromeSettings")
$txtChromeExtensionId = $window.FindName("TxtChromeExtensionId")
$txtChromeUpdateUrl = $window.FindName("TxtChromeUpdateUrl")
$txtChromeValidation = $window.FindName("TxtChromeValidation")

$script:ActionRunning = $false
$script:CurrentLogFile = $null
$script:CurrentActionJob = $null
$script:CurrentActionJobId = $null
$script:ActionTimer = $null
$script:CurrentActionName = $null
$script:CurrentActionLastSeq = 0
$script:PreflightPassed = $false
$script:ChromeConfigValid = $false
$script:ChromeConfigWarning = $null
$script:ReleaseConfigPath = Join-Path $deployRoot "release.config.json"
$script:ChromeSettingsLocked = $true

$txtSubtitle.Text = "Deploy root: $deployRoot"
$txtFooterLeft.Text = "Run mode: Local workstation, Administrator"
$txtFooterRight.Text = "Logs: $logsDir"
$txtStatus.Text = "Run preflight check to validate readiness before install/remove."
$txtLogFile.Text = "-"

function Write-UiLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message

    $window.Dispatcher.Invoke([Action]{
            $txtLog.AppendText($line + [Environment]::NewLine)
            $txtLog.ScrollToEnd()
        })

    if ($script:CurrentLogFile) {
        Add-Content -LiteralPath $script:CurrentLogFile -Value $line
    }
}

function Set-ButtonsEnabled {
    param(
        [bool]$Enabled
    )
    if (-not $Enabled) {
        $btnPreflight.IsEnabled = $false
        $btnInstallFx.IsEnabled = $false
        $btnRemoveFx.IsEnabled = $false
        $btnOpenLogs.IsEnabled = $false
        $btnInstallChrome.IsEnabled = $false
        $btnRemoveChrome.IsEnabled = $false
        $btnSaveChromeSettings.IsEnabled = $false
        $btnEditChromeSettings.IsEnabled = $false
        return
    }

    Refresh-ActionButtons
}

function Set-ChromeSettingsLock {
    param(
        [bool]$Locked
    )

    $script:ChromeSettingsLocked = $Locked
    $txtChromeExtensionId.IsReadOnly = $Locked
    $txtChromeUpdateUrl.IsReadOnly = $Locked

    if ($Locked) {
        $txtChromeExtensionId.Background = "#f3f4f6"
        $txtChromeUpdateUrl.Background = "#f3f4f6"
        $btnEditChromeSettings.Content = "Edit Chrome Settings"
    }
    else {
        $txtChromeExtensionId.Background = "White"
        $txtChromeUpdateUrl.Background = "White"
        $btnEditChromeSettings.Content = "Cancel Edit"
    }
}

function Get-IsDomainJoined {
    try {
        return (Get-CimInstance Win32_ComputerSystem).PartOfDomain
    }
    catch {
        return $false
    }
}

function Read-ReleaseConfig {
    if (-not (Test-Path $script:ReleaseConfigPath)) {
        return $null
    }
    try {
        return Get-Content $script:ReleaseConfigPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-UiLog "ERROR: Failed to parse release config: $($_.Exception.Message)"
        return $null
    }
}

function Validate-ChromeInputs {
    $id = ($txtChromeExtensionId.Text | ForEach-Object { $_.Trim() })
    $url = ($txtChromeUpdateUrl.Text | ForEach-Object { $_.Trim() })

    if (-not $id) {
        $script:ChromeConfigValid = $false
        $script:ChromeConfigWarning = "Chrome Extension ID is required."
        return
    }
    if ($id -notmatch '^[a-z]{32}$') {
        $script:ChromeConfigValid = $false
        $script:ChromeConfigWarning = "Extension ID must be exactly 32 lowercase letters."
        return
    }

    if (-not $url) {
        $script:ChromeConfigValid = $false
        $script:ChromeConfigWarning = "Chrome Update URL is required."
        return
    }

    $uri = $null
    if (-not [System.Uri]::TryCreate($url, [System.UriKind]::Absolute, [ref]$uri)) {
        $script:ChromeConfigValid = $false
        $script:ChromeConfigWarning = "Update URL must be a valid absolute URL."
        return
    }
    if ($uri.Scheme -ne "https") {
        $script:ChromeConfigValid = $false
        $script:ChromeConfigWarning = "Update URL must use https."
        return
    }

    $isWebStore = $url -like "https://clients2.google.com/*"
    $isDomainJoined = Get-IsDomainJoined
    if (-not $isWebStore -and -not $isDomainJoined) {
        $script:ChromeConfigValid = $true
        $script:ChromeConfigWarning = "Off-store URL on non-domain machine may be blocked by Chrome. You can still install policy, but Chrome may ignore force-install unless the PC is managed."
        return
    }

    $script:ChromeConfigValid = $true
    $script:ChromeConfigWarning = "Chrome settings look valid."
}

function Update-ChromeValidationUi {
    if ($script:ChromeConfigValid) {
        $txtChromeValidation.Foreground = "#059669"
    }
    elseif ($script:ChromeConfigWarning -like "Off-store URL on non-domain machine*") {
        $txtChromeValidation.Foreground = "#b45309"
    }
    else {
        $txtChromeValidation.Foreground = "#b91c1c"
    }
    $txtChromeValidation.Text = $script:ChromeConfigWarning
}

function Refresh-ActionButtons {
    if ($script:ActionRunning) {
        return
    }
    $btnPreflight.IsEnabled = $true
    $btnOpenLogs.IsEnabled = $true
    $btnEditChromeSettings.IsEnabled = $true
    $btnSaveChromeSettings.IsEnabled = -not $script:ChromeSettingsLocked

    $btnInstallFx.IsEnabled = $script:PreflightPassed
    $btnRemoveFx.IsEnabled = $script:PreflightPassed

    $btnInstallChrome.IsEnabled = $script:ChromeConfigValid
    $btnRemoveChrome.IsEnabled = $true

    Update-ChromeValidationUi
}

function Load-ChromeSettingsFromConfig {
    $release = Read-ReleaseConfig
    if (-not $release) {
        $txtChromeExtensionId.Text = ""
        $txtChromeUpdateUrl.Text = ""
    }
    else {
        $txtChromeExtensionId.Text = if ($release.chrome.extensionId) { [string]$release.chrome.extensionId } else { "" }
        $txtChromeUpdateUrl.Text = if ($release.chrome.updateUrl) { [string]$release.chrome.updateUrl } else { "" }
    }

    Validate-ChromeInputs
    Set-ChromeSettingsLock -Locked $true
    Refresh-ActionButtons
}

function Save-ChromeSettingsToConfig {
    try {
        $release = Read-ReleaseConfig
        if (-not $release) {
            throw "release.config.json is missing or invalid."
        }
        if (-not $release.chrome) {
            $release | Add-Member -MemberType NoteProperty -Name chrome -Value ([pscustomobject]@{}) -Force
        }

        $release.chrome.extensionId = $txtChromeExtensionId.Text.Trim()
        $release.chrome.updateUrl = $txtChromeUpdateUrl.Text.Trim()

        $json = $release | ConvertTo-Json -Depth 50
        Set-Content -Path $script:ReleaseConfigPath -Value $json -Encoding UTF8

        Validate-ChromeInputs
        Set-ChromeSettingsLock -Locked $true
        Refresh-ActionButtons
        Write-UiLog "Saved Chrome settings to release.config.json."
        $txtStatus.Text = "Chrome settings saved."
    }
    catch {
        Validate-ChromeInputs
        $script:ChromeConfigValid = $false
        $script:ChromeConfigWarning = "Failed to save Chrome settings: $($_.Exception.Message)"
        Refresh-ActionButtons
        Write-UiLog "ERROR: Failed to save Chrome settings: $($_.Exception.Message)"
        $txtStatus.Text = "Save failed. Check log."
    }
}

function Complete-CurrentAction {
    param(
        [string]$ActionName,
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [string]$JobState = "Completed"
    )

    if (-not $ActionName -or $ActionName.Trim().Length -eq 0) {
        if ($script:CurrentActionName -and $script:CurrentActionName.Trim().Length -gt 0) {
            $ActionName = $script:CurrentActionName
        }
        else {
            $ActionName = "script-action"
        }
    }

    if ($script:ActionTimer) {
        $script:ActionTimer.Stop()
        $script:ActionTimer = $null
    }

    if ($JobState -ne "Completed") {
        Write-UiLog "$ActionName ended with job state: $JobState"
    }

    if ($ExitCode -eq 0) {
        Write-UiLog "$ActionName completed successfully."
        $txtStatus.Text = "$ActionName completed successfully."
    }
    else {
        Write-UiLog "$ActionName failed with exit code $ExitCode."
        $txtStatus.Text = "$ActionName failed. Check logs."
    }

    if ($script:CurrentActionJob) {
        Remove-Job -Job $script:CurrentActionJob -Force -ErrorAction SilentlyContinue
    }
    elseif ($script:CurrentActionJobId) {
        Get-Job -Id $script:CurrentActionJobId -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue
    }

    $script:CurrentActionJob = $null
    $script:CurrentActionJobId = $null
    $script:CurrentActionName = $null
    $script:ActionRunning = $false
    Set-ButtonsEnabled -Enabled $true
    $null = Invoke-PreflightCheck
}

function Invoke-PreflightCheck {
    $window.Dispatcher.Invoke([Action]{
            $txtStatus.Text = "Running preflight checks..."
        })

    $installScript = Join-Path $deployRoot "install_policy.ps1"
    $removeScript = Join-Path $deployRoot "remove_policy.ps1"
    $releaseConfigPath = Join-Path $deployRoot "release.config.json"
    $manifestPath = Join-Path (Join-Path $deployRoot "..\extension") "manifest.json"
    $fallbackXpi = Join-Path $deployRoot "watch-employee.xpi"

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    if (-not (Test-Path $installScript)) {
        $errors.Add("Missing install script: $installScript")
    }
    if (-not (Test-Path $removeScript)) {
        $errors.Add("Missing remove script: $removeScript")
    }
    if (-not (Test-Path $releaseConfigPath)) {
        $errors.Add("Missing release config: $releaseConfigPath")
    }

    $backendUrl = $null
    if (Test-Path $releaseConfigPath) {
        try {
            $release = Get-Content $releaseConfigPath -Raw | ConvertFrom-Json
            $backendUrl = $release.backendUrl
            if (-not $backendUrl) {
                $errors.Add("release.config.json has empty backendUrl.")
            }
        }
        catch {
            $errors.Add("release.config.json parse failed: $($_.Exception.Message)")
        }
    }

    $versionedXpi = $null
    if (Test-Path $manifestPath) {
        try {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $versionedXpi = Join-Path $deployRoot ("artifacts\firefox\watch-employee-firefox-v{0}.xpi" -f $manifest.version)
        }
        catch {
            $warnings.Add("Could not read extension manifest for versioned XPI check.")
        }
    }

    if (($versionedXpi -and (Test-Path $versionedXpi)) -or (Test-Path $fallbackXpi)) {
        Write-UiLog "Preflight: Firefox package found."
    }
    else {
        $errors.Add("No Firefox package found. Expected $fallbackXpi or versioned artifact.")
    }

    if ($backendUrl) {
        try {
            $healthUrl = ($backendUrl.TrimEnd("/") + "/api/activity/health")
            $resp = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 6
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
                Write-UiLog "Preflight: Backend connectivity OK ($healthUrl)."
            }
            else {
                $warnings.Add("Backend health endpoint returned status $($resp.StatusCode).")
            }
        }
        catch {
            $warnings.Add("Backend connectivity check failed (warn-only): $($_.Exception.Message)")
        }
    }

    foreach ($e in $errors) {
        Write-UiLog "ERROR: $e"
    }
    foreach ($w in $warnings) {
        Write-UiLog "WARN: $w"
    }

    if ($errors.Count -eq 0) {
        $script:PreflightPassed = $true
        $window.Dispatcher.Invoke([Action]{ $txtStatus.Text = "Preflight passed. Install/Remove actions are ready." })
        Refresh-ActionButtons
        return $true
    }
    else {
        $script:PreflightPassed = $false
        $window.Dispatcher.Invoke([Action]{ $txtStatus.Text = "Preflight failed. Fix errors before install/remove." })
        Refresh-ActionButtons
        return $false
    }
}

function Start-ScriptAction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ActionName,
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [string[]]$ScriptArguments = @()
    )

    if ($script:ActionRunning) {
        Write-UiLog "Another action is already running. Please wait."
        return
    }

    if (-not (Test-Path $ScriptPath)) {
        Write-UiLog "ERROR: Script not found: $ScriptPath"
        return
    }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:CurrentLogFile = Join-Path $logsDir ("{0}-{1}.log" -f $ActionName, $stamp)
    $window.Dispatcher.Invoke([Action]{
            $txtLogFile.Text = $script:CurrentLogFile
            $txtStatus.Text = "Running action: $ActionName"
        })

    Set-ButtonsEnabled -Enabled $false
    $script:ActionRunning = $true
    $script:CurrentActionName = $ActionName

    Write-UiLog "Starting $ActionName..."
    Write-UiLog "Script: $ScriptPath"

    $script:LastActionExitCode = $null
    $script:CurrentActionLastSeq = 0

    $script:CurrentActionJob = Start-Job -ArgumentList $ScriptPath, $ScriptArguments -ScriptBlock {
        param($ScriptPathInner, $ScriptArgumentsInner)

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"

        $argParts = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPathInner`"")
        foreach ($arg in $ScriptArgumentsInner) {
            $argParts += "`"$arg`""
        }
        $psi.Arguments = $argParts -join " "

        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.WorkingDirectory = Split-Path -Parent $ScriptPathInner

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $null = $proc.Start()
        $seq = 0

        while (-not $proc.HasExited -or -not $proc.StandardOutput.EndOfStream -or -not $proc.StandardError.EndOfStream) {
            if (-not $proc.StandardOutput.EndOfStream) {
                $seq++
                [pscustomobject]@{
                    Stream = "OUT"
                    Line = $proc.StandardOutput.ReadLine()
                    Seq = $seq
                }
            }
            if (-not $proc.StandardError.EndOfStream) {
                $seq++
                [pscustomobject]@{
                    Stream = "ERR"
                    Line = $proc.StandardError.ReadLine()
                    Seq = $seq
                }
            }
            Start-Sleep -Milliseconds 25
        }

        $proc.WaitForExit()
        $seq++
        [pscustomobject]@{
            Stream = "EXIT"
            Line = $proc.ExitCode
            Seq = $seq
        }
    }
    $script:CurrentActionJobId = $script:CurrentActionJob.Id

    $script:ActionTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:ActionTimer.Interval = [TimeSpan]::FromMilliseconds(120)
    $script:ActionTimer.Add_Tick({
            try {
                $jobRef = $script:CurrentActionJob
                if (-not $jobRef -and $script:CurrentActionJobId) {
                    $jobRef = Get-Job -Id $script:CurrentActionJobId -ErrorAction SilentlyContinue
                    if ($jobRef) {
                        $script:CurrentActionJob = $jobRef
                    }
                }

                if (-not $jobRef) {
                    Write-UiLog "ERROR: background execution job handle was lost."
                    Complete-CurrentAction -ActionName $ActionName -ExitCode 1 -JobState "Failed"
                    return
                }

                $outputs = Receive-Job -Id $jobRef.Id -Keep
                foreach ($o in $outputs) {
                    if (-not $o) { continue }
                    if ($o.PSObject.Properties.Match("Seq").Count -gt 0) {
                        if ([int]$o.Seq -le $script:CurrentActionLastSeq) { continue }
                        $script:CurrentActionLastSeq = [int]$o.Seq
                    }
                    if ($o.Stream -eq "OUT") {
                        if ([string]::IsNullOrWhiteSpace([string]$o.Line)) { continue }
                        Write-UiLog $o.Line
                    }
                    elseif ($o.Stream -eq "ERR") {
                        if ([string]::IsNullOrWhiteSpace([string]$o.Line)) { continue }
                        Write-UiLog ("ERROR: " + $o.Line)
                    }
                    elseif ($o.Stream -eq "EXIT") {
                        $script:LastActionExitCode = [int]$o.Line
                    }
                }

                if ($jobRef.State -in @("Completed", "Failed", "Stopped")) {
                    $exitCode = if ($null -ne $script:LastActionExitCode) { [int]$script:LastActionExitCode } else { 1 }
                    Complete-CurrentAction -ActionName $ActionName -ExitCode $exitCode -JobState $jobRef.State
                }
            }
            catch {
                Write-UiLog "ERROR: Action monitor crashed: $($_.Exception.Message)"
                Complete-CurrentAction -ActionName $ActionName -ExitCode 1 -JobState "Failed"
            }
        })
    $script:ActionTimer.Start()
}

$btnPreflight.Add_Click({
        Write-UiLog "Running preflight check..."
        $null = Invoke-PreflightCheck
    })

$btnInstallFx.Add_Click({
        $installScript = Join-Path $deployRoot "install_policy.ps1"
        Start-ScriptAction -ActionName "install-firefox-policy" -ScriptPath $installScript
    })

$btnRemoveFx.Add_Click({
        $removeScript = Join-Path $deployRoot "remove_policy.ps1"
        Start-ScriptAction -ActionName "remove-firefox-policy" -ScriptPath $removeScript
    })

$btnOpenLogs.Add_Click({
        if (-not (Test-Path $logsDir)) {
            New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        }
        Start-Process -FilePath "explorer.exe" -ArgumentList "`"$logsDir`""
    })

$btnSaveChromeSettings.Add_Click({
        Save-ChromeSettingsToConfig
    })

$btnEditChromeSettings.Add_Click({
        if ($script:ChromeSettingsLocked) {
            Set-ChromeSettingsLock -Locked $false
            $txtStatus.Text = "Chrome settings unlocked for editing."
            Write-UiLog "Chrome settings unlocked for editing."
        }
        else {
            Load-ChromeSettingsFromConfig
            $txtStatus.Text = "Chrome settings reverted to saved values."
            Write-UiLog "Chrome settings edit canceled; reverted to saved config."
        }
        Refresh-ActionButtons
    })

$btnInstallChrome.Add_Click({
        Validate-ChromeInputs
        if (-not $script:ChromeConfigValid) {
            Refresh-ActionButtons
            Write-UiLog "ERROR: Chrome settings are invalid; install blocked."
            return
        }

        $scriptPath = Join-Path $deployRoot "install_policy_chrome.ps1"
        $args = @("-ExtensionId", $txtChromeExtensionId.Text.Trim(), "-UpdateUrl", $txtChromeUpdateUrl.Text.Trim())
        Start-ScriptAction -ActionName "install-chrome-policy" -ScriptPath $scriptPath -ScriptArguments $args
    })

$btnRemoveChrome.Add_Click({
        $scriptPath = Join-Path $deployRoot "remove_policy_chrome.ps1"
        Start-ScriptAction -ActionName "remove-chrome-policy" -ScriptPath $scriptPath
    })

$txtChromeExtensionId.Add_TextChanged({
        Validate-ChromeInputs
        Refresh-ActionButtons
    })

$txtChromeUpdateUrl.Add_TextChanged({
        Validate-ChromeInputs
        Refresh-ActionButtons
    })

$btnInstallFx.IsEnabled = $false
$btnRemoveFx.IsEnabled = $false
$btnInstallChrome.IsEnabled = $false
$btnRemoveChrome.IsEnabled = $true
$btnSaveChromeSettings.IsEnabled = $false
$btnEditChromeSettings.IsEnabled = $true

Write-UiLog "Installer started."
Write-UiLog "Detected deploy root: $deployRoot"
Load-ChromeSettingsFromConfig
$null = Invoke-PreflightCheck

$window.ShowDialog() | Out-Null
