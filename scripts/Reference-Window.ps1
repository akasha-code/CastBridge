param([int]$X,[int]$Y,[switch]$LatencyClock)
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ReferenceDpi {
 [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window,int command);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
 [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; }
 [DllImport("user32.dll")] public static extern bool GetPhysicalCursorPos(out Point point);
}
'@
$null=[ReferenceDpi]::SetProcessDpiAwarenessContext([IntPtr]::new(-4))
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form=[Windows.Forms.Form]::new()
$form.Text='CastAggregator — referencia sin datos personales'
$form.StartPosition='Manual'
$form.Location=[Drawing.Point]::new(($X+20),($Y+20))
$form.Size=[Drawing.Size]::new(1220,660)
$text=[Windows.Forms.TextBox]::new()
$text.Multiline=$true
$text.ReadOnly=$true
$text.ScrollBars='Vertical'
$text.Dock='Fill'
$text.Font=[Drawing.Font]::new('Segoe UI',28)
$text.Text="Pantalla extendida — prueba de texto y cursor`r`n`r`nContenido sintético sin datos personales.`r`nMové el mouse hacia esta pantalla y desplazá el texto.`r`n`r`nABCDEFGHIJKLMNOPQRSTUVWXYZ`r`n0123456789 — áéíóú ñ`r`n`r`n" + ((1..30 | ForEach-Object { "Línea de referencia $_ — comprobar actualización y legibilidad." }) -join "`r`n")
$form.Controls.Add($text)
$physicalClock=$null
if ($LatencyClock) {
    $tvClock=[Windows.Forms.Label]::new(); $tvClock.Dock='Top'; $tvClock.Height=80
    $tvClock.Font=[Drawing.Font]::new('Consolas',36)
    $form.Controls.Add($tvClock); $tvClock.BringToFront()
    $physicalClock=[Windows.Forms.Form]::new(); $physicalClock.Text='Reloj PC - comparar con TV'
    $physicalClock.Size=[Drawing.Size]::new(500,150); $physicalClock.StartPosition='Manual'
    $primary=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $physicalClock.Location=[Drawing.Point]::new(($primary.Left+30),($primary.Top+30))
    $pcClock=[Windows.Forms.Label]::new(); $pcClock.Dock='Fill'; $pcClock.Font=[Drawing.Font]::new('Consolas',36)
    $physicalClock.Controls.Add($pcClock)
    $physicalClock.Add_FormClosing({ $form.Close() })
    $physicalClock.Show(); $null=[ReferenceDpi]::ShowWindow($physicalClock.Handle,5)
}
$root=Split-Path $PSScriptRoot -Parent
$statePath=Join-Path $root 'artifacts\reference-window-state.json'
$state=[ordered]@{processId=$PID;visible=$false;x=$X+20;y=$Y+20;cursorEnteredVirtual=$false;cursorSamples=0;keyboardObserved=$false;scrollObserved=$false}
$text.Add_KeyDown({
    if (-not $state.keyboardObserved) { [Console]::WriteLine('{"keyboard_observed":true}') }
    $state.keyboardObserved=$true
})
# The console starts hidden; explicitly show the reference window itself.
$null=[ReferenceDpi]::ShowWindow($form.Handle,5)
$null=[ReferenceDpi]::ShowWindow($form.Handle,5)
$state.visible=[ReferenceDpi]::IsWindowVisible($form.Handle)
$state.x=$form.Left; $state.y=$form.Top
$readyPath=Join-Path $root "artifacts\reference-window-ready-$PID.json"
$temporary=$readyPath+'.tmp'
[IO.File]::WriteAllText($temporary,($state | ConvertTo-Json),[Text.UTF8Encoding]::new($true))
[IO.File]::Move($temporary,$readyPath)
$timer=[Windows.Forms.Timer]::new()
$timer.Interval=if ($LatencyClock) { 100 } else { 250 }
$timer.Add_Tick({
    if ($LatencyClock) {
        $stamp=[DateTime]::Now.ToString('HH:mm:ss.f')
        $tvClock.Text=$stamp; $pcClock.Text=$stamp
    }
    if ($text.GetCharIndexFromPosition([Drawing.Point]::new(1,1)) -gt 0) {
        if (-not $state.scrollObserved) { [Console]::WriteLine('{"scroll_observed":true}') }
        $state.scrollObserved=$true
    }
    $point=[ReferenceDpi+Point]::new()
    if ([ReferenceDpi]::GetPhysicalCursorPos([ref]$point)) {
        $state.cursorSamples++
        if ($point.X -ge $X -and $point.X -lt ($X+1280) -and $point.Y -ge $Y -and $point.Y -lt ($Y+720)) {
            if (-not $state.cursorEnteredVirtual) { [Console]::WriteLine('{"cursor_entered_virtual":true}') }
            $state.cursorEnteredVirtual=$true
        }
    }
    $state.visible=[ReferenceDpi]::IsWindowVisible($form.Handle)
    $state.x=$form.Left; $state.y=$form.Top
})
$timer.Start()
try { [Windows.Forms.Application]::Run($form) }
finally {
    $timer.Stop(); $timer.Dispose()
    $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    if ($physicalClock) { $physicalClock.Dispose() }
    $form.Dispose()
}
