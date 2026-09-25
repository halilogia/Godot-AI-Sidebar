# Refactor Planı — Ertelenen Borcun Ödenmesi

> Durum: **Faz 1 tamamlandı ve `main`'e birleştirildi (2026-09-25)** · **Faz 2 (AgentRunner) tamamlandı ve `main`'e birleştirildi (2026-09-25, PR #3)**: canlı 9Router doğrulaması (yerel) ve editör duman testi sonradan yapılacak · Başlangıç: 2026-09-25 · Baz commit: `1af07d3` · **Faz 3 (diğer büyük dosyalar) tamamlandı (2026-09-26)**: 1 bölme, 3 bilinçli bırakma, 5 bug düzeltmesi
> Faz 1 kapanış ölçümü: typecheck 187/187 GDScript + 4/4 sahne ✅ · test_runner **610 assertion** ✅
> Baz ölçüm: typecheck 162/162 GDScript + 4/4 sahne ✅ · test_runner **553 assertion** ✅

> **Numaralandırma:** Bu belgedeki fazlar **refactor** fazlarıdır; başka belgelerde "Refactor Faz N" diye anılır. Ürün fazları (özellikler) `ROADMAP.md`'dedir ve ayrı numaralanır.

## Amaç

"1 dosya = 1 iş" kuralını gerçeğe dönüştürmek. En büyük iki dosya kuralı açıkça çiğniyor:

| Dosya | Satır | Fonksiyon | Sorun |
|---|---|---|---|
| `ui/docks/chat_dock.gd` | 2349 | 119 | ~9 ayrı sorumluluk tek dosyada |
| `core/agent/agent_runner.gd` | 1061 | 31 | ~30 telemetri değişkeni + 200 satırlık `_on_provider_response` |

**Kapsam dışı:** yeni özellik, UI görünüm değişikliği, davranış değişikliği.

## Değişmez Kurallar

1. **Refactor commit'i davranış değiştirmez.** Kod taşınır, mantık aynen kalır.
2. **Bulunan bug'lar ayrı commit'te düzeltilir**, testle birlikte ve refactor commit'lerine karıştırılmadan (bkz. "Okurken bulunanlar").
3. **Her adımdan sonra** typecheck + `test_runner` yeşil olmalı. Kırmızıysa adım geri alınır, yamanmaz.
4. **Testler iç üyelere dokunuyor** (ChatDock'un ~40 private üyesi: `_on_agent_text_received`, `_current_checklist`…). Taşınan her parça için ilgili testler yeni birime yönlendirilir; eski isimlere geçici delege bırakılmaz.
5. Yeni dosyalar `preload` ile bağlanır (headless kuralı), `AISidebar` önekini korur.
6. Çalışma biçimi (2026-09-25'ten itibaren, tek geliştirici): doğrulanmış küçük, atomik commit'ler doğrudan `main`'e push'lanır; dal / PR zorunlu değildir. Her commit'ten önce typecheck + tüm testler yeşil olmalı; kırmızı kod `main`'e gitmez (AGENTS.md §8.6). Faz 1–2 `refactor/*` dallarında yürütülüp PR #1–#3 ile birleştirildi.

## Faz 0 — Hazırlık (küçük, düşük risk)

- [x] `verify.ps1` + ortak `tools/find_godot.ps1`: typecheck + test_runner tek komutta, fail-closed (bozuk script ile exit 1 kanıtlandı). `-Live` ile canlı test.
- [x] Doküman tutarlılığı: README/README.tr/AGENTS'taki eski sayılar kaldırıldı veya güncellendi (76 suite / 553 assertion). CHANGELOG ve ROADMAP'teki geçmiş sayılar tarihçe olduğu için korunur. `docs/KNOWLEDGE.md` paylaşılan kaynak ilan edildi; `brain/` (git-ignored, Antigravity alanı) elle silinmedi.
- [x] AGENTS.md'ye §8 "Refactor Kuralları" ve §9 "Doküman Haritası".
- Not: `typecheck` yalnızca `addons/` ve `tests/`'i tarar; `scripts/` (demo) kapsam dışıdır.

## Faz 1 — ChatDock'un parçalanması

Sıra riske göre: saf/izole olanlar önce, sinyal akışının kalbi en son.

| Adım | Yeni birim | İçerik (başlangıçtaki satırlar) | Risk | Durum |
|---|---|---|---|---|
| 1.1 | `ui/docks/chat_dock_theme.gd` | `_apply_theme`, `_update_send_button_style` (270–397) | Çok düşük | ✅ `caaf041` |
| 1.2 | `ui/presenters/tool_presentation.gd` (static) | `_get_human_tool_title`, `_build_tech_details`, `_extract_tool_error`, `_screenshot_image_path`, `is_task_limit_error`, `format_limit_stop_reason` | Düşük | ✅ `7476583` |
| 1.3 | `ui/presenters/plan_checklist_tracker.gd` | Checklist eşleştirme + snapshot (1777–1864) — saf mantık, birim testi kolay | Düşük | ✅ `3b51c9b` (+8 test) |
| 1.4 | `ui/components/message_queue_panel.gd` + kuyruk modeli | FIFO kuyruk, UI, dispatch (415–457, 1480–1556) | Orta | ✅ `f7d7f79` (sahte testler gerçeğe çevrildi) |
| 1.5 | `ui/components/input_composer.gd` | Mention/slash autocomplete, klavye, görsel eki (459–527, 745–928) | Orta | ✅ `d83cfb4` (Test 1 gerçeğe çevrildi) |
| 1.6 | `ui/controllers/chat_export_actions.gd` | Export, Copy Chat, per-task copy, history export dialog (606–688, 972–1029) | Düşük | ✅ `1c81cec` (+5 test) |
| 1.7 | `ui/controllers/chat_session_store.gd` | New/load/save/clear, history panel olayları, checkpoint/pause/resume (930–1097, 1338–1389, 1558–1577) | Orta-yüksek | ✅ (+8 test, bug #7 bulundu) |
| 1.8 | `ui/presenters/session_replay_renderer.gd` | `_rebuild_ui_stream_from_session` (1098–1180) | Orta | ✅ (+4 test; replay çökme bug'ı `826fc68` ile düzeltildi) |
| 1.9a | `ui/presenters/agent_stream_presenter.gd` | Cevap akışı (stream tamponu, zarf süzme, asistan balonu), thinking/reasoning kartları, bekleme sayacı + durum rozeti | Yüksek | ✅ |
| 1.9b | `ui/presenters/agent_activity_presenter.gd` | Activity grubu, tool satırları, doğrulama/runtime/debug, ekran görüntüsü önizlemesi, step progress | Yüksek | ✅ |
| 1.9c | `ui/presenters/agent_interaction_presenter.gd` | Soru, onay, plan, değişiklik kartları, diff ve undo | Orta | ✅ (+3 test: dock↔AgentRunner sinyal bağlantıları ilk kez test altında) |
| 1.10 | `ui/controllers/model_bar_controller.gd` | Model listesi (önbellek + provider), seçim kaydı, onay modu butonu. Provider kurulumu kompozisyon olarak ChatDock'ta kalır | Düşük | ✅ (+2 test; config.json test sonunda birebir geri yüklenir) |
| 1.11 | `ui/controllers/task_controller.gd` | Girişten gönderme (slash / kuyruk / devam et / yeni task), task başlatma ve devam, kuyruk dağıtımı, pause checkpoint + Paused rozeti, task bitişi ve hata orkestrasyonu | Yüksek | ✅ (önce `TaskDispatchTests` ile sabitlendi; Paused rozeti bug'ı bulundu ve ayrı commit'te düzeltildi) |

**İlerleme:** 2349 → 1415 satır (1.1–1.8) → 1238 (1.9a) → 1047 (1.9b) → 901 (1.9c) → 835 (1.10) → 606 (1.11). 1.9 tek dosya yerine üç birime bölündü (tek dosya ~550 satır ve birden çok sorumluluk olurdu); task bitişi/hata orkestrasyonu (oturum, kuyruk, görsel eki) ChatDock'ta kalır ve presenter API'lerini kullanır. 1.7'de kalıcı oturum durumu UI'sız `ChatSessionStore`'a taşındı; UI orkestrasyonu (akış temizleme, rozet, history paneli) bilinçli olarak ChatDock'ta kaldı. **Hedef:** ChatDock ≤ ~500 satır; yalnızca sahne bağlantısı + birimlerin kompozisyonu.
**Faz 1 kod durumu (1.11 sonrası):** 606 satır. Kalan içerik: sahne referansları ve alanlar, `_ready`'deki birim bağlamaları, provider kompozisyonu, dil/ikon yenileme ve sohbet gezinmesi (New / History yükle / Clear / karşılama kartı). Bunlar ChatDock'un kendi işi; daha fazla bölmek bağlama kodunu artırır, kazancı düşük. ~500 hedefi bilinçli olarak bu noktada bırakıldı. Faz 1'in kapanışı için kalan: editörde elle duman testi (aşağıdaki liste).
**Ara kontrol:** 1.1–1.6 kullanıcı tarafından editörde (yeni-oyun-projesi, junction) elle test edildi, sorun yok (2026-09-25).
**Faz sonu:** editörde elle duman testi (aşağıdaki kontrol listesi) — headless testler UI'ın gerçek hissini kanıtlamaz.

## Faz 1.1 — Harici inceleme sonrası temizlik (✅ 2026-09-25)

ChatGPT'nin PR #1 diff incelemesindeki dört madde koda karşı doğrulandı:

| Madde | Sonuç | Commit |
|---|---|---|
| Retry task hattını atlıyor | Doğru ve daha ciddi: slash komutunda modele düz "/analyze" gidiyordu | `30d4464` (+`TaskDispatchTests` T5) |
| `/help` kaydı kayboluyor | Doğru (bulgu #7) | `8d46dcb` (+`ChatSessionStoreTests` T5) |
| `verify.ps1 -Live` fail-closed değil | Doğru ve daha ciddi: canlı test her durumda `quit(0)` diyordu, 9Router kapalıyken sonsuza kadar asılıyordu | `e0f53b4` (sahte sunucu + PowerShell 7.5.3 ile 3 senaryo) |
| ChatDock altyapıyı (`network/`, `providers/`) doğrudan kuruyor | Doğru; `AGENTS.md` §3.1 ile çelişiyor | Faz 2.0'a alındı |

## Faz 2 — AgentRunner

**Başlangıç ölçümü (2026-09-25):** `core/agent/agent_runner.gd` 1061 satır · 56 alan · 20 sinyal · 35 fonksiyon. En büyük fonksiyonlar: `_on_provider_response` 201, `start_task` 71, `_finish_task` 52, `_build_changeset_for_tool` 45, `_run_next_step` 44, `approve_pending_action` 40. Alanların ~30'u telemetri sayacı/süresi, ~12'si bekleyen onay / soru / plan durumu. Runner'ı doğrudan kuran 26 test dosyası var.

**Kurallar (Faz 1'den):** Önce sabitleme testi, sonra taşıma. Her adımda typecheck + test_runner yeşil ve motor hata/uyarı profili aynı. Bulunan bug ayrı commit'te, kırmızıya dönen testle. Faz sonunda `verify.ps1 -Live` (artık fail-closed) yerelde koşulur.

| Adım | Yeni birim | İçerik | Risk | Durum |
|---|---|---|---|---|
| 2.0 | `core/agent/agent_host.gd` + `plugin.gd` kompozisyon kökü | Provider + NetworkManager oluşturma ChatDock'tan çıkar; ChatDock host'u enjekte alır. `AGENTS.md` §3.1 çelişkisi kapanır | Orta | ✅ (önce `ProviderCompositionTests` ile sabitlendi) |
| 2.1 | `core/agent/agent_telemetry.gd` | ~30 sayaç/süre alanı, `_record_tool_telemetry`, `_classify_telemetry_op`, `_record_category_time`, `_finish_task` içindeki metrik sözlüğü | Orta | ✅ (önce `AgentTelemetryTests` ile sabitlendi) |
| 2.2 | `core/agent/pending_interaction.gd` | Bekleyen onay / netleştirme / plan durumu ve onay-red geçişleri | Orta | ✅ (önce `PendingInteractionTests` ile sabitlendi) |
| 2.3 | — | `_on_provider_response` (201 satır) iç adımlara bölünür: parse → boş yanıt / retry → tool dispatch → tamamlama kapısı. Önce her dal için sabitleme testi | **Yüksek** | ✅ (önce `ProviderResponseTests`: 13 senaryoluk altın iz) |
| 2.4 | — | Bağımsızlık: iki `AgentRunner` aynı anda kurulup çalıştırılır (ayrı context, ayrı telemetri, birbirini etkilemez). Ürün Faz 10 (alt ajanlar) ve CLI / MCP köprüsünün önkoşulu | Orta | ✅ (`RunnerIndependenceTests`) |

**2.0 karar notu — factory değil, kompozisyon birimi + `plugin.gd` kökü.** Yalnızca bir `provider_factory` provider'ın `new` çağrısını gizlerdi; ChatDock yine provider'ı tutar, `models_fetched` / `readiness_changed` / `is_ready` / `supports_vision` / `fetch_models` / `stop_process` için doğrudan altyapıya konuşurdu. Bunun yerine `AISidebarAgentHost` (Node) NetworkManager, provider, context ve runner'ın sahibi oldu: provider seçimi (`create_provider`, ısıtmasız), yeniden kurulum (`rebuild_provider`: eski alt süreç durur, yeni provider bağlanır, ısıtılır, runner ona geçer) ve provider olaylarının aktarımı orada. `plugin.gd` host'u kurar ve dock'a `_ready`'den önce enjekte eder; ChatDock `attach_agent_host()` ile bağlanır. Sıra korunur: dock önce host sinyallerine bağlanır, sonra provider'ı kurdurur; böylece `pre_warm`'ın senkron "AGY hazırlanıyor" olayı rozete ulaşır. Isıtma, runner yeni provider'a geçmeden önce yapılır (eski koddaki sıra). Testlerde üç yerde elle kopyalanan dock bağlaması (`DockAgentWiringTests`, `TaskDispatchTests`, `tools/readme_shots.gd`) tek `attach_agent_host()` çağrısına indi; testler sahte provider'ı `host.set_provider()` ile bağlar.
**2.1 notu:** Telemetri alanları (`telemetry.*`) ve yardımcıları `AISidebarAgentTelemetry`'ye taşındı; runner olayları kaydeder (`begin/end_llm_step`, `begin/end_waiting`, `classify_op`, `record_category_time`, `record_tool`, `note_retry`), metrik sözlüğü `build_metrics` ile üretilir. Tamamlama kapısının girdileri olan `plan_was_approved`, `unrecovered_failures` ve `last_completion` karar durumudur, runner'da kaldı. `get_elapsed_s()` runner'ın genel API'si olarak kaldı (TaskController kullanır). Sabitleme testi mevcut kategori eşlemesini olduğu gibi kaydetti; `replace_file_content` ve `delete_file`'ın `file_time`'a eklenmediği görüldü ve ayrı commit'te düzeltildi (bulgu #13).
**2.2 notu:** Bekleyen karar verisi (`_pending_tool_*`, `_pending_change_set`, `_pending_clarification_*`, `_pending_plan*`) `AISidebarPendingInteraction`'a taşındı: `request_*` saklar, `take_*` bir kez tüketip temizler, `clear_*` temizler. Karar fonksiyonları (`approve_pending_action`, `reject_pending_action`, `submit_clarification_response`, `approve_plan`, `reject_plan`) runner'ın genel API'si olarak kaldı; durum kontrolü, bekleme süresi, context kaydı ve sinyaller orada. Temizlik kuralları korundu: yeni task ve Stop hepsini, task sonu yalnızca netleştirmeyi temizler. `_plan_phase_active` bir bekleyen karar değil plan fazı bayrağıdır (mutation guard ve araç şeması), runner'da kaldı. Gözlem (bug değil): netleştirme seçenek dizisi kopyalanmadan saklanıp temizlikte yerinde boşaltılıyor; aynı dizi `clarification_requested` ile karta da gidiyor. Kart butonlarını eklendiği anda kurduğu ve transcript `duplicate()` kaydettiği için bugün görünür etkisi yok; davranış aynen korundu.
**2.3 notu:** `_on_provider_response` 201 → ~27 satır. Parçalar: `_handle_empty_response` (boş yanıt / tek yeniden deneme), `_dispatch_tool_calls` (turdaki çağrılar, tur sonu tek `_run_next_step`), `_process_tool_call` (çağrı başına sıra: tekrar koruması → `ask_user` / `propose_plan` araya girişi → plan fazı engeli → icra), `_guard_stagnation`, `_request_clarification`, `_request_plan_approval`, `_block_plan_phase_mutation`, `_execute_tool_call` (telemetri, keşfedilen araçlar, onay beklemesi, sonuç + doğrulama) ve `_evaluate_completion` (tamamlama kapısı). Eski döngüdeki `return` / `continue` akışı `ToolCallFlow { NEXT, HALT }` ile açık hale geldi; `await` zinciri korundu (tool senkron biterse davranış birebir aynı, askıya alınırsa yanıt işleyicisi yine askıda kalır). Sabitleme: `ProviderResponseTests` 13 senaryoda sinyal/durum izi, context mesajları ve son durumu refactor öncesi koddan üretilmiş izlerle birebir karşılaştırır (adım sınırı, arayüz dili ve araç kaydı normalleştirildi). Sabitlenemeyenler: `play_game` / `restart_game` için `RUNNING_GAME` durumu (oyunu başlatırdı) ve tool beklenirken Stop (headless'ta tool'lar senkron biter); bu satırlar aynen taşındı. `tests/integration/test_planning_flow.gd` çıktısı baz commit ile birebir aynı.
**2.4 notu:** `RunnerIndependenceTests` aynı süreçte iki runner'ı iç içe çalıştırır. Kapsam: A soru beklerken B'nin tool çalıştırıp bitmesi; A onay, B plan beklerken çapraz kararların etkisiz kalması; aynı çağrının iki runner'da DUPLICATE sayılmaması; `search_tools` ile açılan araçların yalnızca kendi runner'ında açılması; Stop'un yalnızca kendi runner'ını durdurması; iki `AgentHost`'un ayrı NetworkManager / context / runner / model listesi taşıması. Testin paylaşımı gerçekten yakaladığı mutasyonla gösterildi: telemetri ortak (statik) yapılınca T1, tekrar imzası statik yapılınca T3 kırmızıya döner. Runner'ın kendi durumunda statik alan yok. Runner'ın dokunduğu paylaşılan durum yukarıdaki envanterdekilerle sınırlı; bunlardan runner'ı etkileyen tek gerçek bağ runtime izleme (bulgu #14; Stop artık yalnızca runner'ın kendi başlattığı oyunu durdurur).
Bilinen tek fark: `chat_dock.tscn` editörde eklentisiz, tek başına açılırsa artık provider kurmaz (eskiden `@tool` `_ready`'si AGY sürecini başlatmaya çalışırdı). Eklenti yolunda davranış aynı. Açık konu: dock ağaçtan çıkınca (ör. dock yuvası değişince) AGY süreci durdurulur ve `_ready` tekrar çalışmadığı için yeniden ısıtılmaz; bu eski davranıştır, korunmuştur.

**Paylaşılan (statik) durum envanteri:** `verification_pipeline` (`_validators`, `_engine_verifiers`), `permission_policy` (`_tool_risk_registry`), `slash_command_manager` (`_commands`) salt okunur kayıt defteri; paylaşılması sorun değil. `runtime_debugger` izleme durumu (`_is_monitoring`, log offset'leri, `_last_observation`) gerçekten paylaşılan: tek oyun örneği olduğu için anlamlı, ama alt ajanlar oyunu çalıştıramamalı (2.4'te test edilir). `ui_telemetry_tools._registered_sidebar_dock` tek dock referansı. `debugger_plugin.instance` tek `EditorDebuggerPlugin` referansı (runtime köprüsü; tek oyun örneğiyle aynı gerekçe). UI önbellekleri (`icon_helper` ikon/boya önbelleği, `markdown_renderer` regex ve yazı tipi) saf önbellektir, runner'la ilgisi yoktur.

Faz 2 sonunda canlı entegrasyon testi (`test_real_9router_live.gd`) de koşulur.

**Faz 2 kapanışı (2026-09-25):**

| Ölçüm (`core/agent/agent_runner.gd`) | Başlangıç | Son |
|---|---|---|
| Satır | 1061 | 853 |
| Alan (`var`) | 56 | 23 |
| Sinyal | 20 | 20 (genel API değişmedi) |
| Fonksiyon | 35 | 36 (büyük fonksiyonlar bölündü) |
| `_on_provider_response` | 201 satır | 24 satır |
| En büyük fonksiyon | `_on_provider_response` 201 | `_execute_tool_call` 53, `_build_changeset_for_tool` 45, `_run_next_step` 41, `start_task` 39 |

Yeni birimler: `core/agent/agent_host.gd` (2.0), `core/agent/agent_telemetry.gd` (2.1), `core/agent/pending_interaction.gd` (2.2). Yeni testler: `ProviderCompositionTests`, `AgentTelemetryTests`, `PendingInteractionTests`, `ProviderResponseTests`, `RunnerIndependenceTests`; hepsi taşımadan önce yazıldı ve mutasyonla (kodu kasıtlı bozarak) sınandı. Her adımdan sonra typecheck + test_runner yeşil, motor hata/uyarı profili baz ile birebir aynı; editör headless açılışında (eklenti yolu) provider seçimi, runner bağı ve hazırlık rozeti baz ile aynı; `tests/integration/test_planning_flow.gd` çıktısı baz ile aynı.
Commit'ler: `895db3f`, `e9ed3f2`, `a7528c4` (2.0) · `b34841b`, `e33e565` (2.1) · `25b4d02` (bulgu #13 düzeltmesi) · `a6491c9`, `7e327f7` (2.2) · `2520d57`, `c79fca9` (2.3) · `268e348` (2.4).
Bekleyen: (1) `verify.ps1 -Live` yerelde; bulut oturumunda `127.0.0.1:20128`'de 9Router yoktu (bağlantı reddedildi; canlı test fail-closed olarak `exit 1` döndü). Mock testleri gerçek ağ kanıtı değildir. (2) Editörde elle kısa duman testi: gönder / onay / plan / soru / Stop → devam et / ayarlardan provider değiştirme + Refresh. (3) #12 Faz 2 sonrası ayrı commit'te düzeltildi.

Faz 2, ROADMAP'teki ürün Faz 10'un (Alt Ajanlar) ve Faz 7'deki editör köprüsü / CLI / MCP işinin önkoşuludur: `AgentRunner` birden çok kez, birbirinden bağımsız oluşturulabilir hale gelmeli. Bu yüzden 2.1–2.3'te runner'ın global / statik duruma bağımlılığı da kaldırılır ve iki bağımsız runner'ın aynı anda çalıştığı bir test eklenir.

## Faz 3 — Diğer büyük dosyalar (önce değerlendirme)

`chat_exporter.gd` (806), `editor_tools.gd` (653), `scene_tools.gd` (652), `verification_pipeline.gd` (576). Satır sayısı tek başına sorun değildir; yalnızca birden fazla sorumluluk varsa bölünür. Her biri için kısa karar notu yazılır.

**Başlangıç ölçümü (2026-09-26, `bb29ef4`):** typecheck 195/195 + 4/4 sahne, test_runner 92 paket yeşil. 500 satırı geçen diğer dosyalar `agent_runner.gd` (871; Faz 2 kapanışında 853, fark #14 / #20 düzeltmeleri) ve `chat_dock.gd` (585; Faz 1'de bilinçli bırakıldı) Faz 1–2'de karara bağlandı, yeniden açılmadı.

| Dosya | Karar | Gerekçe |
|---|---|---|
| `core/chat/chat_exporter.gd` (806, 41 fn) | Olduğu gibi kalır | Tek iş: sohbet verisini export biçimine çevirmek. Gruplar (eski history Markdown'u, transcript Markdown'u gruplu/kronolojik, JSON + redaction, oturum adaptörleri) `_rx`, `_append_history_entry`, `_append_completion_section` gibi private yardımcıları paylaşır; bölmek dosyalar arası private bağ ve §7 `_` fallback'ini iki yere dağıtırdı. En büyük fonksiyon (`_append_transcript_event`, 122) event türleri üzerinde tek `match`'tir. Asıl borç export testlerindeki çakışmadır (Faz 3.5). |
| `core/tools/primitive/editor_tools.gd` (653, 23 fn) | Olduğu gibi kalır | "Bir araç ailesi = bir modül" düzeni (scene/script/ui_telemetry de böyle); %33'ü bildirimsel şema. Bölmek `tool_manager` yönlendirmesini ve LLM'e giden şema sırasını değiştirirdi. Tekrarlanan `is_playing` / debugger kontrolleri DRY konusudur ve mesaj metinleri birebir aynı değildir. |
| `core/tools/primitive/scene_tools.gd` (652, 22 fn) | Olduğu gibi kalır | Düğüm araçları `MutationService`'e ince sarmalayıcı; sahne dosyası yardımcılarını (`validate_scene_parse`, `confirm_active_scene`, `refresh_open_scenes`) ayırmanın tek kazancı `script_tools → scene_tools` bağını koparmak olurdu (~130 satır, 2 test dosyası). Asıl sorun boyut değil bulgulardı (#23–#25). |
| `core/verification/verification_pipeline.gd` (576, 18 fn) | **Bölündü** → 305 + `tscn_validator.gd` 282 | `validate_tscn_source` tek fonksiyonda 272 satır (%47): kendi bölüm durum makinesi ve regex'leriyle ayrı bir iş, kayıt defterine takılan bir doğrulayıcı. Kalan sorumluluklar (kayıt defteri, GDScript, batch sırası, düğüm/görsel doğrulama) "doğrulama boru hattı" kimliğinde. |

| Adım | Yeni birim | İçerik | Durum |
|---|---|---|---|
| 3.1 | — | TSCN sabitleme: 17 vaka (erişilebilir her hata kodu + geçen durumlar), tüm sonuç sözlüklerinin altın md5 izi (`TSCNVerificationTests` T7). Mutasyon: `[node]` sıra kontrolü gevşetilince ve bir mesaj değişince kırmızı | ✅ `7bdf87d` |
| 3.2 | `core/verification/tscn_validator.gd` | `validate_tscn_source` → `AISidebarTscnValidator.validate`; pipeline `tscn` / `tres` için yeni birimi kaydeder. Test yeni birime yönlendirildi, delege yok | ✅ |

**3.2 notu:** Gövde birebir taşındı; hata sözlükleri `fail_result()`'a çevrilmedi (o yardımcı `suggestion` / `line` anahtarlarını ekler, çıktı değişirdi). `VerificationStatus` enum'u pipeline'da kaldı; doğrulayıcı onu `const VerificationStatus = AISidebarVerificationPipeline.VerificationStatus` ile kullanır. Pipeline ↔ doğrulayıcı döngüsel preload'u Godot 4.7.2'de sorunsuz: altın iz taşıma sonrası birebir aynı. Motor hata/uyarı profili baz ile aynı.

**Faz 3 kapanışı (2026-09-26):** Dört adaydan biri bölündü, üçü gerekçesiyle bırakıldı. Değerlendirmede 6 bulgu (#21–#26) ve 8 gözlem çıktı; 5'i ayrı `fix` commit'lerinde, düzeltme olmadan kırmızı olan testlerle kapandı, #25 headless'ta kırmızı test yazılamadığı için açık (duman testine eklendi). Her commit öncesi typecheck + test_runner yeşil; motor profili tek istisnayla baz ile aynı: #21'in Test F'si kasıtlı derleme hataları basar (3 × `Expected parameter name`, 2 × `Preload file … does not exist`, 1 × `Could not resolve super class path`, 1 × `Static function "nope()" not found`), yeni tür yalnızca bunlar. Ağ / provider katmanına dokunulmadı; `verify.ps1 -Live` gerekmez.
Commit'ler: `7bdf87d` (3.1) · `fe8a211` (3.2) · `6185178` (#21) · `127a109` (#22) · `120d017` (#23) · `815cbf0` (#24) · `e5c6a69` (#26).

## Faz 3.5 — Test denetimi (Faz 1–2 bittikten sonra)

Refactor sürerken test silinmez: güvenlik ağı odur. Refactor sırasında yalnızca taşınan koda ait testler yeni birime yönlendirilir ve orada rastlanan sahte testler gerçeğe çevrilir. Faz 1–2 bitince:

- [ ] **Sahte testler:** Üretim kodunu çağırmayan, kendi yazdığı ifadeyi veya Array davranışını doğrulayan testler bulunur. Her biri ya gerçek koda bağlanır ya da silinir.
- [ ] **Export kümesi (7 paket, tek modül):** `copy_chat`, `copy_task_checklist`, `task_copy_order`, `everything_export`, `chat_exporter`, `export_coverage`, `history_export`. Örneğin `export_transcript_to_markdown` 4 ayrı pakette test ediliyor. Çakışanlar birleştirilir, gerçekten farklı senaryolar korunur.
- [ ] **Diğer olası çakışmalar:** telemetri (5 paket), streaming/SSE (4 paket), runtime/visual (8 paket) için aynı inceleme yapılır.
- [ ] **`tests/diagnostic/` (12 probe) ve runner dışındaki `test_reality_probe.gd`:** AGY donma araştırmasından kalan tek seferlik betikler. Hâlâ gereken tutulur ve belgelenir, gerisi silinir (git geçmişinde kalır).
- [ ] **Private üye bağımlılığı:** Testler, bileşenlerin genel API'si üzerinden yazılır. Refactor sonunda ChatDock'un iç üyelerine dokunan test kalmamalı.
- Ölçüt: assertion sayısı düşebilir. Hedef sayı değil, **her testin gerçek bir hatayı yakalayabilmesi**; şüpheli testler mutasyonla (mantığı kasıtlı bozarak) sınanır.

## Faz 4 — Borcun geri gelmesini önleme

- [ ] Satır bütçesi testi: `.gd` dosyası > 600 satırsa uyarı, > 900 ise test başarısız (istisna listesi açık yazılır).
- [ ] `ARCHITECTURE.md` yeni UI katmanlarını (components / presenters / controllers) anlatacak şekilde güncellenir.

### Faz 4.A — Sıkı GDScript kontrolü (`tsc --noEmit` benzeri)

Bugünkü `tools/typecheck.gd` her script'i derleyip sahneleri yükler: sözdizimi, eksik preload ve tipli değişkenlerde olmayan üye kullanımını yakalar. Yakalayamadıkları (25.09'da görüldü): tipsiz değişken üzerinden silinmiş metot çağrısı (`tests/diagnostic/` betikleri), sinyal–handler argüman sayısı, metin anahtarları, `tools/` klasörü. Hedef: TypeScript'teki `strict` + `noEmit` + CI akışının GDScript karşılığı.

- [ ] **4.A.1 Kapsam:** `tools/` taramaya eklenir. `scripts/` (demo) kapsam dışı kalır ve bu açıkça yazılır.
- [ ] **4.A.2 Araştırma (önce kanıt):** Godot 4.7'de (a) `debug/gdscript/warnings/*` uyarıları headless `reload()` sırasında çıktıya basılıyor mu, (b) eklenti klasörü için uyarıları kapatan ayar (4.x'te `exclude_addons`; adı 4.7'de doğrulanacak) nasıl kapatılır, (c) basılmıyorsa `--lsp-port` üzerinden LSP `publishDiagnostics` ile toplanabilir mi. Sonuç `docs/KNOWLEDGE.md`'ye yazılır.
- [ ] **4.A.3 Uyarı raporu:** `untyped_declaration`, `unsafe_method_access`, `unsafe_property_access`, `unsafe_call_argument`, `unsafe_cast` yalnızca `addons/godot_sidebar_ai` için açılır. Typecheck dosya başına uyarı sayısını raporlar; başarısız saymaz.
- [ ] **4.A.4 Cırcır (ratchet):** Dosya başına sayılar `tools/typecheck_baseline.json`'a yazılır. Bir dosyada sayı artarsa typecheck başarısız olur, azalırsa baseline güncellenir (TypeScript'e kademeli geçişteki yöntem).
- [ ] **4.A.5 Tip ekleme:** Önce yeni birimler (presenters / controllers) ve `core/agent`; `var runner = null` gibi alanlar tiplenir, `Callable` yerine mümkünse sinyal kullanılır.
- [ ] **4.A.6 Sıfırda sertleşme:** Bir dosya sıfıra inince uyarılar o dosya için hata seviyesine çekilir; sonunda tüm eklentide.
- [ ] **4.A.7 Tipin göremediğini test görür:** Sinyal bağlantı testleri (`DockAgentWiringTests` modeli) diğer bileşenlere yayılır; `preload` yollarının varlığı ve i18n anahtarları (Faz 5) statik taramayla kontrol edilir.
- [ ] **4.A.8 CI:** GitHub Actions'ta her PR'da Linux headless Godot ile typecheck + test_runner (`verify.ps1` eşdeğeri). `tsc --noEmit`'in CI'daki rolü.

## Faz 5 — i18n (i18next benzeri)

Durum (25.09 ölçümü): `AISidebarI18n` sözlüğü kod içinde; TR ve EN'de 69'ar anahtar, ikisi birebir eşit. Kod 43 anahtar kullanıyor, tanımsız anahtar yok, 28 anahtar kullanılmıyor. `ui/` içinde i18n'den geçmeyen yaklaşık 55 sabit `.text` / `.tooltip_text` ataması var ("Clarification Needed", "Activity", "Send"...); Türkçe arayüzdeki İngilizce metinlerin kaynağı bunlar. Varsayılan dil `tr`, eksik anahtarda TR'ye düşülür.

- [ ] **5.1 Kaynak dosyalar:** Metinler koddan `addons/godot_sidebar_ai/i18n/tr.json` ve `en.json` dosyalarına taşınır (i18next resource dosyaları gibi). İsteğe bağlı ad alanları (`chat.*`, `settings.*`, `cards.*`). `AISidebarI18n.get_text(key, params)` API'si korunur; çağıranlar değişmez.
- [ ] **5.2 Çoğul ve bağlam:** i18next'teki `_one` / `_other` son ekleri: `get_text("steps", {"count": n})` → `steps_one` / `steps_other`. Yedek zinciri: seçili dil → EN → anahtarın kendisi (eksik metin sessiz kalmaz).
- [ ] **5.3 Denetim testleri:** (a) TR/EN anahtar eşitliği, (b) kodda `get_text("x")` ile çağrılan her anahtarın tanımlı olması, (c) kullanılmayan anahtar raporu, (d) `{param}` yer tutucularının iki dilde aynı olması.
- [ ] **5.4 Sabit metin kuralı:** `ui/` içinde `.text = "..."` / `.tooltip_text = "..."` sabit atamalarını yakalayan test (eslint `i18next/no-literal-string` karşılığı), açık istisna listesiyle. Mevcut ~55 satır bu kurala göre taşınır.
- [ ] **5.5 Alternatif (değerlendirilecek):** Godot'nun yerleşik `TranslationServer` + CSV/PO (gettext) sistemi ve `tr()` / `tr_n()`. Artısı araç desteği (Poedit, Weblate); dikkat: editör eklentisi çevirileri oyun projesinin çevirileriyle karışmamalı. Godot 4.x'teki çeviri alanı (translation domain) desteği 4.7'de doğrulanıp karar notu yazılır.

## Okurken bulunanlar (ayrı commit, önce doğrulanacak)

0. ✅ **Düzeltildi (`d5efc41`) — Test runner açığı:** çalışma anında çöken bir paket `[PASS] Unknown (0/0)` sayılıyor, koşu yeşil kalıyordu. Artık FAIL. 1af07d3 bazında gizli çökme yoktu (doğrulandı).

1. ✅ **Düzeltildi (Faz 1.1) — Retry yolu task hattını atlıyordu:** `ErrorCard.retry_requested` doğrudan `runner.start_task(last_user_prompt)` çağırıyordu. Transcript'te yeni görev açılmıyor, checkpoint sıfırlanmıyor, mention çözülmüyordu; üstelik `last_user_prompt` ekrandaki metin olduğu için `/analyze` gibi slash komutlarında modele komutun ürettiği istem yerine düz "/analyze" gidiyordu. Artık `TaskController.retry_last_task()` son isteği (`last_request`: istem, görünen metin, görseller) normal `start_task_prompt` hattından başlatır. Test: `TaskDispatchTests` T5. (Harici inceleme: ChatGPT, 25.09.)
2. ✅ **Kaldırıldı — Ölü değişken:** `_stream_is_envelope` hiçbir yerde `true` yapılmıyordu.
3. **Tekrarlı kontrol:** `_resume_paused_task` içinde `current_session == null` iki kez kontrol ediliyor.
4. **Tema dışı renkler:** Kuyruk panelinde `Color(0.7, 0.7, 0.7)`, `Color(0.9, 0.4, 0.4)` gibi sabit renkler var (tema token'ı değil).
5. ✅ **Kaldırıldı — Ölü kod:** `report_task_stop` hiçbir yerden çağrılmıyordu (1.9b'de yeni birime taşınmadan önce silindi). `ToolPresentation.format_limit_stop_reason` yalnızca testte kullanılıyor; testli yardımcı olduğu için şimdilik korundu.
6. **Sahte testler (kalan):** `test_ui_ux_queue_and_input.gd` Test 10 hâlâ düz Array üzerinde çalışıyor. Benzer "kendi ifadesini test eden" testler için Faz 3'te tarama yapılacak.
7. ✅ **Düzeltildi (Faz 1.1) — Yerel slash komutları kayboluyordu:** `/help` gibi LLM'siz komutlar oturuma ekleniyor, hemen ardından `save()` mesajları context'ten yeniden kurduğu için siliniyordu. Karar: yerel komutlar `ChatSessionStore._local_entries` içinde `local: true` işaretiyle ayrı tutulur ve eklendikleri konuma göre (anchor) kayıtta araya yerleştirilir; yüklemede tekrar ayrılır, modele giden context'e hiç girmez (eski oturumlardaki `command` rolü de ayıklanır). Transcript tabanlı export'ta yer almazlar (transcript olayı değiller, UI-yerel); oturum mesajı tabanlı Copy Chat / History'de görünürler. Test: `ChatSessionStoreTests` T5.
8. ✅ **Düzeltildi (`826fc68`) — History replay çökmesi:** yanıtlanmış `ask_user` içeren oturum yüklenince replay var olmayan `card._input_container` alanında çöküyor, sonraki mesajlar/telemetri çizilmiyordu; kart ayrıca `_ready` iki kez çağrıldığı için çift kuruluyordu. Gerçek SceneTree probe'u ile kanıtlandı.
9. ✅ **Düzeltildi — `/clear` sohbeti temizlemiyordu:** yalnızca ajan context'ini sıfırlayıp ekrana "Agent çalışma hafızası sıfırlandı" balonu basıyor, eski sohbet ekranda ve kayıtta (base mesajlar) kalıyordu. Artık Clear butonuyla aynı yolu izler (`clear_chat` aksiyonu → `_on_clear_pressed`); bilgi balonu yok. Base sabitleme mekanizması tek kullanıcısı gittiği için `ChatSessionStore`'dan kaldırıldı. Testler: `SlashCommandTests` 9/9b, `ChatSessionStoreTests` T4.
10. ✅ **Düzeltildi — İki ayrı "düşünme" göstergesi:** her LLM turunda akışa "Düşünülüyor (Ns)..." yazan yer tutucu asistan balonu ekleniyordu. Modelin gerçek thinking kartı sonra geldiği için balonun altına düşüyor (düşünce cevabın altında görünüyordu); metinsiz tool turlarında balon akışta asılı kalıyordu. Baz commit `1af07d3`'te de vardı. Yer tutucu kaldırıldı. Ardından (kullanıcı geri bildirimi: ilk yanıta kadar ekran boş kalıyordu) balon olmayan bir `PendingIndicator` eklendi: akışın sonunda dönen ikon + bilinen aşama + süre, 15 sn sonra iptal ipucu; ilk hayat belirtisinde (thinking, metin, tool, kart, durum değişimi) kalkar, thinking kartı onun yerine oturur. Testler: `ReasoningUITests` T11–T15.
11. ✅ **Düzeltildi — Stop sonrası Paused rozeti görünmüyordu:** Stop → checkpoint yazılıp "Paused — Step x/y" gösteriliyor, ardından runner `IDLE`'a geçince rozet "● Hazır" ile eziliyordu; kullanıcı "devam et" seçeneğini göremiyordu. Baz commit `1af07d3`'te de aynı (worktree'de izlenerek doğrulandı). Artık boşta durumda devam ettirilebilir checkpoint varsa rozet Paused kalır. Görev gönderme hattı (gönder/kuyruk/durdur/devam/görsel/slash/kuyruk dağıtımı) 1.11 öncesi ilk kez sabitleme testleriyle kapsandı: `TaskDispatchTests` T1–T4.
12. ✅ **Düzeltildi — Slash komutları eklenmiş görseli iletmiyordu:** `submit_input` görsel ekini slash kontrolünden önce tüketiyor, `handle_slash_command` ise `run_agent` yolunda görseli `start_task_prompt` / kuyruğa geçirmiyordu: `/analyze` + görsel → görsel sessizce düşüyordu; `/help` + görsel → ek de siliniyordu (Faz 1 öncesinden). Karar (kullanıcı + harici inceleme): `action == "run_agent"` komutları (`/analyze`, `/inspect`, `/debug`, `/fix`, `/review`, `/explain`…) normal istemin kısayoludur; ekli görsel aynı hattan modele gider (ajan çalışıyorsa kuyruğa görselle girer, hata olursa Retry / ek geri yükleme normal yoldaki gibi). Yerel komutlar (`local_response`) ve bilinmeyen komut eki tüketmez, yerinde bırakır. `/clear` Clear butonuyla aynı yoldur (bulgu #9) ve Clear gibi eki de temizler; bu bilinçli olarak korundu. Test: `TaskDispatchTests` T3 (düzeltme olmadan kırmızı: `image_kept/image_sent/queued_image=false`).
13. ✅ **Düzeltildi (Faz 2.1'de bulundu) — `file_time` iki dosya aracını saymıyordu:** `replace_file_content` ve `delete_file` `file_ops` sayacına ekleniyor ama süreleri `file_time`'a eklenmiyordu (kategori süresi listesi eksikti; baz `1af07d3`'te de aynı). Telemetri kartındaki / export'taki dosya süresi eksik görünüyordu. Artık `file_ops` sayılan her dosya aracının süresi `file_time`'a girer. Test: `AgentTelemetryTests` T4 (düzeltme olmadan kırmızı: 140 ≠ 250).
14. ✅ **Düzeltildi (Faz 2.4'te bulundu) — Runner'ın Stop'u oyunu her durumda kapatıyordu:** `AgentRunner.stop()` koşulsuz `runtime_debugger.stop()` → `EditorInterface.stop_playing_scene()` çağırıyordu; oyunun sahibi hiçbir yerde tutulmuyordu (`play_game` / `stop_game` / `restart_game` her çağrıda geçici `RuntimeDebugger` kurar, izleme durumu statiktir). Kullanıcının F5 ile açtığı oyun ajan durdurulunca kapanıyordu; alt ajanlarda A'nın Stop'u B'nin oyununu kapatırdı. Karar: sahiplik runner örneğinde (`_owns_runtime`); yalnızca **başarılı** `play_game` / `restart_game` verir, başarılı `stop_game` alır; `start_task` sıfırlar, `resume_task` korur; Stop yalnızca sahipse oyunu durdurur. Runtime / debugger araçları ve ortak izleme durumu değişmedi. Bilinen sınırlama: aynı task içinde ajanın başlattığı oyunu kullanıcı elle kapatıp F5 ile yenisini açarsa, ajanın Stop'u yeni oyunu da kapatır (oturum kimliği izlenmiyor; kapsam dışı bırakıldı). Test: `RuntimeOwnershipTests` (düzeltme olmadan T1: oyunu başlatmamış runner'ın Stop'u debugger'ı durduruyordu, `stops=1`). Editörde gerçek kapanma headless'ta görülemez; duman testine eklendi.

## Faz 2 sonrası inceleme bulguları (PR #2 / #3 review, 2026-09-25)

Birleştirme sonrası açık kalan inceleme maddeleri; her biri önce kodla / testle doğrulandı, gerçek olanlar ayrı commit'te kapatıldı.

15. ✅ **Sağlamlaştırıldı — Emekli provider ortak NetworkManager'ı dinlemeye devam edebiliyordu:** `OpenAICompatibleProvider._init` kendini ortak NetworkManager'ın `request_completed` / `response_chunk_received` / `request_failed` sinyallerine bağlıyor, `AgentHost` provider değiştirirken yalnızca kendi aktarım bağlarını koparıyordu. Ölçüm: bugünkü üretim yolunda eski provider'a başka referans kalmadığı için serbest kalıyor ve bağlantılar kendiliğinden kopuyor (3 değişimden sonra her sinyalde 1 alıcı); eski provider herhangi bir yerde tutulursa alıcı 2'ye çıkıyor (aynı yanıt iki kez işlenir). Yani görünür bir hata değil, referans sayımına dayanan gizli bir kırılganlıktı. Düzeltme: `AISidebarAIProvider.dispose()` (varsayılan boş), OpenAI provider'da NetworkManager bağlarını koparır; `AgentHost` değiştirilen provider'ı emekliye ayırır. Test: `ProviderCompositionTests` T2 (düzeltme olmadan kırmızı: `nm_single=false`). Ayar kaydı sırasında süren istek konusu #20'de kapatıldı.

16. ✅ **Düzeltildi — Kuyruk dağıtımı başka bir görevle yarışıyordu:** `dispatch_next_queued()` öğeyi hemen kuyruktan çekip 50 ms sonra koşulsuz `start_task_prompt` çağırıyordu. Gerçek zamanlayıcılı SceneTree probe'uyla iki yolda yeniden üretildi: (a) hata sonrası 50 ms içinde Retry → Retry görevi transcript'te "cancelled", kuyruktaki istem kayboldu; (b) daha olası olanı: runner hatada `error_occurred` ve `task_completed`'i art arda yaydığı için `on_error` ve `on_task_completed` iki kez dağıtım yapıyor, kuyrukta ≥2 öğe varsa Q1 transcript'te "cancelled" (runner onu çalıştırırken), Q2'nin istemi hiç gönderilmeden kayboluyordu. Düzeltme: öğe başlatılacağı an çekilir (`_start_next_queued`); o anda runner çalışıyorsa veya kullanıcı durdurduysa öğe kuyrukta kalır, çalışan görev bitince dağıtılır. Yeni zamanlayıcı yapısı yok. Test: `TaskDispatchTests` T6 (düzeltme olmadan kırmızı: `queue=0 task=Q2`). Probe düzeltme sonrası: (a) Retry çalışıyor + Q1 kuyrukta, (b) Q1 çalışıyor + Q2 kuyrukta. Yan etki: Stop'tan hemen sonra (50 ms içinde) zamanlanmış dağıtım artık kuyruktaki öğeyi başlatmaz.

17. ✅ **Düzeltildi — Eski oturumlarda yerel komut yanıtı modele giriyordu:** Yayımlanmış v2.7.0 / v2.7.1'de `/clear`, önceki mesajları "base" listeye sabitleyip sonuna işaretsiz `{"role": "command"}` + `{"role": "assistant"}` yazıyor ve diske kaydediyordu (git geçmişinden doğrulandı; `run_agent` yolu `command` rolü yazmıyor, yani eski verideki her `command` yerel bir komuttur). Faz 1.1'deki `load_by_id` yalnızca `command`'ı ayırıyor, arkasındaki yerel yanıtı ("Agent çalışma hafızası sıfırlandı.") modele giden context'e koyuyordu. Düzeltme: işaretsiz `command`'ın hemen arkasındaki tool çağrısız `assistant` mesajı da yerel sayılır; ikisi `local: true` ile işaretlenir, bir sonraki kayıtta yeni formata geçer. Test: `ChatSessionStoreTests` T5 (düzeltme olmadan kırmızı: yanıt context'te).

18. **Yanlış alarm — `plugin.gd`'de `chat_dock: Control` üzerinden `chat_dock.agent_host` ataması (PR #3 incelemesi):** Godot 4.7'de yerel tipli (`Control`) değişken üzerinden betiğin kendi alanına atama dinamik olarak çözülür ve geçerlidir. Kanıt: typecheck `plugin.gd` dahil her script'i `reload() == OK` ile derliyor; aynı desen scratch probe'da (`var chat_dock: Control = …instantiate(); chat_dock.agent_host = host`) hatasız atıyor; editör headless açılışında NetworkManager'ın ebeveyni `GodotAIAgentHost` (host dock'a ulaşıyor). Statik uyarı yalnızca `debug/gdscript/warnings/unsafe_property_access` açılırsa çıkar (varsayılan kapalı; Faz 4.A konusu). Kod değiştirilmedi.
19. ✅ **Silindi — Kırık diagnostic probe'lar:** `tests/diagnostic/agy_send_path_probe.gd` ve `integrated_send_path_probe.gd` (ve `.uid`'leri) kaldırılmış ChatDock üyelerine erişiyordu (`_on_agent_*` Faz 1.9, `_start_task_prompt` / `_on_send_pressed` Faz 1.11, `provider` / `network_manager` / `_setup_provider` Faz 2.0); typecheck tipsiz erişimi yakalamadığı için sessizce kırıktı. İkisi de 22.09 "AGY 10 sn donma" araştırmasının tek seferlik ölçümleriydi; sorun AGY hazırlık durum makinesiyle çözüldü (`tests/integration/test_agy_readiness_scenarios.gd`). Karar (kullanıcı + harici inceleme): yeni mimariye taşımak yerine silindi; git geçmişinde duruyorlar. `agy_send_substep_probe.gd`'deki tarihsel atıf güncellendi. Kalan 10 probe'un değerlendirmesi Faz 3.5'te.

20. ✅ **Düzeltildi — Ayar kaydında süren istek yeni provider'a sızıyordu:** `_on_settings_saved` çalışan görevi kontrol etmeden provider'ı yeniden kuruyordu; NetworkManager tek aktif istek tutar ve sinyallerinde istek kimliği yoktur. Probe ile yeniden üretildi: (a) OpenAI → OpenAI: eski istek iptal edilmiyor, yanıtı yeni provider üzerinden runner'a yeni provider'ın cevabıymış gibi geliyordu; (b) OpenAI → NetworkManager kullanmayan provider (AGY): eski yanıtın alıcısı kalmıyor, runner `PLANNING`'de sonsuza kadar bekliyordu. Düzeltme (istek kimliği / yeni ağ katmanı yok): dock provider'ı yeniden kurmadan önce çalışan görevi kullanıcı adına durdurur (`stop_by_user` → Paused; "devam et" yeni provider'da sürer); `AgentHost.rebuild_provider` değiştirilen provider'ın süren isteğini `cancel()` ile kapatır, sonra `dispose()` eder. Test: `ProviderCompositionTests` T2 (düzeltme olmadan kırmızı: `inflight_closed=false`).

## Faz 3 değerlendirmesinde bulunanlar (2026-09-26)

Aday dosyalar okunurken bulundu; her biri önce repo dışı headless probe ile (ya da kanıt statikse öyle yazılarak) doğrulandı, düzeltmeler ayrı commit'lerde, düzeltme olmadan kırmızı olan testle.

21. ✅ **Düzeltildi — Batch istisnası her sözdizimi hatasını gizliyordu:** `validate_script_source`, `reload()` `43` (`ERR_PARSE_ERROR`, yani *herhangi* bir parse hatası) döndüğünde kaynakta batch'teki herhangi bir yol metin olarak geçiyorsa PASSED diyordu. `validate_batch_files` dosyanın kendi yolunu da batch'e koyduğu için kendi yolunu anan bir yorum bile hatayı gizliyordu. Probe: `func f(:` içeren betik batch'siz FAILED, batch ile PASSED. Etki: `write_files` bozuk `.gd`'yi "doğrulandı" diye diske yazabiliyordu. Karar: istisna yalnızca kaynak, *kendisi dışındaki* bir batch dosyasını tırnaklı yol olarak andığında denenir; batch dosyaları proje dışı geçici bir aynaya (`user://ai_sidebar_verify/<benzersiz>/`) yazılır, batch yolları aynaya çevrilir, betik gerçekten derlenir, ayna silinir. Böylece geçerli batch içi bağımlılık (preload / `extends "…"`) yine geçer; sözdizimi hatası ve bağımlılıkta olmayan üyeye erişim yakalanır. Bellek içi çözüm denendi ve çalışmadı (bkz. `docs/KNOWLEDGE.md`). Test: `DependencyAwareBatchTests` Test F (düzeltme olmadan kırmızı: `syntax_error_with_dep`, `missing_member_on_dep`, `syntax_error_self_mention` geçiyordu). Profil farkı yalnızca Test F'nin kasıtlı derleme hatalarıdır.
22. ✅ **Düzeltildi — Ekran görüntüsü araçları PathPolicy'yi atlıyordu:** `take_viewport_screenshot` ve `take_runtime_screenshot` `save_path`'i yalnızca normalleştiriyor, `take_editor_screenshot` normalleştirmiyordu bile (mutlak işletim sistemi yolu kabul); üçü de `READ_ONLY` olduğu için MANUAL modda bile onay istemiyordu. Model `save_path="res://project.godot"` ya da eklenti dosyası verirse üstüne PNG yazılabilirdi (kanıt statik: headless'ta araçlar `EDITOR_REQUIRED` ile erken dönüyordu). Karar: `EditorTools.resolve_screenshot_path` (boşsa varsayılan, sonra `is_safe_to_write`) üç araçta da editör kontrolünden **önce** çalışır; korumalı yol `PERMISSION_DENIED`, mutlak yol `res://` altına sandıklanır. `user://` ve normal `res://` yolları eskisi gibi. Test: `ViewportScreenshotTests` T7 (düzeltme olmadan kırmızı: korumalı yollarda `EDITOR_REQUIRED`). `take_runtime_screenshot` asenkron olduğu için aynı yardımcı üzerinden test edildi; editörde gerçek kayıt duman testine bırakıldı.
23. ✅ **Düzeltildi — Node olmayan `root_type` ile `create_scene` çöküyordu:** `ClassDB.class_exists` geçen ama Node olmayan tip (`Resource`, `Object`, `Image`) `root_node.name = …` satırında SCRIPT ERROR veriyor, araç `{}` döndürüyordu (probe ile görüldü). Artık `INVALID_CLASS` ("Kök düğüm tipi bir Node sınıfı olmalı"). `add_node` aynı kontrolü aldı (orada `MutationService.add_node`'a Node olmayan nesne gidiyordu; editör kökü gerektirdiği için yalnızca statik kanıt). Test: `SceneReliabilityTests` G (düzeltme olmadan kırmızı: üç tipte `{}`).
24. ✅ **Düzeltildi — File-first `create_scene` yanlış kök raporluyordu:** `tscn_content` ile yazılan sahnede sonuç `root_name` / `root_type` / `root_path` ve mesaj argüman varsayılanlarını ("Root (Node2D)") taşıyordu; model, transcript ve `ContextCompactor` özeti (`root_name` okur) yanlış bilgi alıyordu (probe: içerikteki kök `Player (CharacterBody2D)`). Artık `validate_scene_parse` `PackedScene` durumundan kökün adını ve tipini de döndürür, `create_scene` bunları raporlar. Test: `SceneReliabilityTests` H (düzeltme olmadan kırmızı: `root_name=Root`).
25. **Açık — `instantiate_scene` tipli atamada çökebilir:** `var packed: PackedScene = load(scene_path)` (`scene_tools.gd`), sahne olmayan bir yol (ör. `.gd`) verilirse tip atama hatası beklenir; üst düğüm bulunamazsa oluşturulan örnek de sızar. Kanıt statik: araç önce editör kökünü ister (`NO_ACTIVE_SCENE`), headless'ta bu satıra ulaşılamıyor; "düzeltme olmadan kırmızı test" kuralı sağlanamadığı için düzeltilmedi. Editör duman testine eklendi.
26. ✅ **Düzeltildi — Exporter, tool sonucundaki `message` metin değilse bölümü kesiyordu:** Eski Markdown yolunda `msg.is_empty()` `null` için SCRIPT ERROR verip tool bölümünü yarıda bırakıyordu (probe). Olasılık düşük (`ToolResult` hep metin üretir; eski/dış veride görülebilir). Artık `null` boş, diğer tipler `str()` ile yazılır (JSON sayıları float çözüldüğü için `42` → `42.0`). Test: `ChatExporterTests` T9 (düzeltme olmadan kırmızı: bölüm 119 karakterde kesiliyor).

Gözlemler (bug değil ya da etkisi düşük; düzeltilmedi): (O1) `TSCN_EMPTY_FILE` dalına ulaşılamaz, `"".split("\n")` `[""]` döndürür; boş dosya `TSCN_MISSING_HEADER` alır (sabitleme testi bunu kaydeder). (O2) `auto_verify_tool_execution`'ın `create_or_update_script` ve `add_node` dalları ölü: runner onu yalnızca `validate_script` / `play_game` / `get_runtime_errors` için çağırır; `add_node` dalı `parent_path` kök adına eşitse yanlış sonuç verirdi. (O3) `validate_batch_files` yorumu ".gd → .tres → .tscn → diğerleri" der, kod "diğerleri"ni başa koyar; hangisinin kasıtlı olduğu bilinmiyor. (O4) `verify_node` editörsüz modda "varsayılan başarılı" PASSED döner (§2 açısından INCONCLUSIVE olmalı); yalnızca ölü daldan erişiliyor. (O5) `_create_scene` içeriksiz yolda `ClassDB.instantiate` ile kurulan kök düğüm paketlendikten sonra serbest bırakılmıyor (yetim Node). (O6) Eski Markdown'da `has_vision_data` olunca viewport ve Screenshot satırları aynı bilgiyi iki kez yazar. (O7) `tool_manager._pre_verify_write_candidate`, `script_tools` / `scene_tools`'un kendi doğrulamasını tekrar yapar. (O8) `get_scene_tree` geçersiz `root_path`'te hata yerine tüm ağacı döndürür.

## Editör Duman Testi Kontrol Listesi (Faz 1 sonu)

- [ ] Mesaj gönder → streaming balon, thinking kartı, activity grubu
- [ ] Onay kartı → Approve / Reject / View Diff / Undo
- [ ] Plan kartı → Apply → checklist ilerlemesi
- [ ] `ask_user` → clarification kartı → cevap
- [ ] Çalışırken yeni mesaj → kuyruk, tek iptal, Clear All
- [ ] `@` ve `/` autocomplete, Enter / Shift+Enter, Ctrl+V görsel
- [ ] New Chat, History (yükle, yeniden adlandır, sil, export)
- [ ] Export, Copy Chat, telemetri kartından task kopyalama
- [ ] Stop → Paused rozeti → "devam et" ile resume
- [ ] (#14) Oyunu F5 ile aç, ajana metin görevi ver, Stop → oyun açık kalmalı; ajan `play_game` ile açtıysa Stop → oyun kapanmalı
- [ ] (#22) Ajandan `take_viewport_screenshot` / `take_runtime_screenshot` iste → varsayılan `user://` yolunda PNG oluşmalı; `save_path="res://project.godot"` ile `PERMISSION_DENIED`
- [ ] (#25) Açık sahnede `instantiate_scene` ile bir `.gd` yolu ver → araç çökmeden hata dönmeli (bugün tip atama hatası bekleniyor)

**Faz 1 kapanışı (2026-09-25):** Kullanıcı editörde (yeni-oyun-projesi, junction) genel duman testi yaptı; maddeler tek tek kayda geçmedi. Testte bulunan iki sorun ayrı commit'lerde düzeltildi (`89dd0cd` normal kod bloklarında "Parse JSON failed" logu, `e78b8f3` kod bloğunun komşu satırları örtmesi). Başka sorun bildirilmedi; kullanıcı onayıyla `main`'e birleştirildi.
