# Grand-strategy benchmark için boş bir Godot oyun projesi hazırlar:
#   - klasör + git deposu, en küçük project.godot (eklenti etkin)
#   - addons/godot_sidebar_ai -> bu depodaki eklentiye junction (kopya değil; eklenti güncellemesi anında görünür)
#   - Claude Code skill'leri .claude/skills/ altına kopyalanır, ACCEPTANCE.md projeye kopyalanır
# Kullanım:
#   powershell -ExecutionPolicy Bypass -File .\benchmarks\grand-strategy-slice\new_benchmark_project.ps1 -Path C:\Users\<siz>\Documents\gs-benchmark
# Sonra: projeyi Godot 4.7'de açın, sidebar'da /mcp on, kopyalanan `claude mcp add ...` komutunu proje klasöründe çalıştırın,
# `/mcp write auto` (ya da ask) ve PROMPT.md içeriğini Claude Code'a verin. Kayıt: ACCEPTANCE.md "What to record per run".

param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$Name = "GS Benchmark"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$addonSrc = Join-Path $repo "addons\godot_sidebar_ai"
$skillsSrc = Join-Path $repo "integrations\claude-code\skills"

if (Test-Path $Path) {
    if ((Get-ChildItem -Force $Path | Measure-Object).Count -gt 0) {
        throw "Target folder is not empty: $Path"
    }
} else {
    New-Item -ItemType Directory -Path $Path | Out-Null
}

$projectGodot = @"
; Engine configuration file.
config_version=5

[application]

config/name="$Name"
config/features=PackedStringArray("4.7")

[editor_plugins]

enabled=PackedStringArray("res://addons/godot_sidebar_ai/plugin.cfg")
"@
# BOM'suz UTF-8 (Windows PowerShell 5.1'in -Encoding UTF8'i BOM yazar).
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $Path "project.godot"), $projectGodot, $utf8)

New-Item -ItemType Directory -Path (Join-Path $Path "addons") | Out-Null
New-Item -ItemType Junction -Path (Join-Path $Path "addons\godot_sidebar_ai") -Target $addonSrc | Out-Null

$skillsDst = Join-Path $Path ".claude\skills"
New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null
Copy-Item -Path (Join-Path $skillsSrc "*") -Destination $skillsDst -Recurse
Copy-Item -Path (Join-Path $PSScriptRoot "ACCEPTANCE.md") -Destination $Path

# Eklenti junction'ı ve Godot önbelleği oyun deposuna girmez; eklentinin kişisel config.json'ı zaten eklenti tarafında.
[System.IO.File]::WriteAllText((Join-Path $Path ".gitignore"), ".godot/`naddons/godot_sidebar_ai/`n", $utf8)
Push-Location $Path
try {
    git init -q
} finally {
    Pop-Location
}

Write-Host "Ready: $Path"
Write-Host "1) open it in Godot 4.7  2) sidebar: /mcp on  3) in the project folder: claude mcp add ... (from clipboard)  4) sidebar: /mcp write auto  5) give PROMPT.md to Claude Code"
