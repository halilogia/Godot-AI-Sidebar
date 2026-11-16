# Evrensel oyun test sarmalayicisi (Godot Playwright / Agent Driver).
# Herhangi bir Godot 4 projesinin ana sahnesini acar, tuslari/aktorleri/butonlari kendisi kesfedip oynar,
# telemetri olcer ve playtest_report.json uretir. Cikis kodu: 0 = PASS, 1 = FAIL.
#
#   game_playtest.ps1 -Project "C:\...\Oyun" [-Duration 6] [-Headless] [-Scenario s.json] [-Out klasor]
#                     [-Scene res://x.tscn] [-Shots 3] [-Strict] [-ExpectMove] [-GodotPath yol]

param(
    [string]$Project = ".",
    [double]$Duration = 6,
    [switch]$Headless,
    [string]$Scenario = "",
    [string]$Out = "",
    [string]$Scene = "",
    [int]$Shots = 3,
    [string]$Resolution = "1280x720",
    [double]$MinFps = 15,
    [switch]$Strict,
    [switch]$ExpectMove,
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ScriptDir = $PSScriptRoot

$projPath = Resolve-Path $Project -ErrorAction SilentlyContinue
if (-not $projPath -or -not (Test-Path (Join-Path $projPath.Path "project.godot"))) {
    Write-Host "[game_playtest] HATA: project.godot bulunamadi: $Project" -ForegroundColor Red
    exit 2
}
$projDir = $projPath.Path
$projName = Split-Path $projDir -Leaf

. (Join-Path $ScriptDir "find_godot.ps1")
$GodotBin = Resolve-GodotBin $GodotPath
if (-not $GodotBin) {
    Write-Host "[game_playtest] HATA: Godot binary bulunamadi (-GodotPath ya da `$env:GODOT_BIN)." -ForegroundColor Red
    exit 2
}

if (-not $Out) { $Out = Join-Path $env:TEMP "godot_playtest\$projName" }
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$Out = (Resolve-Path $Out).Path
Get-ChildItem $Out -Include "playtest_report.json", "auto_*.png" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force
$report = Join-Path $Out "playtest_report.json"

$scenarioArg = @()
if ($Scenario) {
    $sp = Resolve-Path $Scenario -ErrorAction SilentlyContinue
    if (-not $sp) { Write-Host "[game_playtest] HATA: senaryo yok: $Scenario" -ForegroundColor Red; exit 2 }
    $scenarioArg = @("scenario=$($sp.Path)")
}

$userArgs = @("duration=$Duration", "out=$Out", "shots=$Shots", "min_fps=$MinFps", "size=$Resolution") + $scenarioArg
if ($Scene) { $userArgs += "scene=$Scene" }
if ($Strict) { $userArgs += "strict=1" }
if ($ExpectMove) { $userArgs += "expect_move=1" }
$userArgs += "timeout=$([int]($Duration * 4 + 60))"

$godotArgs = @("--path", $projDir)
if ($Headless) { $godotArgs += "--headless" } else { $godotArgs += @("--resolution", $Resolution) }
$godotArgs += @("-s", (Join-Path $ScriptDir "game_playtest.gd"), "--") + $userArgs

Write-Host "[game_playtest] Proje: $projDir" -ForegroundColor Cyan
Write-Host "[game_playtest] Godot: $GodotBin | Sure: ${Duration}s | Headless: $($Headless.IsPresent)" -ForegroundColor Cyan

$logFile = Join-Path $env:TEMP ("godot_playtest_" + [guid]::NewGuid().ToString() + ".log")
$proc = Start-Process -FilePath $GodotBin -ArgumentList ($godotArgs | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) `
    -NoNewWindow -PassThru -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err"
$limit = [int]($Duration * 4 + 90)
if (-not $proc.WaitForExit($limit * 1000)) {
    $proc.Kill()
    Write-Host "[game_playtest] ZAMAN ASIMI ($limit sn): Godot sonlandirildi." -ForegroundColor Red
}

$log = @()
if (Test-Path $logFile) { $log += Get-Content $logFile }
if (Test-Path "$logFile.err") { $log += Get-Content "$logFile.err" }
Remove-Item $logFile, "$logFile.err" -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $report)) {
    Write-Host "[game_playtest] FAIL: rapor uretilmedi (Godot coktu ya da script derlenemedi)." -ForegroundColor Red
    $log | Select-Object -Last 25 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    exit 1
}

$r = Get-Content $report -Raw | ConvertFrom-Json
$color = if ($r.verdict -eq "PASS") { "Green" } else { "Red" }
Write-Host ""
Write-Host "=== PLAYTEST: $($r.project) -> $($r.verdict) ===" -ForegroundColor $color
Write-Host ("Sure {0}s | Kare {1} | FPS ort {2} / min {3} / p1 {4}{5}" -f $r.duration_s, $r.frames, $r.fps.avg, $r.fps.min, $r.fps.p1_low, $(if (-not $r.fps.fps_meaningful) { " (headless: anlamsiz)" } else { "" }))
Write-Host ("Aktor hareket etti: {0} | Simule edilen girdi: {1} | Dugum: {2} -> {3} (tepe {4})" -f $r.actor_moved, $r.actions_simulated.total, $r.nodes.start, $r.nodes.end, $r.nodes.peak)
foreach ($a in $r.actors) { Write-Host ("  aktor {0} [{1}] toplam={2} girdiyle={3}" -f $a.path, $a.class, $a.distance_total, $a.distance_while_input) }
Write-Host ("Kesfedilen girdi: hareket=[{0}] eylem=[{1}] ziplama=[{2}]" -f ($r.discovered_inputs.move -join ","), ($r.discovered_inputs.act -join ","), ($r.discovered_inputs.jump -join ","))
if ($r.clicks) { foreach ($c in $r.clicks) { Write-Host ("  tik: '{0}' ({1})" -f $c.target, $c.method) } }
Write-Host ("Sahneler: {0}" -f ($r.scenes_visited -join " -> "))
Write-Host ("Hata: {0} | Uyari(log): {1}" -f $r.errors.count, $r.errors.warnings)
foreach ($e in $r.errors.samples) { Write-Host "  $e" -ForegroundColor Red }
foreach ($w in $r.warnings) { Write-Host "  UYARI: $w" -ForegroundColor Yellow }
foreach ($f in $r.failed_checks) { Write-Host "  BASARISIZ: $f" -ForegroundColor Red }
foreach ($s in $r.screenshots) { Write-Host "  ekran: $s" -ForegroundColor Cyan }
Write-Host "Rapor: $report"
if ($r.verdict -eq "PASS") { exit 0 } else { exit 1 }
