param(
    [string]$Output = "assets/app_icon/qingpu_icon_1024.png"
)

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outPath = Join-Path $root $Output
$outDir = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$size = 1024
$bitmap = New-Object System.Drawing.Bitmap $size, $size
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.Clear([System.Drawing.ColorTranslator]::FromHtml("#F7F3EA"))

function New-RoundedRectPath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

$paperBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FFFBF3"))
$linePen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml("#E5DED1")), 18
$brandBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#2F7D76"))
$brandPen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml("#2F7D76")), 26
$accentBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#E36F4C"))
$amberBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#E2A84B"))

$paper = New-RoundedRectPath 154 128 716 768 84
$graphics.FillPath($paperBrush, $paper)
$graphics.DrawPath($linePen, $paper)

foreach ($y in @(304, 394, 484, 574, 664)) {
    $graphics.DrawLine((New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml("#E5DED1")), 10), 248, $y, 776, $y)
}

$brandPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$brandPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.DrawLine($brandPen, 696, 252, 696, 558)
$graphics.DrawBezier($brandPen, 696, 252, 788, 282, 814, 336, 790, 392)
$graphics.FillEllipse($brandBrush, 610, 532, 142, 104)

$numberFont = New-Object System.Drawing.Font "Segoe UI", 470, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$numberFormat = New-Object System.Drawing.StringFormat
$numberFormat.Alignment = [System.Drawing.StringAlignment]::Center
$numberFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
$graphics.DrawString("1", $numberFont, $brandBrush, (New-Object System.Drawing.RectangleF 260, 246, 330, 430), $numberFormat)

$graphics.FillEllipse($accentBrush, 584, 222, 64, 64)
$graphics.FillEllipse($amberBrush, 386, 680, 52, 52)
$graphics.FillRectangle($accentBrush, 278, 722, 266, 24)

$bitmap.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$bitmap.Dispose()
$paperBrush.Dispose()
$linePen.Dispose()
$brandBrush.Dispose()
$brandPen.Dispose()
$accentBrush.Dispose()
$amberBrush.Dispose()
$numberFont.Dispose()
$numberFormat.Dispose()

Write-Host "Generated $outPath"
