# Turns the chosen ComfyUI logo (light background) into icon.png + icon.ico:
# flood-fills the light background from the edges to transparent, crops, pads to a square.
param([string]$SrcPath, [string]$OutDir)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Collections.Generic;
public static class Cutout {
    public static Bitmap Run(Bitmap src) {
        int w = src.Width, h = src.Height;
        var bmp = src.Clone(new Rectangle(0, 0, w, h), PixelFormat.Format32bppArgb);
        var d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        var px = new byte[w * h * 4];
        System.Runtime.InteropServices.Marshal.Copy(d.Scan0, px, 0, px.Length);
        var seen = new bool[w * h]; var q = new Queue<int>();
        Func<int, int> light = i => Math.Min(px[i*4], Math.Min(px[i*4+1], px[i*4+2]));
        for (int x = 0; x < w; x++) { q.Enqueue(x); q.Enqueue((h-1)*w + x); }
        for (int y = 0; y < h; y++) { q.Enqueue(y*w); q.Enqueue(y*w + w-1); }
        while (q.Count > 0) {
            int i = q.Dequeue();
            if (seen[i]) continue; seen[i] = true;
            int l = light(i);
            if (l < 150) continue;
            // fully light = background; the light part of the anti-aliased rim fades out
            int a = l >= 215 ? 0 : (215 - l) * 255 / 65;
            px[i*4+3] = (byte)Math.Min(px[i*4+3], a);
            if (l < 215) { px[i*4] = (byte)(px[i*4] * 0.4); px[i*4+1] = (byte)(px[i*4+1] * 0.4); px[i*4+2] = (byte)(px[i*4+2] * 0.4); continue; }
            int x0 = i % w, y0 = i / w;
            if (x0 > 0) q.Enqueue(i-1); if (x0 < w-1) q.Enqueue(i+1);
            if (y0 > 0) q.Enqueue(i-w); if (y0 < h-1) q.Enqueue(i+w);
        }
        System.Runtime.InteropServices.Marshal.Copy(px, 0, d.Scan0, px.Length);
        bmp.UnlockBits(d);
        return bmp;
    }
}
"@
$orig = [System.Drawing.Bitmap]::FromFile($SrcPath)
$cut = [Cutout]::Run($orig); $orig.Dispose()
$minX = $cut.Width; $minY = $cut.Height; $maxX = 0; $maxY = 0
for ($y = 0; $y -lt $cut.Height; $y += 2) { for ($x = 0; $x -lt $cut.Width; $x += 2) {
    if ($cut.GetPixel($x, $y).A -gt 40) {
        if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y } } } }
$bw0 = $maxX - $minX; $bh0 = $maxY - $minY

function Render([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.SmoothingMode = 'AntiAlias'
    $fill = if ($size -le 32) { 1.0 } else { 0.96 }
    $sc = [Math]::Min($size * $fill / $bw0, $size * $fill / $bh0)
    $ow = $bw0 * $sc; $oh = $bh0 * $sc
    $g.DrawImage($cut, (New-Object System.Drawing.RectangleF (($size - $ow) / 2), (($size - $oh) / 2), $ow, $oh), (New-Object System.Drawing.RectangleF $minX, $minY, $bw0, $bh0), 'Pixel')
    $g.Dispose()
    return $bmp
}
$pngs = @()
foreach ($s in 16, 24, 32, 48, 64, 128, 256) {
    $b = Render $s; $f = Join-Path $OutDir "logo_icon_$s.png"; $b.Save($f, [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
    $pngs += , @($s, $f)
}
$b = Render 1024; $b.Save((Join-Path $OutDir "logo_icon_1024.png"), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
$cut.Dispose()

# ICO with PNG-compressed entries (Vista+)
$ms = New-Object System.IO.MemoryStream; $bw = New-Object System.IO.BinaryWriter $ms
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$pngs.Count)
$data = $pngs | ForEach-Object { , [System.IO.File]::ReadAllBytes($_[1]) }
$off = 6 + 16 * $pngs.Count
for ($i = 0; $i -lt $pngs.Count; $i++) {
    $s = $pngs[$i][0]; $d = $data[$i]
    $bw.Write([byte]($s % 256)); $bw.Write([byte]($s % 256)); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([UInt16]1); $bw.Write([UInt16]32); $bw.Write([UInt32]$d.Length); $bw.Write([UInt32]$off)
    $off += $d.Length
}
foreach ($d in $data) { $bw.Write($d) }
[System.IO.File]::WriteAllBytes((Join-Path $OutDir "logo_icon.ico"), $ms.ToArray())
"ok"
