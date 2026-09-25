@tool
extends RefCounted

## ChatExportActions için DETERMINISTIK testler (pano içeriği headless'ta doğrulanamaz;
## durum rozeti metni ve dosya yazımı üzerinden gözlemlenir).
## Kapsar: boş sohbet, session transcript'ine düşüş, bilinmeyen task, per-task copy,
## history export dosya yazımı, boş içerik reddi, iptalde bekleyen export'un temizlenmesi.

const AISidebarChatExportActions = preload("res://addons/godot_sidebar_ai/ui/controllers/chat_export_actions.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")

static func _make(ctx, sess) -> AISidebarChatExportActions:
	var a = AISidebarChatExportActions.new()
	a.agent_context = ctx
	a.get_session = func(): return sess
	a.status_badge = Label.new()
	a.status_badge.text = "Ready"
	return a

static func _dispose(a: AISidebarChatExportActions) -> void:
	a.status_badge.free()
	a.free()

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Boş sohbet: Copy Chat "No chat yet" gösterir
	var a1 = _make(AISidebarAgentContext.new(), null)
	a1.copy_chat()
	if a1.status_badge.text == "No chat yet":
		passed += 1
	else:
		failed += 1
		errors.append("T1 (empty chat) failed: " + a1.status_badge.text)
	_dispose(a1)

	# 2. Canlı transcript boşsa session transcript'ine düşer
	var old_ctx = AISidebarAgentContext.new()
	old_ctx.begin_task("Eski görev", "")
	old_ctx.end_task("completed")
	var sess = AISidebarChatSession.new()
	sess.transcript_tasks = old_ctx.get_transcript().to_data()
	var a2 = _make(AISidebarAgentContext.new(), sess)
	a2.copy_chat()
	if a2.status_badge.text == "Chat copied":
		passed += 1
	else:
		failed += 1
		errors.append("T2 (session fallback) failed: " + a2.status_badge.text)
	_dispose(a2)

	# 3. Per-task copy: bilinmeyen id -> "Task not found"; bilinen id -> "Task copied"
	var ctx3 = AISidebarAgentContext.new()
	var tid = ctx3.begin_task("Sahne kur", "")
	ctx3.end_task("completed")
	var a3 = _make(ctx3, null)
	a3.copy_single_task("nope")
	var not_found = a3.status_badge.text == "Task not found"
	a3.copy_single_task(tid)
	if not_found and a3.status_badge.text == "Task copied":
		passed += 1
	else:
		failed += 1
		errors.append("T3 (single task) failed: nf=%s last='%s'" % [str(not_found), a3.status_badge.text])
	_dispose(a3)

	# 4. History export: seçilen yola içerik yazılır, bekleyen export temizlenir
	var a4 = _make(null, null)
	var out_path = "user://__export_actions_test.md"
	a4._pending_history_export = {"content": "# Export içerik"}
	a4._on_export_file_chosen(out_path)
	var written = FileAccess.get_file_as_string(out_path)
	if written == "# Export içerik" and a4._pending_history_export.is_empty() and a4.status_badge.text == "Chat exported: __export_actions_test.md":
		passed += 1
	else:
		failed += 1
		errors.append("T4 (history export write) failed: '%s' / '%s'" % [written, a4.status_badge.text])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out_path))

	# 5. Boş içerik yazılmaz; iptal bekleyen export'u temizler
	a4._on_export_file_chosen(out_path)
	var empty_rejected = a4.status_badge.text == "Export failed: empty content" and not FileAccess.file_exists(out_path)
	a4._pending_history_export = {"content": "x"}
	a4._on_export_file_canceled()
	if empty_rejected and a4._pending_history_export.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T5 (empty/cancel) failed: " + a4.status_badge.text)
	_dispose(a4)

	return {"name": "ChatExportActionsTests", "passed": passed, "failed": failed, "errors": errors}
