@tool
extends RefCounted

## Chronological Copy Task + bottom checklist + collapse için DETERMINISTIK testler.

const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")
const AISidebarTaskChecklist = preload("res://addons/godot_sidebar_ai/ui/components/task_checklist.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")
const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

static func _ordered_task() -> Dictionary:
	var tr = AISidebarTaskTranscript.new()
	tr.begin_task("Sahne kur", "")
	tr.mark_step(1)
	tr.record("clarification_answered", {"answer": "3D yap"})
	tr.mark_step(2)
	tr.record("plan_proposed", {"steps": 2, "files": 1, "goal": "3D grid"})
	tr.record("plan_approved", {})
	tr.mark_step(3)
	tr.record("tool_executing", {"tool": "create_scene", "title": "Created scene Main.tscn", "args": "{}"})
	tr.record("tool_completed", {"tool": "create_scene", "title": "Created scene Main.tscn", "success": true, "error": "", "duration_ms": 50})
	tr.record("activity", {"icon": "✓", "title": "Created scene Main.tscn"})
	tr.mark_step(4)
	tr.record("tool_executing", {"tool": "validate_script", "title": "Validated", "args": "{}"})
	tr.record("tool_completed", {"tool": "validate_script", "title": "Validated", "success": false, "error": "Unexpected indent.", "duration_ms": 120})
	tr.end_task("failed", "Unexpected indent.", {"success": false})
	return tr.get_current_task()

static func _clear_stream(dock) -> void:
	if dock.message_stream:
		for child in dock.message_stream.get_children():
			child.free()
	dock.activity.group = null
	dock.checklist_tracker.checklist = null

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Chronological Copy Task order (timeline sırası korunur)
	var task1 = _ordered_task()
	var md1 = AISidebarChatExporter.export_single_task_chronological(task1)
	var p_clar = md1.find("3D yap")
	var p_plan = md1.find("Plan approved")
	var p_tool = md1.find("create_scene")
	var p_fail = md1.find("Unexpected indent.")
	if p_clar > 0 and p_clar < p_plan and p_plan < p_tool and p_tool < p_fail and "[S1]" in md1 and "[S4]" in md1:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (chronological order) failed: %d %d %d %d" % [p_clar, p_plan, p_tool, p_fail])

	# 2. Copy Task ters sırada değil (ilk timeline satırı S1, son timeline satırı S4)
	var tl_lines: Array = []
	for line in md1.split("\n"):
		if line.begins_with("[S"):
			tl_lines.append(line)
	if tl_lines.size() >= 2 and tl_lines[0].begins_with("[S1]") and "3D yap" in tl_lines[0] and tl_lines[tl_lines.size() - 1].begins_with("[S4]"):
		passed += 1
	else:
		failed += 1
		errors.append("T2 (not reversed) failed: %d timeline lines" % tl_lines.size())

	# 3. Everything Export gruplu formatını koruyor
	var md3 = AISidebarChatExporter.export_single_task_to_markdown(task1)
	var g_calls = md3.find("### Tool Calls")
	var g_results = md3.find("### Tool Results")
	var g_check = md3.find("### Task Checklist")
	if g_calls > 0 and g_calls < g_results:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (grouped format intact) failed: %d %d" % [g_calls, g_results])

	# 4. Checklist creation (plan step sayısı)
	var cl4 = AISidebarTaskChecklist.new()
	cl4.setup(["Create Main.tscn", "Validate GDScript"], "Sahne kur")
	cl4._ready()
	if cl4.step_count() == 2 and cl4.is_expanded and "0/2" in cl4.get_header_text():
		passed += 1
	else:
		failed += 1
		errors.append("T4 (checklist creation) failed: '" + cl4.get_header_text() + "'")
	cl4.queue_free()

	# 5-6. Dock: checklist en alta taşınıyor + yeni component sonrası da sonda
	var dock = ChatDockScene.instantiate()
	if dock == null:
		failed += 2
		errors.append("T5/T6 dock instantiate failed.")
		return {"name": "TaskCopyOrderTests", "passed": passed, "failed": failed, "errors": errors}
	dock._ready()
	dock.auto_scroll_enabled = false
	_clear_stream(dock)
	var cl = AISidebarTaskChecklist.new()
	cl.setup(["Create Main.tscn"], "Sahne kur")
	cl._ready()
	dock.checklist_tracker.checklist = cl
	dock.add_stream_component(cl)
	var bubble = AISidebarMessageBubble.new("assistant", "Not metni")
	dock.add_stream_component(bubble)
	var last5 = dock.message_stream.get_child(dock.message_stream.get_child_count() - 1)
	if last5 == cl:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (checklist bottom) failed.")
	var grp = AISidebarActivityGroup.new(true)
	grp._ready()
	dock.add_stream_component(grp)
	var bubble2 = AISidebarMessageBubble.new("assistant", "İkinci not")
	dock.add_stream_component(bubble2)
	var last6 = dock.message_stream.get_child(dock.message_stream.get_child_count() - 1)
	if last6 == cl:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (checklist stays last) failed.")
	_clear_stream(dock)
	dock.queue_free()

	# 7. Collapse/expand (kullanıcı toggle korunur)
	var cl7 = AISidebarTaskChecklist.new()
	cl7.setup(["A", "B"], "g")
	cl7._ready()
	var expanded_before = cl7.is_expanded and cl7._items_container.visible
	cl7.set_expanded(false)
	var collapsed_mid = not cl7.is_expanded and not cl7._items_container.visible and cl7.get_header_text().begins_with("▸")
	# Kullanıcı toggle sonrası finish zorla değiştirmemeli (toggle×2 → expanded+toggled)
	cl7.set_expanded(true)
	cl7._header_btn.pressed.emit()
	cl7._header_btn.pressed.emit()
	cl7.set_finished_success()
	var preserved = cl7.is_expanded
	# Dokunulmamış checklist finish'te kapanır
	var cl7b = AISidebarTaskChecklist.new()
	cl7b.setup(["A"], "g")
	cl7b._ready()
	cl7b.set_finished_success()
	if expanded_before and collapsed_mid and preserved and not cl7b.is_expanded:
		passed += 1
	else:
		failed += 1
		errors.append("T7 (collapse/expand) failed.")
	cl7.queue_free()
	cl7b.queue_free()

	# 8. Completed checklist state
	var cl8 = AISidebarTaskChecklist.new()
	cl8.setup(["A", "B", "C", "D"], "g")
	cl8._ready()
	cl8.set_finished_success()
	if cl8.get_states() == ["completed", "completed", "completed", "completed"] and "4/4" in cl8.get_header_text():
		passed += 1
	else:
		failed += 1
		errors.append("T8 (completed state) failed: '" + cl8.get_header_text() + "'")
	cl8.queue_free()

	# 9. Failed checklist state
	var cl9 = AISidebarTaskChecklist.new()
	cl9.setup(["A", "B"], "g")
	cl9._ready()
	cl9.set_step_state(0, AISidebarTaskChecklist.STATE_COMPLETED)
	cl9.set_step_state(1, AISidebarTaskChecklist.STATE_RUNNING)
	cl9.finish_with_stop(1, "Tool-call limit reached: 20/20")
	if cl9.get_states() == ["completed", "failed"] and cl9.get_header_text().contains(AISidebarI18n.get_text("checklist_stopped", {"done": 1, "total": 2, "reason": ""}).strip_edges()) and "20/20" in cl9.get_header_text():
		passed += 1
	else:
		failed += 1
		errors.append("T9 (failed state) failed: '" + cl9.get_header_text() + "'")
	cl9.queue_free()

	return {"name": "TaskCopyOrderTests", "passed": passed, "failed": failed, "errors": errors}
