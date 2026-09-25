@tool
extends RefCounted

## Görev gönderme hattının davranış sabitleme testleri (ChatDock üzerinden, gerçek AgentRunner):
## gönder → kuyruk → durdur → Paused → "devam et" ile aynı task'a dönüş, görsel eki,
## slash komut yolları ve kuyruk dağıtımı. Oluşturulan oturumlar test sonunda silinir.

const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")

class SilentProvider extends AISidebarAIProvider:
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		pass

## Editör yolundaki kurulumla aynı bağlama; dock ağaçta değildir (kuyruk hemen dağıtılır).
static func _make_dock() -> Dictionary:
	var dock = ChatDockScene.instantiate()
	dock._ready()
	dock._auto_scroll_enabled = false
	for child in dock.message_stream.get_children():
		child.free()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(SilentProvider.new(), ctx)
	dock.agent_context = ctx
	dock._sessions.context = ctx
	dock._export_actions.agent_context = ctx
	dock._checklist_tracker.context = ctx
	dock._activity.context = ctx
	dock._interaction.context = ctx
	dock.agent_runner = runner
	dock._interaction.runner = runner
	dock._connect_agent_runner()
	dock._sessions.start_new()
	return {"dock": dock, "ctx": ctx, "runner": runner}

static func _send(dock, text: String) -> void:
	dock.input_field.text = text
	dock._on_send_pressed()

static func _user_bubbles(dock) -> Array:
	var out: Array = []
	for child in dock.message_stream.get_children():
		if child is AISidebarMessageBubble and not child.is_queued_for_deletion() and child.role == "user":
			out.append(child.text_content)
	return out

static func _dispose(dock, created: Array) -> void:
	if dock.agent_runner.is_running():
		dock.agent_runner.stop()
	dock._stream.stop_thinking_timer()
	created.append(dock._sessions.current_id())
	for child in dock.message_stream.get_children():
		child.free()
	dock.free()

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	var created: Array = []

	# 1. Tam hat: boşta gönder → çalışırken gönder (kuyruk) → boş gönder (durdur) → Paused →
	#    "devam et" aynı task'ı açar; durdurulmuşken kuyruk kendiliğinden dağıtılmaz.
	var s1 = _make_dock()
	var d1 = s1["dock"]
	var r1 = s1["runner"]
	_send(d1, "Oyuncuya zıplama ekle")
	var started = r1.is_running() and d1.input_field.text == "" and d1.last_user_prompt == "Oyuncuya zıplama ekle" and _user_bubbles(d1) == ["Oyuncuya zıplama ekle"]
	var task_id = str(s1["ctx"].get_transcript().get_current_task().get("id", ""))
	_send(d1, "Sonra hasar sistemi")
	var queued = d1._queue_panel.count() == 1 and d1.last_user_prompt == "Oyuncuya zıplama ekle"
	_send(d1, "")
	var stopped = not r1.is_running() and d1._is_user_stopped and d1.status_badge.text.begins_with("Paused") and d1._queue_panel.count() == 1
	_send(d1, "devam et")
	var resumed_id = str(s1["ctx"].get_transcript().get_current_task().get("id", ""))
	var resumed = r1.is_running() and not task_id.is_empty() and resumed_id == task_id and not d1._is_user_stopped
	if started and queued and stopped and resumed:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (send/queue/stop/resume) failed: started=%s queued=%s stopped=%s resumed=%s badge='%s'" % [str(started), str(queued), str(stopped), str(resumed), d1.status_badge.text])
	_dispose(d1, created)

	# 2. Yalnızca görsel: varsayılan metin gönderilir, görsel hatırlanır ve ekten kalkar
	var s2 = _make_dock()
	var d2 = s2["dock"]
	var vi = AISidebarVisionInput.new("user://img.png", "aGVsbG8=", 4, 4)
	d2._composer.attach_vision_input(vi)
	_send(d2, "")
	if s2["runner"].is_running() and d2.last_user_prompt == "Bu görseli incele ve yardımcı ol." and d2._last_sent_vision_input == vi and d2._composer.attached_vision_input == null:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (image-only send) failed: prompt='%s'" % d2.last_user_prompt)
	_dispose(d2, created)

	# 3. Slash yolları: bilinmeyen komut hata balonu; /help yerel yanıt; /analyze boşta task,
	#    çalışırken kuyruk
	var s3 = _make_dock()
	var d3 = s3["dock"]
	_send(d3, "/bilinmeyen")
	var unknown_ok = not s3["runner"].is_running() and d3.message_stream.get_child_count() == 2
	_send(d3, "/help")
	var help_ok = not s3["runner"].is_running() and d3.message_stream.get_child_count() == 4
	_send(d3, "/analyze")
	var analyze_ok = s3["runner"].is_running() and d3.last_user_prompt == "/analyze"
	_send(d3, "/analyze Player")
	var queued_ok = d3._queue_panel.count() == 1
	if unknown_ok and help_ok and analyze_ok and queued_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (slash paths) failed: unknown=%s help=%s analyze=%s queued=%s" % [str(unknown_ok), str(help_ok), str(analyze_ok), str(queued_ok)])
	_dispose(d3, created)

	# 4. Kuyruk dağıtımı: kullanıcı durdurduysa bekler; aksi halde sıradakini başlatır
	var s4 = _make_dock()
	var d4 = s4["dock"]
	d4._queue_panel.enqueue("Kuyruktaki istek", "Kuyruktaki istek")
	d4._is_user_stopped = true
	d4._check_and_dispatch_next_queue()
	var held = d4._queue_panel.count() == 1 and not s4["runner"].is_running()
	d4._is_user_stopped = false
	d4._check_and_dispatch_next_queue()
	var dispatched = d4._queue_panel.count() == 0 and s4["runner"].is_running() and d4.last_user_prompt == "Kuyruktaki istek"
	if held and dispatched:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (queue dispatch) failed: held=%s dispatched=%s" % [str(held), str(dispatched)])
	_dispose(d4, created)

	for id in created:
		if not str(id).is_empty():
			AISidebarChatManager.delete_session(id)
	return {"name": "TaskDispatchTests", "passed": passed, "failed": failed, "errors": errors}
