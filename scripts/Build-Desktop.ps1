param([string]$Payload)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $compiler)) {throw '.NET Framework C# compiler unavailable.'}
$references=@('System.dll','System.Core.dll','System.Drawing.dll','System.Windows.Forms.dll','System.Web.Extensions.dll','System.Management.dll','System.Xml.dll','System.IO.Compression.dll','System.IO.Compression.FileSystem.dll')
$arguments=@('/nologo','/target:winexe','/platform:x64','/optimize+','/warnaserror+',('/win32icon:'+(Join-Path $root 'assets\castbridge.ico')),('/win32manifest:'+(Join-Path $root 'native\app.manifest')),('/resource:'+(Join-Path $root 'assets\languages.json')+',languages.json'))
foreach($reference in $references){$arguments+=('/reference:'+$reference)}
$sources=@((Join-Path $root 'native\Common.cs'),(Join-Path $root 'native\App.cs'),(Join-Path $root 'scripts\NativeSoftwareDisplay.cs'))
if ($Payload) {
    $arguments+=@('/main:CastBridge.SetupProgram',('/out:'+(Join-Path $root 'artifacts\CastBridge-Setup.exe')),('/resource:'+$Payload+',payload.zip'),('/resource:'+(Join-Path $root 'driver\vdd_settings.xml')+',driver-template.xml'))
    $sources+=(Join-Path $root 'native\Installer.cs')
} else {$arguments+=@('/main:CastBridge.Program',('/out:'+(Join-Path $root 'CastBridge.exe')))}
& $compiler @arguments @sources
if($LASTEXITCODE -ne 0){throw 'Desktop compilation failed.'}
