# Oyun arayuzu icin once / sonra karsilastirma tablosu (tek PNG).
#
# 1. "Once" projesi kurulur: projenin gecici kopyasi + secilen kaynak
#      -BeforeRef <git ref>   kopyadaki izlenen dosyalar o ref'e cevrilir (asil reponun index'ine dokunmaz)
#      -AgySince <ISO zaman>  Antigravity'nin o zamandan sonraki duzenlemeleri kopyada geri alinir (agy_revert.ps1)
#      -BeforeDir <klasor>    hazir bir "once" projesi (kopyalanmaz)
# 2. Ayni senaryo (tools/ui_states.gd) iki projede de calistirilir; ekranlar ayni anda, ayni durumda cekilir.
# 3. tools/ui_compare.gd degisen bolgeleri kirmizi cerceveyle isaretler.
# 4. Satir basliklari senaryonun titles.json'undan alinir; ONCE / SONRA basliklari ve dipnotla tek PNG yazilir.
#
#   powershell -File tools\ui_before_after.ps1 -Project <proje> -Scenario res://tools/capture/ui_states.gd -AgySince 2026-11-26T17:19
#
# Cikti varsayilani: <proje>\screenshots\ui_before_after.png. Cerceveler yalniz bu gorseldedir, oyunda yoktur.

param(
    [Parameter(Mandatory = $true)][string]$Project,
    [Parameter(Mandatory = $true)][string]$Scenario,
    [string]$BeforeRef = "",
    [string]$AgySince = "",
    [string]$BeforeDir = "",
    [string]$Out = "",
    [string]$Resolution = "640x400",
    [int]$TimeoutSec = 240,
    [string]$GodotPath = "",
    [switch]$Keep
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$SidebarRoot = Split-Path -Parent $ScriptDir
$proj = (Resolve-Path $Project).Path
if (-not (Test-Path (Join-Path $proj "project.godot"))) { Write-Host "[ui_before_after] HATA: project.godot yok: $proj" -ForegroundColor Red; exit 1 }
if (@($BeforeRef, $AgySince, $BeforeDir | Where-Object { $_ }).Count -ne 1) {
    Write-Host "[ui_before_after] HATA: -BeforeRef, -AgySince ya da -BeforeDir'den tam biri verilmeli." -ForegroundColor Red; exit 1
}
if (-not $Out) { $Out = Join-Path $proj "screenshots\ui_before_after.png" }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null

. (Join-Path $ScriptDir "find_godot.ps1")
$GodotBin = Resolve-GodotBin $GodotPath
if (-not $GodotBin) { Write-Host "[ui_before_after] HATA: Godot bulunamadi." -ForegroundColor Red; exit 1 }

$work = Join-Path $env:TEMP ("ui_before_after_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
Write-Host "[ui_before_after] Calisma klasoru: $work" -ForegroundColor Cyan

# --- 1. "Once" projesi -------------------------------------------------------------------------
if ($BeforeDir) {
    $before = (Resolve-Path $BeforeDir).Path
} else {
    $before = Join-Path $work (Split-Path -Leaf $proj)
    & robocopy $proj $before /E /XD .git screenshots /MT:16 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Write-Host "[ui_before_after] HATA: kopyalama basarisiz ($LASTEXITCODE)." -ForegroundColor Red; exit 1 }
    if ($BeforeRef) {
        # Gecici index: asil reponun index'i ve calisma agaci degismez.
        $env:GIT_INDEX_FILE = Join-Path $work "before.index"
        & git -C $proj read-tree $BeforeRef
        if ($LASTEXITCODE -ne 0) { Remove-Item Env:GIT_INDEX_FILE; Write-Host "[ui_before_after] HATA: ref okunamadi: $BeforeRef" -ForegroundColor Red; exit 1 }
        & git -C $proj --work-tree=$before checkout-index -a -f
        Remove-Item Env:GIT_INDEX_FILE
        # Ref'ten sonra eklenmis izlenen dosyalar kopyadan silinir.
        foreach ($rel in (& git -C $proj diff --name-only --diff-filter=A $BeforeRef)) {
            $fp = Join-Path $before $rel
            if (Test-Path $fp) { Remove-Item -Force $fp }
        }
        Write-Host "[ui_before_after] Once = $BeforeRef (izlenmeyen yeni dosyalar kopyada kalir)" -ForegroundColor Cyan
    } else {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir "agy_revert.ps1") -Root $before -Match (Split-Path -Leaf $proj) -Since $AgySince
    }
}

# --- 2. Senaryoyu iki projede calistir ---------------------------------------------------------
function Invoke-States([string]$dir, [string]$shots, [string]$tag) {
    $log = Join-Path $work "$tag.log"
    $argList = @("--path", "`"$dir`"", "--resolution", $Resolution, "-s", "`"$(Join-Path $ScriptDir 'ui_states.gd')`"", "--", $Scenario, "`"$shots`"", [string]($TimeoutSec - 10))
    $p = Start-Process -FilePath $GodotBin -ArgumentList $argList -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -WindowStyle Minimized
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        $p.Kill()
        Write-Host "[ui_before_after] $tag zaman asimi; oldurulup devam ediliyor." -ForegroundColor Yellow
    }
    $errs = @(Get-Content "$log.err", $log -ErrorAction SilentlyContinue | Where-Object { $_ -match 'SCRIPT ERROR|ERROR:|Parse Error|\[ui_states\] (Zaman|Senaryo|Yaz)' } | Select-Object -Unique -First 8)
    $n = @(Get-ChildItem $shots -Filter *.png -ErrorAction SilentlyContinue).Count
    Write-Host "[ui_before_after] $tag : $n goruntu" -ForegroundColor Cyan
    foreach ($e in $errs) { Write-Host "    $e" -ForegroundColor DarkYellow }
}
$shotsBefore = Join-Path $work "shots_before"
$shotsAfter = Join-Path $work "shots_after"
Invoke-States $before $shotsBefore "once"
Invoke-States $proj $shotsAfter "sonra"

# --- 3. Fark bolgeleri -------------------------------------------------------------------------
$cmp = Join-Path $work "compare"
& $GodotBin --headless --path $SidebarRoot -s res://tools/ui_compare.gd -- $shotsBefore $shotsAfter $cmp 2>&1 | Select-String "ui_compare" | ForEach-Object { Write-Host "[ui_before_after] $_" -ForegroundColor Cyan }

# --- 4. Tablo ----------------------------------------------------------------------------------
Add-Type -AssemblyName System.Drawing
$titlesFile = Join-Path $shotsAfter "titles.json"
if (-not (Test-Path $titlesFile)) { $titlesFile = Join-Path $shotsBefore "titles.json" }
$order = New-Object System.Collections.ArrayList
$titles = @{}
if (Test-Path $titlesFile) {
    $tj = Get-Content $titlesFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($prop in $tj.PSObject.Properties) { [void]$order.Add($prop.Name); $titles[$prop.Name] = [string]$prop.Value }
}
foreach ($png in (Get-ChildItem $shotsAfter, $shotsBefore -Filter *.png -ErrorAction SilentlyContinue | Sort-Object Name)) {
    if (-not $order.Contains($png.BaseName)) { [void]$order.Add($png.BaseName); $titles[$png.BaseName] = $png.BaseName }
}
if ($order.Count -eq 0) { Write-Host "[ui_before_after] HATA: hic goruntu yok; loglar: $work" -ForegroundColor Red; exit 1 }

$GAP = 16; $PAD = 20; $HEAD = 54; $ROWH = 30; $FOOT = 40
$probe = $null
foreach ($name in $order) { $f = Join-Path $shotsAfter "$name.png"; if (Test-Path $f) { $probe = [System.Drawing.Image]::FromFile($f); break } }
$cw = $probe.Width; $ch = $probe.Height; $probe.Dispose()
$W = $PAD * 2 + $cw * 2 + $GAP
$H = $HEAD + $order.Count * ($ch + $ROWH + $PAD) + $FOOT
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::FromArgb(14, 11, 22))
$fBig = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$fRow = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$fNote = New-Object System.Drawing.Font("Segoe UI", 10)
$cOld = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(165, 158, 185))
$cNew = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(95, 216, 255))
$cRow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(240, 196, 90))
$cMiss = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 34, 56))
$sOnce = ([char]0xD6) + "NCE"
$g.DrawString($sOnce, $fBig, $cOld, $PAD + $cw / 2 - 30, 12)
$g.DrawString("SONRA", $fBig, $cNew, $PAD + $cw + $GAP + $cw / 2 - 40, 12)
$y = $HEAD
foreach ($name in $order) {
    $g.DrawString($titles[$name], $fRow, $cRow, $PAD, $y + 4)
    $iy = $y + $ROWH
    $cmpFile = Join-Path $cmp "$name.png"
    if (Test-Path $cmpFile) {
        $im = [System.Drawing.Image]::FromFile($cmpFile); $g.DrawImage($im, $PAD, $iy, $im.Width, $im.Height); $im.Dispose()
    } else {
        $x = $PAD
        foreach ($src in @((Join-Path $shotsBefore "$name.png"), (Join-Path $shotsAfter "$name.png"))) {
            if (Test-Path $src) { $im = [System.Drawing.Image]::FromFile($src); $g.DrawImage($im, $x, $iy, $cw, $ch); $im.Dispose() }
            else { $g.FillRectangle($cMiss, $x, $iy, $cw, $ch) }
            $x += $cw + $GAP
        }
    }
    $y += $ROWH + $ch + $PAD
}
$note = "K" + [char]0x131 + "rm" + [char]0x131 + "z" + [char]0x131 + " " + [char]0xE7 + "er" + [char]0xE7 + "eve = de" + [char]0x11F + "i" + [char]0x15F + "en b" + [char]0xF6 + "lge (Godot AI Sidebar ui_compare). Yaln" + [char]0x131 + "z bu g" + [char]0xF6 + "rselde, oyunda yok."
$g.DrawString($note, $fNote, $cOld, $PAD, $H - $FOOT + 10)
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "[ui_before_after] Tablo: $Out ($W x $H, $($order.Count) satir)" -ForegroundColor Green
if ($Keep) { Write-Host "[ui_before_after] Ara dosyalar: $work" } else { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
