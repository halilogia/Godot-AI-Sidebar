param(
    [string]$GodotPath = "",
    [switch]$Live
)

# Tek komutluk doğrulama: typecheck -> uyarı cırcırı -> birim testleri -> (isteğe bağlı) canlı 9Router testi.
# Usage: ./verify.ps1 [-GodotPath <path>] [-Live]
# Herhangi bir adım başarısızsa sonraki adımlar koşmaz ve exit 1 döner.

# Windows PowerShell 5.1 decodes native (Godot) output with [Console]::OutputEncoding,
# i.e. the OEM code page (437/857) -> UTF-8 text turns into mojibake. Switch the console
# to UTF-8 without BOM (code page 65001). No-op on Linux/macOS.
if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    try { [Console]::OutputEncoding = $utf8NoBom; [Console]::InputEncoding = $utf8NoBom } catch { }
    $OutputEncoding = $utf8NoBom
}

$ProjectPath = $PSScriptRoot
. (Join-Path $PSScriptRoot "tools\find_godot.ps1")
$GodotBin = Resolve-GodotBin $GodotPath

if (-not $GodotBin) {
    Write-Error "Godot binary bulunamadi. Lutfen PATH'e ekleyin, `$env:GODOT_BIN degiskenini tanimlayin veya -GodotPath parametresi gecin."
    exit 1
}

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

# 1. Typecheck (kendi fail-closed mantığı typecheck.ps1 içinde)
Write-Step "Typecheck"
& (Join-Path $ProjectPath "typecheck.ps1") -GodotPath $GodotBin | Select-Object -Last 6
if ($LASTEXITCODE -ne 0) {
    Write-Host "[VERIFY FAIL] Typecheck basarisiz." -ForegroundColor Red
    exit 1
}

# 1b. Sıkı uyarı cırcırı: addons/ için 5 uyarı türü dosya başına sayılır; bir dosyada
# sayı tools/typecheck_baseline.json'dakinden fazlaysa (yeni dosyada > 0) başarısız.
Write-Step "Strict warnings (ratchet)"
$warnOut = & $GodotBin --headless --path $ProjectPath -s "res://tools/warning_report.gd" 2>&1 | ForEach-Object { "$_" }
$warnExit = $LASTEXITCODE
$warnOut | Select-String -Pattern "^\s+-\s|WARNINGS|azald|^\s+\* " | ForEach-Object { Write-Host $_.Line }
$warnOk = $warnOut | Select-String -SimpleMatch "[WARNINGS OK]" | Select-Object -Last 1
if ($warnExit -ne 0 -or -not $warnOk) {
    Write-Host "[VERIFY FAIL] Uyari circiri basarisiz (exit=$warnExit)." -ForegroundColor Red
    exit 1
}

# 2. Birim testleri. Fail-closed: exit 0 yetmez, runner'ın başarı satırı da görülmeli
# (runner quit() çağıramadan çökerse Godot 0 dönebilir).
Write-Step "Unit tests"
$testOut = & $GodotBin --headless --path $ProjectPath -s "res://tests/test_runner.gd" 2>&1 | ForEach-Object { "$_" }
$testExit = $LASTEXITCODE
$testOut | Select-String -Pattern "\[FAIL\]|^\s+- " | ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
$summary = $testOut | Select-String -Pattern "ALL TESTS PASSED|TEST SUITE FAILED" | Select-Object -Last 1
$suites = ($testOut | Select-String -Pattern "^\s*\[PASS\]").Count
if ($testExit -ne 0 -or -not $summary -or $summary.Line -notmatch "ALL TESTS PASSED") {
    Write-Host "[VERIFY FAIL] Unit tests basarisiz (exit=$testExit)." -ForegroundColor Red
    if ($summary) { Write-Host $summary.Line -ForegroundColor Red }
    exit 1
}
Write-Host "$($summary.Line) ($suites suites)" -ForegroundColor Green

# 3. Canlı entegrasyon (yalnızca -Live ile; 127.0.0.1:20128 üzerinde 9Router gerekir)
if ($Live) {
    Write-Step "Live 9Router integration"
    # Fail-closed: exit 0 yetmez, script'in "LIVE TEST PASSED" satiri da gorulmeli
    # (cokme / erken quit yesil sayilmaz). Cikti ekrana da akar.
    $liveOut = & $GodotBin --headless --path $ProjectPath -s "res://tests/integration/test_real_9router_live.gd" 2>&1 | ForEach-Object { "$_" }
    $liveExit = $LASTEXITCODE
    $liveOut | ForEach-Object { Write-Host $_ }
    $livePassed = $liveOut | Select-String -SimpleMatch "LIVE TEST PASSED" | Select-Object -Last 1
    if ($liveExit -ne 0 -or -not $livePassed) {
        Write-Host "[VERIFY FAIL] Canli entegrasyon testi basarisiz (exit=$liveExit, sentinel=$([bool]$livePassed))." -ForegroundColor Red
        exit 1
    }
    Write-Host $livePassed.Line -ForegroundColor Green
}

Write-Host ""
Write-Host "[VERIFY OK]" -ForegroundColor Green
exit 0
