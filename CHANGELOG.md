# 📝 Changelog

Tüm önemli değişiklikler bu dosyada kronolojik olarak listelenmektedir.

Biçim: [Keep a Changelog](https://keepachangelog.com/tr/1.0.0/), 
Sürümleme: [Semantic Versioning](https://semver.org/lang/tr/).

---

## [2.0.0] - 2026-08-26 (Godot AI Core Architecture Overhaul)

### 🌟 Eklenenler
* **Clean Architecture & Katı SRP:** Proje katmanlara ayrıldı (`types`, `security`, `state`, `mutations`, `agent`, `providers`, `network`, `tools`, `ui`, `tests`).
* **Merkezi Undo/Redo Servisi (`AISidebarMutationService`):** `add_node`, `delete_node`, `set_property`, `connect_signal`, `attach_script` ve `reparent_node` işlemlerine tam `EditorUndoRedoManager` desteği eklendi.
* **Güvenlik Kalkanı (`AISidebarPathPolicy`):** Path traversal (`../`) engellendi, `project.godot`, `.git/**` ve eklenti sistem dosyaları korumaya alındı.
* **Sağlayıcı Soyutlaması (`AISidebarAIProvider`):** OpenAI uyumlu modeller (`OpenAICompatibleProvider`), 9Router, OpenRouter, yerel Ollama ve LM Studio ile çalışacak şekilde ayrıştırıldı.
* **Bağımsız Ağ Motoru (`AISidebarNetworkManager`):** `HTTPRequest` düğümleri Presentation katmanından çıkarıldı, altyapı servisine taşındı.
* **Editör Zemin Bilgisi (`AISidebarEditorStateSnapshot`):** Aktif sahne adı, dosyası ve seçili düğümler prompt bağlamına otomatik eklendi.
* **Ajan Durum Makinesi (`AISidebarAgentRunner`):** `IDLE`, `PLANNING`, `EXECUTING`, `OBSERVING`, `VERIFYING`, `COMPLETED`, `ERROR`, `RECOVERING`, `CANCELLED` durumları ve Stagnation (tekrarlayan araç döngüsü) koruması eklendi.
* **Diff & ChangeSet Modeli (`AISidebarChangeSet`):** Kod değişiklikleri için satır satır diff üreten domain modeli eklendi.
* **Headless Birim Test Paketi (`tests/test_runner.gd`):** Godot 4.7 CLI üzerinden çalışan 7 test paketi ve 20 assertion eklendi.
* **GNU GPL-3.0 Lisansı:** Açık kaynak lisans dosyası (`LICENSE`) eklendi.

### 🔄 Değiştirilenler
* UI dock sahnesi (`chat_dock.tscn`) tamamen hafifletildi; içindeki ağ düğümleri kaldırıldı.
* Araçlar **Primitive** (`scene_tools`, `script_tools`, `editor_tools`) ve **Intent** (`game_intent_tools`) olarak ikiye ayrıldı.
* Tip dönüşüm mantığı `tool_base.gd` içinden alınıp bağımsız `type_parser.gd` sınıfına taşındı.
* `plugin.cfg` sürümü `2.0.0` olarak güncellendi.

### 🗑️ Kaldırılanlar
* Eski monolitik `core/tool_executor.gd` ve `core/tool_registry.gd` dosyaları silindi.
* `etheria` arşiv projesindeki eski eklenti kalıntıları temizlendi.

---

## [1.0.0] - 2026-08-20 (Initial Prototype)

### 🌟 Eklenenler
* Godot sol dock paneline yerleşen temel AI sohbet arayüzü.
* 9Router API entegrasyonu.
* Basit GDScript ve sahne oluşturma araçları.
* TR/EN dil desteği.
