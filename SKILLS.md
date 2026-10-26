# 📜 SKILLS.md — Godot AI Sidebar Geliştirici & Ajan Kuralları

Bu doküman, Godot AI Sidebar projesinde çalışan ajanlar ve geliştiriciler için mimari sınırları, GDScript standartlarını ve Definition of Done (DoD) kriterlerini tanımlar.

---

## 🎯 Temel İlkeler ve Sınırlar

- **Hedef Motor:** Godot 4.2+ ve GDScript 2.0.
- **Kesin Cerrahi Düzenleme:** GDScript dosyaları körlemesine baştan yazılmaz; yalnızca değiştirilecek fonksiyon veya blok cerrahi olarak düzenlenir.
- **Undo/Redo Zorunluluğu:** Editör üzerinde yapılan hiçbir değişiklik `UndoRedoManager` bypass edilerek gerçekleştirilemez.

---

## 🛠️ Mimari Kurallar

- **Headless Doğrulama:** Eklenen her yeni GDScript dosyası `godot --headless --check-only` ile sözdizimi ve tip hatalarına karşı doğrulanmalıdır.
- **UI & Core Ayrımı:** `addons/godot_ai_sidebar/ui/` yalnızca görsel bileşenleri içerir; iş mantığı ve yapay zeka istemcileri `addons/godot_ai_sidebar/core/` altında tutulur.

---

## ✅ Tamamlanma Kriteri (Definition of Done)

1. GDScript dosyaları statik tip uyarıları olmadan derlenmeli.
2. Editör eklentisi etkinleştirildiğinde hata fırlatmamalı (`plugin.cfg` geçerli olmalı).
3. `TASKS.md` güncellenmeli ve belgeler 200 satır sınırını aşmamalı.
