param (
    [string]$TargetProjectPath = ""
)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Godot AI Core - Otomatik Kurulum Yöneticisi   " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Kaynak Dizin Belirleme
$SourceAddonDir = Join-Path $PSScriptRoot "addons\godot_sidebar_ai"
if (-not (Test-Path $SourceAddonDir)) {
    Write-Host "HATA: Kaynak eklenti klasoru bulunamadi: $SourceAddonDir" -ForegroundColor Red
    exit 1
}

# 2. Hedef Proje Yolu Alma
if ([string]::IsNullOrWhiteSpace($TargetProjectPath)) {
    $TargetProjectPath = Read-Host "Lutfen eklentiyi yuklemek istediginiz Godot proje dizinini girin"
}

$TargetProjectPath = $TargetProjectPath.Trim('"', "'", " ")

if (-not (Test-Path $TargetProjectPath)) {
    Write-Host "HATA: Belirtilen hedef dizin bulunamadi: $TargetProjectPath" -ForegroundColor Red
    exit 1
}

$ProjectGodotFile = Join-Path $TargetProjectPath "project.godot"
if (-not (Test-Path $ProjectGodotFile)) {
    Write-Host "UYARI: Hedef dizinde 'project.godot' dosyasi bulunamadi." -ForegroundColor Yellow
}

# 3. Addons Klasörüne Kopyalama
$TargetAddonsParent = Join-Path $TargetProjectPath "addons"
$TargetAddonDir = Join-Path $TargetAddonsParent "godot_sidebar_ai"
Write-Host "`nEklenti dosyalari kopyalaniyor..." -ForegroundColor Yellow

if (-not (Test-Path $TargetAddonsParent)) {
    New-Item -ItemType Directory -Path $TargetAddonsParent | Out-Null
}

Copy-Item -Path $SourceAddonDir -Destination $TargetAddonsParent -Recurse -Force
Write-Host "Dosyalar basariyla kopyalandi." -ForegroundColor Green

# 4. project.godot İçinde Eklentiyi Otomatik Etkinleştirme
if (Test-Path $ProjectGodotFile) {
    Write-Host "`n'project.godot' yapilandiriliyor..." -ForegroundColor Yellow
    $content = [System.IO.File]::ReadAllText($ProjectGodotFile, [System.Text.Encoding]::UTF8)
    $pluginConfig = 'res://addons/godot_sidebar_ai/plugin.cfg'

    if (-not $content.Contains($pluginConfig)) {
        if ($content.Contains('[editor_plugins]')) {
            $content = $content.Replace('[editor_plugins]', "[editor_plugins]`r`nenabled=PackedStringArray(`"$pluginConfig`")")
        } else {
            $content += "`r`n`r`n[editor_plugins]`r`n`r`nenabled=PackedStringArray(`"$pluginConfig`")`r`n"
        }
        [System.IO.File]::WriteAllText($ProjectGodotFile, $content, [System.Text.Encoding]::UTF8)
        Write-Host "Eklenti 'project.godot' icine eklendi ve etkinlestirildi." -ForegroundColor Green
    } else {
        Write-Host "Eklenti zaten 'project.godot' icinde etkin." -ForegroundColor Green
    }
}

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "KURULUM BASARIYLA TAMAMLANDI!" -ForegroundColor Green
Write-Host "Godot Editoru ile projenizi actiginizda AI Asistani kullanima hazir olacaktir." -ForegroundColor White
Write-Host "==================================================" -ForegroundColor Green
