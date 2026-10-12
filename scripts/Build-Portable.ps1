$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$stage=Join-Path $root ('artifacts\package-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
foreach ($name in @('assets','prototype','scripts','artifacts','driver')) { New-Item -ItemType Directory -Path (Join-Path $stage $name) | Out-Null }
foreach ($name in @('CastAggregator.cmd','Install-CastAggregator.cmd','INSTALL.md','requirements-prototype.lock.txt')) { Copy-Item -LiteralPath (Join-Path $root $name) -Destination $stage }
Get-ChildItem (Join-Path $root 'prototype') -Filter '*.py' -File | Copy-Item -Destination (Join-Path $stage 'prototype')
foreach ($name in @('Start-CastAggregator.ps1','Test-MonitorCast.ps1','NativeSoftwareDisplay.cs','Reference-Window.ps1','Setup-Local.ps1','New-Shortcut.ps1','Test-Prerequisites.ps1','Install-Wizard.ps1')) { Copy-Item -LiteralPath (Join-Path $root ('scripts\'+$name)) -Destination (Join-Path $stage 'scripts') }
Copy-Item -LiteralPath (Join-Path $root 'assets\castaggregator.ico') -Destination (Join-Path $stage 'assets')
Copy-Item -LiteralPath (Join-Path $root 'artifacts\castaggregator-device.dll') -Destination (Join-Path $stage 'artifacts')
Copy-Item -LiteralPath (Join-Path $root 'driver\vdd_settings.xml') -Destination (Join-Path $stage 'driver')
$zip=Join-Path $root ('artifacts\CastAggregator-Windows-x64-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.zip')
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
Get-FileHash -LiteralPath $zip | Select-Object Path,Hash
