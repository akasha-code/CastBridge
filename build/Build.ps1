param([switch]$CheckOnly)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$closed=$true
$mutex=$null
if ([Threading.Mutex]::TryOpenExisting('Local\CastAggregatorTray',[ref]$mutex)) {
    $acquired=$false
    try { $acquired=$mutex.WaitOne(0); $closed=$acquired }
    catch [Threading.AbandonedMutexException] { $acquired=$true; $closed=$true }
    finally { if($acquired){$mutex.ReleaseMutex()};$mutex.Dispose() }
}
$checks=@(
    [pscustomobject]@{Name='Windows x64';Ready=[Environment]::Is64BitOperatingSystem},
    [pscustomobject]@{Name='.NET Framework C# compiler';Ready=(Test-Path -LiteralPath $compiler)},
    [pscustomobject]@{Name='GCC x64 toolchain';Ready=[bool](Get-Command gcc.exe -ErrorAction SilentlyContinue)},
    [pscustomobject]@{Name='CastBridge is closed';Ready=$closed}
)
if($CheckOnly){$checks;return}
if(@($checks|Where-Object {-not $_.Ready}).Count){throw 'Build prerequisites failed. Close CastBridge and run build/Build.ps1 -CheckOnly for details.'}
foreach($script in @('Build-Icon.ps1','Build-NativeHelper.ps1','Build-Portable.ps1')) {
    & (Join-Path $root ('scripts\'+$script))
}
