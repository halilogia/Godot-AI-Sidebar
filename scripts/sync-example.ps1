# ==============================================================================
# Godot AI Core — Examples Proje Senkronizasyon ve Otomasyon Yöneticisi
# ==============================================================================
# Bu script, 'addons/godot_sidebar_ai' eklentisini 'examples/' altındaki oyun
# projelerine kopyalar, günceller veya canlı olarak izler (watch mode).
# ==============================================================================

param (
    [Parameter(Position = 0)]
    [string]$ProjectName = "",

    [switch]$All,
    [switch]$Watch,
    [switch]$Link,
    [string]$NewProject = ""
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

# Repo ana dizinini tespit et (scripts/ altındaysa bir üst klasöre çık, ana dizindeyse doğrudan kullan)
$CandidateRoot = $PSScriptRoot
if (Test-Path (Join-Path $CandidateRoot "addons\godot_sidebar_ai")) {
    $RepoRoot = $CandidateRoot
} elseif (Test-Path (Join-Path (Split-Path $CandidateRoot -Parent) "addons\godot_sidebar_ai")) {
    $RepoRoot = Split-Path $CandidateRoot -Parent
} else {
    $RepoRoot = Split-Path $CandidateRoot -Parent
}

$SourceAddonDir = Join-Path $RepoRoot "addons\godot_sidebar_ai"
$ExamplesDir = Join-Path $RepoRoot "examples"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   Godot AI Core - Example Proje Otomasyon Yöneticisi   " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Kaynak Eklenti Doğrulaması
if (-not (Test-Path $SourceAddonDir)) {
    Write-Host "HATA: Kaynak eklenti dizini bulunamadı: $SourceAddonDir" -ForegroundColor Red
    exit 1
}

# 2. Examples Klasörü Kontrolü
if (-not (Test-Path $ExamplesDir)) {
    New-Item -ItemType Directory -Path $ExamplesDir | Out-Null
    Write-Host "Bilgi: 'examples' klasörü oluşturuldu." -ForegroundColor Yellow
}

# Yardımcı Fonksiyon: project.godot içinde eklentiyi etkinleştir
function Enable-PluginInProject([string]$ProjectGodotPath) {
    if (-not (Test-Path $ProjectGodotPath)) { return }

    $content = [System.IO.File]::ReadAllText($ProjectGodotPath, [System.Text.Encoding]::UTF8)
    $pluginConfig = 'res://addons/godot_sidebar_ai/plugin.cfg'

    if ($content.Contains($pluginConfig)) {
        Write-Host "  [OK] Eklenti zaten 'project.godot' içinde etkin." -ForegroundColor Gray
        return
    }

    if ($content -match '(?ms)\[editor_plugins\].*?enabled=PackedStringArray\((.*?)\)') {
        $existing = $matches[1].Trim()
        $replacement = if ($existing.Length -gt 0) {
            "[editor_plugins]`nenabled=PackedStringArray($existing, `"$pluginConfig`")"
        } else {
            "[editor_plugins]`nenabled=PackedStringArray(`"$pluginConfig`")"
        }
        $content = [regex]::Replace($content, '(?ms)\[editor_plugins\].*?enabled=PackedStringArray\(.*?\)', $replacement)
    } elseif ($content.Contains('[editor_plugins]')) {
        $content = $content.Replace('[editor_plugins]', "[editor_plugins]`nenabled=PackedStringArray(`"$pluginConfig`")")
    } else {
        $content += "`n`n[editor_plugins]`n`nenabled=PackedStringArray(`"$pluginConfig`")`n"
    }

    [System.IO.File]::WriteAllText($ProjectGodotPath, $content, [System.Text.Encoding]::UTF8)
    Write-Host "  [OK] Eklenti 'project.godot' içine eklendi ve etkinleştirildi." -ForegroundColor Green
}

# Yardımcı Fonksiyon: Tek bir projeye senkronizasyon yap
function Sync-ToProject([string]$TargetProjectPath, [bool]$UseJunction = $false) {
    $projectName = Split-Path $TargetProjectPath -Leaf
    Write-Host "`n>> Projeye uygulanıyor: $projectName" -ForegroundColor Yellow

    $targetAddonsDir = Join-Path $TargetProjectPath "addons"
    $targetPluginDir = Join-Path $targetAddonsDir "godot_sidebar_ai"
    $projectGodot = Join-Path $TargetProjectPath "project.godot"

    if (-not (Test-Path $targetAddonsDir)) {
        New-Item -ItemType Directory -Path $targetAddonsDir | Out-Null
    }

    if ($UseJunction) {
        # NTFS Junction Modu (Canlı bağlantı)
        if (Test-Path $targetPluginDir) {
            $isJunction = (Get-Item $targetPluginDir).Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)
            if ($isJunction) {
                Write-Host "  [OK] Zaten junction bağlantısı mevcut." -ForegroundColor Green
            } else {
                Write-Host "  [!] Mevcut fiziksel klasör kaldırılıyor ve junction oluşturuluyor..." -ForegroundColor Yellow
                Remove-Item -Path $targetPluginDir -Recurse -Force
                New-Item -ItemType Junction -Path $targetPluginDir -Target $SourceAddonDir | Out-Null
                Write-Host "  [OK] Junction başarıyla bağlandı." -ForegroundColor Green
            }
        } else {
            New-Item -ItemType Junction -Path $targetPluginDir -Target $SourceAddonDir | Out-Null
            Write-Host "  [OK] Junction başarıyla bağlandı." -ForegroundColor Green
        }
    } else {
        # Fiziksel Kopyalama Modu (Robocopy ile hızlı ve config.json korumalı)
        $targetConfig = Join-Path $targetPluginDir "config.json"
        $hasExistingConfig = Test-Path $targetConfig

        if (-not (Test-Path $targetPluginDir)) {
            New-Item -ItemType Directory -Path $targetPluginDir | Out-Null
        }

        # Robocopy ile kopyala, eğer hedefte config.json varsa üzerine yazma
        $excludeFiles = @()
        if ($hasExistingConfig) {
            $excludeFiles += "config.json"
        }

        $roboArgs = @(
            $SourceAddonDir,
            $targetPluginDir,
            "/MIR",
            "/R:1",
            "/W:1",
            "/NFL",
            "/NDL",
            "/NJH",
            "/NJS"
        )
        if ($excludeFiles.Count -gt 0) {
            $roboArgs += "/XF"
            $roboArgs += $excludeFiles
        }

        & robocopy.exe @roboArgs | Out-Null

        # Eğer hedefte hiç config.json yoksa kaynaktan kopyala
        if (-not (Test-Path $targetConfig)) {
            $srcConfig = Join-Path $SourceAddonDir "config.json"
            if (Test-Path $srcConfig) {
                Copy-Item -Path $srcConfig -Destination $targetConfig -Force
                Write-Host "  [OK] Varsayılan config.json kopyalandı." -ForegroundColor Gray
            }
        } else {
            Write-Host "  [KORUNDU] Mevcut config.json (API ayarları) korundu." -ForegroundColor Gray
        }

        Write-Host "  [OK] Eklenti dosyaları senkronize edildi." -ForegroundColor Green
    }

    # project.godot'ta etkinleştir
    Enable-PluginInProject -ProjectGodotPath $projectGodot
}

# 3. Yeni Proje Oluşturma İsteği Varsa
if (-not [string]::IsNullOrWhiteSpace($NewProject)) {
    $newProjectPath = Join-Path $ExamplesDir $NewProject
    if (Test-Path $newProjectPath) {
        Write-Host "UYARI: '$NewProject' klasörü zaten mevcut!" -ForegroundColor Yellow
    } else {
        New-Item -ItemType Directory -Path $newProjectPath | Out-Null
        $newProjectGodot = Join-Path $newProjectPath "project.godot"
        $godotContent = @"
; Engine configuration file.
config_version=5

[application]
config/name="$NewProject"
config/features=PackedStringArray("4.7", "GL Compatibility")

[editor_plugins]
enabled=PackedStringArray("res://addons/godot_sidebar_ai/plugin.cfg")
"@
        [System.IO.File]::WriteAllText($newProjectGodot, $godotContent, [System.Text.Encoding]::UTF8)
        Write-Host "Yeni proje oluşturuldu: $newProjectPath" -ForegroundColor Green
    }
    Sync-ToProject -TargetProjectPath $newProjectPath -UseJunction $Link
    exit 0
}

# 4. Hedef Proje(leri) Belirleme
$targetProjects = @()

if ($All) {
    Get-ChildItem -Path $ExamplesDir -Directory | ForEach-Object {
        $pg = Join-Path $_.FullName "project.godot"
        if (Test-Path $pg) { $targetProjects += $_.FullName }
    }
    if ($targetProjects.Count -eq 0) {
        Write-Host "HATA: 'examples/' altında project.godot içeren proje bulunamadı." -ForegroundColor Red
        exit 1
    }
} elseif (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
    $directPath = if ([System.IO.Path]::IsPathRooted($ProjectName)) { $ProjectName } else { Join-Path $ExamplesDir $ProjectName }
    if (-not (Test-Path $directPath)) {
        Write-Host "HATA: Belirtilen proje yolu bulunamadı: $directPath" -ForegroundColor Red
        exit 1
    }
    $targetProjects += $directPath
} else {
    # İnteraktif Seçim Menüsü
    $availableProjects = @()
    Get-ChildItem -Path $ExamplesDir -Directory | ForEach-Object {
        $pg = Join-Path $_.FullName "project.godot"
        if (Test-Path $pg) {
            $availableProjects += $_
        }
    }

    Write-Host "`n'examples' altında bulunan oyun projeleri:" -ForegroundColor White
    for ($i = 0; $i -lt $availableProjects.Count; $i++) {
        $pName = $availableProjects[$i].Name
        Write-Host "  [$($i + 1)] $pName" -ForegroundColor Cyan
    }
    Write-Host "  [N] Yeni bir örnek oyun projesi oluştur" -ForegroundColor Green
    Write-Host "  [A] Tüm projelere senkronize et" -ForegroundColor Magenta
    Write-Host "  [Q] Çıkış" -ForegroundColor Gray

    $choice = Read-Host "`nLütfen bir seçim yapın"

    if ($choice -match '^[Qq]$' -or [string]::IsNullOrWhiteSpace($choice)) {
        Write-Host "İşlem iptal edildi." -ForegroundColor Gray
        exit 0
    } elseif ($choice -match '^[Aa]$') {
        $availableProjects | ForEach-Object { $targetProjects += $_.FullName }
    } elseif ($choice -match '^[Nn]$') {
        $projName = Read-Host "Yeni proje adı (ör: space-shooter)"
        if ([string]::IsNullOrWhiteSpace($projName)) {
            Write-Host "Proje adı boş olamaz." -ForegroundColor Red
            exit 1
        }
        $newProjectPath = Join-Path $ExamplesDir $projName
        New-Item -ItemType Directory -Path $newProjectPath | Out-Null
        $newProjectGodot = Join-Path $newProjectPath "project.godot"
        $godotContent = @"
; Engine configuration file.
config_version=5

[application]
config/name="$projName"
config/features=PackedStringArray("4.7", "GL Compatibility")

[editor_plugins]
enabled=PackedStringArray("res://addons/godot_sidebar_ai/plugin.cfg")
"@
        [System.IO.File]::WriteAllText($newProjectGodot, $godotContent, [System.Text.Encoding]::UTF8)
        Write-Host "Yeni proje oluşturuldu: $newProjectPath" -ForegroundColor Green
        $targetProjects += $newProjectPath
    } elseif ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $availableProjects.Count) {
            $targetProjects += $availableProjects[$idx].FullName
        } else {
            Write-Host "Geçersiz seçim!" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Geçersiz giriş!" -ForegroundColor Red
        exit 1
    }
}

# 5. Senkronizasyonu Çalıştır
foreach ($proj in $targetProjects) {
    Sync-ToProject -TargetProjectPath $proj -UseJunction $Link
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "İşlem tamamlandı!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green

# 6. Canlı İzleme (Watch Mode)
if ($Watch) {
    if ($targetProjects.Count -gt 1) {
        Write-Host "`nWatch modu yalnızca tek bir proje için çalıştırılabilir. İlk proje seçildi: $($targetProjects[0])" -ForegroundColor Yellow
    }
    $watchTarget = $targetProjects[0]
    $watchTargetPluginDir = Join-Path $watchTarget "addons\godot_sidebar_ai"

    Write-Host "`n[CANLI İZLEME AKTİF] 'addons/godot_sidebar_ai' klasöründeki değişiklikler anında aktarılıyor..." -ForegroundColor Cyan
    Write-Host "Durdurmak için Ctrl+C tuşlarına basın.`n" -ForegroundColor Gray

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $SourceAddonDir
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    $action = {
        param($source, $eventArgs)
        $relPath = $eventArgs.FullPath.Substring($SourceAddonDir.Length).TrimStart('\', '/')
        if ($relPath -eq "config.json") { return }

        $destFile = Join-Path $watchTargetPluginDir $relPath
        $destDir = Split-Path $destFile -Parent

        try {
            if ($eventArgs.ChangeType -eq "Deleted") {
                if (Test-Path $destFile) { Remove-Item $destFile -Force }
                Write-Host "[SİLİNDİ] $relPath" -ForegroundColor Red
            } else {
                if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                Start-Sleep -Milliseconds 100
                Copy-Item -Path $eventArgs.FullPath -Destination $destFile -Force
                Write-Host "[GÜNCELLENDİ] $relPath" -ForegroundColor Green
            }
        } catch {
            # Dosya kilitli olabilir
        }
    }

    Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
    Register-ObjectEvent $watcher "Created" -Action $action | Out-Null
    Register-ObjectEvent $watcher "Deleted" -Action $action | Out-Null

    while ($true) {
        Start-Sleep -Seconds 1
    }
}
