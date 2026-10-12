$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$output=Join-Path $root 'artifacts\power-resume-checks.exe'
& $compiler /nologo /target:exe /platform:x64 /main:PowerResumeChecks ('/out:'+$output) ('/win32icon:'+(Join-Path $root 'assets\castbridge.ico')) /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll /reference:System.Xml.dll /reference:System.Management.dll (Join-Path $root 'native\Common.cs') (Join-Path $root 'native\App.cs') (Join-Path $root 'scripts\NativeSoftwareDisplay.cs') (Join-Path $root 'tests\power_resume.cs')
if($LASTEXITCODE -ne 0){throw 'Power resume test compilation failed.'}
& $output $root
if($LASTEXITCODE -ne 0){throw 'Power resume regression failed.'}
