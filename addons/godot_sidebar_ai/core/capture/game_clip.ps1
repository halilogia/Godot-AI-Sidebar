# Universal Game Video Clip Tool (Godot AI Sidebar) - eklentinin içindeki asıl kopya
# (tools\game_clip.ps1 bunu çağıran ince bir sarmalayıcıdır; Ayarlar → Devlog kancası da doğrudan bunu çalıştırır).
#
# Herhangi bir Godot projesinin oyun videosunu (devlog / Instagram / YouTube Shorts) çeker: Godot'nun film modu
# (--write-movie) ile AVI yazar, ffmpeg ile H.264 MP4'e çevirir. game_shot.ps1'in video karşılığıdır.
#
#   .\game_clip.ps1 -Project "C:\...\GrandStrategy3D"                       # 1080x1920 dikey, projenin devlog_clip.gd'si
#   .\game_clip.ps1 -Project . -Clip kiyilar -Name devlog_03                # projenin adlı klibi
#   .\game_clip.ps1 -Project . -Resolution 1920x1080 -Seconds 15            # yatay, yedek betik (ana sahne 15 sn)
#
# Sürüm modu: .\game_clip.ps1 -Project . -Release v0.4   # projedeki tools\devlog\clips.json'da "added":"unreleased" olan her klibi
#   çeker, ardından hepsini devlog_v0.4.mp4 olarak birleştirir, devlog_v0.4.md'ye "bu sürümde yeni" listesini yazar ve
#   manifestte o klipleri "added":"v0.4" yapar. -Only koprular,deniz ile yalnız adı geçenler çekilir (deneme). Böylece devlog hep
#   o sürümde eklenen yeni özellikleri gösterir; yeni özellik eklerken manifeste bir klip girdisi eklemek yeter.
#
# Koreografi: projede tools\devlog_clip.gd varsa o çalışır (godot ... --script res://tools/devlog_clip.gd -- <klip adı>);
# yoksa capture_clip.gd ana sahneyi -Seconds saniye çalıştırır. Çıktı varsayılan olarak repo DIŞINA yazılır:
# Desktop\GitHub\Devlog\<proje adı>\<Name>.mp4

param(
    [string]$Project = ".",
    [string]$OutDir = "",
    [string]$Name = "",
    [string]$Resolution = "1080x1920",
    [int]$Fps = 30,
    [double]$Seconds = 10,
    [string]$Clip = "",
    [string]$Release = "",
    [string[]]$Only = @(),
    [string]$ClipScript = "",
    [int]$Crf = 18,
    [switch]$KeepAvi,
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$Only = @($Only | ForEach-Object { $_ -split "," } | Where-Object { $_ })   # -File ile "a,b" tek metin gelir
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

$GodotBin = $GodotPath
if (-not $GodotBin) {
    $cmd = Get-Command godot.exe, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $GodotBin = $cmd.Source }
}
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
# Koreografi seçimi: proje betiği > evrensel yedek
$projScript = if ($ClipScript) { $ClipScript } elseif (Test-Path (Join-Path $projDir "tools\devlog_clip.gd")) { "res://tools/devlog_clip.gd" } else { "" }

# Godot'nun film modu çıktıyı pencere boyutundan değil projenin temel çözünürlüğünden (display/window/size/viewport_*)
# alır; bu yüzden geçici bir override.cfg ile temel çözünürlük istenen boyuta çekilir ve iş bitince geri alınır.
function Record-Clip([string]$clipName, [string]$mp4Path) {
    $aviPath = [System.IO.Path]::ChangeExtension($mp4Path, ".avi")
    if ($projScript) {
        $scriptArg = $projScript
        $userArg = $clipName
        Write-Host "[game_clip] Projenin klip betiği: $projScript $userArg" -ForegroundColor Green
    } else {
        $scriptArg = Join-Path $ScriptDir "capture_clip.gd"
        $userArg = [string][int][math]::Ceiling($Seconds * $Fps)
        Write-Host "[game_clip] Evrensel yedek betik: ana sahne $Seconds sn ($userArg kare)" -ForegroundColor Yellow
    }
    Write-Host "[game_clip] Proje: $projDir | $Resolution @ ${Fps}fps | Hedef: $mp4Path" -ForegroundColor Cyan

    $overrideCfg = Join-Path $projDir "override.cfg"
    $overrideBackup = $null
    if (Test-Path $overrideCfg) {
        $overrideBackup = Get-Content $overrideCfg -Raw
    }
    $overrideText = "[display]`nwindow/size/viewport_width=$vw`nwindow/size/viewport_height=$vh`nwindow/size/window_width_override=$vw`nwindow/size/window_height_override=$vh`n"
    if ($overrideBackup) { $overrideText = $overrideBackup + "`n" + $overrideText }
    [System.IO.File]::WriteAllText($overrideCfg, $overrideText, (New-Object System.Text.UTF8Encoding($false)))

    $logFile = Join-Path $env:TEMP ("godot_clip_" + [System.Guid]::NewGuid().ToString() + ".log")
    $godotArgs = "--path `"$projDir`" --resolution $Resolution --write-movie `"$aviPath`" --fixed-fps $Fps --script `"$scriptArg`""
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
    if (-not (Test-Path $aviPath)) {
        Write-Host "[game_clip] HATA: Godot AVI üretmedi (pencere gerekir; headless çalışmaz)." -ForegroundColor Red
        exit 1
    }
    ffmpeg -y -loglevel error -i $aviPath -c:v libx264 -pix_fmt yuv420p -crf $Crf -preset medium -movflags +faststart -an $mp4Path
    if (-not (Test-Path $mp4Path)) {
        Write-Host "[game_clip] HATA: ffmpeg MP4 üretmedi." -ForegroundColor Red
        exit 1
    }
    if (-not $KeepAvi) { Remove-Item $aviPath -Force -ErrorAction SilentlyContinue }
}

function Show-Result([string]$mp4Path) {
    $info = ffprobe -v error -show_entries "stream=width,height,r_frame_rate:format=duration" -of "default=nw=1" $mp4Path
    $sizeMb = [math]::Round((Get-Item $mp4Path).Length / 1MB, 1)
    Write-Host "`n[game_clip] BASARILI: $mp4Path ($sizeMb MB)" -ForegroundColor Green
    Write-Host ($info -join "  ") -ForegroundColor Gray
}

if (-not $Release) {
    if (-not $Name) { $Name = "clip_" + (Get-Date -Format "yyyyMMdd_HHmmss") }
    $mp4 = Join-Path $OutDir "$Name.mp4"
    Record-Clip $Clip $mp4
    Show-Result $mp4
    exit 0
}

# ---- Sürüm modu --------------------------------------------------------------------------------------------------
$manifestPath = Join-Path $projDir "tools\devlog\clips.json"
if (-not (Test-Path $manifestPath)) {
    Write-Host "[game_clip] HATA: $manifestPath yok. Sürüm modu için projede tools\devlog\clips.json (klip manifesti) gerekir." -ForegroundColor Red
    exit 1
}
$manifest = @(Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json)
if ($manifest.Count -eq 1 -and $manifest[0] -is [System.Array]) { $manifest = @($manifest[0]) }   # Windows PowerShell 5.1 sarar
$todo = @($manifest | Where-Object { $_.added -eq "unreleased" -and ($Only.Count -eq 0 -or $Only -contains $_.id) })
if ($todo.Count -eq 0) {
    Write-Host "[game_clip] Çekilecek yeni klip yok (manifestte 'unreleased' girdi bulunamadi)." -ForegroundColor Yellow
    exit 0
}
$relDir = Join-Path $OutDir $Release
New-Item -ItemType Directory -Force -Path $relDir | Out-Null
$parts = @()
foreach ($entry in $todo) {
    $part = Join-Path $relDir ("{0}.mp4" -f $entry.id)
    Write-Host "[game_clip] Klip: $($entry.id) - $($entry.title)" -ForegroundColor Cyan
    Record-Clip $entry.id $part
    $parts += $part
}
$joined = Join-Path $OutDir ("devlog_{0}.mp4" -f $Release)
$listFile = Join-Path $relDir "list.txt"
($parts | ForEach-Object { "file '" + ($_ -replace "\\", "/") + "'" }) | Set-Content -Path $listFile -Encoding ASCII
ffmpeg -y -loglevel error -f concat -safe 0 -i $listFile -c copy $joined
Show-Result $joined

$md = "# $projName devlog $Release`n`n## Bu sürümde yeni`n"
foreach ($entry in $todo) { $md += "- $($entry.title)`n" }
$md += "`nKlipler: ``$relDir`` (tek tek) ve ``$joined`` (birleşik).`n"
Set-Content -Path (Join-Path $OutDir ("devlog_{0}.md" -f $Release)) -Value $md -Encoding UTF8

if ($Only.Count -eq 0) {   # kısmi (deneme) çekimde manifest değişmez
    foreach ($entry in $todo) { $entry.added = $Release }
    ($manifest | ConvertTo-Json -Depth 8) | Set-Content -Path $manifestPath -Encoding UTF8
    Write-Host "[game_clip] Manifest güncellendi: $($todo.Count) klip '$Release' olarak işaretlendi (commit etmeyi unutma)." -ForegroundColor Green
}
