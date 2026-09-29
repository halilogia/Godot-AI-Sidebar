# Başarılı bir demo benchmark projesini demo kütüphanesine (demos/<Genre>/) ekler.
# Kopyalananlar: oyun dosyaları (addons/, .godot/, _bench/ hariç) + _bench/prompt.txt ve result.json
# (demos/<Genre>/BENCH/ altında, kanıt). demos/README.md tablosuna bir satır eklenir.
#
#   powershell -ExecutionPolicy Bypass -File .\tools\demo_library_add.ps1 -Project <bench proje klasörü> -Genre platformer -Title "Platformer"
#
# Demoyu açmak için: klasörü Godot'da aç, eklentiyi scripts/sync-example.ps1 ile bağla (ya da addons/'a kopyala).

param(
    [Parameter(Mandatory = $true)][string]$Project,
    [Parameter(Mandatory = $true)][string]$Genre,
    [string]$Title = "",
    [int]$Score = -1,
    [switch]$Force,
    [switch]$Latest   # son surum kuraldir: puan ve sabitleme bakilmaz; degisen eski surum archives/demos-replaced/ altina tasinir
)

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
$Lib = Join-Path $Repo "demos"
$Dest = Join-Path $Lib $Genre
if ([string]::IsNullOrWhiteSpace($Title)) { $Title = $Genre }
$bench = Join-Path $Project "_bench"
$result = Get-Content (Join-Path $bench "result.json") -Raw -Encoding UTF8 | ConvertFrom-Json
if ($result.status -ne "completed" -or -not $result.metrics.success) {
    throw "Demo başarılı değil (status=$($result.status)); kütüphaneye eklenmez."
}
# Kütüphanedeki sürüm daha yüksek puanlıysa değiştirilmez (çıkış kodu 3): yeni koşu eskisinden kötü olabilir.
# -Force: puan görünümü ölçmediği için elle "bu görsel olarak daha iyi" denen sürümü zorla koyar.
$scoreFile = Join-Path $Dest "BENCH\score.txt"
$pinFile = Join-Path $Dest "BENCH\pinned.txt"
if (-not $Force -and -not $Latest -and (Test-Path $pinFile)) {
    Write-Host "[demo_library] ${Genre}: elle seçilmiş sürüm sabit (BENCH/pinned.txt); değiştirilmedi."
    exit 3
}
if (-not $Force -and -not $Latest -and $Score -ge 0 -and (Test-Path $scoreFile)) {
    $old = [int](Get-Content $scoreFile -Raw).Trim()
    if ($old -gt $Score) {
        Write-Host "[demo_library] ${Genre}: kütüphanedeki sürüm ($old) yeninden ($Score) yüksek, değiştirilmedi."
        exit 3
    }
}
if (Test-Path $Dest) {
    # Hicbir basarili demo cope gitmez: yerine yenisi gelen eski surum archives/demos-replaced/ altina tasinir.
    $keep = Join-Path $Repo ("archives\demos-replaced\{0}-{1}" -f $Genre, (Get-Date -Format "yyyyMMdd-HHmmss"))
    New-Item -ItemType Directory -Force (Split-Path -Parent $keep) | Out-Null
    Move-Item $Dest $keep
}
New-Item -ItemType Directory -Force $Dest | Out-Null

$skip = @("addons", ".godot", "_bench", ".git")
Get-ChildItem -Force $Project | Where-Object { $skip -notcontains $_.Name } | ForEach-Object {
    Copy-Item -Recurse -Force $_.FullName (Join-Path $Dest $_.Name)
}
$proof = Join-Path $Dest "BENCH"
New-Item -ItemType Directory -Force $proof | Out-Null
Copy-Item (Join-Path $bench "prompt.txt"), (Join-Path $bench "result.json") $proof
if ($Force) { [IO.File]::WriteAllText((Join-Path $proof "pinned.txt"), "elle secildi (gorsel olarak daha iyi)", (New-Object System.Text.UTF8Encoding($false))) }
if ($Score -ge 0) { [IO.File]::WriteAllText((Join-Path $proof "score.txt"), "$Score", (New-Object System.Text.UTF8Encoding($false))) }
# Godot bu klasörü içe aktarmasın.
New-Item -ItemType File -Force (Join-Path $proof ".gdignore") | Out-Null

# Ekran görüntüsü (GitHub galerisi): projenin ilk kareleri, oyunun kendi viewport'undan (tools/game_shot.gd).
try {
    . (Join-Path $PSScriptRoot "find_godot.ps1")
    $godot = Resolve-GodotBin ""
    if ($godot) {
        $shot = Join-Path $Dest "screenshot.png"
        $ErrorActionPreference = "Continue"
        & $godot --path $Project -s (Join-Path $PSScriptRoot "game_shot.gd") -- $shot 1.5 2>&1 | Out-Null
        $ErrorActionPreference = "Stop"
    }
} catch { Write-Host "[demo_library] ekran görüntüsü alınamadı: $_" -ForegroundColor Yellow }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$readme = Join-Path $Lib "README.md"
if (-not (Test-Path $readme)) {
    $head = "# Demo kütüphanesi`n`nHer demo, boş bir projede tek bir istemle **Godot AI Sidebar ajanının kendisi** tarafından yazıldı (``tools/demo_bench.ps1``); insan eli değmedi. İstem ve ölçüm her demonun ``BENCH/`` klasöründe.`n`nAçmak için: klasörü Godot 4.7'de aç ve eklentiyi ``scripts/sync-example.ps1`` ile bağla.`n`n| Tür | İstem | Süre | Adım | Araç | Tarih |`n|---|---|---|---|---|---|`n"
    [IO.File]::WriteAllText($readme, $head, $utf8)
}
$prompt = (Get-Content (Join-Path $bench "prompt.txt") -Raw -Encoding UTF8).Trim()
$m = $result.metrics
$row = "| [$Title]($Genre/) | $prompt | $([Math]::Round($result.elapsed_s / 60, 1)) dk | $($m.used_steps) | $($m.tool_calls) | $(Get-Date -Format 'yyyy-MM-dd') |`n"
$lines = [IO.File]::ReadAllText($readme, $utf8) -split "`n" | Where-Object { $_ -notmatch "^\| \[.*\]\($([regex]::Escape($Genre))/\)" }
[IO.File]::WriteAllText($readme, (($lines -join "`n").TrimEnd() + "`n" + $row), $utf8)
& (Join-Path $PSScriptRoot "demo_gallery.ps1") | Out-Null
Write-Host "[demo_library] $Genre -> $Dest"
