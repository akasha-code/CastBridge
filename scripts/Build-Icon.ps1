Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent
$frames=@()
foreach ($size in @(16,24,32,48,64,256)) {
 $bitmap=[Drawing.Bitmap]::new($size,$size); $g=[Drawing.Graphics]::FromImage($bitmap)
 $g.SmoothingMode='AntiAlias'; $g.ScaleTransform(($size/256.0),($size/256.0))
 $g.Clear([Drawing.Color]::Transparent)
 $blue=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(26,104,224)); $white=[Drawing.SolidBrush]::new([Drawing.Color]::White)
 $dark=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(15,28,52)); $pen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(70,230,224),14); $pen.StartCap='Round'; $pen.EndCap='Round'
 $g.FillRectangle($blue,12,48,232,156); $g.FillRectangle($dark,28,64,200,124)
 $g.FillRectangle($white,112,204,32,20); $g.FillRectangle($white,70,224,116,14)
 $g.DrawArc($pen,43,102,100,100,270,90); $g.DrawArc($pen,43,138,64,64,270,90); $g.FillEllipse($white,38,174,18,18)
 $stream=[IO.MemoryStream]::new(); $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png); $frames+=,@{Size=$size;Bytes=$stream.ToArray()}
 if ($size -eq 256) { $bitmap.Save((Join-Path $root 'assets\castaggregator.png'),[Drawing.Imaging.ImageFormat]::Png) }
 $stream.Dispose(); $g.Dispose(); $bitmap.Dispose(); $blue.Dispose(); $white.Dispose(); $dark.Dispose(); $pen.Dispose()
}
$output=[IO.MemoryStream]::new(); $writer=[IO.BinaryWriter]::new($output); $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$frames.Count)
$offset=6+16*$frames.Count
foreach ($frame in $frames) { $dimension=if ($frame.Size -eq 256) { 0 } else { $frame.Size }; $writer.Write([byte]$dimension); $writer.Write([byte]$dimension); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([uint16]1); $writer.Write([uint16]32); $writer.Write([uint32]$frame.Bytes.Length); $writer.Write([uint32]$offset); $offset+=$frame.Bytes.Length }
foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Bytes) }
$writer.Flush(); [IO.File]::WriteAllBytes((Join-Path $root 'assets\castaggregator.ico'),$output.ToArray()); $writer.Dispose(); $output.Dispose()
