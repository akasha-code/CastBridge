$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$statePath=Join-Path $root 'artifacts\software-device-state.json'
$logPath=Join-Path $root 'artifacts\software-device-test.log'
$journal=[ordered]@{phase='preflight';publishedInf=$null;instanceIds=@();cycles=@();error=$null}
$device=$null
function Save-State { $journal | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding UTF8 }
function Snapshot([string]$Name) {
    Push-Location $root
    try {
        $snapshot=& (Join-Path $root '.venv\Scripts\python.exe') -m prototype.windows_display
        if ($LASTEXITCODE -ne 0) { throw 'Native topology snapshot failed' }
        $snapshot | Set-Content -LiteralPath (Join-Path $root "artifacts\$Name.json") -Encoding UTF8
    } finally { Pop-Location }
}
try {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator elevation required' }
    if (Test-Path $statePath) { throw 'Software-device journal already exists; do not retry blindly' }
    if (Test-Path 'C:\VirtualDisplayDriver') { throw 'Existing VDD configuration' }
    if (Get-CimInstance Win32_PnPEntity | Where-Object { $_.HardwareID -contains 'Root\MttVDD' -or $_.HardwareID -contains 'MttVDD' }) { throw 'Existing VDD device' }
    if (Get-WindowsDriver -Online -All | Where-Object { $_.OriginalFileName -match 'MttVDD\.inf$' }) { throw 'Existing staged VDD package' }
    Snapshot 'software-display-before'
    $package=Join-Path $root 'artifacts\software-device-verified'
    if (Test-Path $package) { throw 'Verification directory already exists' }
    $zip=Join-Path $root 'artifacts\vdd-25.7.23.zip'
    if ((Get-FileHash -LiteralPath $zip).Hash -ne 'E24210692B442B39AF763536330CE78B423F19342B7A7792C26DE3944E418B3A') { throw 'ZIP hash mismatch' }
    Expand-Archive -LiteralPath $zip -DestinationPath $package
    $inf=Join-Path $package 'VirtualDisplayDriver\MttVDD.inf'
    foreach ($name in @('mttvdd.cat','MttVDD.dll')) {
        $signature=Get-AuthenticodeSignature (Join-Path (Split-Path $inf) $name)
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'CN=SignPath Foundation,') { throw "Invalid signature: $name" }
    }
    Add-Type -Path (Join-Path $PSScriptRoot 'SoftwareDisplay.cs')
    Save-State
    New-Item -ItemType Directory -Path 'C:\VirtualDisplayDriver' | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'artifacts\driver-configuration-used.xml') -Destination 'C:\VirtualDisplayDriver\vdd_settings.xml'
    $journal.phase='configuration_ready'; Save-State
    $output=& "$env:SystemRoot\System32\pnputil.exe" /add-driver $inf 2>&1
    $code=$LASTEXITCODE
    $output | Out-File -LiteralPath $logPath -Encoding UTF8
    if ($code -ne 0) { throw "Package staging failed: $code" }
    $matches=[regex]::Matches(($output -join "`n"),'oem\d+\.inf')
    $names=@($matches | ForEach-Object { $_.Value } | Select-Object -Unique)
    if ($names.Count -ne 1) { throw 'Cannot identify staged OEM package' }
    $journal.publishedInf=$names[0]; $journal.phase='package_staged'; Save-State
    foreach ($cycle in @(1,2)) {
        try {
            $device=[SoftwareDisplay]::new()
            $journal.instanceIds+=@($device.InstanceId)
            $journal.phase="cycle_${cycle}_device_created"; Save-State
            Start-Sleep -Seconds 5
            $pnp=Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -eq $device.InstanceId }
            if (-not $pnp -or $pnp.ConfigManagerErrorCode -ne 0) { throw 'Software display driver did not start successfully' }
            Snapshot "software-display-cycle-$cycle-active"
        } finally {
            if ($device) { $device.Dispose(); $device=$null }
        }
        Start-Sleep -Seconds 5
        Snapshot "software-display-cycle-$cycle-closed"
        $journal.cycles+=@(@{cycle=$cycle;handleClosed=$true})
        $journal.phase="cycle_${cycle}_closed"; Save-State
    }
    $journal.phase='lifecycle_cycles_observed'; Save-State
} catch {
    $journal.error=$_.Exception.Message
    $journal.phase='failed'; Save-State
    $journal.error | Out-File -LiteralPath $logPath -Append -Encoding UTF8
} finally {
    if ($device) { $device.Dispose(); $device=$null }
    Start-Sleep -Seconds 3
    Snapshot 'software-display-final'
}
if ($journal.error) { exit 1 }
