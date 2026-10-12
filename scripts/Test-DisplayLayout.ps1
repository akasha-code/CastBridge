$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$python=Join-Path $root '.venv\Scripts\python.exe'
$directory=Join-Path $root ('artifacts\layout-validation-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory | Out-Null
$directory | Set-Content (Join-Path $root 'artifacts\layout-validation-current.txt')
$baseline=Join-Path $directory 'baseline.json'
$candidate=Join-Path $directory 'candidate.json'
$saved=Join-Path $directory 'saved.json'
$log=Join-Path $directory 'validation.log'
$result=[ordered]@{cycles=@();error=$null;cleanupErrors=@()}
$device=$null
function Run-Python([string[]]$Arguments) {
    $previous=$ErrorActionPreference
    try { $ErrorActionPreference='Continue'; & $python @Arguments 2>&1 | Out-File -LiteralPath $log -Append -Encoding UTF8; $code=$LASTEXITCODE }
    finally { $ErrorActionPreference=$previous }
    if ($code -ne 0) { throw "Layout operation failed: $code" }
}
Push-Location $root
try {
    if (Get-Process ffmpeg -ErrorAction SilentlyContinue) { throw 'Active encoder; refusing test' }
    if (Get-CimInstance Win32_PnPEntity | Where-Object { $_.HardwareID -contains 'MttVDD' -or $_.HardwareID -contains 'Root\MttVDD' }) { throw 'Existing virtual display; refusing test' }
    Run-Python @('-m','prototype.display_session','snapshot',$baseline)
    $snapshot=Get-Content $baseline -Raw | ConvertFrom-Json
    $anchors=@($snapshot.topology | Where-Object { $snapshot.bounds.PSObject.Properties[$_.source].Value.primary })
    if ($anchors.Count -ne 1) { throw 'Ambiguous physical primary' }
    $anchor=$anchors[0]
    $anchorBounds=$snapshot.bounds.PSObject.Properties[$anchor.source].Value
    $left=$snapshot.bounds.PSObject.Properties.Value | Sort-Object x | Select-Object -First 1
    $desiredX=[int]$left.x-1280; $desiredY=[int]$left.y
    @{version=1;displays=@{validation=@{anchor_target=$anchor.target_path;offset_x=$desiredX-[int]$anchorBounds.x;offset_y=$desiredY-[int]$anchorBounds.y;width=1280;height=720}}} | ConvertTo-Json -Depth 6 | Set-Content $candidate -Encoding UTF8
    Add-Type -Path (Join-Path $PSScriptRoot 'NativeSoftwareDisplay.cs')
    foreach ($cycle in @(1,2)) {
        try {
            $device=[NativeSoftwareDisplay]::new((Join-Path $root 'artifacts\castaggregator-device.dll'))
            Start-Sleep -Seconds 3
            if ($cycle -eq 1) {
                Run-Python @('-m','prototype.display_session','extend',$baseline)
                Run-Python @('-m','prototype.display_session','extend',$baseline,'--layout-file',$candidate,'--display-id','validation')
            } else {
                Run-Python @('-m','prototype.display_session','extend',$baseline,'--layout-file',$saved,'--display-id','validation')
            }
            $active=Join-Path $directory "cycle-$cycle.json"
            Run-Python @('-m','prototype.display_session','snapshot',$active)
            $current=Get-Content $active -Raw | ConvertFrom-Json
            $virtual=@($current.topology | Where-Object { $_.target_path -like '*#MTT1337#*' })
            if ($virtual.Count -ne 1) { throw 'Ambiguous virtual target' }
            $bounds=$current.bounds.PSObject.Properties[$virtual[0].source].Value
            if ($bounds.x -ne $desiredX -or $bounds.y -ne $desiredY) { throw 'Remembered placement mismatch' }
            if ($cycle -eq 1) { Run-Python @('-m','prototype.display_layout',$saved,'--display-id','validation','--target',$virtual[0].target_path) }
        } finally { if ($device) { $device.Dispose(); $device=$null } }
        Start-Sleep -Seconds 3
        Run-Python @('-m','prototype.display_session','restore',$baseline)
        $result.cycles+=@(@{cycle=$cycle;placementVerified=$true;physicalRestored=$true})
    }
} catch { $result.error=$_.Exception.Message }
finally {
    if ($device) { $device.Dispose() }
    try {
        if (Test-Path $baseline) { Start-Sleep -Seconds 3; Run-Python @('-m','prototype.display_session','restore',$baseline) }
    } catch { $result.cleanupErrors+=@($_.Exception.Message) }
    $result | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $directory 'result.json') -Encoding UTF8
    Pop-Location
}
if ($result.error -or $result.cleanupErrors.Count) { exit 1 }
