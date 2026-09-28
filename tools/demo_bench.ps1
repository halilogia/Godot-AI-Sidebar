# Demo benchmark: boş yeni bir Godot projesi açar, istemi Godot AI Sidebar ajanına verir, bitince
# Everything export'unu ve özet sonucu toplar. Ajan kullanıcının config.json'ındaki sağlayıcı ve modelle
# çalışır (kota harcar); onay modu yalnız bu çalıştırmada bellekte Tam Otomatik olur.
#
#   powershell -ExecutionPolicy Bypass -File .\tools\demo_bench.ps1 -Prompt "platformer oyun demosu yap"
#   ... -Name platformer -TimeoutMin 25 -Root D:\bench
#
# Proje: <Root>\<tarih>-<Name>\ (varsayılan Root: Belgeler\ai_sidebar_bench); eklenti depodaki klasöre
# kopyalanır (yalıtım). Sonuç: <proje>\_bench\ (prompt.txt, export.md, export.json, result.json, editor.log).
# Oyunu sonra açıp F5 ile deneyebilirsin. Ekran gerekir (editör ve oyun penceresi açılır).

param(
    [Parameter(Mandatory = $true)][string]$Prompt,
    [string]$Name = "demo",
    [int]$TimeoutMin = 25,
    [string]$Root = "",
    [string]$GodotPath = "",
    [string]$Model = "",
    [string]$Provider = "",
    [string]$Reasoning = ""
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
# Eklentinin KOPYASI (junction değil): çalıştırma, depodaki testlerden (ConfigSafetyTests config.json'ı
# bozup geri yazar), çalışma sırasında yapılan kod değişikliklerinden ve kullanıcının ayarlarından yalıtılır.
# config.json da kopyalanır: sağlayıcı ve model kullanıcınınkiyle aynıdır.
Copy-Item -Recurse (Join-Path $Repo "addons\godot_sidebar_ai") (Join-Path $Project "addons\godot_sidebar_ai")
[IO.File]::WriteAllText((Join-Path $Out "prompt.txt"), $Prompt, $utf8)
# Profil verilmediyse listedeki İLK profil kullanılır: kullanıcı editörde başka bir profili etkinleştirmiş olsa da
# (config.json kopyalanır) benchmark sağlayıcısı belli olsun.
# Profil listesi: kopyadaki config'te (eski biçim) ya da kullanıcı düzeyi depoda (%APPDATA%\Godot\godot_ai_sidebar\providers.json).
function Get-Profiles([string]$cfgPath) {
    $c = [IO.File]::ReadAllText($cfgPath) | ConvertFrom-Json
    $list = @($c.provider_profiles) | ? { $_ }
    if ($list.Count -eq 0) {
        $store = Join-Path $env:APPDATA "Godot\godot_ai_sidebar\providers.json"
        if (Test-Path $store) { $list = @(([IO.File]::ReadAllText($store) | ConvertFrom-Json).provider_profiles) | ? { $_ } }
    }
    return $list
}
if (-not $Provider) {
    $firstProfile = @(Get-Profiles (Join-Path $Project "addons\godot_sidebar_ai\config.json"))[0]
    if ($firstProfile) { $Provider = [string]$firstProfile.id }
}
# -Provider: kopyadaki config'te bu adlı (ya da kimlikli) sağlayıcı profili etkin olur (Ayarlar → Sağlayıcı
# profilleri). Aynı demoyu 9Router ve doğrudan OpenRouter ile koşup sağlayıcı hatalarını ayırmak için.
if ($Provider) {
    $cfgPath = Join-Path $Project "addons\godot_sidebar_ai\config.json"
    $cfgObj = [IO.File]::ReadAllText($cfgPath) | ConvertFrom-Json
    $prof = @(Get-Profiles $cfgPath) | Where-Object { $_.name -eq $Provider -or $_.id -eq $Provider } | Select-Object -First 1
    if (-not $prof) {
        Write-Host "[demo_bench] Sağlayıcı profili yok: $Provider (Ayarlar → Sağlayıcı profilleri'nde ekleyin)." -ForegroundColor Red
        exit 1
    }
    foreach ($k in @("provider_type", "base_url", "api_key", "selected_model", "cached_models", "stream", "report_usage", "context_window", "vision_capable")) {
        if ($prof.PSObject.Properties[$k]) { $cfgObj | Add-Member -NotePropertyName $k -NotePropertyValue $prof.$k -Force }
    }
    $cfgObj.active_provider_id = $prof.id
    [IO.File]::WriteAllText($cfgPath, ($cfgObj | ConvertTo-Json -Depth 20), $utf8)
    Write-Host "[demo_bench] Sağlayıcı: $($prof.name) ($($prof.base_url))"
}
# -Reasoning low|medium|high: düşünen modellerin akıl yürütme çabası (yalnız kopyadaki config'te). Yavaş düşünen
# modeller her adımda dakikalarca düşünüp zaman aşımına giriyordu.
if ($Reasoning) {
    $cfgPath = Join-Path $Project "addons\godot_sidebar_ai\config.json"
    $rc = [IO.File]::ReadAllText($cfgPath) | ConvertFrom-Json
    $rc | Add-Member -NotePropertyName reasoning_effort -NotePropertyValue $Reasoning -Force
    [IO.File]::WriteAllText($cfgPath, ($rc | ConvertTo-Json -Depth 20), $utf8)
    Write-Host "[demo_bench] Akıl yürütme çabası: $Reasoning"
}
# -Model: yalnız kopyadaki config.json'da seçili model değişir (kullanıcının ayarı olduğu gibi kalır).
if ($Model) {
    $cfgPath = Join-Path $Project "addons\godot_sidebar_ai\config.json"
    $cfg = [IO.File]::ReadAllText($cfgPath)
    $cfg = [regex]::Replace($cfg, '"selected_model":\s*"[^"]*"', ('"selected_model": "' + $Model + '"'))
    # Model listesinde yoksa editör açılışta seçimi listenin ilk modeline çevirir (liste eski olabilir).
    $cfg = ([regex]'"cached_models":\s*\[').Replace($cfg, ('"cached_models": ["' + $Model + '", '), 1)
    [IO.File]::WriteAllText($cfgPath, $cfg, $utf8)
    Write-Host "[demo_bench] Model: $Model"
}

$log = Join-Path $Out "editor.log"
$errLog = Join-Path $Out "editor.err.log"
$timeoutSec = $TimeoutMin * 60
Write-Host "[demo_bench] $Project"
Write-Host "[demo_bench] İstem: $Prompt (zaman aşımı $TimeoutMin dk)"
$argsList = @("--path", "`"$Project`"", "--editor", "--", "`"--ai-sidebar-bench=$Out`"", "--ai-sidebar-bench-timeout=$timeoutSec")
# Model 9Router'ın liste uç noktasında görünmese de (ör. oc/...) çağrılabilir: editör listeyi yenileyince
# seçimi ilk modele çevirir; bench modeli açılıştan sonra kendisi yeniden yazar.
if ($Model) { $argsList += "--ai-sidebar-bench-model=$Model" }
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
