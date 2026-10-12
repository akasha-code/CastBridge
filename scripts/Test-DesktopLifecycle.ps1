$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$output=Join-Path $root 'artifacts\desktop-lifecycle.exe'
$report=Join-Path $root 'artifacts\desktop-lifecycle.json'
& $compiler /nologo /target:winexe /platform:x64 /main:DesktopLifecycle ('/out:'+$output) ('/win32icon:'+(Join-Path $root 'assets\castbridge.ico')) /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll /reference:System.Xml.dll /reference:System.Management.dll (Join-Path $root 'native\Common.cs') (Join-Path $root 'native\App.cs') (Join-Path $root 'scripts\NativeSoftwareDisplay.cs') (Join-Path $root 'tests\desktop_lifecycle.cs')
if($LASTEXITCODE -ne 0){throw 'Lifecycle test compilation failed.'}
$process=Start-Process -FilePath $output -ArgumentList @(('"'+$root+'"'),('"'+$report+'"')) -WindowStyle Hidden -PassThru
if(-not $process.WaitForExit(10000)){throw 'Lifecycle test timed out.'}
Get-Content -LiteralPath $report
if($process.ExitCode -ne 0){throw 'Lifecycle regression failed.'}
