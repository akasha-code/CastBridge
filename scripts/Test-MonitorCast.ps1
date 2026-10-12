param([ValidateRange(1,86400)][int]$Seconds=60,[string]$DeviceId,[string]$StopFile,[string]$SessionDirectory,[switch]$NoReference,[string]$DisplayName,[switch]$LowLatency,[string]$SyncFile,[switch]$AggressiveLatency,[switch]$LatencyClock,[switch]$Diagnostics,[ValidateRange(1,2)][int]$LatencyStep=1)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$python=Join-Path $root '.venv\Scripts\python.exe'
$layoutPath=Join-Path $root 'artifacts\display-layout.json'
$layoutId=if ($DeviceId) { $DeviceId } else { 'default' }
$artifactDir=Join-Path $root 'artifacts'
if ($SessionDirectory) { $artifactDir=$SessionDirectory }
if (-not (Test-Path -LiteralPath $artifactDir)) { New-Item -ItemType Directory -Path $artifactDir | Out-Null }
$baseline=Join-Path $artifactDir 'monitor-cast-baseline.json'
$resultPath=Join-Path $artifactDir 'monitor-cast-result.json'
$logPath=Join-Path $artifactDir 'monitor-cast.log'
$result=[ordered]@{extended=$false;castExitCode=$null;referenceWindowStarted=$false;monitorClosed=$false;physicalRestored=$false;error=$null;cleanupErrors=@()}
$device=$null; $reference=$null; $target=$null
function Run-Python([string[]]$Arguments) {
    $previousPreference=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        & $python -u @Arguments 2>&1 | ForEach-Object { $_ | Out-File -LiteralPath $logPath -Append -Encoding UTF8 }
        $code=$LASTEXITCODE
    } finally { $ErrorActionPreference=$previousPreference }
    if ($code -ne 0) { throw "Python operation failed: $code; see monitor-cast.log" }
}
Push-Location $root
try {
    if (Test-Path $resultPath) { throw 'Existing Cast test result; review before retrying' }
    if (Get-CimInstance Win32_PnPEntity | Where-Object { $_.HardwareID -contains 'MttVDD' -or $_.HardwareID -contains 'Root\MttVDD' }) { throw 'Existing VDD device; refusing concurrent session' }
    # This configuration belongs to the authorized prototype; no hot reload.
    $config='C:\VirtualDisplayDriver\vdd_settings.xml'
    [xml]$settings=Get-Content -LiteralPath $config
    if ($settings.vdd_settings.monitors.count -ne '1' -or $settings.vdd_settings.resolutions.resolution.width -ne '1280') { throw 'Unexpected driver configuration' }
    Copy-Item -LiteralPath $config -Destination (Join-Path $artifactDir 'driver-before-software-cursor.xml')
    $settings.vdd_settings.options.HardwareCursor='false'
    $settings.Save($config)
    Run-Python @('-m','prototype.display_session','snapshot',$baseline)
    Add-Type -Path (Join-Path $PSScriptRoot 'NativeSoftwareDisplay.cs')
    $device=[NativeSoftwareDisplay]::new((Join-Path $root 'artifacts\castaggregator-device.dll'))
    Start-Sleep -Seconds 3
    Run-Python @('-m','prototype.display_session','extend',$baseline,'--layout-file',$layoutPath,'--display-id',$layoutId)
    $result.extended=$true
    $active=Join-Path $artifactDir 'monitor-cast-active.json'
    Run-Python @('-m','prototype.display_session','snapshot',$active)
    $info=Get-Content -LiteralPath $active -Raw | ConvertFrom-Json
    $virtual=@($info.topology | Where-Object { $_.target_path -like '*#MTT1337#*' })
    if ($virtual.Count -ne 1) { throw 'Cannot attribute virtual target' }
    $target=$virtual[0].target_path
    $bounds=$info.bounds.PSObject.Properties[$virtual[0].source].Value
    if (-not $NoReference) {
    $windowScript=Join-Path $PSScriptRoot 'Reference-Window.ps1'
    $clockArgument=if ($LatencyClock) { '-LatencyClock' } else { '' }
    $reference=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -ArgumentList @('-NoProfile','-File',('"'+$windowScript+'"'),'-X',[string]$bounds.x,'-Y',[string]$bounds.y,$clockArgument) -RedirectStandardError (Join-Path $root 'artifacts\reference-window-error.log') -RedirectStandardOutput (Join-Path $root 'artifacts\reference-window-output.log') -PassThru
    $result.referenceWindowStarted=$true
    $referenceState=Join-Path $root "artifacts\reference-window-ready-$($reference.Id).json"
    $deadline=[DateTime]::UtcNow.AddSeconds(30)
    $ready=$false
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($reference.HasExited) { throw 'Reference process exited; see reference-window-error.log' }
        if (Test-Path $referenceState) {
            $window=Get-Content -LiteralPath $referenceState -Raw | ConvertFrom-Json
            if ($window.processId -eq $reference.Id -and $window.visible -and $window.x -ge $bounds.x -and $window.x -lt ($bounds.x+1280) -and $window.y -ge $bounds.y -and $window.y -lt ($bounds.y+720)) { $ready=$true; break }
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $ready) { throw 'Reference window readiness timed out' }
    }
    $castArguments=@('-m','prototype.cast','--capture-target',$target,'--seconds',[string]$Seconds)
    if ($DeviceId) { $castArguments+=@('--device-id',$DeviceId) }
    if ($StopFile) { $castArguments+=@('--stop-file',$StopFile) }
    if ($DisplayName) { $castArguments+=@('--display-name',$DisplayName) }; if ($LowLatency) { $castArguments+=@('--low-latency') }; if ($SyncFile) { $castArguments+=@('--sync-file',$SyncFile) }
    if ($AggressiveLatency) { $castArguments+=@('--aggressive-latency') }; if ($Diagnostics) { $castArguments+=@('--diagnostics') }
    $castArguments+=@('--latency-step',[string]$LatencyStep)
    Run-Python $castArguments
    $result.castExitCode=0
} catch { $result.error=$_.Exception.Message }
finally {
    if ($target) {
        try { Run-Python @('-m','prototype.display_layout',$layoutPath,'--display-id',$layoutId,'--target',$target) }
        catch { $result.cleanupErrors+=@($_.Exception.Message) }
        try { Run-Python @('-m','prototype.window_recovery',$target) }
        catch { $result.cleanupErrors+=@($_.Exception.Message) }
    }
    if ($reference -and -not $reference.HasExited) {
        try {
            $null=$reference.CloseMainWindow()
            if (-not $reference.WaitForExit(3000)) { Stop-Process -Id $reference.Id -ErrorAction Stop }
        } catch { $result.cleanupErrors+=@($_.Exception.Message) }
    }
    if ($device) { $device.Dispose(); $result.monitorClosed=$true }
    try {
        Start-Sleep -Seconds 3
        if (Test-Path $baseline) { Run-Python @('-m','prototype.display_session','restore',$baseline); $result.physicalRestored=$true }
    } catch { $result.cleanupErrors+=@($_.Exception.Message) }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    Pop-Location
}
if ($result.error -or $result.cleanupErrors.Count) { exit 1 }
