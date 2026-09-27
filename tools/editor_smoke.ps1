# Gerçek editörde duman testi: editörü GUI ile açar, eklentinin küçük denetleyicisini
# (addons/godot_sidebar_ai/core/dev/editor_smoke.gd) çalıştırır ve kapatır.
#
#   powershell -ExecutionPolicy Bypass -File .\tools\editor_smoke.ps1
#
# Denetler: panel yüklendi ve görünür, tema kökte, durum rozeti dolu, Ayarlar ve Yardım açılıyor; editör
# çıktısında eklentiye ait betik hatası yok. Panelin, Ayarlar'ın ve Yardım'ın editördeki gerçek görüntüsü
# (editör teması, ölçek, yazı tipleri) ui_snapshots\editor_smoke\ altına kaydedilir. Başarısızlıkta exit 1.
# Kişisel config.json ve project.godot çalıştırmadan önceki baytlarına geri döner.
# Editör açılırken ekranda kısa süre görünür; ekran gerekir (headless çalışmaz).

param(
    [string]$GodotPath = "",
    [int]$TimeoutSec = 120
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "find_godot.ps1")
$GodotBin = Resolve-GodotBin $GodotPath
if (-not $GodotBin) {
    Write-Host "[editor_smoke] Godot bulunamadı (-GodotPath ya da `$env:GODOT_BIN)." -ForegroundColor Red
    exit 1
}
$Out = Join-Path $Root "ui_snapshots\editor_smoke"
New-Item -ItemType Directory -Force $Out | Out-Null
# Godot bu klasördeki PNG'leri içe aktarmasın (içe aktarma penceresi görüntülere karışıyordu).
$gdignore = Join-Path (Split-Path -Parent $Out) ".gdignore"
if (-not (Test-Path $gdignore)) { New-Item -ItemType File $gdignore | Out-Null }
Get-ChildItem $Out -File | Remove-Item -Force
$log = Join-Path $Out "editor.log"
$errLog = Join-Path $Out "editor.err.log"

# Editörün normal açılışı kişisel config'i (model listesi, sürüm göçü) ve project.godot'u (autoload) yazar;
# duman testi iz bırakmasın diye bu dosyalar bayt bayt saklanır ve sonunda geri konur.
$Keep = @("addons\godot_sidebar_ai\config.json", "addons\godot_sidebar_ai\config.json.bak",
    "addons\godot_sidebar_ai\config.json.tmp", "addons\godot_sidebar_ai\config.json.corrupt", "project.godot")
$saved = @{}
foreach ($rel in $Keep) {
    $f = Join-Path $Root $rel
    $saved[$f] = if (Test-Path $f) { [IO.File]::ReadAllBytes($f) } else { $null }
}
$timedOut = $false
try {
    $argsList = @("--path", "`"$Root`"", "--editor", "--", "`"--ai-sidebar-smoke=$Out`"")
    $p = Start-Process -FilePath $GodotBin -ArgumentList $argsList -PassThru -RedirectStandardOutput $log -RedirectStandardError $errLog
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        $p.Kill()
        $p.WaitForExit()
        $timedOut = $true
    }
} finally {
    foreach ($f in $saved.Keys) {
        if ($null -ne $saved[$f]) { [IO.File]::WriteAllBytes($f, $saved[$f]) }
        elseif (Test-Path $f) { Remove-Item -Force $f }
    }
}
if ($timedOut) {
    Write-Host "[editor_smoke] Zaman aşımı ($TimeoutSec sn); editör kapatıldı." -ForegroundColor Red
    exit 1
}

$report = Join-Path $Out "report.json"
if (-not (Test-Path $report)) {
    Write-Host "[editor_smoke] report.json yok: eklenti duman testini başlatmadı (panel yüklenmedi mi?). Log: $log" -ForegroundColor Red
    exit 1
}
$r = Get-Content $report -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($c in $r.checks) {
    $mark = if ($c.ok) { "OK  " } else { "FAIL" }
    $color = if ($c.ok) { "Green" } else { "Red" }
    Write-Host ("  [{0}] {1} {2}" -f $mark, $c.id, $c.detail) -ForegroundColor $color
}
$scriptErrors = @()
foreach ($f in @($log, $errLog)) {
    if (Test-Path $f) {
        $scriptErrors += Get-Content $f -Encoding UTF8 | Where-Object { $_ -match "SCRIPT ERROR|Parse Error" }
    }
}
$pluginErrors = $scriptErrors | Where-Object { $_ -match "godot_sidebar_ai" }
if ($pluginErrors) {
    Write-Host "[editor_smoke] Eklentiye ait betik hataları:" -ForegroundColor Red
    $pluginErrors | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
}
Write-Host ("[editor_smoke] Godot {0}: {1} geçti, {2} kaldı. Görüntüler: {3}" -f $r.godot, $r.passed, $r.failed, $Out)
if ($r.failed -gt 0 -or $pluginErrors) { exit 1 }
exit 0
