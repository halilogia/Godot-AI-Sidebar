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

# Eklentinin kendi maliyeti (puana girmez, optimizasyon için): model isteklerinin boyutu (editor.log
# REQUEST_SENT, sohbet = method=2) ve modelin dışında geçen süre (araçlar, doğrulama, bekleme).
$reqAvg = "-"; $reqMax = "-"
$elog = Join-Path $bench "editor.log"
if (Test-Path $elog) {
    $sizes = Select-String -Path $elog -Pattern "REQUEST_SENT \| method=2 bytes=(\d+)" | ForEach-Object { [int]$_.Matches[0].Groups[1].Value }
    if ($sizes) {
        $reqAvg = [int](($sizes | Measure-Object -Average).Average / 1024)
        $reqMax = [int](($sizes | Measure-Object -Maximum).Maximum / 1024)
    }
}
$pluginS = if ($m) { [Math]::Round([double]$m.elapsed_seconds - [double]$m.llm_time_s, 1) } else { "-" }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = Join-Path $Repo "demos\SCORES.md"
if (-not (Test-Path $file)) {
    $head = "# Ajan puan tablosu`n`nHer satır bir ``tools/demo_bench.ps1`` çalıştırması (başarısızlar dahil). Puan ``tools/demo_score.ps1``'deki kurala göre yalnız ölçümlerden hesaplanır: tamamlanma 40, oyunu çalıştırıp doğrulama 20, süre 15, başarısız araç 15, adım 10. Son iki sütun eklentinin kendi maliyeti (puana girmez): model isteklerinin ortalama / en büyük boyutu ve modelin dışında geçen süre.`n`n| Tarih | Tür | Puan | Durum | Süre | Adım | Başarısız araç | Model | İstek KB ort / max | Eklenti süresi |`n|---|---|---|---|---|---|---|---|---|---|`n"
    [IO.File]::WriteAllText($file, $head, $utf8)
}
$status = if ($r) { if ($r.status -eq "completed" -and $m.success) { "başarılı" } elseif ($r.status -eq "completed") { "bitti, başarısız" } else { $r.status } } else { "sonuç yok" }
$elapsed = if ($r) { "$([Math]::Round([double]$r.elapsed_s / 60, 1)) dk" } else { "-" }
# Çalıştırmanın gerçekten kullandığı model (editör günlüğü; -Model kullanıcının ayarından farklı olabilir).
$edLog = Join-Path $Project "_bench\editor.log"
$model = "?"
if (Test-Path $edLog) {
    $hit = Select-String -Path $edLog -Pattern "LLM_REQUEST_START \| model=(\S+)" | Select-Object -First 1
    if ($hit) { $model = $hit.Matches[0].Groups[1].Value }
}
# Çalıştırmanın tarihi proje klasörünün adından (demo_bench.ps1: yyyyMMdd-HHmmss-<ad>).
$stamp = Split-Path -Leaf $Project
$when = if ($stamp -match '^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})') { "$($Matches[1])-$($Matches[2])-$($Matches[3]) $($Matches[4]):$($Matches[5])" } else { Get-Date -Format 'yyyy-MM-dd HH:mm' }
$row = "| $when | $Genre | **$score** | $status | $elapsed | $(if ($m) { $m.used_steps } else { '-' }) | $(if ($m) { $m.failed_tools } else { '-' }) | $model | $reqAvg / $reqMax | $pluginS s |`n"
[IO.File]::AppendAllText($file, $row, $utf8)
Write-Host "[demo_score] $Genre = $score ($status)"
