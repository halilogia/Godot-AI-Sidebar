@tool
extends RefCounted

## ChatSessionStore için DETERMINISTIK testler (UI yok; gerçek ChatManager diski kullanılır,
## oluşturulan her oturum test sonunda silinir).
## Kapsar: yeni oturum, kaydet/yükle round-trip, bulunamayan oturum, Clear'ın kalıcılığı,
## yerel komut kaydı, Clear, pause checkpoint (resumable / terminal), yeni task'ın checkpoint'i
## geçersiz kılması, rename.

const AISidebarChatSessionStore = preload("res://addons/godot_sidebar_ai/ui/controllers/chat_session_store.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")

static func _make() -> AISidebarChatSessionStore:
	var st = AISidebarChatSessionStore.new()
	st.context = AISidebarAgentContext.new()
	st.start_new()
	return st

static func _msg(role: String, content: String) -> Dictionary:
	return {"role": role, "content": content}

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	var created_ids: Array = []

	# 1. start_new: yeni id, context boşalır
	var st1 = _make()
	st1.context.messages.append(_msg("user", "eski"))
	var old_id = st1.current_id()
	st1.start_new()
	if st1.current_id() != old_id and not st1.current_id().is_empty() and st1.context.messages.is_empty() and not st1.has_live_messages():
		passed += 1
	else:
		failed += 1
		errors.append("T1 (start_new) failed.")

	# 2. Kaydet -> yükle round-trip: mesajlar ve transcript context'e geri kurulur
	var st2 = _make()
	st2.context.messages.append(_msg("user", "Sahne kur"))
	st2.context.begin_task("Sahne kur", "")
	st2.context.end_task("completed")
	st2.save()
	var sid = st2.current_id()
	created_ids.append(sid)
	var st2b = _make()
	var loaded_ok = st2b.load_by_id(sid)
	if loaded_ok and st2b.is_current(sid) and st2b.context.messages.size() == 1 \
			and st2b.context.get_transcript().to_data().size() == 1 and st2b.current.title != "New Chat":
		passed += 1
	else:
		failed += 1
		errors.append("T2 (save/load round-trip) failed: ok=%s msgs=%d title='%s'" % [str(loaded_ok), st2b.context.messages.size(), st2b.current.title])

	# 3. Bulunamayan oturum: false, mevcut oturum değişmez
	var before = st2b.current_id()
	if not st2b.load_by_id("__no_such_session__") and st2b.current_id() == before:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (missing session) failed.")

	# 4. Clear (buton ve /clear) sonrası diskten yüklenen oturum boştur; sonraki kayıt
	# yalnızca yeni mesajları içerir (eski sohbet geri gelmez).
	var st4 = _make()
	created_ids.append(st4.current_id())
	st4.context.messages.append(_msg("user", "ilk"))
	st4.save()
	st4.clear_contents()
	var reloaded_empty = st4.load_by_id(st4.current_id()) and st4.context.messages.is_empty()
	st4.context.messages.append(_msg("user", "sonraki"))
	st4.save()
	var contents: Array = []
	for m in AISidebarChatManager.load_session(st4.current_id()).messages:
		contents.append(str(m.get("content", "")))
	if reloaded_empty and contents == ["sonraki"]:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (clear persists) failed: empty=%s contents=%s" % [str(reloaded_empty), str(contents)])

	# 5. Yerel komut (/help) oturumda doğru sırada kalır, History'den yüklenince geri gelir ve
	# modele giden context'e hiç girmez. (Önceden save() context'ten yeniden kurarken siliyordu.)
	var st5 = _make()
	created_ids.append(st5.current_id())
	st5.context.messages.append(_msg("user", "ilk soru"))
	st5.record_local_command("/help", "Komutlar...")
	st5.context.messages.append(_msg("user", "ikinci soru"))
	st5.save()
	var saved: Array = []
	for m in st5.current.messages:
		saved.append(str(m.get("content", "")))
	var ctx_clean = st5.context.messages.filter(func(m): return str(m.get("role", "")) == "command").is_empty()
	var st5b = AISidebarChatSessionStore.new()
	st5b.context = AISidebarAgentContext.new()
	var loaded5 = st5b.load_by_id(st5.current_id())
	st5b.save()
	var reloaded: Array = []
	for m in AISidebarChatManager.load_session(st5.current_id()).messages:
		reloaded.append(str(m.get("content", "")))
	var ctx_after: Array = []
	for m in st5b.context.messages:
		ctx_after.append(str(m.get("content", "")))
	var expected = ["ilk soru", "/help", "Komutlar...", "ikinci soru"]
	if saved == expected and ctx_clean and loaded5 and reloaded == expected and ctx_after == ["ilk soru", "ikinci soru"]:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (local command persistence) failed: saved=%s reloaded=%s ctx=%s" % [str(saved), str(reloaded), str(ctx_after)])

	# 6. Pause checkpoint: iptal edilen task resumable; terminal limit hatası değil; task yoksa {}
	var st6 = _make()
	created_ids.append(st6.current_id())
	var none_cp = st6.store_pause_checkpoint({"current_step": 1, "max_steps": 20, "elapsed_s": 1.0}, "")
	st6.context.begin_task("Oyuncu ekle", "")
	st6.context.end_task("cancelled", "User stopped")
	var cp = st6.store_pause_checkpoint({"current_step": 3, "max_steps": 20, "elapsed_s": 2.0}, "res://Main.tscn")
	var resumable_ok = st6.has_resumable_checkpoint() and int(cp.get("current_step", 0)) == 3 and int(st6.checkpoint_copy().get("max_steps", 0)) == 20
	st6.context.begin_task("Oyuncu ekle", "")
	st6.context.end_task("failed", "Tool-call limit reached: 20/20")
	st6.store_pause_checkpoint({"current_step": 20, "max_steps": 20, "elapsed_s": 9.0}, "")
	var terminal_ok = not st6.has_resumable_checkpoint()
	if none_cp.is_empty() and resumable_ok and terminal_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (pause checkpoint) failed: none=%s resumable=%s terminal=%s" % [str(none_cp.is_empty()), str(resumable_ok), str(terminal_ok)])

	# 7. Yeni task checkpoint'i geçersiz kılar; Clear tüm içeriği boşaltır
	st6.context.begin_task("Tekrar", "")
	st6.context.end_task("cancelled")
	st6.store_pause_checkpoint({"current_step": 2, "max_steps": 20, "elapsed_s": 1.0}, "")
	var had_cp = st6.has_resumable_checkpoint()
	st6.begin_new_task()
	var cp_cleared = not st6.has_resumable_checkpoint()
	st6.current.telemetry = {"success": true}
	st6.clear_contents()
	if had_cp and cp_cleared and st6.current.messages.is_empty() and st6.current.telemetry.is_empty() \
			and st6.current.transcript_tasks.is_empty() and st6.context.get_transcript().to_data().is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T7 (new task / clear) failed: had=%s cleared=%s" % [str(had_cp), str(cp_cleared)])

	# 8. rename_if_current yalnızca aktif oturumu değiştirir
	var st8 = _make()
	var renamed_other = st8.rename_if_current("başka", "X")
	var renamed_self = st8.rename_if_current(st8.current_id(), "Yeni Başlık")
	if not renamed_other and renamed_self and st8.current.title == "Yeni Başlık":
		passed += 1
	else:
		failed += 1
		errors.append("T8 (rename) failed.")

	for id in created_ids:
		AISidebarChatManager.delete_session(id)
	return {"name": "ChatSessionStoreTests", "passed": passed, "failed": failed, "errors": errors}
