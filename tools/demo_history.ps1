# Butun demo kosularinin (kutuphanede kalanlar ve eski surumler dahil) ekran goruntulerini alir ve
# archives/history/index.html sayfasinda tur tur listeler (yeniden eskiye; puan ve sure ile). Sayfa repoya girmez
# (archives/ gitignore'lu). Ekran goruntusu zaten varsa yeniden alinmaz.
#
#   powershell -ExecutionPolicy Bypass -File .\tools\demo_history.ps1

$ErrorActionPreference = "Continue"
$Repo = Split-Path -Parent $PSScriptRoot
$out = Join-Path $Repo "archives\history"
$shots = Join-Path $out "shots"
New-Item -ItemType Directory -Force $shots | Out-Null
. (Join-Path $PSScriptRoot "find_godot.ps1")
$godot = Resolve-GodotBin ""
$utf8 = New-Object System.Text.UTF8Encoding($false)

$runs = @()
foreach ($root in @((Join-Path $Repo "archives\bench-runs"), (Join-Path $env:USERPROFILE "Documents\ai_sidebar_bench"))) {
    if (Test-Path $root) { $runs += Get-ChildItem $root -Directory | Where-Object { $_.Name -match '^\d{8}-\d{6}-' } }
}
$runs = $runs | Sort-Object Name -Unique

# Puanlar demos/SCORES.md'den: "| yyyy-MM-dd HH:mm | tur | **puan** | durum | sure | ..."
$scores = @{}
$scoreFile = Join-Path $Repo "demos\SCORES.md"
if (Test-Path $scoreFile) {
    foreach ($l in [IO.File]::ReadAllLines($scoreFile, $utf8)) {
        if ($l -match '^\| (\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}) \| ([^|]+) \| \*\*(\d+)\*\* \| ([^|]+) \| ([^|]+) \|') {
            $scores["$($Matches[1])$($Matches[2])$($Matches[3])-$($Matches[4])$($Matches[5])-$($Matches[6].Trim())"] = "$($Matches[7]) puan, $($Matches[8].Trim()), $($Matches[9].Trim())"
        }
    }
}

$n = 0
foreach ($r in $runs) {
    $png = Join-Path $shots ($r.Name + ".png")
    if (-not (Test-Path $png) -and $godot -and (Test-Path (Join-Path $r.FullName "project.godot"))) {
        # Kosunun kopyasi uzerinde cekilir: koprü autoload'u (eklenti bu klasorde olmayabilir) cikarilir.
        $tmp = Join-Path $env:TEMP ("hist_" + $r.Name)
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
        Copy-Item $r.FullName $tmp -Recurse -Force -Exclude "_bench"
        $pg = Join-Path $tmp "project.godot"
        $lines = [IO.File]::ReadAllLines($pg) | Where-Object { $_ -notmatch '^GodotAIRuntimeBridge=' }
        [IO.File]::WriteAllLines($pg, $lines)
        & $godot --headless --path $tmp --import 2>&1 | Out-Null
        $p = Start-Process -FilePath $godot -ArgumentList @("--path", "`"$tmp`"", "-s", "`"$(Join-Path $PSScriptRoot "game_shot.gd")`"", "--", "`"$png`"", "1.5") -PassThru -WindowStyle Minimized
        if (-not $p.WaitForExit(40000)) { $p.Kill() }
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        $n++
    }
}
Write-Host "[demo_history] $n yeni ekran goruntusu"

$byGenre = @{}
foreach ($r in $runs) {
    $g = ($r.Name -replace '^\d{8}-\d{6}-', '')
    if (-not $byGenre.ContainsKey($g)) { $byGenre[$g] = @() }
    $byGenre[$g] += $r
}
$html = New-Object System.Text.StringBuilder
[void]$html.AppendLine('<!doctype html><meta charset="utf-8"><title>Demo gecmisi</title><style>body{font-family:sans-serif;background:#12141c;color:#e8e8ee;margin:24px}h2{margin-top:36px;border-bottom:1px solid #333;padding-bottom:6px}.g{display:flex;flex-wrap:wrap;gap:14px}.c{width:300px}.c img{width:300px;border:1px solid #333;border-radius:6px;background:#000}.c div{font-size:12px;color:#aab;margin-top:4px}.no{width:300px;height:169px;display:flex;align-items:center;justify-content:center;border:1px dashed #444;color:#778;border-radius:6px}</style><h1>Demo gecmisi (yeniden eskiye)</h1>')
foreach ($g in ($byGenre.Keys | Sort-Object)) {
    [void]$html.AppendLine("<h2>$g ($($byGenre[$g].Count) kosu)</h2><div class='g'>")
    foreach ($r in ($byGenre[$g] | Sort-Object Name -Descending)) {
        $stamp = $r.Name.Substring(0, 15)
        $key = "$($stamp.Substring(0,8))-$($stamp.Substring(9,4))-$g"
        $info = if ($scores.ContainsKey($key)) { $scores[$key] } else { "puan kaydi yok" }
        $when = "$($stamp.Substring(6,2)).$($stamp.Substring(4,2)) $($stamp.Substring(9,2)):$($stamp.Substring(11,2))"
        $png = Join-Path $shots ($r.Name + ".png")
        $img = if (Test-Path $png) { "<img src='shots/$($r.Name).png'>" } else { "<div class='no'>ekran goruntusu yok</div>" }
        [void]$html.AppendLine("<div class='c'>$img<div>$when - $info</div></div>")
    }
    [void]$html.AppendLine("</div>")
}
[IO.File]::WriteAllText((Join-Path $out "index.html"), $html.ToString(), $utf8)
Write-Host "[demo_history] $($runs.Count) kosu -> $out\index.html"
