# Release devlog hook installer (Godot AI Sidebar)
#
# Bir projenin git deposuna "sürüm etiketi atılınca devlog klibini otomatik çek" kancasını kurar. Git'te etiket sonrası
# (post-tag) kancası yoktur; bu yüzden `reference-transaction` kancası kullanılır: refs/tags/v* ref'i yazıldığında
# game_clip.ps1 -Release <etiket> ayrı bir pencerede başlatılır. Her commit'te değil, yalnız `git tag v0.4` gibi bir etiketle.
#
#   .\install_release_hook.ps1 -Project "C:\...\GrandStrategy3D"            # kur
#   .\install_release_hook.ps1 -Project . -Remove                           # kaldır
#
# Kanca yalnız projede tools\devlog\clips.json varsa çalışır. Kapatmak için ortam değişkeni: DEVLOG_AUTO=0.
# Deneme: DEVLOG_DRY_RUN=1 git tag vdeneme  -> komutu .git\devlog_hook.log'a yazar, klip çekmez.

param(
    [string]$Project = ".",
    [switch]$Remove
)

$ErrorActionPreference = "Stop"
$projPath = Resolve-Path $Project -ErrorAction SilentlyContinue
if (-not $projPath -or -not (Test-Path (Join-Path $projPath.Path "project.godot"))) {
    Write-Host "[release_hook] HATA: project.godot bulunamadi: $Project" -ForegroundColor Red
    exit 1
}
$projDir = $projPath.Path
$gitDir = (git -C $projDir rev-parse --git-common-dir).Trim()
if (-not [System.IO.Path]::IsPathRooted($gitDir)) { $gitDir = Join-Path $projDir $gitDir }
$hooksDir = Join-Path $gitDir "hooks"
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
$hookPath = Join-Path $hooksDir "reference-transaction"
$clipScript = (Join-Path $PSScriptRoot "game_clip.ps1")

if ($Remove) {
    if (Test-Path $hookPath) { Remove-Item $hookPath -Force; Write-Host "[release_hook] Kaldirildi: $hookPath" -ForegroundColor Green }
    exit 0
}

if ((Test-Path $hookPath) -and -not ((Get-Content $hookPath -Raw) -match "sidebar-devlog-hook")) {
    Write-Host "[release_hook] HATA: $hookPath zaten baska bir kanca; uzerine yazilmadi." -ForegroundColor Red
    exit 1
}

$clipUnix = $clipScript -replace "\\", "/"
$projUnix = $projDir -replace "\\", "/"
$hook = @"
#!/bin/sh
# sidebar-devlog-hook: refs/tags/v* yazilinca devlog klibini baslatir (tools/install_release_hook.ps1)
[ "`$1" = "committed" ] || exit 0
[ "`${DEVLOG_AUTO:-1}" = "0" ] && exit 0
[ -f "$projUnix/tools/devlog/clips.json" ] || exit 0
while read old new ref; do
  case "`$ref" in
    refs/tags/v*)
      case "`$new" in 0000000000000000000000000000000000000000) continue ;; esac
      tag="`${ref#refs/tags/}"
      cmd="powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"$clipUnix\" -Project \"$projUnix\" -Release `$tag"
      if [ "`${DEVLOG_DRY_RUN:-0}" = "1" ]; then
        echo "`$(date '+%F %T') DRY `$cmd" >> "$($gitDir -replace '\\', '/')/devlog_hook.log"
      else
        echo "`$(date '+%F %T') START `$cmd" >> "$($gitDir -replace '\\', '/')/devlog_hook.log"
        ( nohup powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$clipUnix" -Project "$projUnix" -Release "`$tag" >> "$($gitDir -replace '\\', '/')/devlog_hook.log" 2>&1 & ) >/dev/null 2>&1
      fi
      ;;
  esac
done
exit 0
"@
[System.IO.File]::WriteAllText($hookPath, ($hook -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[release_hook] Kuruldu: $hookPath" -ForegroundColor Green
Write-Host "[release_hook] Artik 'git tag v<surum>' devlog klibini otomatik baslatir (kapatmak icin DEVLOG_AUTO=0)." -ForegroundColor Gray
