param([switch]$CheckOnly)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$preflight=& (Join-Path $PSScriptRoot 'Test-Prerequisites.ps1') -Root $root
if ($CheckOnly) { $preflight; return }
if (-not $preflight.Ready) {
    foreach ($item in @($preflight.Checks | Where-Object {-not $_.Ready})) { Write-Host ($item.Name+': '+$item.Help+' '+$item.Url) }
    throw 'Instalacion bloqueada: resolve los requisitos y volve a comprobar. No se instalaron dependencias ni se crearon atajos.'
}
Push-Location $root
try {
    $launcher=Get-Command py.exe -ErrorAction Stop
    & $launcher.Source -3.12 -c "import struct; assert struct.calcsize('P') == 8, 'Python x64 required'"
    if ($LASTEXITCODE -ne 0) { throw 'Python 3.12 x64 required.' }
    if (-not (Test-Path '.venv\Scripts\python.exe')) {
        & $launcher.Source -3.12 -m venv .venv
        if ($LASTEXITCODE -ne 0) { throw 'Virtual environment creation failed.' }
    }
    & .\.venv\Scripts\python.exe -m pip install -r requirements-prototype.lock.txt
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
    & .\.venv\Scripts\python.exe -m pip check
    if ($LASTEXITCODE -ne 0) { throw 'Dependency validation failed.' }
    & (Join-Path $PSScriptRoot 'New-Shortcut.ps1')
    'Runtime prepared. Open CastAggregator.lnk or CastAggregator.cmd.'
} finally { Pop-Location }
