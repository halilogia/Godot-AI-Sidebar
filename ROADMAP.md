# 🗺️ Godot AI Core Roadmap

Bu yol haritası, Godot AI Core'un **AI-native oyun geliştirme ortamı** vizyonu doğrultusundaki geliştirme aşamalarını ve hedeflerini içerir.

> **Numaralandırma:** Buradaki "Faz N" **ürün** aşamalarıdır. Kod sağlığı işleri (refactor, sıkı tip kontrolü, i18n altyapısı) ayrı yürür ve [`docs/REFACTOR_PLAN.md`](docs/REFACTOR_PLAN.md) içinde **"Refactor Faz N"** olarak anılır. İki numara birbirine karıştırılmaz.

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
- [x] **Editör köprüsü + MCP:** v3.0'a taşındı (aşağıda).

---

## 📍 v3.x: Dış Ajan Platformu (Başladı 🚧, 2026-09-26)

Hedef: Claude Code gibi dış ajanlar (orkestratör) Godot editörünü eklentinin güvenli araç katmanı üzerinden kullanır; eklenti Godot'un "elleri ve gözleri" olur, terminal / web / git dış ajanda kalır. Sıra: önce köprü, sonra iş akışı (skills), en son gerçek ihtiyaç çıkarsa kendi orkestratörümüz (Companion).

### Çalışma modları

| Mod | Kim yönetir | Ne için | Durum |
|---|---|---|---|
| **1. Sidebar tek başına** | Eklentinin kendi ajanı (`AgentRunner`) | Editörden çıkmadan küçük / orta Godot işleri | Var (v2.x) |
| **2. Dış ajan (External Agent)** | Claude Code, Cursor, Codex, Antigravity… (MCP istemcisi) | Büyük projeler: araştırma, terminal, git, dosya yazımı dış ajanda; Godot'a özgü işler köprü üzerinden eklentide | **Yakın vadeli ana hedef** (v3.0 köprü var) |
| **3. Companion** | Kendi yerel orkestratörümüz (ayrı süreç) | Dış bir AI IDE kullanmak istemeyenler için bağımsız otonom geliştirme ortamı | **Ertelendi**; yalnız mod 2 gerçek kullanımda yetersiz kalırsa |

### Sorumluluk sınırı

* **Godot AI Sidebar (eklenti) = Godot uzmanı / editör çalışma zamanı:** sahne ağacı, düğüm mutasyonları ve `EditorUndoRedo`, sahne kaydı, oyunu çalıştırma / durdurma, runtime ağacı ve hataları, ekran görüntüleri, editör hataları, Godot'a özgü doğrulama, izin / yol politikaları.
* **Dış ajan (mod 2) veya Companion (mod 3) = geliştirme ortamı / orkestrasyon:** terminal, git, dosya sistemi, web ve dokümantasyon araştırması, GitHub, paket / bağımlılık işlemleri, asset indirme, uzun görev kuyruğu, proje hafızası, görev grafiği / milestone yönetimi, checkpoint / devam, LLM sağlayıcı yönetimi, MCP istemci koordinasyonu.
* **Kural:** Genel bilgisayar yetenekleri (terminal, tarayıcı, genel indirme, paket yöneticisi) eklentiye eklenmez; eklentiye yalnızca Godot'a özgü yetenekler girer. Örnekler: "Godot 4.7'de 20.000 province nasıl render edilir?" → dış ajan / Companion araştırır. "MapRoot altına ProvinceRenderer ekle" → eklenti (Undo/Redo ile). "Testleri çalıştır, git diff'e bak" → dış ajan / Companion. "Oyunu çalıştır, runtime ağacını ve ekranı incele" → eklenti.

### Companion (ertelendi — tasarım notu)

Ayrı bir yerel süreç; eklentiye aynı köprü üzerinden (bugünkü MCP uç noktası ya da onun arkasındaki basit Godot köprü protokolü) bağlanır, kendisi MCP istemcisi olur. Kapsamı yukarıdaki "geliştirme ortamı / orkestrasyon" listesidir. Başlatma koşulu: mod 2 ile gerçek bir projede (v3.2 benchmark) ölçülmüş eksikler (ör. oturumlar arası görev durumu kayboluyor, yüzlerce görevlik plan yönetilemiyor, otomatik milestone devamı gerekiyor). Tahminle değil, ölçülmüş ihtiyaçla yazılır; eklentinin köprüsü değişmeden kalır.

### Motor sürümü politikası

Geliştirme Godot **4.7.2-stable** üzerinde sürer. Godot 4.8 **stable** çıktığında (resmi tahmin 2026 Q4) bir kez uyumluluk değerlendirmesi yapılır: özellikle editör / eklenti API'si (dock yapısındaki değişiklikler), editör içi oyun görünümü ve eklentiye yarayacak yeni API'ler. Değerliyse taşınır ve sonra motor tabanı dondurulur; sonraki sürümler (4.9+) ancak somut bir ihtiyaç için izlenir. Fork bugünkü bir hedef değildir; ürün motorda değişiklik gerektirdiği gün değerlendirilir. (4.8 içeriğine dair notlar dış kaynaklıdır ve stable sürümle doğrulanacaktır.)


- [x] **v3.0 köprü MVP:** Editör içinde MCP Streamable HTTP uç noktası (`core/bridge/`), yalnız `127.0.0.1`, Bearer token, tarayıcı kökenli istek reddi, `/mcp on|off` komutu ve hazır `claude mcp add` komutu. Okuma, `validate_script`, `sync_project`, oyunu çalıştırma / durdurma, runtime hataları ve ağacı, ekran görüntüleri (21 araç). Her çağrı `ToolManager` + PermissionPolicy + PathPolicy'den geçer.
- [x] **v3.0 Claude Code bağlantı uyumluluğu:** Claude Code 2.1.226'nın kendi MCP istemcisi köprüye bağlandı (`claude mcp list` → ✔ Connected); `initialize` (2025-11-25) → `notifications/initialized` → `tools/list` akışı proxy kaydıyla doğrulandı (bkz. `docs/KNOWLEDGE.md`).
- [x] **v3.0 Claude Code uçtan uca kullanım (2026-09-26):** GUI'li editörde, boş bir oyun projesinde Claude Code modeli araçları kendisi çağırdı: `get_scene_tree` → `play_game` → `get_runtime_errors` → `take_runtime_screenshot` (görüntü modele ulaştı) → `stop_game`; dış ajanın kendi `Write` aracıyla yaz → `sync_project` → `validate_script` → çalıştır döngüsü de çalıştı (bkz. `docs/KNOWLEDGE.md`).
- [ ] **v3.0.x sahne araçları:** `add_node`, `set_node_property`, `instantiate_scene`, `save_scene` vb. dış ajana açılır; dış ajan için onay politikası (Full Auto'da bile değiştirici araçlarda editörde onay seçeneği) ve tek aktif yazıcı kuralı.
- [ ] **v3.1 Godot geliştirme skill'leri:** Claude Code için `SKILL.md` paketleri (özellik geliştirme, hata ayıklama, sahne yazımı, runtime doğrulama, proje başlatma) ve oyun reposunda `GAME_SPEC.md` / `DECISIONS.md` / `KNOWN_ISSUES.md` düzeni.
- [ ] **v3.2 benchmark:** Claude Code + köprüye tek istemle küçük bir grand strateji dikey kesiti (province haritası, 3 ülke, seçim, zaman akışı, basit ekonomi / savaş); eksikler ölçülür.
- [ ] **Sonra:** Claude Code plugin paketi (MCP + skills), diğer MCP istemcileri (Cursor, Codex, Antigravity), gerekirse kendi orkestratörümüz ve alt ajanlar (Faz 10).

---

## 📍 Faz 8: AI-Native UI Telemetri, Statik Derleyici & Merkezi Tasarım Sistemi (Tamamlandı ✅)

- [x] **AI-Native UI Layout Telemetri Motoru (`inspect_ui_layout`):** `@edited_scene` ve `@sidebar` semantik hedefleri, efektif görünürlük filtreleri, kümülatif konteyner taşma kontrolü (`UI_CONTAINER_OVERFLOW`) ve tema özellik analizi.
- [x] **Headless Statik Tip & Sözdizimi Derleyicisi (`typecheck.ps1` & `tools/typecheck.gd`):** Godot'yu açmadan 1.5 saniyede 129 script ve 4 sahneyi denetleme; VS Code `Ctrl+Shift+B` derleme entegrasyonu.
- [x] **Merkezi `AISidebarTheme` Tasarım Sistemi:** Modern Dark Slate & Midnight Dark token mimarisi, dinamik aksan butonları, ghost butonlar, odak bordürleri ve minimalist durum göstergeleri.
- [x] **55 Test Paketi / 331 Assertion:** Headless test runner ile %100 yeşil birim ve entegrasyon test güvencesi.

---

## 📍 Faz 9: Sidebar UX 3.0 (Tamamlandı ✅, 2026-09-25)

- [x] **Markdown:** Asistan cevaplarında ve plan kartında başlık, kalın, italik, kod, liste, alıntı; kod blokları tek kutu + eş genişlikli yazı tipi; metin BBCode enjekte edemez.
- [x] **Bekleme göstergesi:** İlk model yanıtına kadar akışta dönen ikon, bilinen aşama ve süre; uzun bekleyişte iptal ipucu.
- [x] **İkon sistemi:** Emoji yerine tek renkli Lucide SVG ikonları (`AISidebarStatusIcon`, boyanabilir SVG'ler).
- [x] **Durum doğruluğu:** Stop sonrası Paused rozeti kalıcı; thinking kartı cevabın üstünde ve kesilmeden; runtime kartı kısa hata satırı gösterir.
- [x] **README vitrini:** Gerçek arayüz bileşenlerinden üretilen ekran görüntüleri (`tools/readme_shots.gd`).

---

## 📍 Faz 10: Alt Ajanlar (Subagents) (Planlandı 🗓️)

Ana ajan, bir alt görevi kendi bağlamı, adım bütçesi ve kısıtlı araç seti olan bir alt ajana devreder; alt ajan ana ajana yalnızca kısa bir özet döner.

**Önkoşul:** Refactor Faz 2 — `AgentRunner` birden çok kez, birbirinden bağımsız oluşturulabilmeli (telemetri, bekleyen onay durumu ve yanıt işleme ayrılmış olmalı). Durum: kodda karşılandı (`AgentTelemetry`, `PendingInteraction`, `AgentHost`, `RunnerIndependenceTests`); `main`'e birleştirildi (PR #3); canlı 9Router doğrulaması yerelde bekliyor. Runtime sahipliği runner başına: Stop yalnızca o runner'ın başlattığı oyunu durdurur (`docs/REFACTOR_PLAN.md` bulgu #14). Runtime izleme durumu (tek oyun) hâlâ ortaktır.

- [ ] **`delegate_task` aracı:** Ana ajan alt görevi, hedef ve araç setiyle başlatır; sonuç tool result olarak döner (ham çıktı ana bağlama girmez).
- [ ] **Salt okuma ile başlangıç:** İlk sürümde alt ajanlar yalnızca okuma / arama / inceleme araçları kullanır. Sahne ve dosya yazımı ana ajanda kalır (Undo/Redo tek sıradan geçer; eşzamanlı yazıcı yok).
- [ ] **Uzman profiller:** Sahne inceleyici, proje araştırmacısı, test çalıştırıcı, kod inceleyici (her biri ayrı talimat + araç seti).
- [ ] **Bütçe ve güvenlik:** Alt ajan başına adım ve token sınırı, iptal (Stop tüm ağacı durdurur), PathPolicy ve PermissionPolicy aynen geçerli.
- [ ] **Arayüz:** Alt ajan çalışması ana akışta iç içe, katlanabilir bir activity grubu olarak görünür; transcript ve export'ta ayrı bölüm olarak yer alır (Chat Export invariantı, AGENTS.md §7).
- [ ] **Paralel araştırma (sonraki adım):** Birden çok salt okuma alt ajanı aynı anda.

