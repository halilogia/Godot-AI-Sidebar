# Universal Game Video Clip Tool (Godot AI Sidebar)
#
# Herhangi bir Godot projesinin oyun videosunu (devlog / Instagram / YouTube Shorts) çeker: Godot'nun film modu
# (--write-movie) ile AVI yazar, ffmpeg ile H.264 MP4'e çevirir. game_shot.ps1'in video karşılığıdır.
#
#   .\game_clip.ps1 -Project "C:\...\GrandStrategy3D"                       # 1080x1920 dikey, projenin devlog_clip.gd'si
#   .\game_clip.ps1 -Project . -Clip kiyilar -Name devlog_03                # projenin adlı klibi
#   .\game_clip.ps1 -Project . -Resolution 1920x1080 -Seconds 15            # yatay, yedek betik (ana sahne 15 sn)
#
# Koreografi: projede tools\devlog_clip.gd varsa o çalışır (godot ... --script res://tools/devlog_clip.gd -- <klip adı>);
# yoksa tools\game_clip.gd ana sahneyi -Seconds saniye çalıştırır. Çıktı varsayılan olarak repo DIŞINA yazılır:
# Desktop\GitHub\Devlog\<proje adı>\<Name>.mp4

param(
    [string]$Project = ".",
    [string]$OutDir = "",
    [string]$Name = "",
    [string]$Resolution = "1080x1920",
    [int]$Fps = 30,
    [double]$Seconds = 10,
    [string]$Clip = "",
    [string]$ClipScript = "",
    [int]$Crf = 18,
    [switch]$KeepAvi,
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

$projPath = Resolve-Path $Project -ErrorAction SilentlyContinue
if (-not $projPath -or -not (Test-Path (Join-Path $projPath.Path "project.godot"))) {
    Write-Host "[game_clip] HATA: Belirtilen dizinde project.godot bulunamadi: $Project" -ForegroundColor Red
    exit 1
}
$projDir = $projPath.Path
$projName = Split-Path $projDir -Leaf

if ($Resolution -notmatch '^(\d+)x(\d+)$') {
    Write-Host "[game_clip] HATA: -Resolution 1080x1920 biçiminde olmalı: $Resolution" -ForegroundColor Red
    exit 1
}
$vw = [int]$matches[1]
$vh = [int]$matches[2]

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "[game_clip] HATA: ffmpeg PATH'te yok (winget install Gyan.FFmpeg)." -ForegroundColor Red
    exit 1
}

. (Join-Path $ScriptDir "find_godot.ps1")
$GodotBin = Resolve-GodotBin $GodotPath
if (-not $GodotBin) {
    Write-Host "[game_clip] HATA: Godot binary bulunamadi." -ForegroundColor Red
    exit 1
}

if (-not $OutDir) {
    $githubRoot = Split-Path (Split-Path $projDir -Parent) -Parent   # ...\GitHub\Public\<proje> -> ...\GitHub
    $OutDir = Join-Path (Join-Path $githubRoot "Devlog") $projName
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
if (-not $Name) {
    $Name = "clip_" + (Get-Date -Format "yyyyMMdd_HHmmss")
}
$avi = Join-Path $OutDir "$Name.avi"
$mp4 = Join-Path $OutDir "$Name.mp4"

# Koreografi seçimi: proje betiği > evrensel yedek
$projScript = if ($ClipScript) { $ClipScript } elseif (Test-Path (Join-Path $projDir "tools\devlog_clip.gd")) { "res://tools/devlog_clip.gd" } else { "" }
if ($projScript) {
    $scriptArg = $projScript
    $userArg = if ($Clip) { $Clip } else { "" }
    Write-Host "[game_clip] Projenin klip betiği: $projScript $userArg" -ForegroundColor Green
} else {
    $scriptArg = Join-Path $ScriptDir "game_clip.gd"
    $userArg = [string][int][math]::Ceiling($Seconds * $Fps)
    Write-Host "[game_clip] Evrensel yedek betik: ana sahne $Seconds sn ($userArg kare)" -ForegroundColor Yellow
}

Write-Host "[game_clip] Proje: $projDir | $Resolution @ ${Fps}fps | Hedef: $mp4" -ForegroundColor Cyan

# Godot'nun film modu çıktıyı pencere boyutundan değil projenin temel çözünürlüğünden (display/window/size/viewport_*)
# alır; bu yüzden geçici bir override.cfg ile temel çözünürlük istenen boyuta çekilir ve iş bitince geri alınır.
$overrideCfg = Join-Path $projDir "override.cfg"
$overrideBackup = $null
if (Test-Path $overrideCfg) {
    $overrideBackup = Get-Content $overrideCfg -Raw
}
$overrideText = "[display]`nwindow/size/viewport_width=$vw`nwindow/size/viewport_height=$vh`nwindow/size/window_width_override=$vw`nwindow/size/window_height_override=$vh`n"
if ($overrideBackup) { $overrideText = $overrideBackup + "`n" + $overrideText }
[System.IO.File]::WriteAllText($overrideCfg, $overrideText, (New-Object System.Text.UTF8Encoding($false)))

$logFile = Join-Path $env:TEMP ("godot_clip_" + [System.Guid]::NewGuid().ToString() + ".log")
$godotArgs = "--path `"$projDir`" --resolution $Resolution --write-movie `"$avi`" --fixed-fps $Fps --script `"$scriptArg`""
if ($userArg) { $godotArgs += " -- $userArg" }
try {
    cmd.exe /c "`"$GodotBin`" $godotArgs > `"$logFile`" 2>&1"
} finally {
    if ($overrideBackup) {
        [System.IO.File]::WriteAllText($overrideCfg, $overrideBackup, (New-Object System.Text.UTF8Encoding($false)))
    } else {
        Remove-Item $overrideCfg -Force -ErrorAction SilentlyContinue
    }
}

if (Test-Path $logFile) {
    $log = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
    if ($log -match "SCRIPT ERROR|Parse Error") { Write-Host $log -ForegroundColor Red }
    Remove-Item $logFile -Force -ErrorAction SilentlyContinue
}
if (-not (Test-Path $avi)) {
    Write-Host "[game_clip] HATA: Godot AVI üretmedi (pencere gerekir; headless çalışmaz)." -ForegroundColor Red
    exit 1
}

ffmpeg -y -loglevel error -i $avi -c:v libx264 -pix_fmt yuv420p -crf $Crf -preset medium -movflags +faststart -an $mp4
if (-not (Test-Path $mp4)) {
    Write-Host "[game_clip] HATA: ffmpeg MP4 üretmedi." -ForegroundColor Red
    exit 1
}
if (-not $KeepAvi) { Remove-Item $avi -Force -ErrorAction SilentlyContinue }

$info = ffprobe -v error -show_entries "stream=width,height,r_frame_rate:format=duration" -of "default=nw=1" $mp4
$sizeMb = [math]::Round((Get-Item $mp4).Length / 1MB, 1)
Write-Host "`n[game_clip] BASARILI: $mp4 ($sizeMb MB)" -ForegroundColor Green
Write-Host ($info -join "  ") -ForegroundColor Gray
