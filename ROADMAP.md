# 🗺️ Godot AI Core Roadmap

Bu yol haritası, Godot AI Core'un **AI-native oyun geliştirme ortamı** vizyonu doğrultusundaki geliştirme aşamalarını ve hedeflerini içerir.

---

## 📍 Faz 1: Çekirdek Mimari, Güvenlik ve Temiz Temel (Tamamlandı ✅)

- [x] Clean Architecture ve katı SRP (1 Dosya = 1 İş) refaktörü.
- [x] Merkezi `EditorMutationService` ile %100 Undo/Redo (Ctrl+Z) sahne mutasyonu.
- [x] `AISidebarPathPolicy` ile Path traversal ve korumalı dosya kalkanı.
- [x] `AISidebarAIProvider` sağlayıcı soyutlaması (9Router, OpenRouter, Ollama uyumu).
- [x] UI katmanından `HTTPRequest` ve ağ mantığının tamamen sökülmesi.
- [x] `EditorStateSnapshot` ile dinamik editör zeminleme (grounding context).
- [x] Ajan durum makinesi (State Machine) ve Stagnation (sonsuz döngü) koruması.
- [x] Godot 4.7 headless test altyapısı (45 test paketi / 192 assertion).
- [x] GNU GPL-3.0 lisansı ve Türkçe/İngilizce çift dil desteği.

---

## 📍 Faz 2: Cerrahi Kod Düzenleme, Diff & Güvenli Onay (Tamamlandı ✅)

- [x] `replace_file_content` ile 400 satırlık scriptlerde satır satır cerrahi değişiklik.
- [x] Satır bazlı Diff (`+` yeşil, `-` kırmızı) ve `ChangeSet` domain modeli.
- [x] Atomik GDScript syntax doğrulaması (diske bozuk kod yazılmasını engelleme).
- [x] Tek yüzeyli inline `ApprovalCard` onay/red kartları ve çift onay engeli.
- [x] Atomik Rollback (Undo) mekanizması.

---

## 📍 Faz 3: Canlı LLM SSE Streaming, @Mention & UX 2.0 (Tamamlandı ✅)

- [x] Gerçek zamanlı LLM SSE akışı ve canlı sohbet baloncuğu güncellemesi.
- [x] `@mention` ile proje dosyalarını ve sahne ağacı düğümlerini otomatik tamamlama.
- [x] `AISidebarContextCompactor` ile eski araç çıktılarını 1-2 satırlık özetlere dönüştürme (%70 token tasarrufu).
- [x] Chat panellerinde fareyle metin seçimi ve `Ctrl+C` kısayolu desteği.
- [x] **Enter = Send & Shift+Enter = Newline:** Doğal sohbet etkileşimi, çok satırlı girdi desteği ve @mention popup klavye koruması.
- [x] **Queued Messages (FIFO Sıralı Mesaj Kuyruğu):** AI çalışırken yeni görev gönderebilme, `Queued Messages (X)` UI paneli, tek tek iptal ve sıralı otomatik yürütme.
- [x] **Gelişmiş Chat Export 2.0 (`ChatExporter`):** İnsan ve AI dostu zengin Markdown & JSON hiyerarşisi, tool argümanları, diff ve telemetri ayrıştırma.
- [x] **Agent Clarification / Soru Sorma:** Kritik belirsizliklerde duraklayıp soru sorma (`ask_user`), `ClarificationCard` hızlı seçenekler (`[2D] [3D]`), serbest metin girişi ve kesintisiz devam etme.
- [x] **Chat Management & Geçmiş Kalıcılığı:** `+ New Chat`, `user://sidebar_ai_chats/` JSON persistence, `📚 History` arama & filtreleme paneli, güvenli sohbet değiştirme, yeniden adlandırma ve silme.

---

## 📍 Faz 4: Gerçek 9Router Protokol Uyumu & Canlı Teşhis (Tamamlandı ✅)

- [x] 9Router / Gemini 3.7 Flash `finish_reason: "stop"` + soket kapanışını (`Status: 8`) kayıpsız karşılama.
- [x] Windows `localhost` $\rightarrow$ `127.0.0.1` 30 saniyelik gecikme önleme mekanizması.
- [x] `tests/integration/test_real_9router_live.gd` ile canlı TTFT, chunk ve model doğrulaması.
- [x] Gizli API anahtarı yönetimi (`.env` ve ortam değişkeni güvenliği).

---

## 📍 Faz 5: Çalışma Zamanı Denetimi & Hata Ayıklama (Runtime Debugging & Healing) (Kısmen Tamamlandı 🔄)

- [x] `RuntimeObservation` ve `SourceMapper` ile çalışma zamanı stack trace haritalama.
- [x] Modelin runtime hatalarını otomatik düzeltmesi için `Self-Healing` döngüsü.
- [x] **Yerleşik Godot Debugger Köprüsü (EditorDebuggerPlugin + EngineDebugger):** `inspect_runtime_tree` ve `inspect_runtime_node` ile canlı hiyerarşi (Remote Scene Tree) ve güvenli özellik sorgulama (POC).
- [ ] Oyun çalışırken canlı ClassDB ve Node ağacı görsel sorgulama dock'u.
- [ ] Çalışma zamanı deterministik kare ilerletme (`runtime_freeze`, `runtime_step`).
- [ ] Oyun esnasında girdi simülasyonu (`input_injection`).

---

## 📍 Faz 6: Görsel Yapay Zeka & Multimodal Viewport (Vision) (Kod Tamamlandı / Manuel GUI Doğrulaması Bekliyor 🔄)

- [x] `VisionInput` ve multimodal Base64 OpenAI parça formatı.
- [x] Editör Viewport ve 2D/3D sahne ekran görüntüsü alma aracı (`take_viewport_screenshot`).
- [x] Pano (Clipboard) Görseli Desteği (`Ctrl+V`): Panodaki görüntüyü (`PrtScr` / `Win+Shift+S`) algılama, önizleme çipi, seans kalıcılığı ve hata anında ek koruma (P2 UX Fix).
- [x] Ajan döngüsünde görsel gözlemi modele otomatik `image_url` multimodal parçası olarak iletme (OpenAI-uyumlu sağlayıcılar için doğrulanmış).
- [ ] UI hizalama ve seviye tasarımı (Level Design) geri bildirimlerini görsel analiz etme.

---

## 📍 Faz 7: Genişletilmiş Motor Araçları & CLI Agent Desteği (Gelecek 🔮)

- [ ] **TileMap & Seviye Araçları:** Otomatik 2D/3D tilemap döşeme ve zindan üretimi.
- [ ] **AnimationPlayer Araçları:** Kodla animasyon anahtarları ve blend tree kurulumu.
- [ ] **Shader Composer:** Canlı `.gdshader` üretimi, hata denetimi ve görsel materyal oluşturma.
- [ ] **Headless CI/CD Agent:** CLI üzerinden otonom oyun testi ve kod refaktörü.

---

## 📍 Faz 8: AI-Native UI Telemetri, Statik Derleyici & Merkezi Tasarım Sistemi (Tamamlandı ✅)

- [x] **AI-Native UI Layout Telemetri Motoru (`inspect_ui_layout`):** `@edited_scene` ve `@sidebar` semantik hedefleri, efektif görünürlük filtreleri, kümülatif konteyner taşma kontrolü (`UI_CONTAINER_OVERFLOW`) ve tema özellik analizi.
- [x] **Headless Statik Tip & Sözdizimi Derleyicisi (`typecheck.ps1` & `tools/typecheck.gd`):** Godot'yu açmadan 1.5 saniyede 113 script ve 4 sahneyi denetleme; VS Code `Ctrl+Shift+B` derleme entegrasyonu.
- [x] **Merkezi `AISidebarTheme` Tasarım Sistemi:** Modern Dark Slate & Midnight Dark token mimarisi, dinamik aksan butonları, ghost butonlar, odak bordürleri ve minimalist durum göstergeleri.
- [x] **54 Test Paketi / 296 Assertion:** Headless test runner ile %100 yeşil birim ve entegrasyon test güvencesi.
