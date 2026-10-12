$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$shell=New-Object -ComObject WScript.Shell
$shortcut=$null
try {
    $shortcut=$shell.CreateShortcut((Join-Path $root 'CastBridge.lnk'))
    $shortcut.TargetPath="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $shortcut.Arguments='-NoProfile -STA -WindowStyle Hidden -File "'+(Join-Path $root 'scripts\Start-CastAggregator.ps1')+'"'
    $shortcut.WorkingDirectory=$root
    $shortcut.IconLocation=(Join-Path $root 'assets\castaggregator.ico')+',0'
    $shortcut.Description='CastBridge - pantalla extendida por Chromecast. Una producción de MateKraft.'
    $shortcut.Save()
} finally {
    if ($shortcut) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut) }
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
}
