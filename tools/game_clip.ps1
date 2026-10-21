# Universal Game Video Clip Tool (Godot AI Sidebar) - ince sarmalayıcı
# Asıl kod eklentinin içinde: addons\godot_sidebar_ai\core\capture\game_clip.ps1 (kullanım ve parametreler orada).
# Burada yalnız Godot binary'si çözülüp (find_godot.ps1) aynı parametrelerle çağrılır.

param(
    [string]$Project = ".",
    [string]$OutDir = "",
    [string]$Name = "",
    [string]$Resolution = "1080x1920",
    [int]$Fps = 30,
    [double]$Seconds = 10,
    [string]$Clip = "",
    [string]$Release = "",
    [string[]]$Only = @(),
    [string]$ClipScript = "",
    [int]$Crf = 18,
    [switch]$KeepAvi,
    [string]$GodotPath = ""
)

. (Join-Path $PSScriptRoot "find_godot.ps1")
if (-not $GodotPath) {
    $found = Resolve-GodotBin ""
    if ($found) { $PSBoundParameters["GodotPath"] = $found }
}
& (Join-Path $PSScriptRoot "..\addons\godot_sidebar_ai\core\capture\game_clip.ps1") @PSBoundParameters
exit $LASTEXITCODE
