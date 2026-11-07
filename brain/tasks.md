# 📋 Godot AI Sidebar Görev Takibi (TASKS.md)

---

## 🚀 Aktif Sprint (v3.2)
- [/] **Core Docs Standardizasyonu:** KNOWLEDGE, TASKS ve SKILLS dosyalarının tamamlanması ve GitHub ile senkronizasyonu
- [ ] **Canlı Sahne İnceleme Geliştirmesi:** Çoklu viewport ve 3D kamera seçimlerinin ajana aktarımı
- [ ] **Shader Kodlama Asistanı:** VisualShader ve kod shader'ları için otomatik doğrulama

---

## ⏳ Backlog
- [ ] Godot 4.3+ AnimationMixer node desteği
- [ ] Gelişmiş NavMesh ve TileMapLayer (4.2+) otonom oluşturma kuralları
- [ ] Ajan için yerel ses/efekt önizleme kütüphanesi

---

## ✅ Tamamlananlar (v3.1)
- [x] Godot 4 editör paneli (Sidebar Dock UI) entegrasyonu
- [x] Cerrahi kod düzenleme ve sözdizimi doğrulaması
- [x] Çoklu soru-cevap ile netleştirme motoru
- [x] Canlı çalışan oyundan sahne hiyerarşisi okuma
- [x] Full Undo/Redo desteği


---

# 📋 Project Task Tracker (Godot AI Core)

Bu dosya, projenin canlı görev takibini, tamamlanan işleri ve sıradaki geliştirme adımlarını içerir.

---

## ✅ Tamamlanan Görevler (Done)

- [x] **Audit & Mimari Analiz:** v2.0 kod tabanının 14 boyutta derinlemesine denetimi ve puanlaması.
- [x] **Clean Architecture Refactor:** Katmanların ayrılması (`types`, `security`, `state`, `mutations`, `agent`, `providers`, `network`, `tools`, `ui`, `tests`).
- [x] **Security / PathPolicy:** Path traversal (`../`) engelleme ve `project.godot`, `.git/**`, `addons/godot_sidebar_ai/**` koruması.
- [x] **Merkezi Undo/Redo Servisi:** `AISidebarMutationService` ile 8 kritik sahne/düğüm operasyonunun (`add`, `delete`, `set_prop`, `connect`, `attach_script`, `reparent`, `rename`, `duplicate`) tamamının `EditorUndoRedoManager`'a bağlanması.
- [x] **Sağlayıcı Soyutlaması & Yetenekler:** `AISidebarAIProvider`, `AISidebarOpenAICompatibleProvider` ve `AISidebarAGYCLIProvider`.
- [x] **Saf Ağ Motoru:** `AISidebarNetworkManager` ile `HTTPRequest` yönetiminin Presentation katmanından sökülmesi, 9Router SSE akış ve soket kapanışı (`Status: 8`) kurtarması.
- [x] **Editör Zeminleme (Grounding) & Seçim Farkındalığı (Selection Awareness):** `AISidebarEditorStateSnapshot` ile aktif sahne, birincil seçili düğüm ve açık scriptin prompta enjekte edilmesi.
- [x] **Cerrahi Kod Düzenleme (`replace_file_content`):** Çok satırlı scriptlerde tüm dosyayı ezmek yerine aralık bazlı satır değişikliği ve ChangeSet görsel diff incelemesi.
- [x] **Sohbet & Kuyruk Yönetimi:** Enter/Shift+Enter mesajlaşma, FIFO Mesaj Kuyruğu (`Queued Messages`), `user://sidebar_ai_chats/` oturum kalıcılığı ve `AISidebarHistoryPanel`.
- [x] **Ajan Netleştirme / Soru Sorma (`ask_user`):** Belirsiz komutlarda `ClarificationCard` ile kullanıcıya interaktif soru sorma ve karar destek akışı.
- [x] **AI-Native UI Layout Telemetrisi (`inspect_ui_layout`):** `@edited_scene` ve `@sidebar` semantik hedefleri, konteyner taşma kontrolü (`UI_CONTAINER_OVERFLOW`) ve tema StyleBox analiz motoru.
- [x] **Merkezi Tasarım Sistemi (`AISidebarTheme`):** Slate & Midnight Dark semantik renk tokenları, tutarlı StyleBoxFlat factory metotları ve minimalist IDE rozetleri.
- [x] **Headless GDScript Derleme & Sahne Doğrulayıcı (`typecheck.ps1` & `tools/typecheck.gd`):** 113 GDScript ve 4 sahne dosyasının derleme bütünlüğünü headless olarak denetleme.
- [x] **Birim & Entegrasyon Test Güvencesi:** `tests/test_runner.gd` ile 54 test paketi ve 291 assertion'ın %100 geçmesi.

---

## ⏳ Aktif ve Sıradaki Görevler (Next)

- [ ] **Canlı Editör Ekran Görüntüsü ile UI Değerlendirmesi:**
  - Sidebar'ın Godot Editörü içindeki gerçek görsel kalitesinin, kontrastının ve layout boşluklarının ekran görüntüsü üzerinden incelenmesi.
- [ ] **Çalışma Zamanı Canlı Gözlem (Runtime Introspection):**
  - Oyun çalışırken canlı sahne ağacı ve ClassDB görsel sorgulama yetenekleri.

