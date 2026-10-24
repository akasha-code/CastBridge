$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$python=Join-Path $root '.venv\Scripts\python.exe'
$baseline=Join-Path $root 'artifacts\native-session-baseline.json'
$resultPath=Join-Path $root 'artifacts\native-session-result.json'
$logPath=Join-Path $root 'artifacts\native-session.log'
$result=[ordered]@{cycles=@();error=$null;cleanupError=$null}
$device=$null
function Run-Python([string[]]$Arguments) {
    $previousPreference=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        $output=& $python @Arguments 2>&1
        $code=$LASTEXITCODE
    } finally { $ErrorActionPreference=$previousPreference }
    $output | Out-File -LiteralPath $logPath -Append -Encoding UTF8
    if ($code -ne 0) { throw "Display operation failed: $code; see native-session.log" }
}
Push-Location $root
try {
    if (Test-Path $resultPath) { throw 'Existing session result; review before retrying' }
    if (Get-CimInstance Win32_PnPEntity | Where-Object { $_.HardwareID -contains 'MttVDD' -or $_.HardwareID -contains 'Root\MttVDD' }) { throw 'Existing VDD device' }
    Run-Python @('-m','prototype.display_session','snapshot',$baseline)
    Add-Type -Path (Join-Path $PSScriptRoot 'NativeSoftwareDisplay.cs')
    foreach ($cycle in @(1,2)) {
        try {
            $device=[NativeSoftwareDisplay]::new((Join-Path $root 'artifacts\castaggregator-device.dll'))
            Start-Sleep -Seconds 3
            $pnp=Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -eq $device.InstanceId }
            if (-not $pnp -or $pnp.ConfigManagerErrorCode -ne 0) { throw 'Driver did not start cleanly' }
            Run-Python @('-m','prototype.display_session','extend',$baseline)
            Run-Python @('-m','prototype.display_session','snapshot',(Join-Path $root "artifacts\native-session-cycle-$cycle-active.json"))
            $result.cycles+=@(@{cycle=$cycle;instanceId=$device.InstanceId;extended=$true;handleClosed=$false;physicalRestored=$false})
            Start-Sleep -Seconds 3
        } finally {
            if ($device) { $device.Dispose(); $device=$null }
        }
        Start-Sleep -Seconds 3
        Run-Python @('-m','prototype.display_session','restore',$baseline)
        $result.cycles[-1].handleClosed=$true
        $result.cycles[-1].physicalRestored=$true
        $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    }
} catch { $result.error=$_.Exception.Message }
finally {
    if ($device) { $device.Dispose(); $device=$null }
    try {
        if (Test-Path $baseline) {
            Start-Sleep -Seconds 3
            Run-Python @('-m','prototype.display_session','restore',$baseline)
        }
    } catch { $result.cleanupError=$_.Exception.Message }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    Pop-Location
}
if ($result.error -or $result.cleanupError) { exit 1 }
