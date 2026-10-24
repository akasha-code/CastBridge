$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$statePath=Join-Path $root 'artifacts\driver-install-state.json'
$logPath=Join-Path $root 'artifacts\driver-rollback.log'
$state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
try {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator elevation required' }
    if ($state.instanceId -ne 'ROOT\DISPLAY\0000' -or $state.publishedInf -ne 'oem33.inf') { throw 'Rollback attribution differs from the observed installation' }
    $device=Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -eq $state.instanceId }
    if ($device -and $device.HardwareID -notcontains 'Root\MttVDD') { throw 'Device hardware ID mismatch' }
    $output=& "$env:SystemRoot\System32\pnputil.exe" /remove-device $state.instanceId 2>&1
    $code=$LASTEXITCODE
    $output | Out-File -LiteralPath $logPath -Encoding UTF8
    if ($code -notin @(0,3010)) { throw "Device removal failed: $code" }
    if ($code -eq 3010) { $state.rebootRequired=$true }
    $remaining=Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -eq $state.instanceId }
    if ($remaining) { throw 'Device removal pending; package retained until removal is confirmed' }
    $package=Get-WindowsDriver -Online -Driver $state.publishedInf
    if ($package.OriginalFileName -notmatch 'MttVDD\.inf$') { throw 'Package INF mismatch' }
    $output=& "$env:SystemRoot\System32\pnputil.exe" /delete-driver $state.publishedInf 2>&1
    $code=$LASTEXITCODE
    $output | Out-File -LiteralPath $logPath -Append -Encoding UTF8
    if ($code -notin @(0,3010)) { throw "Package removal failed: $code" }
    if ($code -eq 3010) { $state.rebootRequired=$true }
    $state.phase='rollback_device_and_package_removed'
    $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    exit 0
} catch {
    $_.Exception.Message | Out-File -LiteralPath $logPath -Append -Encoding UTF8
    $state.phase='rollback_pending'
    $state.error=$_.Exception.Message
    $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    exit 1
}
