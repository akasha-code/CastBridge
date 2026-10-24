$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$statePath=Join-Path $root 'artifacts\driver-install-state.json'
$state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
if ($state.phase -ne 'rollback_device_and_package_removed' -or -not $state.configurationCreated) { throw 'Rollback journal does not authorize configuration cleanup' }
if (Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -eq $state.instanceId }) { throw 'Device remains present' }
if (Test-Path (Join-Path "$env:SystemRoot\INF" $state.publishedInf)) { throw 'Published INF remains present' }
$configuration='C:\VirtualDisplayDriver\vdd_settings.xml'
$resolved=[IO.Path]::GetFullPath($configuration)
if ($resolved -ne 'C:\VirtualDisplayDriver\vdd_settings.xml') { throw 'Unexpected configuration path' }
$files=@(Get-ChildItem -LiteralPath 'C:\VirtualDisplayDriver' -Force)
if ($files.Count -ne 1 -or $files[0].Name -ne 'vdd_settings.xml') { throw 'Additional files found; refusing directory cleanup' }
[xml]$settings=Get-Content -LiteralPath $configuration
if ($settings.vdd_settings.monitors.count -ne '1' -or $settings.vdd_settings.resolutions.resolution.width -ne '1280' -or $settings.vdd_settings.resolutions.resolution.height -ne '720') { throw 'Configuration changed; refusing cleanup' }
Copy-Item -LiteralPath $configuration -Destination (Join-Path $root 'artifacts\driver-configuration-used.xml')
Remove-Item -LiteralPath $configuration
if (@(Get-ChildItem -LiteralPath 'C:\VirtualDisplayDriver' -Force).Count -eq 0) { Remove-Item -LiteralPath 'C:\VirtualDisplayDriver' }
$state.phase='rollback_completed_reboot_was_requested'
$state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
