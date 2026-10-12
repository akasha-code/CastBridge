$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Get-Command gcc.exe -ErrorAction Stop
$source=Join-Path $root 'prototype\software_display_native.c'
$output=Join-Path $root 'artifacts\castaggregator-device.dll'
if (-not (Test-Path (Split-Path $output))) { New-Item -ItemType Directory -Path (Split-Path $output) | Out-Null }
& $compiler.Source -shared -m64 -O2 -Wall -Wextra -Werror -o $output $source
if ($LASTEXITCODE -ne 0) { throw "Native helper compilation failed: $LASTEXITCODE" }
Get-FileHash -LiteralPath $output | Select-Object Algorithm,Hash
