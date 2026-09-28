# Bir demo benchmark çalıştırmasına 100 üzerinden puan verir ve demos/SCORES.md tablosuna ekler
# (başarısız çalıştırmalar dahil). Puan yalnız result.json ölçümlerinden hesaplanır:
#   Tamamlandı ve başarılı 40 (tamamlandı ama başarısız 15, zaman aşımı 0)
#   Oyunu çalıştırıp doğruladı (runtime araçları) 20
#   Süre <=10 dk 15, <=20 dk 10, <=35 dk 5
#   Başarısız araç 0-2: 15, 3-5: 10, 6-10: 5, fazlası 0
#   Adım <=30: 10, <=60: 5, fazlası 0
#
#   powershell -ExecutionPolicy Bypass -File .\tools\demo_score.ps1 -Project <bench proje klasörü> -Genre card-game

param(
    [Parameter(Mandatory = $true)][string]$Project,
    [Parameter(Mandatory = $true)][string]$Genre
)

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
$bench = Join-Path $Project "_bench"
$resFile = Join-Path $bench "result.json"
$r = if (Test-Path $resFile) { Get-Content $resFile -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
$m = if ($r) { $r.metrics } else { $null }

$completion = 0; $runtime = 0; $time = 0; $fails = 0; $steps = 0
if ($r) {
    if ($r.status -eq "completed" -and $m.success) { $completion = 40 } elseif ($r.status -eq "completed") { $completion = 15 }
    if ([int]$m.runtime_ops -gt 0) { $runtime = 20 }
    $min = [double]$r.elapsed_s / 60
    $time = if ($min -le 10) { 15 } elseif ($min -le 20) { 10 } elseif ($min -le 35) { 5 } else { 0 }
    $f = [int]$m.failed_tools
    $fails = if ($f -le 2) { 15 } elseif ($f -le 5) { 10 } elseif ($f -le 10) { 5 } else { 0 }
    $s = [int]$m.used_steps
    $steps = if ($s -le 30) { 10 } elseif ($s -le 60) { 5 } else { 0 }
}
$score = $completion + $runtime + $time + $fails + $steps

$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = Join-Path $Repo "demos\SCORES.md"
if (-not (Test-Path $file)) {
    $head = "# Ajan puan tablosu`n`nHer satır bir ``tools/demo_bench.ps1`` çalıştırması (başarısızlar dahil). Puan ``tools/demo_score.ps1``'deki kurala göre yalnız ölçümlerden hesaplanır: tamamlanma 40, oyunu çalıştırıp doğrulama 20, süre 15, başarısız araç 15, adım 10.`n`n| Tarih | Tür | Puan | Durum | Süre | Adım | Başarısız araç | Model |`n|---|---|---|---|---|---|---|---|`n"
    [IO.File]::WriteAllText($file, $head, $utf8)
}
$status = if ($r) { if ($r.status -eq "completed" -and $m.success) { "başarılı" } elseif ($r.status -eq "completed") { "bitti, başarısız" } else { $r.status } } else { "sonuç yok" }
$elapsed = if ($r) { "$([Math]::Round([double]$r.elapsed_s / 60, 1)) dk" } else { "-" }
$cfg = Join-Path $Repo "addons\godot_sidebar_ai\config.json"
$model = if (Test-Path $cfg) { (Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json).selected_model } else { "?" }
# Çalıştırmanın tarihi proje klasörünün adından (demo_bench.ps1: yyyyMMdd-HHmmss-<ad>).
$stamp = Split-Path -Leaf $Project
$when = if ($stamp -match '^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})') { "$($Matches[1])-$($Matches[2])-$($Matches[3]) $($Matches[4]):$($Matches[5])" } else { Get-Date -Format 'yyyy-MM-dd HH:mm' }
$row = "| $when | $Genre | **$score** | $status | $elapsed | $(if ($m) { $m.used_steps } else { '-' }) | $(if ($m) { $m.failed_tools } else { '-' }) | $model |`n"
[IO.File]::AppendAllText($file, $row, $utf8)
Write-Host "[demo_score] $Genre = $score ($status)"
