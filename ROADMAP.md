# 🗺️ Godot AI Core Roadmap

Bu yol haritası, Godot AI Core'un **AI-native oyun geliştirme ortamı** vizyonu doğrultusundaki geliştirme aşamalarını ve hedeflerini içerir.

---

## 📍 Faz 1: Çekirdek Mimari, Güvenlik ve Temiz Temel (Tamamlandı ✅ - v2.0)

- [x] Clean Architecture ve katı SRP (1 Dosya = 1 İş) refaktörü.
- [x] Merkezi `EditorMutationService` ile %100 Undo/Redo (Ctrl+Z) sahne mutasyonu.
- [x] `AISidebarPathPolicy` ile Path traversal ve korumalı dosya kalkanı.
- [x] `AISidebarAIProvider` sağlayıcı soyutlaması (9Router, OpenRouter, Ollama uyumu).
- [x] UI katmanından `HTTPRequest` ve ağ mantığının tamamen sökülmesi.
- [x] `EditorStateSnapshot` ile dinamik editör zeminleme (grounding context).
- [x] Ajan durum makinesi (State Machine) ve Stagnation (sonsuz döngü) koruması.
- [x] Godot 4.7 headless test altyapısı ve 7 birim test paketi.
- [x] GNU GPL-3.0 lisansı ve Türkçe/İngilizce çift dil desteği.

---

## 📍 Faz 2: Görsel Diff & İnteraktif ChangeSet Onay Penceresi (Sırada ⏳)

- [ ] `ChangeSetDialog` görsel arayüzü (Yeşil eklenen satırlar `+`, Kırmızı silinen satırlar `-`).
- [ ] Kod ve sahne değişikliklerinde kullanıcıya "Uygula (Apply)" veya "Reddet (Reject)" seçeneği.
- [ ] Uygulanan değişikliklerin anında `EditorUndoRedoManager` geçmişine tek parça olarak işlenmesi.
- [ ] Dosya bazlı geri alma (Rollback) geçmişi paneli.

---

## 📍 Faz 3: Çalışma Zamanı Denetimi & Hata Ayıklama (Runtime Debugging)

- [ ] Oyun çalışırken canlı ClassDB ve Node ağacı sorgulama (`runtime_get_state`).
- [ ] Çalışma zamanı deterministik kare ilerletme (`runtime_freeze`, `runtime_step`).
- [ ] Çalışma zamanı hata yakalama (Runtime Stack Trace & Exception auto-recovery).
- [ ] Oyun esnasında girdi simülasyonu (`input_injection`).

---

## 📍 Faz 4: Görsel Yapay Zeka & Multimodal Viewport (Vision)

- [ ] Editör Viewport ve 2D/3D sahne ekran görüntüsü alma aracı (`take_viewport_screenshot`).
- [ ] Görsel modeller (Gemini Flash, Claude Sonnet vb.) için sahne görüntüsünü otomatik prompta ekleme.
- [ ] UI hizalama ve seviye tasarımı (Level Design) geri bildirimlerini görsel analiz etme.

---

## 📍 Faz 5: Doğrudan Sağlayıcı Genişletmeleri (Native Providers)

- [ ] `AnthropicProvider` (Doğrudan Claude `/v1/messages` akış desteği).
- [ ] `GeminiProvider` (Doğrudan Google AI Studio `/v1beta` akış desteği).
- [ ] `LocalOllamaProvider` (İnternetsiz, tamamen yerel çalışan LLM modelleri için tek tık yapılandırma).

---

## 📍 Faz 6: Genişletilmiş Motor Araçları (Extended Tool Ecosystem)

- [ ] **TileMap & Seviye Araçları:** Otomatik 2D/3D tilemap döşeme ve zindan üretimi.
- [ ] **AnimationPlayer & AnimationTree Araçları:** Kodla animasyon anahtarları ve blend tree kurulumu.
- [ ] **Shader Composer:** Canlı `.gdshader` üretimi, hata denetimi ve görsel materyal oluşturma.
- [ ] **Ses ve Fizik:** AudioStreamPlayer otomasyonu, 2D/3D RayCast ve Collision optimizasyonu.
