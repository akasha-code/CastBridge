$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$output=Join-Path $root 'artifacts\driver-configuration-checks.exe'
$sources=@('native\Common.cs','native\App.cs','native\Installer.cs','scripts\NativeSoftwareDisplay.cs','tests\driver_configuration.cs')|ForEach-Object {Join-Path $root $_}
& $compiler /nologo /target:exe /platform:x64 /main:DriverConfigurationChecks ('/out:'+$output) ('/resource:'+(Join-Path $root 'driver\vdd_settings.xml')+',driver-template.xml') /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll /reference:System.Xml.dll /reference:System.Management.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll @sources
if($LASTEXITCODE -ne 0){throw 'Configuration test compilation failed.'}
& $output $root
if($LASTEXITCODE -ne 0){throw 'Configuration regression failed.'}
