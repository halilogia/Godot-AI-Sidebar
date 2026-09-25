@tool
extends RefCounted

## Görev gönderme hattının davranış sabitleme testleri (ChatDock üzerinden, gerçek AgentRunner):
## gönder → kuyruk → durdur → Paused → "devam et" ile aynı task'a dönüş, görsel eki,
## slash komut yolları ve kuyruk dağıtımı. Oluşturulan oturumlar test sonunda silinir.

const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarAgentHost = preload("res://addons/godot_sidebar_ai/core/agent/agent_host.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")
const AISidebarErrorCard = preload("res://addons/godot_sidebar_ai/ui/components/error_card.gd")

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
	var host = AISidebarAgentHost.new()
	host.set_provider(SilentProvider.new())
	dock.attach_agent_host(host)
	dock._sessions.start_new()
	return {"dock": dock, "ctx": host.context, "runner": host.runner}

static func _send(dock, text: String) -> void:
	dock.input_field.text = text
	dock._tasks.submit_input()

static func _user_bubbles(dock) -> Array:
	var out: Array = []
	for child in dock.message_stream.get_children():
		if child is AISidebarMessageBubble and not child.is_queued_for_deletion() and child.role == "user":
			out.append(child.text_content)
	return out

static func _dispose(dock, created: Array) -> void:
	var host = dock.agent_host
	if dock.agent_runner.is_running():
		dock.agent_runner.stop()
	dock._stream.stop_thinking_timer()
	created.append(dock._sessions.current_id())
	for child in dock.message_stream.get_children():
		child.free()
	dock.free()
	host.free()

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
	var started = r1.is_running() and d1.input_field.text == "" and d1._tasks.last_user_prompt == "Oyuncuya zıplama ekle" and _user_bubbles(d1) == ["Oyuncuya zıplama ekle"]
	var task_id = str(s1["ctx"].get_transcript().get_current_task().get("id", ""))
	_send(d1, "Sonra hasar sistemi")
	var queued = d1._queue_panel.count() == 1 and d1._tasks.last_user_prompt == "Oyuncuya zıplama ekle"
	_send(d1, "")
	var stopped = not r1.is_running() and d1._tasks.is_user_stopped and d1.status_badge.text.begins_with("Paused") and d1._queue_panel.count() == 1
	_send(d1, "devam et")
	var resumed_id = str(s1["ctx"].get_transcript().get_current_task().get("id", ""))
	var resumed = r1.is_running() and not task_id.is_empty() and resumed_id == task_id and not d1._tasks.is_user_stopped
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
	if s2["runner"].is_running() and d2._tasks.last_user_prompt == "Bu görseli incele ve yardımcı ol." and d2._tasks.last_sent_vision_input == vi and d2._composer.attached_vision_input == null:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (image-only send) failed: prompt='%s'" % d2._tasks.last_user_prompt)
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
	var analyze_ok = s3["runner"].is_running() and d3._tasks.last_user_prompt == "/analyze"
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
	d4._tasks.is_user_stopped = true
	d4._tasks.dispatch_next_queued()
	var held = d4._queue_panel.count() == 1 and not s4["runner"].is_running()
	d4._tasks.is_user_stopped = false
	d4._tasks.dispatch_next_queued()
	var dispatched = d4._queue_panel.count() == 0 and s4["runner"].is_running() and d4._tasks.last_user_prompt == "Kuyruktaki istek"
	if held and dispatched:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (queue dispatch) failed: held=%s dispatched=%s" % [str(held), str(dispatched)])
	_dispose(d4, created)

	# 5. Retry normal task hattından geçer: slash komutunun ÜRETTİĞİ istem tekrar gönderilir
	#    (ekrandaki "/analyze" değil), yeni transcript görevi açılır, görsel eki korunur.
	var s5 = _make_dock()
	var d5 = s5["dock"]
	var r5 = s5["runner"]
	var ctx5 = s5["ctx"]
	_send(d5, "/analyze Player")
	var first_task = str(ctx5.get_transcript().get_current_task().get("id", ""))
	r5.stop()  # kullanıcı Stop'u değil: ağ/model hatası gibi
	var err_card = null
	for child in d5.message_stream.get_children():
		if child is AISidebarErrorCard:
			err_card = child
	if err_card:
		err_card.retry_requested.emit()
	# Kullanıcı mesajları (runner ayrıca planlama talimatı ekleyebilir; onlar display_text taşımaz).
	var sent: Array = []
	for m in ctx5.messages:
		if str(m.get("role", "")) == "user" and str(m.get("display_text", "")) == "/analyze Player":
			sent.append(m)
	var first_prompt = str(sent[0].get("content", "")) if sent.size() > 0 else ""
	var last_user: Dictionary = sent[-1] if sent.size() > 1 else {}
	var retry_task = str(ctx5.get_transcript().get_current_task().get("id", ""))
	var retried = err_card != null and r5.is_running()
	var same_prompt = str(last_user.get("content", "")) == first_prompt and first_prompt.length() > 20 and str(last_user.get("display_text", "")) == "/analyze Player"
	var new_task = not first_task.is_empty() and retry_task != first_task and ctx5.get_transcript().has_running_task()
	# Görsel eki: normal mesaj + görsel → hata → Retry görseli yeniden gönderir.
	r5.stop()
	d5._composer.attach_vision_input(AISidebarVisionInput.new("user://shot.png", "aGVsbG8=", 4, 4))
	_send(d5, "Bu ekrana bak")
	r5.stop()
	d5._tasks.retry_last_task()
	var img_msgs = ctx5.messages.filter(func(m): return str(m.get("role", "")) == "user" and str(m.get("content", "")) == "Bu ekrana bak")
	var image_kept = img_msgs.size() == 2 and img_msgs[1].has("vision_inputs") and r5.is_running()
	if retried and same_prompt and new_task and image_kept:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (retry pipeline) failed: retried=%s same_prompt=%s ('%s') new_task=%s image=%s" % [str(retried), str(same_prompt), str(last_user.get("content", "")).left(40), str(new_task), str(image_kept)])
	_dispose(d5, created)

	# 6. Kuyruk dağıtımı başka bir görev başladıktan sonra gelirse (Retry, ya da hatada
	# on_error + on_task_completed'in ikinci dağıtımı) öğe kuyrukta kalır; çalışan görevin
	# transcript'i iptal edilmez, istem kaybolmaz.
	var s6 = _make_dock()
	var d6 = s6["dock"]
	var r6 = s6["runner"]
	var ctx6 = s6["ctx"]
	d6._queue_panel.enqueue("Q1", "Q1")
	d6._queue_panel.enqueue("Q2", "Q2")
	d6._tasks.dispatch_next_queued()
	d6._tasks.dispatch_next_queued()
	var double_ok = r6.is_running() and d6._queue_panel.count() == 1 and str(ctx6.get_transcript().get_current_task().get("display_prompt", "")) == "Q1" and str(ctx6.get_transcript().get_current_task().get("status", "")) == "running"
	d6._tasks.stop_by_user()
	d6._tasks.retry_last_task()
	var retry_task6 = str(ctx6.get_transcript().get_current_task().get("id", ""))
	d6._tasks.dispatch_next_queued()
	var retry_ok = r6.is_running() and d6._queue_panel.count() == 1 and str(ctx6.get_transcript().get_current_task().get("id", "")) == retry_task6 and str(ctx6.get_transcript().get_current_task().get("status", "")) == "running"
	if double_ok and retry_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (dispatch after another start) failed: double=%s retry=%s queue=%d task=%s" % [str(double_ok), str(retry_ok), d6._queue_panel.count(), str(ctx6.get_transcript().get_current_task().get("display_prompt", ""))])
	_dispose(d6, created)

	for id in created:
		if not str(id).is_empty():
			AISidebarChatManager.delete_session(id)
	return {"name": "TaskDispatchTests", "passed": passed, "failed": failed, "errors": errors}
