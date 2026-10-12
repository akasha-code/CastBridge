param([switch]$SmokeTest,[switch]$ConnectOnStart,[switch]$SelectionSmokeTest,[string]$IntegrationTestDeviceId,[ValidateRange(3,300)][int]$IntegrationHoldSeconds=3)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=[Security.Principal.WindowsPrincipal]::new($identity)
if (-not $SmokeTest -and -not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ($IntegrationTestDeviceId) { throw 'Integration test requires elevated PowerShell.' }
    $launchArguments=@('-NoProfile','-STA','-File',('"'+$PSCommandPath+'"'))
    if ($ConnectOnStart) { $launchArguments+=@('-ConnectOnStart') }
    Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -WindowStyle Hidden -ArgumentList $launchArguments
    exit
}
$mutex=[Threading.Mutex]::new($false,'Local\CastAggregatorTray')
if (-not $mutex.WaitOne(0)) { $mutex.Dispose(); throw 'CastAggregator ya esta abierto.' }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class TrayWindow { [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c); }'
$python=Join-Path $root '.venv\Scripts\python.exe'
$preferences=Join-Path $root 'artifacts\preferences.json'
$script:selected=$null
$script:worker=$null
$script:discovery=$null
$script:session=$null
$script:exitRequested=$false
$script:state='Desconectado'
$tray=[Windows.Forms.NotifyIcon]::new()
$appIcon=[Drawing.Icon]::new((Join-Path $root 'assets\castaggregator.ico'))
$tray.Icon=$appIcon
$tray.Text='CastAggregator: Desconectado'
$menu=[Windows.Forms.ContextMenuStrip]::new()
$statusItem=$menu.Items.Add('Desconectado'); $statusItem.Enabled=$false
$selectItem=$menu.Items.Add('Elegir dispositivo...')
$renameItem=$menu.Items.Add('Nombre de pantalla...')
$latencyItem=$menu.Items.Add('Perfil de latencia')
$stableProfileItem=$latencyItem.DropDownItems.Add('Estable')
$reducedProfileItem=$latencyItem.DropDownItems.Add('Reducido')
$minimumProfileItem=$latencyItem.DropDownItems.Add('Minimo (experimental)')
$connectItem=$menu.Items.Add('Conectar')
$disconnectItem=$menu.Items.Add('Desconectar'); $disconnectItem.Enabled=$false
$syncItem=$menu.Items.Add('Actualizar al vivo'); $syncItem.Enabled=$false
$exitItem=$menu.Items.Add('Salir')
$tray.ContextMenuStrip=$menu
$tray.Visible=$true
$context=[Windows.Forms.ApplicationContext]::new()
function Set-State([string]$value) {
    if ($IntegrationTestDeviceId) { [Console]::WriteLine($value) }
    $script:state=$value
    $statusItem.Text=$value
    $tray.Text='CastAggregator: '+$value
    $connectItem.Enabled=($null -eq $script:worker -and $null -ne $script:selected -and $null -eq $script:discovery)
    $selectItem.Enabled=($null -eq $script:worker -and $null -eq $script:discovery)
    $renameItem.Enabled=($null -eq $script:worker -and $null -ne $script:selected)
    $latencyItem.Enabled=($null -eq $script:worker -and $null -ne $script:selected)
    $disconnectItem.Enabled=($null -ne $script:worker -and $value -ne 'Desconectando')
    $syncItem.Enabled=($null -ne $script:worker -and $value -eq 'Conectado')
}
function Show-Problem([string]$message) {
    Add-Content -LiteralPath (Join-Path $root 'artifacts\tray-errors.log') -Value ((Get-Date -Format o)+' '+$message)
    $tray.ShowBalloonTip(8000,'CastAggregator',$message,[Windows.Forms.ToolTipIcon]::Error)
}
function Set-LatencyProfile([int]$Profile,[bool]$Save=$true) {
    $stableProfileItem.Checked=($Profile -eq 0)
    $reducedProfileItem.Checked=($Profile -eq 1)
    $minimumProfileItem.Checked=($Profile -eq 2)
    $latencyItem.Checked=($Profile -gt 0)
    if ($Save -and $script:selected) {
        $script:selected | Add-Member -NotePropertyName lowLatency -NotePropertyValue ($Profile -gt 0) -Force
        $script:selected | Add-Member -NotePropertyName aggressiveLatency -NotePropertyValue ($Profile -eq 2) -Force
        $script:selected | ConvertTo-Json | Set-Content -LiteralPath $preferences -Encoding UTF8
    }
}
function Request-Stop {
    if ($script:worker) {
        [IO.File]::WriteAllText((Join-Path $script:session 'stop'),'stop')
        Set-State 'Desconectando'
    } elseif ($script:exitRequested) { $context.ExitThread() }
}
if (Test-Path -LiteralPath $preferences) {
    try { $script:selected=Get-Content -LiteralPath $preferences -Raw | ConvertFrom-Json }
    catch { Show-Problem 'No se pudieron leer las preferencias. Elegi nuevamente el dispositivo.' }
}
$initialProfile=if ($script:selected.aggressiveLatency) { 2 } elseif ($script:selected.lowLatency) { 1 } else { 0 }
Set-LatencyProfile $initialProfile $false
$stableProfileItem.Add_Click({ Set-LatencyProfile 0 })
$reducedProfileItem.Add_Click({ Set-LatencyProfile 1 })
$minimumProfileItem.Add_Click({ Set-LatencyProfile 2 })
if ($IntegrationTestDeviceId) {
    $script:selected=[pscustomobject]@{id=$IntegrationTestDeviceId;name='Integration test';model='Chromecast'}
    $script:testDeadline=[DateTime]::UtcNow.AddSeconds($IntegrationHoldSeconds+90)
    $script:testConnectedAt=$null
}
$selectItem.Add_Click({
    try {
        $script:discoveryDirectory=Join-Path $root ('artifacts\discovery-'+[Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:discoveryDirectory | Out-Null
        $script:discovery=Start-Process -FilePath $python -WorkingDirectory $root -WindowStyle Hidden -ArgumentList @('-m','prototype.discover','--selectable') -RedirectStandardOutput (Join-Path $script:discoveryDirectory 'devices.json') -RedirectStandardError (Join-Path $script:discoveryDirectory 'error.log') -PassThru
        $null=$script:discovery.Handle
        Set-State 'Buscando dispositivos'
    } catch { Show-Problem $_.Exception.Message; Set-State 'Error' }
})
$renameItem.Add_Click({
    $dialog=[Windows.Forms.Form]::new(); $dialog.Text='Nombre de pantalla'; $dialog.Size=[Drawing.Size]::new(460,160); $dialog.StartPosition='CenterScreen'; $dialog.TopMost=$true
    $inputBox=[Windows.Forms.TextBox]::new(); $inputBox.Location=[Drawing.Point]::new(15,15); $inputBox.Width=410; $inputBox.MaxLength=80
    $inputBox.Text=if ($script:selected.displayName) { $script:selected.displayName } else { $script:selected.name }
    $button=[Windows.Forms.Button]::new(); $button.Text='Guardar'; $button.Location=[Drawing.Point]::new(320,55); $button.DialogResult='OK'
    $dialog.Controls.Add($inputBox); $dialog.Controls.Add($button); $dialog.AcceptButton=$button
    $dialog.Add_Shown({ param($sender,$eventArgs) [void][TrayWindow]::ShowWindow($sender.Handle,5); $sender.Activate() })
    if ($dialog.ShowDialog() -eq 'OK' -and $inputBox.Text.Trim()) {
        $script:selected | Add-Member -NotePropertyName displayName -NotePropertyValue ($inputBox.Text.Trim().Replace('"',"'")) -Force
        $script:selected | ConvertTo-Json | Set-Content -LiteralPath $preferences -Encoding UTF8
    }
    $dialog.Dispose()
})
$connectItem.Add_Click({
    try {
        if ($script:worker -or -not $script:selected) { return }
        foreach ($required in @($python,(Join-Path $root 'artifacts\castaggregator-device.dll'),'C:\VirtualDisplayDriver\vdd_settings.xml')) {
            if (-not (Test-Path -LiteralPath $required)) { throw 'Falta Python, helper o driver configurado. Consulta README.' }
        }
        $parsedId=[Guid]::Empty
        if (-not [Guid]::TryParse([string]$script:selected.id,[ref]$parsedId)) { throw 'Seleccion de dispositivo invalida.' }
        $script:session=Join-Path $root ('artifacts\session-'+[Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:session | Out-Null
        $workerScript=Join-Path $PSScriptRoot 'Test-MonitorCast.ps1'
        $displayName=if ($script:selected.displayName) { $script:selected.displayName } else { $script:selected.name }
        $displayName=([string]$displayName).Replace('"',"'")
        $latencyArgument=if ($latencyItem.Checked) { '-LowLatency' } else { '' }
        $aggressiveArgument=if ($minimumProfileItem.Checked) { '-AggressiveLatency' } else { '' }
        $script:worker=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -ArgumentList @('-NoProfile','-File',('"'+$workerScript+'"'),'-NoReference',$latencyArgument,$aggressiveArgument,'-Seconds','86400','-DeviceId',$parsedId.ToString(),'-DisplayName',('"'+$displayName+'"'),'-SessionDirectory',('"'+$script:session+'"'),'-SyncFile',('"'+(Join-Path $script:session 'sync')+'"'),'-StopFile',('"'+(Join-Path $script:session 'stop')+'"')) -RedirectStandardError (Join-Path $script:session 'worker-error.log') -PassThru
        $null=$script:worker.Handle
        Set-State 'Conectando'
    } catch { Show-Problem $_.Exception.Message; Set-State 'Error' }
})
$disconnectItem.Add_Click({ Request-Stop })
$syncItem.Add_Click({ [IO.File]::WriteAllText((Join-Path $script:session 'sync'),'sync') })
$exitItem.Add_Click({ $script:exitRequested=$true; Request-Stop })
$timer=[Windows.Forms.Timer]::new(); $timer.Interval=500
$timer.Add_Tick({
    try {
        if ($IntegrationTestDeviceId -and $script:worker) {
            if ($script:state -eq 'Conectado') {
                if (-not $script:testConnectedAt) { $script:testConnectedAt=[DateTime]::UtcNow }
                if ([DateTime]::UtcNow -gt $script:testConnectedAt.AddSeconds($IntegrationHoldSeconds)) {
                    $script:exitRequested=$true; $disconnectItem.PerformClick()
                }
            } elseif ([DateTime]::UtcNow -gt $script:testDeadline -and $script:state -ne 'Desconectando') {
                $script:exitRequested=$true; Request-Stop
            }
        }
        if ($script:discovery -and $script:discovery.HasExited) {
            $code=$script:discovery.ExitCode; $script:discovery.Dispose(); $script:discovery=$null
            if ($null -ne $code -and $code -ne 0) { throw 'No se pudo descubrir dispositivos. Revisa el log de discovery.' }
            $devices=@((Get-Content -LiteralPath (Join-Path $script:discoveryDirectory 'devices.json') -Raw | ConvertFrom-Json).devices)
            if (-not $devices.Count) { throw 'No se encontraron receptores Cast.' }
            $dialog=[Windows.Forms.Form]::new(); $dialog.Text='Elegir Chromecast'; $dialog.Size=[Drawing.Size]::new(460,200); $dialog.StartPosition='CenterScreen'
            $dialog.TopMost=$true
            $list=[Windows.Forms.ComboBox]::new(); $list.DropDownStyle='DropDownList'; $list.Location=[Drawing.Point]::new(15,20); $list.Width=410
            foreach ($entry in $devices) { [void]$list.Items.Add(([string]$entry.name+' ('+$entry.model+')')) }
            $list.SelectedIndex=0
            $button=[Windows.Forms.Button]::new(); $button.Text='Guardar'; $button.Location=[Drawing.Point]::new(320,80); $button.DialogResult='OK'
            $dialog.Controls.Add($list); $dialog.Controls.Add($button); $dialog.AcceptButton=$button
            $dialog.Add_Shown({ param($sender,$eventArgs) [void][TrayWindow]::ShowWindow($sender.Handle,5); $sender.Activate() })
            if ($SelectionSmokeTest) {
                $script:validationDialog=$dialog
                $script:validationTimer=[Windows.Forms.Timer]::new(); $script:validationTimer.Interval=1000
                $script:validationTimer.Add_Tick({
                    [Console]::WriteLine('selection_dialog_visible='+$script:validationDialog.Visible)
                    [IO.File]::WriteAllText((Join-Path $root 'artifacts\selection-validation-result.json'),('{"dialogVisible":'+$script:validationDialog.Visible.ToString().ToLowerInvariant()+'}'))
                    $script:validationTimer.Stop(); $script:validationDialog.DialogResult='Cancel'
                })
                $script:validationTimer.Start()
            }
            if ($dialog.ShowDialog() -eq 'OK') {
                $entry=$devices[$list.SelectedIndex]
                $screenName=if ($script:selected.displayName) { $script:selected.displayName } else { $entry.name }
                $script:selected=[pscustomobject]@{id=$entry.id;name=$entry.name;model=$entry.model;displayName=$screenName;lowLatency=$latencyItem.Checked;aggressiveLatency=$minimumProfileItem.Checked}
                $script:selected | ConvertTo-Json | Set-Content -LiteralPath $preferences -Encoding UTF8
            }
            $dialog.Dispose(); Set-State 'Desconectado'
            if ($SelectionSmokeTest) { $script:validationTimer.Dispose(); $context.ExitThread() }
        }
        if ($script:worker) {
            if ($script:worker.HasExited) {
                $code=$script:worker.ExitCode; $script:worker.Dispose(); $script:worker=$null
                $resultFile=Join-Path $script:session 'monitor-cast-result.json'
                if (-not (Test-Path -LiteralPath $resultFile)) { throw 'El coordinador termino sin confirmar limpieza. Revisa la carpeta session.' }
                $result=Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
                if ($code -ne 0 -or $result.error -or $result.cleanupErrors.Count -or -not $result.physicalRestored) {
                    throw ('La sesion fallo. Revisa los logs de session. '+$result.error)
                }
                Set-State 'Desconectado'
                if ($script:exitRequested) { $context.ExitThread() }
            } elseif ($script:state -eq 'Conectando') {
                $log=Join-Path $script:session 'monitor-cast.log'
                if (Test-Path -LiteralPath $log) {
                    if (Select-String -LiteralPath $log -Pattern '"receiver_confirmed": "PLAYING"' -Quiet) { Set-State 'Conectado' }
                }
            }
        }
    } catch {
        Set-State 'Error'; Show-Problem $_.Exception.Message
        if ($IntegrationTestDeviceId -and -not $script:worker) { $context.ExitThread() }
        if ($SelectionSmokeTest) { $context.ExitThread() }
        if ($script:exitRequested -and -not $script:worker) { $script:exitRequested=$false }
    }
})
Set-State 'Desconectado'
$timer.Start()
try {
    if ($SmokeTest) { 'Tray UI initialized; no discovery or capture started' }
    else {
        if ($IntegrationTestDeviceId -or $ConnectOnStart) { $connectItem.PerformClick() }
        if ($SelectionSmokeTest) { $selectItem.PerformClick() }
        [Windows.Forms.Application]::Run($context)
    }
} finally {
    $timer.Stop(); $timer.Dispose()
    $tray.Visible=$false; $tray.Dispose(); $appIcon.Dispose(); $menu.Dispose(); $context.Dispose()
    $mutex.ReleaseMutex(); $mutex.Dispose()
}
