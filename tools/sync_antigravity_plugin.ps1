param(
    [string]$PluginDir = (Join-Path $env:USERPROFILE ".gemini\config\plugins\godot-ai-sidebar")
)

# Sidebar'ın yerleşik skill'lerini Antigravity eklentisinin skills/ klasörüne kopyalar.
# Yalnız repodaki skill'leri üzerine yazar; eklentiye özgü yeni skill'lere dokunmaz.
# Usage: ./tools/sync_antigravity_plugin.ps1 [-PluginDir <klasör>]

$src = Join-Path (Split-Path $PSScriptRoot -Parent) "addons\godot_sidebar_ai\skills"
$dst = Join-Path $PluginDir "skills"
if (-not (Test-Path $PluginDir)) { Write-Error "Eklenti klasoru yok: $PluginDir"; exit 1 }
New-Item -ItemType Directory -Force $dst | Out-Null
$count = 0
foreach ($dir in Get-ChildItem $src -Directory) {
    $target = Join-Path $dst $dir.Name
    New-Item -ItemType Directory -Force $target | Out-Null
    Copy-Item (Join-Path $dir.FullName "*") $target -Recurse -Force
    $count++
}
Write-Host "$count skill kopyalandi -> $dst"
