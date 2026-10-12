$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form=[Windows.Forms.Form]::new()
$form.Text='Instalar CastAggregator'; $form.Size=[Drawing.Size]::new(820,540); $form.StartPosition='CenterScreen'
$list=[Windows.Forms.ListView]::new(); $list.View='Details'; $list.FullRowSelect=$true; $list.MultiSelect=$false
$list.Location=[Drawing.Point]::new(15,15); $list.Size=[Drawing.Size]::new(770,210)
[void]$list.Columns.Add('Requisito',640); [void]$list.Columns.Add('Estado',100)
$help=[Windows.Forms.TextBox]::new(); $help.Multiline=$true; $help.ReadOnly=$true; $help.ScrollBars='Vertical'
$help.Location=[Drawing.Point]::new(15,235); $help.Size=[Drawing.Size]::new(770,140)
$refresh=[Windows.Forms.Button]::new(); $refresh.Text='Comprobar'; $refresh.Location=[Drawing.Point]::new(15,390); $refresh.Width=120
$download=[Windows.Forms.Button]::new(); $download.Text='Abrir descarga'; $download.Location=[Drawing.Point]::new(150,390); $download.Width=150
$guide=[Windows.Forms.Button]::new(); $guide.Text='Ver instrucciones'; $guide.Location=[Drawing.Point]::new(315,390); $guide.Width=150
$install=[Windows.Forms.Button]::new(); $install.Text='Instalar'; $install.Location=[Drawing.Point]::new(635,390); $install.Width=150; $install.Enabled=$false
$status=[Windows.Forms.Label]::new(); $status.Location=[Drawing.Point]::new(15,445); $status.Size=[Drawing.Size]::new(770,40)
$form.Controls.AddRange(@($list,$help,$refresh,$download,$guide,$install,$status))
$list.Add_SelectedIndexChanged({
    if ($list.SelectedItems.Count) { $help.Text=$list.SelectedItems[0].Tag.Help; $download.Enabled=[bool]$list.SelectedItems[0].Tag.Url }
})
$refresh.Add_Click({
    $install.Enabled=$false; $list.Items.Clear(); $status.Text='Comprobando requisitos...'; $form.Refresh()
    try {
        $result=& (Join-Path $PSScriptRoot 'Test-Prerequisites.ps1')
        foreach ($check in $result.Checks) {
            $item=[Windows.Forms.ListViewItem]::new($check.Name); $item.Tag=$check
            [void]$item.SubItems.Add($(if ($check.Ready) {'OK'} else {'Falta'})); [void]$list.Items.Add($item)
        }
        $install.Enabled=$result.Ready
        $status.Text=if ($result.Ready) {'Listo. Instalar descarga dependencias Python y crea el atajo en esta carpeta.'} else {'Instalacion bloqueada. Selecciona un requisito para ver como resolverlo; despues comproba otra vez.'}
    } catch { $status.Text='No se pudo comprobar: '+$_.Exception.Message }
})
$download.Add_Click({if ($list.SelectedItems.Count -and $list.SelectedItems[0].Tag.Url) { Start-Process $list.SelectedItems[0].Tag.Url }})
$guide.Add_Click({Start-Process notepad.exe -ArgumentList ('"'+(Join-Path (Split-Path $PSScriptRoot -Parent) 'INSTALL.md')+'"')})
$install.Add_Click({
    $install.Enabled=$false; $refresh.Enabled=$false; $status.Text='Instalando; mira la consola para seguir el progreso.'; $form.Refresh()
    try { & (Join-Path $PSScriptRoot 'Setup-Local.ps1'); $status.Text='Instalacion completada. Abri CastAggregator.lnk en la carpeta extraida.' }
    catch { $status.Text='Instalacion no completada: '+$_.Exception.Message }
    finally { $refresh.Enabled=$true }
})
$form.Add_Shown({$refresh.PerformClick()})
try { [void]$form.ShowDialog() } finally { $form.Dispose() }
