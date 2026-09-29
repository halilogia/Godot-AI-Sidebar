# Butun demo kosularinin (kutuphanede kalanlar ve eski surumler dahil) ekran goruntulerini alir ve
# archives/history/index.html sayfasinda tur tur listeler (yeniden eskiye; puan ve sure ile). Sayfa repoya girmez
# (archives/ gitignore'lu). Ekran goruntusu zaten varsa yeniden alinmaz.
#
#   powershell -ExecutionPolicy Bypass -File .\tools\demo_history.ps1

param([switch]$HtmlOnly)   # -HtmlOnly: ekran goruntusu almadan yalniz sayfayi yeniden kur

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

# Kutuphanede (demos/) duran surum: BENCH/result.json'u kosunun result.json'uyla ayni olan kosu.
$libHashes = @{}
foreach ($f in Get-ChildItem (Join-Path $Repo "demos") -Directory -ErrorAction SilentlyContinue) {
    $rj = Join-Path $f.FullName "BENCH\result.json"
    if (Test-Path $rj) { $libHashes[(Get-FileHash $rj -Algorithm MD5).Hash] = $f.Name }
}
$inLibrary = @{}
foreach ($r in $runs) {
    $rj = Join-Path $r.FullName "_bench\result.json"
    if ((Test-Path $rj) -and $libHashes.ContainsKey((Get-FileHash $rj -Algorithm MD5).Hash)) { $inLibrary[$r.Name] = $true }
}

$n = 0
foreach ($r in $runs) {
    $png = Join-Path $shots ($r.Name + ".png")
    if (-not $HtmlOnly -and -not (Test-Path $png) -and $godot -and (Test-Path (Join-Path $r.FullName "project.godot"))) {
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
[void]$html.AppendLine('<!doctype html><meta charset="utf-8"><title>Demo gecmisi</title><style>body{font-family:sans-serif;background:#12141c;color:#e8e8ee;margin:24px}h2{margin-top:36px;border-bottom:1px solid #333;padding-bottom:6px}.g{display:flex;flex-wrap:wrap;gap:14px}.c{width:300px}.w{position:relative}.c img{width:300px;display:block;border:1px solid #333;border-radius:6px;background:#000;cursor:zoom-in}.z{position:absolute;right:6px;top:6px;border:0;border-radius:50%;width:32px;height:32px;font-size:18px;line-height:32px;cursor:pointer;background:rgba(18,20,28,.8);color:#fff}.z:hover{background:#3b82f6}.star{position:absolute;left:6px;top:6px;background:#f5b301;color:#1a1400;font-weight:bold;font-size:12px;padding:3px 8px;border-radius:12px}.c.lib img{border:2px solid #f5b301}.pick{display:block;margin-top:4px;font-size:12px;color:#cfd;cursor:pointer}.pick input{vertical-align:middle;margin-right:4px}.c.sel img{outline:3px solid #22c55e}#bar{position:sticky;top:0;z-index:5;background:#0d0f16;border-bottom:1px solid #333;padding:10px 0;display:flex;gap:10px;align-items:center;flex-wrap:wrap}#bar button{background:#22c55e;color:#04140a;border:0;border-radius:6px;padding:8px 14px;font-weight:bold;cursor:pointer}#bar button.g{background:#2a2f3f;color:#dde}#cnt{color:#9ca}.c .t{font-size:12px;color:#aab;margin-top:4px}.no{width:300px;height:169px;display:flex;align-items:center;justify-content:center;text-align:center;padding:0 12px;box-sizing:border-box;border:1px dashed #444;color:#778;border-radius:6px;font-size:12px}#lb{position:fixed;inset:0;background:rgba(0,0,0,.88);display:none;align-items:center;justify-content:center;flex-direction:column;z-index:9;cursor:zoom-out}#lb.on{display:flex}#lb img{max-width:94vw;max-height:84vh;border-radius:8px;background:#000}#lb p{margin:12px 0 0;color:#dde;font-size:14px}#lb small{color:#889}</style><h1>Demo gecmisi (yeniden eskiye)</h1><div id="bar"><span id="cnt"></span><button id="dl">Secimi indir (secim.txt)</button><button class="g" id="cp">Panoya kopyala</button><button class="g" id="rs">Kutuphane secimine don</button></div><p style="color:#889">Buyutmek icin resme ya da sag ustteki buyutec simgesine tikla. Ok tuslari: onceki / sonraki. Esc ya da tik: kapat.</p><div id="lb"><img id="lbi"><p id="lbt"></p><small>&larr; &rarr; gez &nbsp; Esc kapat</small></div>')
foreach ($g in ($byGenre.Keys | Sort-Object)) {
    [void]$html.AppendLine("<h2>$g ($($byGenre[$g].Count) kosu)</h2><div class='g'>")
    foreach ($r in ($byGenre[$g] | Sort-Object Name -Descending)) {
        $stamp = $r.Name.Substring(0, 15)
        $key = "$($stamp.Substring(0,8))-$($stamp.Substring(9,4))-$g"
        $info = if ($scores.ContainsKey($key)) { $scores[$key] } else { "puan kaydi yok" }
        $when = "$($stamp.Substring(6,2)).$($stamp.Substring(4,2)) $($stamp.Substring(9,2)):$($stamp.Substring(11,2))"
        $png = Join-Path $shots ($r.Name + ".png")
        $isLib = $inLibrary.ContainsKey($r.Name)
        $star = if ($isLib) { "<span class='star'>&#9733; demos'ta</span>" } else { "" }
        $cls = if ($isLib) { "c lib" } else { "c" }
        $cap = $(if ($isLib) { "&#9733; " } else { "" }) + "$g - $when - $info"
        $img = if (Test-Path $png) { "<div class='w'><img class='s' src='shots/$($r.Name).png' data-cap='$cap'><button class='z' title='Buyut'>&#128269;</button>$star</div>" } else { "<div class='no'>ekran goruntusu yok (bu kosuda oynanabilir sahne olusmamis)</div>" }
        [void]$html.AppendLine("<div class='$cls' data-run='$($r.Name)' data-genre='$g' data-lib='$(if ($isLib) { 1 } else { 0 })'>$img<div class='t'>$when - $info</div><label class='pick'><input type='checkbox' class='pk'>demos'a koy</label></div>")
    }
    [void]$html.AppendLine("</div>")
}
[void]$html.AppendLine("<script>(function(){var K='demoPicks',P={};function load(){try{P=JSON.parse(localStorage.getItem(K)||'null')}catch(e){P=null}if(!P){P={};document.querySelectorAll('.c.lib').forEach(function(c){P[c.dataset.genre]=c.dataset.run})}}function save(){try{localStorage.setItem(K,JSON.stringify(P))}catch(e){}}function paint(){var n=0;document.querySelectorAll('.c').forEach(function(c){var on=P[c.dataset.genre]===c.dataset.run;c.classList.toggle('sel',on);c.querySelector('.pk').checked=on});for(var g in P)n++;var ch=0;document.querySelectorAll('.c.lib').forEach(function(c){if(P[c.dataset.genre]!==c.dataset.run)ch++});document.getElementById('cnt').textContent='Secili tur: '+n+' | kutuphaneden farkli: '+ch}function lines(){var o=[];for(var g in P)o.push(P[g]);return o.join(String.fromCharCode(10))+String.fromCharCode(10)}document.querySelectorAll('.c').forEach(function(c){c.querySelector('.pk').onchange=function(){if(this.checked)P[c.dataset.genre]=c.dataset.run;else if(P[c.dataset.genre]===c.dataset.run)delete P[c.dataset.genre];save();paint()}});document.getElementById('dl').onclick=function(){var a=document.createElement('a');a.href=URL.createObjectURL(new Blob([lines()],{type:'text/plain'}));a.download='secim.txt';a.click()};document.getElementById('cp').onclick=function(){navigator.clipboard.writeText(lines())};document.getElementById('rs').onclick=function(){localStorage.removeItem(K);load();paint()};load();paint()})();</script>")
[void]$html.AppendLine("<script>var L=[].slice.call(document.querySelectorAll('img.s')),lb=document.getElementById('lb'),lbi=document.getElementById('lbi'),lbt=document.getElementById('lbt'),cur=0;function show(i){cur=(i+L.length)%L.length;lbi.src=L[cur].src;lbt.textContent=L[cur].getAttribute('data-cap')+'  ('+(cur+1)+'/'+L.length+')';lb.className='on'}L.forEach(function(im,i){im.onclick=function(){show(i)};im.nextElementSibling.onclick=function(){show(i)}});lb.onclick=function(){lb.className=''};document.onkeydown=function(e){if(lb.className!=='on')return;if(e.key==='Escape')lb.className='';if(e.key==='ArrowRight')show(cur+1);if(e.key==='ArrowLeft')show(cur-1)}</script>")
[IO.File]::WriteAllText((Join-Path $out "index.html"), $html.ToString(), $utf8)
Write-Host "[demo_history] $($runs.Count) kosu -> $out\index.html"
