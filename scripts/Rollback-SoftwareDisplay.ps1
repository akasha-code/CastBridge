$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$statePath=Join-Path $root 'artifacts\software-device-state.json'
$state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
if ($state.phase -ne 'failed' -or $state.publishedInf -notmatch '^oem\d+\.inf$') { throw 'No attributable failed staging operation' }
if (Get-CimInstance Win32_PnPEntity | Where-Object { $_.HardwareID -contains 'Root\MttVDD' -or $_.HardwareID -contains 'MttVDD' }) { throw 'VDD device remains present; refusing package removal' }
$package=Get-WindowsDriver -Online -Driver $state.publishedInf
if ($package.OriginalFileName -notmatch 'MttVDD\.inf$' -or $package.Version -ne '11.30.4.434') { throw 'Staged package mismatch' }
$output=& "$env:SystemRoot\System32\pnputil.exe" /delete-driver $state.publishedInf 2>&1
$code=$LASTEXITCODE
$output | Out-File -LiteralPath (Join-Path $root 'artifacts\software-device-rollback.log') -Encoding UTF8
if ($code -ne 0) { throw "Package removal incomplete: $code" }
$configuration='C:\VirtualDisplayDriver\vdd_settings.xml'
if (Test-Path $configuration) {
    $expected=Join-Path $root 'artifacts\driver-configuration-used.xml'
    if ((Get-FileHash -LiteralPath $configuration).Hash -ne (Get-FileHash -LiteralPath $expected).Hash) { throw 'Configuration modified; refusing deletion' }
    Remove-Item -LiteralPath $configuration
    if (@(Get-ChildItem -LiteralPath 'C:\VirtualDisplayDriver' -Force).Count -eq 0) { Remove-Item -LiteralPath 'C:\VirtualDisplayDriver' }
}
$state.phase='staging_rolled_back'
$state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath -Encoding UTF8
