# Universal Headless UI Audit CLI (Godot AI Sidebar)
#
# Hedef Godot projesini kalıcı olarak değiştirmeden (eklenti bağlı değilse geçici junction kurup
# çıkışta kaldırarak) headless UI yerleşim + dokunma/fare denetimi çalıştırır.
#
# Kullanım:
#   powershell -ExecutionPolicy Bypass -File tools/ui_audit.ps1 -Project <yol> [-Scenario <dosya.json>] [-Scene <res://...>] [-Platform desktop|mobile] [-Json]

param(
    [string]$Project = ".",
    [string]$Scenario = "",
    [string]$Scene = "",
    [ValidateSet("desktop", "mobile")]
    [string]$Platform = "desktop",
    [switch]$Json,
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $ScriptDir
$PluginSource = Join-Path $RepoRoot "addons\godot_sidebar_ai"

$projResolved = Resolve-Path $Project -ErrorAction SilentlyContinue
if (-not $projResolved -or -not (Test-Path (Join-Path $projResolved.Path "project.godot"))) {
    Write-Error "[ui_audit] HATA: Belirtilen dizinde project.godot bulunamadı: $Project"
    exit 2
}
$projDir = $projResolved.Path

. (Join-Path $ScriptDir "find_godot.ps1")
$GodotBin = Resolve-GodotBin $GodotPath
if (-not $GodotBin) {
    Write-Error "[ui_audit] HATA: Godot çalıştırılabilir dosyası bulunamadı."
    exit 2
}

$addonsDir = Join-Path $projDir "addons"
$targetPlugin = Join-Path $addonsDir "godot_sidebar_ai"
$createdAddons = $false
$createdJunction = $false

try {
    if (-not (Test-Path $targetPlugin)) {
        if (-not (Test-Path $addonsDir)) {
            New-Item -ItemType Directory -Path $addonsDir -Force | Out-Null
            $createdAddons = $true
        }
        cmd.exe /c "mklink /J `"$targetPlugin`" `"$PluginSource`"" | Out-Null
        $createdJunction = $true
    }

    $auditGd = Join-Path $ScriptDir "ui_audit.gd"
    $projAuditGd = Join-Path $projDir "tools\audit_ui.gd"

    $extraArgs = @("--platform", $Platform)
    if ($Scenario) {
        $scResolved = Resolve-Path $Scenario -ErrorAction SilentlyContinue
        $scPath = if ($scResolved) { $scResolved.Path } else { $Scenario }
        $extraArgs += @("--scenario", $scPath)
    }
    if ($Scene) {
        $extraArgs += @("--scene", $Scene)
    }
    if ($Json) {
        $extraArgs += "--json"
    }

    if ((-not $Scenario) -and (-not $Scene) -and (-not $Json) -and (Test-Path $projAuditGd) -and ($projDir -ne $RepoRoot)) {
        & $GodotBin --headless --path $projDir --resolution 1600x900 --script res://tools/audit_ui.gd -- @extraArgs
        $exitCode = $LASTEXITCODE
    } else {
        & $GodotBin --headless --path $projDir --resolution 1600x900 -s $auditGd -- @extraArgs
        $exitCode = $LASTEXITCODE
    }
} finally {
    if ($createdJunction -and (Test-Path $targetPlugin)) {
        cmd.exe /c "rmdir `"$targetPlugin`"" | Out-Null
    }
    if ($createdAddons -and (Test-Path $addonsDir)) {
        $remaining = Get-ChildItem -Path $addonsDir -Force -ErrorAction SilentlyContinue
        if (-not $remaining) {
            Remove-Item -Path $addonsDir -Force -ErrorAction SilentlyContinue
        }
    }
}

exit $exitCode
