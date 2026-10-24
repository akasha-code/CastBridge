$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$statePath = Join-Path $root 'artifacts\driver-install-state.json'
$logPath = Join-Path $root 'artifacts\driver-install.log'
$journal = [ordered]@{ phase='preflight'; instanceId=$null; publishedInf=$null; configurationCreated=$false; rebootRequired=$false }
function Save-State { $journal | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8 }
function Native-Checked([string[]]$Arguments) {
    $output = & "$env:SystemRoot\System32\pnputil.exe" @Arguments 2>&1
    $code = $LASTEXITCODE
    $output | Out-File -LiteralPath $logPath -Append -Encoding UTF8
    if ($code -notin @(0,3010)) { throw "pnputil failed: $code" }
    if ($code -eq 3010) { $journal.rebootRequired=$true }
}
try {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator elevation required' }
    if (Test-Path $statePath) { throw 'Installation journal already exists; inspect it before retrying' }
    if (Test-Path 'C:\VirtualDisplayDriver') { throw 'Existing driver configuration; refusing to overwrite it' }
    $devices=@(Get-CimInstance Win32_PnPEntity | Where-Object { $_.HardwareID -contains 'Root\MttVDD' -or $_.Name -match 'Virtual Display Driver' })
    if ($devices.Count) { throw 'Existing VDD device; refusing shared ownership' }
    $before=@(Get-WindowsDriver -Online -All | Where-Object { $_.OriginalFileName -match 'MttVDD\.inf$' })
    if ($before.Count) { throw 'Existing staged VDD package; refusing shared ownership' }
    $zip=Join-Path $root 'artifacts\vdd-25.7.23.zip'
    if ((Get-FileHash -LiteralPath $zip).Hash -ne 'E24210692B442B39AF763536330CE78B423F19342B7A7792C26DE3944E418B3A') { throw 'ZIP hash mismatch' }
    $package=Join-Path $root 'artifacts\vdd-install-verified'
    if (Test-Path $package) { throw 'Verification directory already exists' }
    Expand-Archive -LiteralPath $zip -DestinationPath $package
    $inf=Join-Path $package 'VirtualDisplayDriver\MttVDD.inf'
    foreach ($name in @('mttvdd.cat','MttVDD.dll')) {
        $signature=Get-AuthenticodeSignature (Join-Path (Split-Path $inf) $name)
        if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'CN=SignPath Foundation,') { throw "Invalid signature: $name" }
    }
    Add-Type -Path (Join-Path $PSScriptRoot 'DriverDevice.cs')
    Push-Location $root
    try {
        $snapshot=& (Join-Path $root '.venv\Scripts\python.exe') -m prototype.windows_display
        if ($LASTEXITCODE -ne 0) { throw 'Native topology snapshot failed' }
        $snapshot | Set-Content -LiteralPath (Join-Path $root 'artifacts\native-topology-before-install.json') -Encoding UTF8
    } finally { Pop-Location }
    Save-State
    New-Item -ItemType Directory -Path 'C:\VirtualDisplayDriver' | Out-Null
    $journal.configurationCreated=$true; Save-State
    # One explicit SDR mode. Lifecycle is controlled by the owned PnP device.
    [xml]$settings=Get-Content -LiteralPath (Join-Path (Split-Path $inf) 'vdd_settings.xml')
    $settings.vdd_settings.monitors.count='1'
    $settings.vdd_settings.resolutions.InnerXml='<resolution><width>1280</width><height>720</height><refresh_rate>60</refresh_rate></resolution>'
    $global=$settings.vdd_settings.SelectSingleNode('global')
    if ($global) { $null=$settings.vdd_settings.RemoveChild($global) }
    $settings.Save('C:\VirtualDisplayDriver\vdd_settings.xml')
    $journal.phase='configuration_ready'; Save-State
    Native-Checked @('/add-driver',$inf)
    $added=@(Get-WindowsDriver -Online -All | Where-Object { $_.OriginalFileName -match 'MttVDD\.inf$' })
    if ($added.Count -ne 1) { throw 'Cannot attribute the staged package' }
    $journal.publishedInf=$added[0].Driver; $journal.phase='package_staged'; Save-State
    $journal.instanceId=[DriverDevice]::CreateDisabled(); $journal.phase='device_registered'; Save-State
    Native-Checked @('/disable-device',$journal.instanceId)
    $journal.rebootRequired=[DriverDevice]::Bind($inf) -or $journal.rebootRequired
    Native-Checked @('/disable-device',$journal.instanceId)
    $device=Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -eq $journal.instanceId }
    if (-not $device -or $device.ConfigManagerErrorCode -ne 22) { throw 'Device is not confirmed disabled' }
    $journal.phase='installed_disabled'; Save-State
    exit 0
} catch {
    $failure=$_.Exception.Message
    $failure | Out-File -LiteralPath $logPath -Append -Encoding UTF8
    # Leave an attributable journal; never remove an unrecorded package/device.
    if ($journal.instanceId) {
        & "$env:SystemRoot\System32\pnputil.exe" /disable-device $journal.instanceId 2>&1 | Out-File -LiteralPath $logPath -Append -Encoding UTF8
    }
    $journal.phase='failed'; $journal['error']=$failure
    if ($journal.configurationCreated -or $journal.publishedInf -or $journal.instanceId) { Save-State }
    exit 1
}
