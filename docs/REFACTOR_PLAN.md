# Refactor Planı — Ertelenen Borcun Ödenmesi

> Durum: **Taslak / onay bekliyor** · Başlangıç: 2026-09-25 · Baz commit: `1af07d3`
> Baz ölçüm: typecheck 162/162 GDScript + 4/4 sahne ✅ · test_runner **553 assertion** ✅

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
6. Çalışma `refactor/*` dalında yürür; her faz sonunda `main`'e birleştirme kullanıcı onayıyla yapılır.

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

**İlerleme:** 2349 → 1415 satır (1.1–1.8) → 1238 (1.9a) → 1047 (1.9b) → 901 (1.9c) → 835 (1.10). 1.9 tek dosya yerine üç birime bölündü (tek dosya ~550 satır ve birden çok sorumluluk olurdu); task bitişi/hata orkestrasyonu (oturum, kuyruk, görsel eki) ChatDock'ta kalır ve presenter API'lerini kullanır. 1.7'de kalıcı oturum durumu UI'sız `ChatSessionStore`'a taşındı; UI orkestrasyonu (akış temizleme, rozet, history paneli) bilinçli olarak ChatDock'ta kaldı. **Hedef:** ChatDock ≤ ~500 satır; yalnızca sahne bağlantısı + birimlerin kompozisyonu.
**Ara kontrol:** 1.1–1.6 kullanıcı tarafından editörde (yeni-oyun-projesi, junction) elle test edildi, sorun yok (2026-09-25).
**Faz sonu:** editörde elle duman testi (aşağıdaki kontrol listesi) — headless testler UI'ın gerçek hissini kanıtlamaz.

## Faz 2 — AgentRunner

| Adım | Yeni birim | İçerik | Risk |
|---|---|---|---|
| 2.1 | `core/agent/agent_telemetry.gd` | ~30 sayaç/süre değişkeni, `_record_tool_telemetry`, `_classify_telemetry_op`, `_record_category_time`, metrik üretimi | Orta |
| 2.2 | `core/agent/pending_interaction.gd` | Bekleyen onay / clarification / plan durumu | Orta |
| 2.3 | — | `_on_provider_response` (~200 satır) iç adımlara bölünür: parse → boş yanıt/retry → tool dispatch → tamamlama kapısı | **Yüksek** |

Faz 2 sonunda canlı entegrasyon testi (`test_real_9router_live.gd`) de koşulur.

## Faz 3 — Diğer büyük dosyalar (önce değerlendirme)

`chat_exporter.gd` (806), `editor_tools.gd` (653), `scene_tools.gd` (652), `verification_pipeline.gd` (576). Satır sayısı tek başına sorun değildir; yalnızca birden fazla sorumluluk varsa bölünür. Her biri için kısa karar notu yazılır.

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

## Okurken bulunanlar (ayrı commit, önce doğrulanacak)

0. ✅ **Düzeltildi (`d5efc41`) — Test runner açığı:** çalışma anında çöken bir paket `[PASS] Unknown (0/0)` sayılıyor, koşu yeşil kalıyordu. Artık FAIL. 1af07d3 bazında gizli çökme yoktu (doğrulandı).

1. **Şüpheli bug — Retry yolu:** `ErrorCard.retry_requested`, `agent_runner.start_task`'ı doğrudan çağırıyor; `_start_task_prompt` atlanıyor. Sonuç olarak `agent_context.begin_task`, mention çözümleme ve checkpoint sıfırlama yapılmıyor olabilir, yani yeniden denenen task transcript/export'ta eksik görünebilir. Test ile doğrulanacak.
2. ✅ **Kaldırıldı — Ölü değişken:** `_stream_is_envelope` hiçbir yerde `true` yapılmıyordu.
3. **Tekrarlı kontrol:** `_resume_paused_task` içinde `current_session == null` iki kez kontrol ediliyor.
4. **Tema dışı renkler:** Kuyruk panelinde `Color(0.7, 0.7, 0.7)`, `Color(0.9, 0.4, 0.4)` gibi sabit renkler var (tema token'ı değil).
5. ✅ **Kaldırıldı — Ölü kod:** `report_task_stop` hiçbir yerden çağrılmıyordu (1.9b'de yeni birime taşınmadan önce silindi). `ToolPresentation.format_limit_stop_reason` yalnızca testte kullanılıyor; testli yardımcı olduğu için şimdilik korundu.
6. **Sahte testler (kalan):** `test_ui_ux_queue_and_input.gd` Test 10 hâlâ düz Array üzerinde çalışıyor. Benzer "kendi ifadesini test eden" testler için Faz 3'te tarama yapılacak.
7. **Doğrulanmış bug — yerel slash komutları kaybolur:** `/help` gibi LLM'siz yanıtlanan komutlar oturuma eklenir ama hemen ardından `save()` mesajları context'ten yeniden kurar ve silinir; History'den yüklenen sohbette görünmezler. Orijinal kodda da vardı (1.7'de `ChatSessionStoreTests` T5 yakaladı ve belgeledi). Düzeltme tasarım kararı ister: context'e eklemek LLM'e geçersiz `command` rolü gönderir. (`/clear`'ın base sabitlemesi 9. madde ile kaldırıldı.)
8. ✅ **Düzeltildi (`826fc68`) — History replay çökmesi:** yanıtlanmış `ask_user` içeren oturum yüklenince replay var olmayan `card._input_container` alanında çöküyor, sonraki mesajlar/telemetri çizilmiyordu; kart ayrıca `_ready` iki kez çağrıldığı için çift kuruluyordu. Gerçek SceneTree probe'u ile kanıtlandı.
9. ✅ **Düzeltildi — `/clear` sohbeti temizlemiyordu:** yalnızca ajan context'ini sıfırlayıp ekrana "Agent çalışma hafızası sıfırlandı" balonu basıyor, eski sohbet ekranda ve kayıtta (base mesajlar) kalıyordu. Artık Clear butonuyla aynı yolu izler (`clear_chat` aksiyonu → `_on_clear_pressed`); bilgi balonu yok. Base sabitleme mekanizması tek kullanıcısı gittiği için `ChatSessionStore`'dan kaldırıldı. Testler: `SlashCommandTests` 9/9b, `ChatSessionStoreTests` T4.
10. ✅ **Düzeltildi — İki ayrı "düşünme" göstergesi:** her LLM turunda akışa "Düşünülüyor (Ns)..." yazan yer tutucu asistan balonu ekleniyordu. Modelin gerçek thinking kartı sonra geldiği için balonun altına düşüyor (düşünce cevabın altında görünüyordu); metinsiz tool turlarında balon akışta asılı kalıyordu. Baz commit `1af07d3`'te de vardı. Yer tutucu kaldırıldı. Ardından (kullanıcı geri bildirimi: ilk yanıta kadar ekran boş kalıyordu) balon olmayan bir `PendingIndicator` eklendi: akışın sonunda dönen ikon + bilinen aşama + süre, 15 sn sonra iptal ipucu; ilk hayat belirtisinde (thinking, metin, tool, kart, durum değişimi) kalkar, thinking kartı onun yerine oturur. Testler: `ReasoningUITests` T11–T15.

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
