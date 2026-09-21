param(
    [string]$GodotPath = ""
)

# Godot GDScript Headless Compilation & Load Validator
# Usage: ./typecheck.ps1 [-GodotPath <path_to_godot>]

$ProjectPath = $PSScriptRoot
$GodotBin = $GodotPath

if (-not $GodotBin -and $env:GODOT_BIN) {
    $GodotBin = $env:GODOT_BIN
}

if (-not $GodotBin) {
    $cmd = Get-Command godot.exe, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) {
        $GodotBin = $cmd.Source
    }
}

if (-not $GodotBin) {
    # Search Desktop dynamically without hardcoded user paths
    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    $found = Get-ChildItem -Path $desktopPath -Filter "Godot*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $GodotBin = $found.FullName
    }
}

if (-not $GodotBin -or -not (Test-Path $GodotBin)) {
    Write-Error "Godot binary bulunamadi. Lutfen PATH'e ekleyin, `$env:GODOT_BIN degiskenini tanimlayin veya -GodotPath parametresi gecin."
    exit 1
}

Write-Host "Checking all GDScripts and Scenes statically using Godot headless..." -ForegroundColor Cyan
& $GodotBin --headless --path $ProjectPath -s "res://tools/typecheck.gd"
exit $LASTEXITCODE
