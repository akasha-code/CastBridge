$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$shell=New-Object -ComObject WScript.Shell
$shortcut=$null
try {
    $shortcut=$shell.CreateShortcut((Join-Path $root 'CastBridge.lnk'))
    $shortcut.TargetPath=Join-Path $root 'CastBridge.exe'
    $shortcut.Arguments=''
    $shortcut.WorkingDirectory=$root
    $shortcut.IconLocation=(Join-Path $root 'CastBridge.exe')+',0'
    $shortcut.Description='CastBridge — A MateKraft production.'
    $shortcut.Save()
} finally {
    if ($shortcut) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut) }
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
}
