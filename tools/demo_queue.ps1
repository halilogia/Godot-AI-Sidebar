# Demo kuyruğu: türleri sırayla demo_bench.ps1 ile koşturur (paralel olamaz: editör hata ayıklayıcı
# portu tek). Başarılı olanlar demo_library_add.ps1 ile demos/'a eklenir; her sonuç bir satır olarak
# yazılır (kuyruk kaldığı yerden okunabilsin diye queue.log).
#
#   powershell -ExecutionPolicy Bypass -File .\tools\demo_queue.ps1 -Genres "card-game","match3"

param(
    [string[]]$Genres = @(),
    [int]$TimeoutMin = 35
)

$ErrorActionPreference = "Continue"
$Prompts = [ordered]@{
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
if ($Genres.Count -eq 0) { $Genres = @($Prompts.Keys) }
$root = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "ai_sidebar_bench"
New-Item -ItemType Directory -Force $root | Out-Null
$qlog = Join-Path $root "queue.log"
foreach ($g in $Genres) {
    $prompt, $title = $Prompts[$g]
    Add-Content -Path $qlog -Encoding UTF8 -Value ("{0} START {1}" -f (Get-Date -Format "HH:mm:ss"), $g)
    & (Join-Path $PSScriptRoot "demo_bench.ps1") -Prompt $prompt -Name $g -TimeoutMin $TimeoutMin | Out-Null
    $proj = Get-ChildItem $root -Directory -Filter "*-$g" | Sort-Object Name | Select-Object -Last 1
    $res = Join-Path $proj.FullName "_bench\result.json"
    $status = "no_result"
    if (Test-Path $res) {
        $r = Get-Content $res -Raw -Encoding UTF8 | ConvertFrom-Json
        $status = "{0} {1}s steps={2} failed={3}" -f $r.status, $r.elapsed_s, $r.metrics.used_steps, $r.metrics.failed_tools
        if ($r.status -eq "completed" -and $r.metrics.success) {
            & (Join-Path $PSScriptRoot "demo_library_add.ps1") -Project $proj.FullName -Genre $g -Title $title | Out-Null
            $status += " LIBRARY"
        }
    }
    Add-Content -Path $qlog -Encoding UTF8 -Value ("{0} DONE {1} {2} {3}" -f (Get-Date -Format "HH:mm:ss"), $g, $status, $proj.FullName)
}
Add-Content -Path $qlog -Encoding UTF8 -Value ("{0} QUEUE_END" -f (Get-Date -Format "HH:mm:ss"))
