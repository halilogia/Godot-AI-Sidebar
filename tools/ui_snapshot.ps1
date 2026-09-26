# Arayüz görüntü arşivi ve karşılaştırma (CLAUDE.md → Arayüz grafik kalitesi standardı).
#
# 1) Arayüz değişikliğinden ÖNCE, o anki sürümün görüntülerini arşivle:
#      powershell -ExecutionPolicy Bypass -File .\tools\ui_snapshot.ps1
#    Etiket verilmezse git kısa commit kimliği kullanılır (ör. ui_snapshots\39460b5\).
#    Türkçe + İngilizce koyu tema ve Türkçe açık tema çekilir (tools/ui_shots.gd: Ayarlar, Yardım, dock senaryoları).
# 2) Değişiklikten SONRA yeniden arşivle (yeni commit ya da -Label ile ad ver), sonra karşılaştır:
#      powershell -ExecutionPolicy Bypass -File .\tools\ui_snapshot.ps1 -Compare 39460b5 -With c0162b1
#    Sonuç: ui_snapshots\compare_<önce>_vs_<sonra>\ (değişen her ekran yan yana, farklı bölge kırmızı çerçeveli,
#    report.md). Bu bir rapordur, test değildir; farkların istenip istenmediğine gözle bakılır.
#
# ui_snapshots\ git'e girmez (.gitignore). config.json'a yalnız dil için geçici dokunulur, bayt bayt geri yazılır.

param(
    [string]$Label = "",
    [string]$Compare = "",
    [string]$With = "",
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "find_godot.ps1")
$GodotBin = Resolve-GodotBin $GodotPath
if (-not $GodotBin) {
    Write-Host "[ui_snapshot] Godot bulunamadı (-GodotPath ya da `$env:GODOT_BIN)." -ForegroundColor Red
    exit 1
}
$SnapRoot = Join-Path $Root "ui_snapshots"

if ($Compare) {
    if (-not $With) {
        Write-Host "[ui_snapshot] -Compare ile birlikte -With <sonraki etiket> verin." -ForegroundColor Red
        exit 1
    }
    $before = Join-Path $SnapRoot $Compare
    $after = Join-Path $SnapRoot $With
    foreach ($d in @($before, $after)) {
        if (-not (Test-Path $d)) {
            Write-Host "[ui_snapshot] Arşiv yok: $d" -ForegroundColor Red
            exit 1
        }
    }
    $out = Join-Path $SnapRoot ("compare_{0}_vs_{1}" -f $Compare, $With)
    & $GodotBin --headless --path $Root -s "res://tools/ui_compare.gd" -- $before $after $out 2>&1 | Where-Object { "$_" -match "\[ui_compare\]|ERROR" } | ForEach-Object { Write-Host $_ }
    Write-Host "[ui_snapshot] Rapor: $(Join-Path $out 'report.md')"
    exit 0
}

if (-not $Label) {
    $Label = (git -C $Root rev-parse --short HEAD).Trim()
    $dirty = git -C $Root status --porcelain -- addons tools | Where-Object { $_ -notmatch "\.import$" }
    if ($dirty) { $Label = "$Label-dirty" }
}
$dest = Join-Path $SnapRoot $Label
New-Item -ItemType Directory -Force $dest | Out-Null
$runs = @(
    @{ lang = "tr"; dir = $dest; extra = @() },
    @{ lang = "en"; dir = $dest; extra = @() },
    @{ lang = "tr"; dir = (Join-Path $dest "light"); extra = @("all", "1", "light") }
)
$failed = $false
foreach ($r in $runs) {
    $args = @("--path", $Root, "-s", "res://tools/ui_shots.gd", "--", $r.dir, $r.lang) + $r.extra
    $lines = & $GodotBin @args 2>&1 | ForEach-Object { "$_" }
    $lines | Where-Object { $_ -match "OVERFLOW|SCRIPT ERROR" } | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    if ($LASTEXITCODE -ne 0) { $failed = $true }
}
$count = (Get-ChildItem -Recurse -Filter *.png $dest).Count
Write-Host "[ui_snapshot] $count görüntü -> $dest"
if ($failed) {
    Write-Host "[ui_snapshot] Taşma bulundu (OVERFLOW); görüntüler yine de kaydedildi." -ForegroundColor Yellow
    exit 1
}
