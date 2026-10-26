# 🧠 Godot AI Sidebar Mühendislik Hafızası (KNOWLEDGE.md)

Bu dosya, Godot AI Sidebar eklentisinin mimari kararlarını (ADR) ve Godot 4 editör entegrasyonu tuzaklarını (Gotchas) belgeler.

---

## 🏛️ Mimari Karar Kayıtları (ADR)

### [ADR-01] Yerleşik Godot Undo/Redo Entegrasyonu
- **Karar:** Yapay zekanın yaptığı her dosya ve sahne düzenlemesi `EditorUndoRedoManager` üzerinden kaydedilir.
- **Gerekçe:** Geliştiricinin `Ctrl+Z` ile ajanın yaptığı her değişikliği tek hamlede geri alabilmesini sağlamak; güvenliği kullanıcı kontrolünde tutmak.

### [ADR-02] Otonom Çalışma Zamanı Denetimi (Live Inspection)
- **Karar:** Editör içi WebSocket / Debugger IPC üzerinden çalışan oyun örneğiyle (running instance) çift yönlü telemetri kuruldu.
- **Gerekçe:** Ajanın sahnedeki canlı node hiyerarşisini ve runtime değişkenlerini görerek hata ayıklayabilmesi.

---

## ⚠️ Kritik Teknik Tuzaklar (Gotchas)

### [GOTCHA-01] Godot 4 GDScript Statik Tip Denetimi
- **Tuzak:** Headless modda statik analiz yaparken (`godot --headless --script ...`), döngüsel `class_name` referansları editör kilitlenmelerine yol açabilir.
- **Çözüm:** Tip referanslarında doğrudan `preload()` yerine güvenli tip açıklamaları ve zayıf referanslar (`WeakRef`) kullanılır.

### [GOTCHA-02] Dosya Sistemi Eşzamanlama (EditorFileSystem.scan)
- **Tuzak:** Diske yazılan `.gd` veya `.tscn` dosyaları anında sahne ağacında güncellenmezse editör eski önbelleği kullanabilir.
- **Çözüm:** Dosya diske yazıldıktan hemen sonra `EditorInterface.get_resource_filesystem().reimport_files()` veya `scan()` tetiklenir.
