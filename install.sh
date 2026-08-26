#!/usr/bin/env bash
# Godot AI Core - Otomatik Kurulum Scripti (Bash)

set -e

echo "=================================================="
echo "   Godot AI Core - Otomatik Kurulum Yöneticisi   "
echo "=================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ADDON_DIR="$SCRIPT_DIR/addons/godot_sidebar_ai"

if [ ! -d "$SOURCE_ADDON_DIR" ]; then
    echo "❌ HATA: Kaynak eklenti klasörü bulunamadı: $SOURCE_ADDON_DIR"
    exit 1
fi

TARGET_PROJECT_PATH="$1"

if [ -z "$TARGET_PROJECT_PATH" ]; then
    read -p "Lütfen eklentiyi yüklemek istediğiniz Godot proje dizinini girin: " TARGET_PROJECT_PATH
fi

# Trim quotes
TARGET_PROJECT_PATH=$(echo "$TARGET_PROJECT_PATH" | tr -d '"' | tr -d "'")

if [ ! -d "$TARGET_PROJECT_PATH" ]; then
    echo "❌ HATA: Belirtilen hedef dizin bulunamadı: $TARGET_PROJECT_PATH"
    exit 1
fi

PROJECT_GODOT_FILE="$TARGET_PROJECT_PATH/project.godot"
if [ ! -f "$PROJECT_GODOT_FILE" ]; then
    echo "⚠️ UYARI: Hedef dizinde 'project.godot' dosyası bulunamadı."
fi

TARGET_ADDONS_DIR="$TARGET_PROJECT_PATH/addons"
mkdir -p "$TARGET_ADDONS_DIR"

echo "📦 Eklenti dosyaları kopyalanıyor..."
cp -R "$SOURCE_ADDON_DIR" "$TARGET_ADDONS_DIR/"
echo "✓ Dosyalar başarıyla kopyalandı."

# project.godot güncelleme
if [ -f "$PROJECT_GODOT_FILE" ]; then
    PLUGIN_CONFIG="res://addons/godot_sidebar_ai/plugin.cfg"
    if grep -q "\[editor_plugins\]" "$PROJECT_GODOT_FILE"; then
        if ! grep -q "$PLUGIN_CONFIG" "$PROJECT_GODOT_FILE"; then
            echo "⚙️  Eklenti 'project.godot' dosyasına ekleniyor..."
            # Basit ekleme
            sed -i.bak '/\[editor_plugins\]/a enabled=PackedStringArray("res://addons/godot_sidebar_ai/plugin.cfg")' "$PROJECT_GODOT_FILE" && rm -f "$PROJECT_GODOT_FILE.bak"
        fi
    else
        echo "" >> "$PROJECT_GODOT_FILE"
        echo "[editor_plugins]" >> "$PROJECT_GODOT_FILE"
        echo "" >> "$PROJECT_GODOT_FILE"
        echo "enabled=PackedStringArray(\"res://addons/godot_sidebar_ai/plugin.cfg\")" >> "$PROJECT_GODOT_FILE"
    fi
    echo "✓ Eklenti 'project.godot' içinde etkinleştirildi."
fi

echo "=================================================="
echo "🎉 KURULUM TAMAMLANDI!"
echo "=================================================="
