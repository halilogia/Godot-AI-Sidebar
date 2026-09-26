param(
    [string]$GodotPath = ""
)

# Godot GDScript Headless Compilation & Load Validator
# Usage: ./typecheck.ps1 [-GodotPath <path_to_godot>]

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

Write-Host "Using Godot: $GodotBin" -ForegroundColor DarkGray
Write-Host "Checking all GDScripts and Scenes statically using Godot headless..." -ForegroundColor Cyan

# Fail-closed: Godot çıktısındaki fatal script hataları özet sayaçlardan
# bağımsız olarak process sonucunu FAILURE yapar (kaskat yanlış pozitif yok).
# Çıktı konsola aynen akar; tarama kopyası dosya üzerinden yapılır.
$scanFile = Join-Path ([System.IO.Path]::GetTempPath()) "godot_typecheck_scan.txt"
if (Test-Path $scanFile) { Remove-Item -LiteralPath $scanFile -Force }
& $GodotBin --headless --path $ProjectPath -s "res://tools/typecheck.gd" 2>&1 | Tee-Object -FilePath $scanFile | ForEach-Object { "$_" }
$godotExit = $LASTEXITCODE
$joined = ""
if (Test-Path $scanFile) { $joined = Get-Content -Raw -LiteralPath $scanFile }
$fatalPattern = "SCRIPT ERROR|Parse Error|Parser Error|Compilation failed|Failed to load script|ERROR: Failed"
if ($joined -match $fatalPattern) {
    Write-Host ""
    Write-Host "[TYPECHECK FAIL-CLOSED] Godot fatal script hatasi tespit edildi; sonuc FAILURE." -ForegroundColor Red
    exit 1
}
exit $godotExit
