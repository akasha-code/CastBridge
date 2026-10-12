Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent
$frames=@()
foreach ($size in @(16,24,32,48,64,256)) {
 $bitmap=[Drawing.Bitmap]::new($size,$size); $g=[Drawing.Graphics]::FromImage($bitmap)
 $g.SmoothingMode='AntiAlias'; $g.ScaleTransform(($size/256.0),($size/256.0))
 $g.Clear([Drawing.Color]::Transparent)
 $blue=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(212,175,55)); $white=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(247,242,228))
 $dark=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(10,20,18)); $pen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(212,175,55),20); $pen.StartCap='Round'; $pen.EndCap='Round'
 $g.FillEllipse($dark,0,0,256,256)
 $g.DrawArc($pen,55,35,146,156,180,180)
 $g.FillRectangle($blue,26,117,84,71); $g.FillRectangle($blue,146,117,84,71)
 $g.FillRectangle($dark,36,127,64,49); $g.FillRectangle($dark,156,127,64,49)
 $g.FillRectangle($white,61,188,14,17); $g.FillRectangle($white,181,188,14,17)
 $g.FillRectangle($white,44,203,48,9); $g.FillRectangle($white,164,203,48,9)
 $stream=[IO.MemoryStream]::new(); $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png); $frames+=,@{Size=$size;Bytes=$stream.ToArray()}
 if ($size -eq 256) { $bitmap.Save((Join-Path $root 'assets\castbridge.png'),[Drawing.Imaging.ImageFormat]::Png) }
 $stream.Dispose(); $g.Dispose(); $bitmap.Dispose(); $blue.Dispose(); $white.Dispose(); $dark.Dispose(); $pen.Dispose()
}
$output=[IO.MemoryStream]::new(); $writer=[IO.BinaryWriter]::new($output); $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$frames.Count)
$offset=6+16*$frames.Count
foreach ($frame in $frames) { $dimension=if ($frame.Size -eq 256) { 0 } else { $frame.Size }; $writer.Write([byte]$dimension); $writer.Write([byte]$dimension); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([uint16]1); $writer.Write([uint16]32); $writer.Write([uint32]$frame.Bytes.Length); $writer.Write([uint32]$offset); $offset+=$frame.Bytes.Length }
foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Bytes) }
$writer.Flush(); [IO.File]::WriteAllBytes((Join-Path $root 'assets\castbridge.ico'),$output.ToArray()); $writer.Dispose(); $output.Dispose()
