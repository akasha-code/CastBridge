$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$os = Get-CimInstance Win32_OperatingSystem
$drivers = @(Get-CimInstance Win32_PnPSignedDriver | Where-Object {
    $_.DeviceName -match 'Mtt|Virtual Display|IddSample'
} | Select-Object DeviceName, DriverVersion, IsSigned)
[ordered]@{
    operatingSystem = $os.Caption
    version = $os.Version
    architecture = $os.OSArchitecture
    screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
        @{ device = $_.DeviceName; primary = $_.Primary; x = $_.Bounds.X;
           y = $_.Bounds.Y; width = $_.Bounds.Width; height = $_.Bounds.Height }
    })
    candidateDrivers = $drivers
    driverConfigurationPresent = Test-Path 'C:\VirtualDisplayDriver\vdd_settings.xml'
    tools = @(foreach ($name in @('python', 'ffmpeg', 'dotnet')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        @{ name = $name; available = $null -ne $command }
    })
} | ConvertTo-Json -Depth 5
