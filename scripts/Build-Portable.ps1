$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot 'Build-Desktop.ps1')
$stage=Join-Path $root ('artifacts\package-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
foreach ($name in @('assets','prototype','artifacts','driver','docs')) {New-Item -ItemType Directory -Path (Join-Path $stage $name) | Out-Null}
foreach ($name in @('CastBridge.exe','README.md','README.es.md','README.no.md','INSTALL.md','requirements-prototype.lock.txt')) {Copy-Item -LiteralPath (Join-Path $root $name) -Destination $stage}
Get-ChildItem (Join-Path $root 'prototype') -Filter '*.py' -File | Copy-Item -Destination (Join-Path $stage 'prototype')
Get-ChildItem (Join-Path $root 'docs') -Filter 'downloads*.md' -File | Copy-Item -Destination (Join-Path $stage 'docs')
foreach ($name in @('castbridge.ico','castbridge.png','castbridge-banner.svg','languages.json')) {Copy-Item -LiteralPath (Join-Path $root ('assets\'+$name)) -Destination (Join-Path $stage 'assets')}
Copy-Item -LiteralPath (Join-Path $root 'artifacts\castaggregator-device.dll') -Destination (Join-Path $stage 'artifacts')
Copy-Item -LiteralPath (Join-Path $root 'driver\vdd_settings.xml') -Destination (Join-Path $stage 'driver')
$zip=Join-Path $root ('artifacts\CastBridge-Windows-x64-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.zip')
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
& (Join-Path $PSScriptRoot 'Build-Desktop.ps1') -Payload $zip
Get-FileHash -LiteralPath $zip,(Join-Path $root 'artifacts\CastBridge-Setup.exe') | Select-Object Path,Hash
