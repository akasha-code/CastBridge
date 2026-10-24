$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$output=Join-Path $root 'artifacts\software-device-native-probe.json'
$result=[ordered]@{created=$false;instanceId=$null;closed=$false;problemCode=$null;error=$null}
$device=$null
try {
    Add-Type -Path (Join-Path $PSScriptRoot 'NativeSoftwareDisplay.cs')
    $device=[NativeSoftwareDisplay]::new((Join-Path $root 'artifacts\castaggregator-device.dll'))
    $result.created=$true; $result.instanceId=$device.InstanceId
    Start-Sleep -Seconds 5
    $pnp=Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -eq $device.InstanceId }
    if ($pnp) { $result.problemCode=$pnp.ConfigManagerErrorCode }
    Push-Location $root
    try {
        $snapshot=& (Join-Path $root '.venv\Scripts\python.exe') -m prototype.windows_display
        if ($LASTEXITCODE -ne 0) { throw 'Topology snapshot failed' }
        $snapshot | Set-Content -LiteralPath (Join-Path $root 'artifacts\native-probe-active-topology.json') -Encoding UTF8
    } finally { Pop-Location }
} catch { $result.error=$_.Exception.Message }
finally {
    if ($device) { $device.Dispose(); $result.closed=$true }
    $result | ConvertTo-Json | Set-Content -LiteralPath $output -Encoding UTF8
}
