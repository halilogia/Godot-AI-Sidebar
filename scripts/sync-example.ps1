# ==============================================================================
# Godot AI Core — Oyun Projeleri Senkronizasyon ve Otomasyon Yöneticisi
# ==============================================================================
# Bu script, 'addons/godot_sidebar_ai' eklentisini hem 'examples/' altındaki hem de
# 'Belgeler' (Documents) klasöründeki Godot oyun projelerine kopyalar veya bağlar.
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
$DocsDir = [Environment]::GetFolderPath("MyDocuments")

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   Godot AI Core - Oyun Projesi Otomasyon Yöneticisi    " -ForegroundColor Cyan
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
    Write-Host "`n>> Projeye uygulanıyor: $projectName ($TargetProjectPath)" -ForegroundColor Yellow

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

# Yardımcı Fonksiyon: Tüm Godot Projelerini Tara (examples/ + Belgeler)
function Get-AllGodotProjects() {
    $list = @()

    # 1. examples/ Klasöründekiler
    if (Test-Path $ExamplesDir) {
        Get-ChildItem -Path $ExamplesDir -Directory | ForEach-Object {
            $pg = Join-Path $_.FullName "project.godot"
            if (Test-Path $pg) {
                $list += [PSCustomObject]@{
                    Name = $_.Name
                    Path = $_.FullName
                    Location = "Examples (Repo İçi)"
                    DisplayHint = "examples\$($_.Name)"
                }
            }
        }
    }

    # 2. Belgeler (Documents) Klasöründekiler (Derinlik: 2)
    if (Test-Path $DocsDir) {
        Get-ChildItem -Path $DocsDir -Directory -Depth 2 -ErrorAction SilentlyContinue | ForEach-Object {
            $pg = Join-Path $_.FullName "project.godot"
            if ((Test-Path $pg) -and ($_.FullName -ne $RepoRoot) -and ($_.FullName -ne (Join-Path $RepoRoot "examples"))) {
                # Zaten listede yoksa ekle
                $pFullName = $_.FullName
                $already = $list | Where-Object { $_.Path -eq $pFullName }
                if (-not $already) {
                    $relHint = if ($pFullName.StartsWith($DocsDir)) { "Documents" + $pFullName.Substring($DocsDir.Length) } else { $pFullName }
                    $list += [PSCustomObject]@{
                        Name = $_.Name
                        Path = $pFullName
                        Location = "Belgeler (Documents)"
                        DisplayHint = $relHint
                    }
                }
            }
        }
    }

    return $list
}

# 3. Yeni Proje Oluşturma
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

# 4. Projeleri Tara ve Hedef Belirle
$allProjects = Get-AllGodotProjects
$targetProjects = @()

if ($All) {
    if ($allProjects.Count -eq 0) {
        Write-Host "HATA: Ne 'examples/' altında ne de 'Belgeler' klasöründe Godot projesi bulunamadı." -ForegroundColor Red
        exit 1
    }
    $allProjects | ForEach-Object { $targetProjects += $_.Path }
} elseif (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
    # Doğrudan girilen isim veya yol kontrolü
    if ([System.IO.Path]::IsPathRooted($ProjectName) -and (Test-Path $ProjectName)) {
        $targetProjects += $ProjectName
    } else {
        # İsme göre eşleştir
        $matches = $allProjects | Where-Object { $_.Name -eq $ProjectName }
        if ($matches.Count -eq 1) {
            $targetProjects += $matches[0].Path
        } elseif ($matches.Count -gt 1) {
            Write-Host "`nBirden fazla '$ProjectName' adlı proje bulundu:" -ForegroundColor Yellow
            for ($m = 0; $m -lt $matches.Count; $m++) {
                Write-Host "  [$($m + 1)] $($matches[$m].Name) -> $($matches[$m].DisplayHint)" -ForegroundColor Cyan
            }
            $c = Read-Host "Lütfen hangisine uygulanacağını seçin (1-$($matches.Count))"
            $idx = [int]$c - 1
            if ($idx -ge 0 -and $idx -lt $matches.Count) {
                $targetProjects += $matches[$idx].Path
            } else {
                Write-Host "Geçersiz seçim!" -ForegroundColor Red
                exit 1
            }
        } else {
            # Bulunamadıysa examples altında ara
            $fallback = Join-Path $ExamplesDir $ProjectName
            if (Test-Path $fallback) {
                $targetProjects += $fallback
            } else {
                Write-Host "HATA: '$ProjectName' isimli proje ne 'examples/' içinde ne de 'Belgeler' altında bulunamadı." -ForegroundColor Red
                exit 1
            }
        }
    }
} else {
    # İnteraktif Menü
    Write-Host "`nBulunan Godot Oyun Projeleri:" -ForegroundColor White
    
    $examplesList = $allProjects | Where-Object { $_.Location -like "*Examples*" }
    $docsList = $allProjects | Where-Object { $_.Location -like "*Belgeler*" }

    $index = 1
    $indexedProjects = @{}

    if ($examplesList.Count -gt 0) {
        Write-Host "`n--- [Repo / Examples Klasörü] ---" -ForegroundColor DarkCyan
        foreach ($p in $examplesList) {
            Write-Host "  [$index] $($p.Name)  `t($($p.DisplayHint))" -ForegroundColor Cyan
            $indexedProjects[$index] = $p.Path
            $index++
        }
    }

    if ($docsList.Count -gt 0) {
        Write-Host "`n--- [Kullanıcı Belgeler / Documents Klasörü] ---" -ForegroundColor DarkGreen
        foreach ($p in $docsList) {
            Write-Host "  [$index] $($p.Name)  `t($($p.DisplayHint))" -ForegroundColor Green
            $indexedProjects[$index] = $p.Path
            $index++
        }
    }

    if ($allProjects.Count -eq 0) {
        Write-Host "  (Hiçbir Godot projesi bulunamadı)" -ForegroundColor Gray
    }

    Write-Host "`n--- [İşlemler] ---" -ForegroundColor White
    Write-Host "  [N] Yeni bir oyun projesi oluştur" -ForegroundColor Yellow
    if ($allProjects.Count -gt 0) {
        Write-Host "  [A] Bulunan tüm projelere senkronize et ($($allProjects.Count) proje)" -ForegroundColor Magenta
    }
    Write-Host "  [Q] Çıkış" -ForegroundColor Gray

    $choice = Read-Host "`nLütfen bir seçim yapın"

    if ($choice -match '^[Qq]$' -or [string]::IsNullOrWhiteSpace($choice)) {
        Write-Host "İşlem iptal edildi." -ForegroundColor Gray
        exit 0
    } elseif ($choice -match '^[Aa]$') {
        $allProjects | ForEach-Object { $targetProjects += $_.Path }
    } elseif ($choice -match '^[Nn]$') {
        $projName = Read-Host "Yeni proje adı (ör: space-shooter)"
        if ([string]::IsNullOrWhiteSpace($projName)) {
            Write-Host "Proje adı boş olamaz." -ForegroundColor Red
            exit 1
        }
        Write-Host "Nerede oluşturulsun?" -ForegroundColor White
        Write-Host "  [1] examples/ klasörü (Repo İçi)" -ForegroundColor Cyan
        Write-Host "  [2] Belgelerim (Documents) klasörü" -ForegroundColor Green
        $locChoice = Read-Host "Seçiminiz (Varsayılan: 1)"
        
        $baseDir = if ($locChoice -eq "2") { $DocsDir } else { $ExamplesDir }
        $newProjectPath = Join-Path $baseDir $projName

        if (Test-Path $newProjectPath) {
            Write-Host "UYARI: Bu konumda '$projName' zaten mevcut!" -ForegroundColor Yellow
        } else {
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
        }
        $targetProjects += $newProjectPath
    } elseif ($choice -match '^\d+$') {
        $num = [int]$choice
        if ($indexedProjects.ContainsKey($num)) {
            $targetProjects += $indexedProjects[$num]
        } else {
            Write-Host "Geçersiz seçim numarası!" -ForegroundColor Red
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
    Write-Host "Hedef: $watchTarget" -ForegroundColor White
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
