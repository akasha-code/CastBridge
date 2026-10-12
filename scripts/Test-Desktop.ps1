$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$output=Join-Path $root 'artifacts\native-checks.exe'
& $compiler /nologo /target:exe /platform:x64 ('/out:'+$output) /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll /reference:System.Xml.dll /reference:System.Management.dll (Join-Path $root 'native\Common.cs') (Join-Path $root 'tests\native_checks.cs')
if($LASTEXITCODE -ne 0){throw 'Native test compilation failed.'}
& $output $root
if($LASTEXITCODE -ne 0){throw 'Native checks failed.'}
