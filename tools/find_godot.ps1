# Godot binary çözümleyici (typecheck.ps1 ve verify.ps1 ortak kullanır).
# Sıra: -GodotPath parametresi -> $env:GODOT_BIN -> PATH -> Masaüstü (4.7 öncelikli).
# Kullanım: . "$PSScriptRoot\tools\find_godot.ps1"; $bin = Resolve-GodotBin $GodotPath

function Resolve-GodotBin([string]$GodotPath = "") {
    $bin = $GodotPath

    if (-not $bin -and $env:GODOT_BIN) {
        $bin = $env:GODOT_BIN
    }

    if (-not $bin) {
        $cmd = Get-Command godot.exe, godot -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) {
            $bin = $cmd.Source
        }
    }

    if (-not $bin) {
        # Search Desktop dynamically without hardcoded user paths
        $desktopPath = [System.Environment]::GetFolderPath('Desktop')
        # Prioritize 4.7+ binary if multiple versions exist on Desktop
        $found = Get-ChildItem -Path $desktopPath -Filter "*4.7*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $found) {
            $found = Get-ChildItem -Path $desktopPath -Filter "Godot*.exe" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        }
        if ($found) {
            $bin = $found.FullName
        }
    }

    if (-not $bin -or -not (Test-Path $bin)) {
        return $null
    }
    return $bin
}
