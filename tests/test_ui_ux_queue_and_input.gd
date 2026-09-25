@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarMessageQueuePanel = preload("res://addons/godot_sidebar_ai/ui/components/message_queue_panel.gd")
const AISidebarInputComposer = preload("res://addons/godot_sidebar_ai/ui/components/input_composer.gd")

class MockQueueProvider extends AISidebarAIProvider:
	var responses: Array = []
	var last_sent_messages: Array = []
	var last_sent_images: Array = []

	func supports_vision() -> bool:
		return true

	func send_chat(messages: Array, _tools: Array) -> void:
		last_sent_messages = messages

	func send_multimodal_chat(messages: Array, _tools: Array, images: Array) -> void:
		last_sent_messages = messages
		last_sent_images = images

static func _key(code: Key, shift: bool) -> InputEventKey:
	var ev = InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.shift_pressed = shift
	return ev

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Enter gönderir, Shift+Enter yeni satır, /slash popup'ı Esc kapatır, öneri seçimi metni yazar
	# (gerçek InputComposer; runner _init'te koştuğu için düğümler ağaç dışındadır)
	var host = VBoxContainer.new()
	var field = TextEdit.new()
	var popup = PanelContainer.new()
	var list = ItemList.new()
	popup.add_child(list)
	host.add_child(popup)
	host.add_child(field)
	var composer = AISidebarInputComposer.new(host, field, popup, list)
	composer.connect_input_signals()
	var sends: Array = [0]
	composer.send_requested.connect(func(): sends[0] += 1)
	field.text = "Hello Godot AI"
	field.set_caret_column(field.text.length())
	composer.handle_gui_input(_key(KEY_ENTER, false))
	var sent_on_enter = sends[0] == 1
	composer.handle_gui_input(_key(KEY_ENTER, true))
	var newline_on_shift = sends[0] == 1 and field.text.contains("\n")
	field.text = "/hel"
	field.set_caret_line(0)
	field.set_caret_column(4)
	field.text_changed.emit()
	var popup_opened = popup.visible and list.item_count > 0
	composer.handle_gui_input(_key(KEY_ESCAPE, false))
	var esc_closed = not popup.visible and sends[0] == 1
	field.text_changed.emit()
	composer.activate_suggestion(0)
	var completed = field.text == "/help " and not popup.visible
	host.free()
	if sent_on_enter and newline_on_shift and popup_opened and esc_closed and completed:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (composer keys/autocomplete) failed: enter=%s shift=%s popup=%s esc=%s done=%s text='%s'" % [str(sent_on_enter), str(newline_on_shift), str(popup_opened), str(esc_closed), str(completed), field.text])

	# Test 2: FIFO Message Queueing (gerçek MessageQueuePanel)
	var qp = AISidebarMessageQueuePanel.new()
	qp.enqueue("Task 1", "Task 1", [])
	qp.enqueue("Task 2", "Task 2 (display)")
	qp.enqueue("Task 3", "Task 3", [])
	var popped_first = qp.pop_next()
	var popped_second = qp.pop_next()
	if popped_first.get("prompt") == "Task 1" and popped_first.has("vision_inputs") \
			and popped_second.get("display_prompt") == "Task 2 (display)" and not popped_second.has("vision_inputs") \
			and qp.count() == 1 and qp.visible and qp.get_title_text() == "Queued Messages (1)":
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (queued_messages_fifo) failed: " + str(qp.get_items()))

	# Test 3: Queued Message Cancellation by ID (ortadaki item iptal, sıra korunur)
	var cp = AISidebarMessageQueuePanel.new()
	cp.enqueue("Prompt A", "Prompt A")
	cp.enqueue("Prompt B", "Prompt B")
	cp.enqueue("Prompt C", "Prompt C")
	var ids: Array = []
	for it in cp.get_items():
		ids.append(it["id"])
	cp.cancel(ids[1])
	var left = cp.get_items()
	if left.size() == 2 and left[0]["prompt"] == "Prompt A" and left[1]["prompt"] == "Prompt C":
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (queued_message_cancel) failed: " + str(left))

	# Test 4: Boş kuyruk: pop {} döner, panel gizlenir, çift çalıştırma yok; Clear All
	var executed_tasks: Array = []
	var sp = AISidebarMessageQueuePanel.new()
	sp.enqueue("Do Job 1", "Do Job 1")
	sp.enqueue("Do Job 2", "Do Job 2")
	for _i in range(3):
		var item = sp.pop_next()
		if not item.is_empty():
			executed_tasks.append(item["prompt"])
	var hidden_when_empty = not sp.visible
	sp.enqueue("Do Job 3", "Do Job 3")
	sp.clear_all()
	if executed_tasks == ["Do Job 1", "Do Job 2"] and hidden_when_empty and sp.count() == 0 and not sp.visible:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (queue_no_duplicate_execution) failed: " + str(executed_tasks))
	for panel in [qp, cp, sp]:
		panel.free()

	# Test 5: Queue with Approval State Machine
	var mock_p = MockQueueProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock_p, ctx)
	
	# Start task
	runner.start_task("Perform destructive edit")
	# Force state to WAITING_FOR_APPROVAL
	runner._set_state(AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL, "Waiting for user approval")
	
	var is_runner_busy = runner.is_running() # true while waiting for approval
	var queued_while_waiting: Array[Dictionary] = []
	if is_runner_busy:
		queued_while_waiting.append({"id": "q_next", "prompt": "Next Task After Approval"})
		
	if runner.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL and is_runner_busy and queued_while_waiting.size() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (queue_with_approval) failed: state=" + str(runner.current_state))
		
	# (Eski Test 6 "queue with user stop" yerel değişkenleri test ediyordu; aynı davranış
	# gerçek hat üzerinden TaskDispatchTests T1'de: durdurulmuşken kuyruk dağıtılmaz.)

	# Test 7: Clipboard VisionInput creation and Texture preview
	var test_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	test_img.fill(Color.BLUE)
	var vi = AISidebarVisionInput.from_image(test_img)
	var tex = vi.get_texture() if vi else null
	if vi != null and not vi.image_data_base64.is_empty() and tex != null and tex.get_width() == 16:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (clipboard_vision_input_texture) failed.")

	# Test 8: MessageBubble with Attached Vision Inputs
	var bubble = AISidebarMessageBubble.new("user", "Check this layout", [vi])
	bubble._ready()
	var has_tex_rect = false
	for child in bubble._vbox.get_children():
		if child is TextureRect and child.texture != null:
			has_tex_rect = true
			break
	if has_tex_rect:
		passed += 1
	else:
		failed += 1
		errors.append("Test 8 (message_bubble_attached_image) failed.")

	# Test 9: AgentRunner start_task with initial_vision_inputs
	var mock_p2 = MockQueueProvider.new()
	var ctx2 = AISidebarAgentContext.new()
	var runner2 = AISidebarAgentRunner.new(mock_p2, ctx2)
	runner2.start_task("Inspect image", "", [vi])
	if mock_p2.last_sent_images.size() == 1 and ctx2.messages.size() > 0 and ctx2.messages[0].has("vision_inputs"):
		passed += 1
	else:
		failed += 1
		errors.append("Test 9 (agent_runner_initial_vision_inputs) failed: sent_imgs=" + str(mock_p2.last_sent_images.size()) + " ctx=" + str(ctx2.messages))

	# Test 10: Queueing item with vision_inputs (gerçek MessageQueuePanel)
	var vq = AISidebarMessageQueuePanel.new()
	vq.enqueue("Analyze screenshot", "Analyze screenshot", [vi])
	vq.enqueue("No image", "No image")
	var popped_q = vq.pop_next()
	var popped_plain = vq.pop_next()
	var vq_empty = vq.count() == 0
	vq.free()
	if popped_q.get("vision_inputs", []) == [vi] and popped_q.get("prompt", "") == "Analyze screenshot" and not popped_plain.has("vision_inputs") and vq_empty:
		passed += 1
	else:
		failed += 1
		errors.append("Test 10 (queue_with_vision_inputs) failed.")

	# Test 11: ChatDock clipboard attachment UI lifecycle
	var dock_scene = load("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
	var dock = dock_scene.instantiate()
	dock._ready()
	dock.composer.attach_image_from_clipboard(test_img)
	var has_attached = (dock.composer.attached_vision_input != null and dock.composer.attachment_container.visible == true)
	dock.composer.clear_attached_image()
	var has_cleared = (dock.composer.attached_vision_input == null and dock.composer.attachment_container.visible == false)
	dock.queue_free()
	if has_attached and has_cleared:
		passed += 1
	else:
		failed += 1
		errors.append("Test 11 (chat_dock_attachment_ui_lifecycle) failed: attached=" + str(has_attached) + " cleared=" + str(has_cleared))

	# Test 12: Attachment Preservation on Error (P2 UX Regression Test)
	var dock2 = dock_scene.instantiate()
	dock2._ready()
	dock2.composer.attach_image_from_clipboard(test_img)
	var vi_ref = dock2.composer.attached_vision_input
	dock2.tasks.last_sent_vision_input = vi_ref
	dock2.composer.clear_attached_image()
	# Simüle edilen sağlayıcı hatası (örn. AGY vision reddi)
	dock2.tasks.on_error("Antigravity CLI görsel girdisini desteklemiyor")
	var restored_ok = (dock2.composer.attached_vision_input != null and dock2.composer.attachment_container.visible == true)
	dock2.queue_free()
	if restored_ok:
		passed += 1
	else:
		failed += 1
		errors.append("Test 12 (attachment_preservation_on_error) failed: Görsel eki hata anında geri yüklenmedi.")

	return {"name": "UIUXQueueAndInputTests", "passed": passed, "failed": failed, "errors": errors}
