# Demo benchmark: boş yeni bir Godot projesi açar, istemi Godot AI Sidebar ajanına verir, bitince
# Everything export'unu ve özet sonucu toplar. Ajan kullanıcının config.json'ındaki sağlayıcı ve modelle
# çalışır (kota harcar); onay modu yalnız bu çalıştırmada bellekte Tam Otomatik olur.
#
#   powershell -ExecutionPolicy Bypass -File .\tools\demo_bench.ps1 -Prompt "platformer oyun demosu yap"
#   ... -Name platformer -TimeoutMin 25 -Root D:\bench
#
# Proje: <Root>\<tarih>-<Name>\ (varsayılan Root: Belgeler\ai_sidebar_bench); eklenti depodaki klasöre
# junction ile bağlıdır. Sonuç: <proje>\_bench\ (prompt.txt, export.md, export.json, result.json, editor.log).
# Oyunu sonra açıp F5 ile deneyebilirsin. Ekran gerekir (editör ve oyun penceresi açılır).

param(
    [Parameter(Mandatory = $true)][string]$Prompt,
    [string]$Name = "demo",
    [int]$TimeoutMin = 25,
    [string]$Root = "",
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "find_godot.ps1")
$GodotBin = Resolve-GodotBin $GodotPath
if (-not $GodotBin) {
    Write-Host "[demo_bench] Godot bulunamadı (-GodotPath ya da `$env:GODOT_BIN)." -ForegroundColor Red
    exit 1
}
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "ai_sidebar_bench" }
$slug = ($Name -replace '[^A-Za-z0-9_-]', '-')
$Project = Join-Path $Root ("{0}-{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $slug)
$Out = Join-Path $Project "_bench"
$utf8 = New-Object System.Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force $Out | Out-Null
# _bench içeriği Godot'ya içe aktarılmasın.
New-Item -ItemType File (Join-Path $Out ".gdignore") | Out-Null
$projectGodot = "config_version=5`n`n[application]`n`nconfig/name=`"$Name`"`nconfig/features=PackedStringArray(`"4.7`")`n`n[editor_plugins]`n`nenabled=PackedStringArray(`"res://addons/godot_sidebar_ai/plugin.cfg`")`n"
[IO.File]::WriteAllText((Join-Path $Project "project.godot"), $projectGodot, $utf8)
New-Item -ItemType Directory (Join-Path $Project "addons") | Out-Null
New-Item -ItemType Junction -Path (Join-Path $Project "addons\godot_sidebar_ai") -Target (Join-Path $Repo "addons\godot_sidebar_ai") | Out-Null
[IO.File]::WriteAllText((Join-Path $Out "prompt.txt"), $Prompt, $utf8)

$log = Join-Path $Out "editor.log"
$errLog = Join-Path $Out "editor.err.log"
$timeoutSec = $TimeoutMin * 60
Write-Host "[demo_bench] $Project"
Write-Host "[demo_bench] İstem: $Prompt (zaman aşımı $TimeoutMin dk)"
$argsList = @("--path", "`"$Project`"", "--editor", "--", "`"--ai-sidebar-bench=$Out`"", "--ai-sidebar-bench-timeout=$timeoutSec")
$p = Start-Process -FilePath $GodotBin -ArgumentList $argsList -PassThru -RedirectStandardOutput $log -RedirectStandardError $errLog
# Ajanın kendi zaman aşımı + kapanış payı.
if (-not $p.WaitForExit(($timeoutSec + 180) * 1000)) {
    $p.Kill()
    $p.WaitForExit()
    Write-Host "[demo_bench] Editör kapanmadı; öldürüldü." -ForegroundColor Red
}

$resultFile = Join-Path $Out "result.json"
if (-not (Test-Path $resultFile)) {
    Write-Host "[demo_bench] result.json yok: benchmark başlamadı. Log: $log" -ForegroundColor Red
    exit 1
}
$r = Get-Content $resultFile -Raw -Encoding UTF8 | ConvertFrom-Json
$m = $r.metrics
Write-Host ("[demo_bench] durum={0} ({1}) süre={2}s adım={3} araç={4} başarısız={5} yazılan={6}" -f $r.status, $r.detail, $r.elapsed_s, $m.used_steps, $m.tool_calls, $m.failed_tools, $m.files_written_count)
if ($m.completion_reason) { Write-Host "[demo_bench] neden: $($m.completion_reason)" }
Write-Host "[demo_bench] Export: $(Join-Path $Out 'export.md')"
exit 0
