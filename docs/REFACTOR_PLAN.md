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

| Adım | Yeni birim | İçerik (bugünkü satırlar) | Risk |
|---|---|---|---|
| 1.1 | `ui/docks/chat_dock_theme.gd` | `_apply_theme`, `_update_send_button_style` (270–397) | Çok düşük |
| 1.2 | `ui/presenters/tool_presentation.gd` (static) | `_get_human_tool_title`, `_build_tech_details`, `_extract_tool_error`, `_screenshot_image_path`, `is_task_limit_error`, `format_limit_stop_reason` | Düşük |
| 1.3 | `ui/presenters/plan_checklist_tracker.gd` | Checklist eşleştirme + snapshot (1777–1864) — saf mantık, birim testi kolay | Düşük |
| 1.4 | `ui/components/message_queue_panel.gd` + kuyruk modeli | FIFO kuyruk, UI, dispatch (415–457, 1480–1556) | Orta |
| 1.5 | `ui/components/input_composer.gd` | Mention/slash autocomplete, klavye, görsel eki (459–527, 745–928) | Orta |
| 1.6 | `ui/controllers/chat_export_actions.gd` | Export, Copy Chat, per-task copy, history export dialog (606–688, 972–1029) | Düşük |
| 1.7 | `ui/controllers/chat_session_controller.gd` | New/load/save/clear, history panel olayları, checkpoint/pause/resume (930–1097, 1338–1389, 1558–1577) | Orta-yüksek |
| 1.8 | `ui/presenters/session_replay_renderer.gd` | `_rebuild_ui_stream_from_session` (1098–1180) | Orta |
| 1.9 | `ui/presenters/agent_event_presenter.gd` | Ajan sinyal dinleyicileri, stream tamponu, activity/reasoning/thinking kartları (1623–2331) | **Yüksek** — en son |

**Hedef:** ChatDock ≤ ~500 satır; yalnızca sahne bağlantısı + birimlerin kompozisyonu.
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

## Faz 4 — Borcun geri gelmesini önleme

- [ ] Satır bütçesi testi: `.gd` dosyası > 600 satırsa uyarı, > 900 ise test başarısız (istisna listesi açık yazılır).
- [ ] `ARCHITECTURE.md` yeni UI katmanlarını (components / presenters / controllers) anlatacak şekilde güncellenir.

## Okurken bulunanlar (ayrı commit, önce doğrulanacak)

1. **Şüpheli bug — Retry yolu:** `ErrorCard.retry_requested`, `agent_runner.start_task`'ı doğrudan çağırıyor; `_start_task_prompt` atlanıyor. Sonuç olarak `agent_context.begin_task`, mention çözümleme ve checkpoint sıfırlama yapılmıyor olabilir, yani yeniden denenen task transcript/export'ta eksik görünebilir. Test ile doğrulanacak.
2. **Ölü değişken:** `_stream_is_envelope` hiçbir yerde `true` yapılmıyor.
3. **Tekrarlı kontrol:** `_resume_paused_task` içinde `current_session == null` iki kez kontrol ediliyor.
4. **Tema dışı renkler:** Kuyruk panelinde `Color(0.7, 0.7, 0.7)`, `Color(0.9, 0.4, 0.4)` gibi sabit renkler var (tema token'ı değil).

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
