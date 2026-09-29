# Demo kuyruğu: türleri sırayla demo_bench.ps1 ile koşturur (paralel olamaz: editör hata ayıklayıcı
# portu tek). Başarılı olanlar demo_library_add.ps1 ile demos/'a eklenir; her sonuç bir satır olarak
# yazılır (kuyruk kaldığı yerden okunabilsin diye queue.log).
#
#   powershell -ExecutionPolicy Bypass -File .\tools\demo_queue.ps1 -Genres "card-game","match3"
#   ... -Loop -Model openrouter/space-bunny-alpha   (liste bitince baştan; bilgisayar açık kaldıkça sürer)
# -Loop: her tur güncel eklentiyi kopyalar (düzeltmeler bir sonraki demoya kendiliğinden girer). Durdurmak
# için bench klasörüne queue.stop dosyası konur: o anki demo bitince kuyruk çıkar (dosya silinir).

param(
    [string[]]$Genres = @(),
    [int]$TimeoutMin = 35,
    [string]$Model = "",
    [string]$Provider = "",
    [switch]$Loop,
    [int]$PauseMin = 15,
    [string]$Reasoning = ""
)

$ErrorActionPreference = "Continue"
$Prompts = [ordered]@{
    "platformer"      = @("platformer oyun demosu yap", "Platformer")
    "topdown-shooter" = @("top-down shooter demosu yap", "Top-down shooter")
    "card-game"      = @("kart oyunu demosu yap", "Kart oyunu")
    "grand-strategy" = @("hoi4 tarzı grand strateji demosu yap, basit ve hızlı", "Grand strateji")
    "match3"         = @("match-3 bulmaca oyunu demosu yap", "Match-3 bulmaca")
    "tower-defense"  = @("tower defense oyun demosu yap", "Tower defense")
    "endless-runner" = @("endless runner oyun demosu yap", "Endless runner")
    "snake"          = @("snake oyunu demosu yap", "Snake")
    "turn-based-rpg" = @("sıra tabanlı RPG savaş demosu yap", "Sıra tabanlı RPG")
    "fps-3d"         = @("3D birinci şahıs yürüme ve toplama demosu yap", "3D birinci şahıs")
    "topdown-racing" = @("top-down yarış oyunu demosu yap", "Top-down yarış")
}
# -File ile "a","b" tek bir "a,b" dizgesi olarak gelir.
$Genres = @($Genres | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($Genres.Count -eq 0) { $Genres = @($Prompts.Keys) }
$root = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "ai_sidebar_bench"
New-Item -ItemType Directory -Force $root | Out-Null
$qlog = Join-Path $root "queue.log"
# Günlük başka bir süreçte açıksa (izleyici) kuyruk durmasın.
function Write-QLog([string]$line) {
    for ($i = 0; $i -lt 5; $i++) { try { Add-Content -Path $qlog -Encoding UTF8 -Value $line -ErrorAction Stop; return } catch { Start-Sleep -Milliseconds 500 } }
}
$stopFile = Join-Path $root "queue.stop"
$round = 0
do {
$round++
if ($Loop) { Write-QLog ("{0} ROUND {1} model={2} provider={3}" -f (Get-Date -Format "HH:mm:ss"), $round, $Model, $Provider) }
foreach ($g in $Genres) {
    if (Test-Path $stopFile) { break }
    if (-not $Prompts.Contains($g)) { Write-QLog ("{0} SKIP unknown genre {1}" -f (Get-Date -Format "HH:mm:ss"), $g); continue }
    $prompt, $title = $Prompts[$g]
    # Anında biten koşu (kota / ağ kesintisi: birkaç saniye, 1 adım) puanlanmaz ve silinir; kuyruk bekleyip
    # aynı türü yeniden dener. (Günlük ücretsiz model kotası dolunca kuyruk tabloyu çöple dolduruyordu.)
    do {
        Write-QLog ("{0} START {1}" -f (Get-Date -Format "HH:mm:ss"), $g)
        & (Join-Path $PSScriptRoot "demo_bench.ps1") -Prompt $prompt -Name $g -TimeoutMin $TimeoutMin -Model $Model -Provider $Provider -Reasoning $Reasoning | Out-Null
        $proj = Get-ChildItem $root -Directory -Filter "*-$g" | Sort-Object Name | Select-Object -Last 1
        $res = Join-Path $proj.FullName "_bench\result.json"
        $instant = $false
        if (Test-Path $res) {
            $probe = Get-Content $res -Raw -Encoding UTF8 | ConvertFrom-Json
            $instant = ([double]$probe.elapsed_s -le 10) -and ([int]$probe.metrics.used_steps -le 1)
            if ($instant) {
                Write-QLog ("{0} PAUSE {1}: run ended in {2}s ({3}); waiting {4} min" -f (Get-Date -Format "HH:mm:ss"), $g, $probe.elapsed_s, ([string]$probe.metrics.completion_reason).Substring(0, [Math]::Min(90, ([string]$probe.metrics.completion_reason).Length)), $PauseMin)
                Remove-Item -Recurse -Force $proj.FullName
                for ($w = 0; $w -lt $PauseMin * 6 -and -not (Test-Path $stopFile); $w++) { Start-Sleep -Seconds 10 }
            }
        }
    } while ($instant -and -not (Test-Path $stopFile))
    if (Test-Path $stopFile) { break }
    $status = "no_result"
    # Puan önce hesaplanır: kütüphane yalnız daha yüksek (ya da eşit) puanlı sürümle değişir.
    $score = -1
    if ($proj) {
        $scoreOut = (& (Join-Path $PSScriptRoot "demo_score.ps1") -Project $proj.FullName -Genre $g 6>&1 | Out-String)
        if ($scoreOut -match "= (\d+) \(") { $score = [int]$Matches[1] }
    }
    # Koşunun sohbet kaydı (gitignore'lu archives/chat_archive/<koşu adı>/): kopya, bench klasörü yerinde kalır.
    if ($proj) {
        $arch = Join-Path (Split-Path -Parent $PSScriptRoot) ("archives\chat_archive\" + $proj.Name)
        New-Item -ItemType Directory -Force $arch | Out-Null
        foreach ($f in "export.md", "export.json", "live.jsonl", "prompt.txt", "result.json") {
            $src = Join-Path $proj.FullName ("_bench\" + $f)
            if (Test-Path $src) { Copy-Item $src $arch -Force }
        }
    }
    if (Test-Path $res) {
        $r = Get-Content $res -Raw -Encoding UTF8 | ConvertFrom-Json
        $status = "{0} {1}s steps={2} failed={3}" -f $r.status, $r.elapsed_s, $r.metrics.used_steps, $r.metrics.failed_tools
        if ($r.status -eq "completed" -and $r.metrics.success) {
            & (Join-Path $PSScriptRoot "demo_library_add.ps1") -Project $proj.FullName -Genre $g -Title $title -Score $score | Out-Null
            $status += if ($LASTEXITCODE -eq 3) { " LIBRARY_KEPT_OLD" } else { " LIBRARY" }
        }
    }
    Write-QLog ("{0} DONE {1} {2} {3}" -f (Get-Date -Format "HH:mm:ss"), $g, $status, $proj.FullName)
}
} while ($Loop -and -not (Test-Path $stopFile))
if (Test-Path $stopFile) { Remove-Item $stopFile; Write-QLog ("{0} STOPPED (queue.stop)" -f (Get-Date -Format "HH:mm:ss")) }
Write-QLog ("{0} QUEUE_END" -f (Get-Date -Format "HH:mm:ss"))
