# Universal Game Screenshot & Visual Inspection Tool (Godot AI Sidebar)
#
# Otomatik oyun ekrani alma araci. Hem Godot icinden (Viewport render) hem de calisan
# oyundan (PrintWindow) yuksek cozunurluklu ekran goruntusu alir.
# Tum Godot projelerinde (GrandStrategy3D, The Hammer vb.) ortaklasa kullanilabilir.

param(
    [string]$Project = ".",
    [string]$OutDir = "",
    [string]$Resolution = "1280x720",
    [double]$WaitSec = 2.5,
    [string]$Views = "",
    [switch]$Running,
    [string]$Out = "",
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $ScriptDir

# 1. Calisan pencereden anlik cekim isteniyorsa
if ($Running) {
    if (-not $Out) {
        $Out = "running_game.png"
    }
    $captureScript = Join-Path $ScriptDir "capture_window.ps1"
    if (Test-Path $captureScript) {
        & powershell -ExecutionPolicy Bypass -File $captureScript -Out $Out -Title "(DEBUG)"
        Write-Host "[game_shot] Calisan oyun penceresi kaydedildi: $Out" -ForegroundColor Green
        exit 0
    }
}

# 2. Proje dizinini cozumle
$projPath = Resolve-Path $Project -ErrorAction SilentlyContinue
if (-not $projPath -or -not (Test-Path (Join-Path $projPath.Path "project.godot"))) {
    Write-Host "[game_shot] HATA: Belirtilen dizinde project.godot bulunamadi: $Project" -ForegroundColor Red
    exit 1
}
$projDir = $projPath.Path

# 3. Cikti klasorunu belirle
if (-not $OutDir) {
    $OutDir = Join-Path $projDir "screenshots"
}
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}
$resolvedOutDir = (Resolve-Path $OutDir).Path

# 4. Godot binary'sini bul
. (Join-Path $ScriptDir "find_godot.ps1")
$GodotBin = Resolve-GodotBin $GodotPath
if (-not $GodotBin) {
    Write-Host "[game_shot] HATA: Godot binary bulunamadi." -ForegroundColor Red
    exit 1
}

# Cozunurluk parse
$w = 1280
$h = 720
if ($Resolution -match '^(\d+)x(\d+)$') {
    $w = [int]$matches[1]
    $h = [int]$matches[2]
}

Write-Host "[game_shot] Proje: $projDir" -ForegroundColor Cyan
Write-Host "[game_shot] Cozunurluk: ${w}x${h} | Hedef: $resolvedOutDir" -ForegroundColor Cyan

# 5. Projede ozel capture.gd var mi kontrol et
$projCapture = Join-Path $projDir "tools\capture.gd"

$logFile = Join-Path $env:TEMP ("godot_shot_" + [System.Guid]::NewGuid().ToString() + ".log")

if (Test-Path $projCapture) {
    Write-Host "[game_shot] Projeye ozel senaryolu capture bulundu: res://tools/capture.gd" -ForegroundColor Green
    $cmd = "`"$GodotBin`" --path `"$projDir`" --resolution ${w}x${h} --script res://tools/capture.gd -- `"$resolvedOutDir`" $Views"
    cmd.exe /c "$cmd > `"$logFile`" 2>&1"
} else {
    Write-Host "[game_shot] Standart viewport cekimi calistiriliyor (game_shot.gd)..." -ForegroundColor Yellow
    $universalShotGd = Join-Path $ScriptDir "game_shot.gd"
    $targetPng = Join-Path $resolvedOutDir "main_shot.png"
    $cmd = "`"$GodotBin`" --path `"$projDir`" --resolution ${w}x${h} -s `"$universalShotGd`" -- `"$targetPng`" $WaitSec $w $h"
    cmd.exe /c "$cmd > `"$logFile`" 2>&1"
}

if (Test-Path $logFile) {
    $logContent = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
    if ($logContent) {
        Write-Host $logContent -ForegroundColor Gray
    }
    Remove-Item $logFile -Force -ErrorAction SilentlyContinue
}

# 6. Alinan ekran goruntulerini topla ve gallery.md uret
$pngs = Get-ChildItem -Path $resolvedOutDir -Filter "*.png" | Sort-Object LastWriteTime -Descending
if ($pngs.Count -gt 0) {
    Write-Host "`n[game_shot] BASARILI! $($pngs.Count) adet ekran goruntusu alindi:" -ForegroundColor Green
    $galleryMd = "# Oyun Ekran Goruntuleri Galerisi`n`n"
    $galleryMd += "**Proje:** $projDir  `n"
    $galleryMd += "**Tarih:** " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "  `n`n---`n`n"

    foreach ($png in $pngs) {
        $uri = "file:///" + ($png.FullName -replace '\\', '/')
        Write-Host "  - $($png.Name): $uri" -ForegroundColor Cyan
        $galleryMd += "### " + $png.BaseName + "`n`n![" + $png.BaseName + "](" + $uri + ")`n`n"
    }

    $galleryPath = Join-Path $resolvedOutDir "gallery.md"
    [System.IO.File]::WriteAllText($galleryPath, $galleryMd, [System.Text.Encoding]::UTF8)
    Write-Host "[game_shot] Galeri Markdown Raporu: $galleryPath" -ForegroundColor Green
} else {
    Write-Host "[game_shot] UYARI: Hicbir PNG ciktisi uretilmedi." -ForegroundColor Yellow
}
