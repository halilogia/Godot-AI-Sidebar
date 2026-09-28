# Bir sürecin ana penceresinin görüntüsünü alır; pencere başka pencerelerin arkasında olsa da çalışır
# (PrintWindow, PW_RENDERFULLCONTENT). Benchmark editörünü ve oyun penceresini izlemek için.
#
#   powershell -ExecutionPolicy Bypass -File .\tools\capture_window.ps1 -Out C:\tmp\editor.png            (en yeni Godot editörü)
#   powershell -ExecutionPolicy Bypass -File .\tools\capture_window.ps1 -Out C:\tmp\game.png -Title "(DEBUG)"
#
# -Title: pencere başlığında geçen metin (Godot oyun penceresi "(DEBUG)" içerir). Boşsa en yeni Godot süreci.

param(
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Title = "",
    [string]$Process = "Godot*"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32Capture {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
}
"@

$procs = Get-Process -Name $Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
if ($Title) { $procs = $procs | Where-Object { $_.MainWindowTitle -like "*$Title*" } }
$p = $procs | Sort-Object StartTime -Descending | Select-Object -First 1
if (-not $p) { Write-Host "[capture_window] Pencere bulunamadı ($Process $Title)." -ForegroundColor Red; exit 1 }
$h = $p.MainWindowHandle
if ([Win32Capture]::IsIconic($h)) { Write-Host "[capture_window] Pencere simge durumunda (küçültülmüş); içerik çizilmez." -ForegroundColor Yellow }
$r = New-Object Win32Capture+RECT
[void][Win32Capture]::GetWindowRect($h, [ref]$r)
$w = $r.Right - $r.Left; $hgt = $r.Bottom - $r.Top
$bmp = New-Object System.Drawing.Bitmap $w, $hgt
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[void][Win32Capture]::PrintWindow($h, $hdc, 2)
$g.ReleaseHdc($hdc); $g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Host "[capture_window] '$($p.MainWindowTitle)' ${w}x${hgt} -> $Out"
