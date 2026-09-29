# Arsivdeki bir kosuyu elle demos/ vitrinine koyar ve SABITLER (kuyruk sonraki kosularda uzerine yazmaz).
# Eski demos surumu archives/demos-replaced/ altina tasinir, hicbir sey silinmez.
#
#   powershell -ExecutionPolicy Bypass -File .\tools\demo_promote.ps1 -Run 20260928-225642-turn-based-rpg -Title "Sira tabanli RPG"
param(
    [Parameter(Mandatory = $true)][string]$Run,
    [string]$Title = ""
)
$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $Repo ("archives\bench-runs\" + $Run)
if (-not (Test-Path $dir)) { throw "Kosu bulunamadi: $dir" }
$genre = $Run -replace '^\d{8}-\d{6}-', ''
if ([string]::IsNullOrWhiteSpace($Title)) { $Title = $genre }
& (Join-Path $PSScriptRoot "demo_library_add.ps1") -Project $dir -Genre $genre -Title $Title -Force
& (Join-Path $PSScriptRoot "demo_gallery.ps1")
Write-Host "[demo_promote] $Run -> demos/$genre (sabitlendi)"
