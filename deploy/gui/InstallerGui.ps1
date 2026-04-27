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
                    <TextBlock Text="Chrome (Phase 1: Disabled)" FontWeight="Bold" Margin="0,10,0,8"/>
                    <Button x:Name="BtnInstallChrome" Margin="0,0,0,8" Padding="10" IsEnabled="False" ToolTip="Enable after extension ID/update URL finalized." Content="Install Chrome Policy (Coming Next)"/>
                    <Button x:Name="BtnRemoveChrome" Padding="10" IsEnabled="False" ToolTip="Enable after extension ID/update URL finalized." Content="Remove Chrome Policy (Coming Next)"/>
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

$script:ActionRunning = $false
$script:CurrentLogFile = $null
$script:CurrentActionJob = $null
$script:CurrentActionJobId = $null
$script:ActionTimer = $null
$script:CurrentActionName = $null

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
    $btnPreflight.IsEnabled = $Enabled
    $btnInstallFx.IsEnabled = $Enabled
    $btnRemoveFx.IsEnabled = $Enabled
    $btnOpenLogs.IsEnabled = $Enabled
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
        $window.Dispatcher.Invoke([Action]{
                $txtStatus.Text = "Preflight passed. Install/Remove actions are ready."
                $btnInstallFx.IsEnabled = $true
                $btnRemoveFx.IsEnabled = $true
            })
        return $true
    }
    else {
        $window.Dispatcher.Invoke([Action]{
                $txtStatus.Text = "Preflight failed. Fix errors before install/remove."
                $btnInstallFx.IsEnabled = $false
                $btnRemoveFx.IsEnabled = $false
            })
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

        while (-not $proc.HasExited -or -not $proc.StandardOutput.EndOfStream -or -not $proc.StandardError.EndOfStream) {
            if (-not $proc.StandardOutput.EndOfStream) {
                [pscustomobject]@{
                    Stream = "OUT"
                    Line = $proc.StandardOutput.ReadLine()
                }
            }
            if (-not $proc.StandardError.EndOfStream) {
                [pscustomobject]@{
                    Stream = "ERR"
                    Line = $proc.StandardError.ReadLine()
                }
            }
            Start-Sleep -Milliseconds 25
        }

        $proc.WaitForExit()
        [pscustomobject]@{
            Stream = "EXIT"
            Line = $proc.ExitCode
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

                $outputs = Receive-Job -Id $jobRef.Id
                foreach ($o in $outputs) {
                    if (-not $o) { continue }
                    if ($o.Stream -eq "OUT") {
                        Write-UiLog $o.Line
                    }
                    elseif ($o.Stream -eq "ERR") {
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

$btnInstallFx.IsEnabled = $false
$btnRemoveFx.IsEnabled = $false

Write-UiLog "Installer started."
Write-UiLog "Detected deploy root: $deployRoot"
$null = Invoke-PreflightCheck

$window.ShowDialog() | Out-Null
