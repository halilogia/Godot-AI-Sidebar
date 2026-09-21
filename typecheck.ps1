# Godot GDScript Static Typecheck & Compilation Runner
# Usage: ./typecheck.ps1

$GodotBin = "C:\Users\Halil Emre\Desktop\Godot_v4.7.2-stable_win64.exe"
$ProjectPath = $PSScriptRoot

if (-not (Test-Path $GodotBin)) {
    # Fallback to PATH or common locations
    $GodotBin = (Get-Command godot -ErrorAction SilentlyContinue).Source
}

if (-not $GodotBin) {
    Write-Error "Godot binary bulunamadi. Lutfen PATH veya script icindeki GodotBin yolunu ayarlayin."
    exit 1
}

Write-Host "Checking all GDScripts and Scenes statically using Godot headless..." -ForegroundColor Cyan
& $GodotBin --headless --path $ProjectPath -s "res://tools/typecheck.gd"
exit $LASTEXITCODE
