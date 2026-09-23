@tool
extends RefCounted

## Action / Summary UI: özet gösterimi, ham reasoning sızıntısı yok,
## collapse/cap, cevap ayrımı, AGY boş akışı.

const AISidebarReasoningCard = preload("res://addons/godot_sidebar_ai/ui/components/reasoning_card.gd")
const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")

const SECRET_MARKER = "GIZLI_DUSUNCE_XYZ_123"

static func _dock():
	var dock = ChatDockScene.instantiate()
	dock._ready()
	dock._auto_scroll_enabled = false
	for child in dock.message_stream.get_children():
		child.free()
	dock._current_assistant_bubble = null
	dock._current_reasoning_card = null
	dock._current_activity_group = null
	dock._reset_stream_buffer()
	return dock

static func _reasoning_cards(dock) -> Array:
	var out: Array = []
	for child in dock.message_stream.get_children():
		if child is AISidebarReasoningCard:
			out.append(child)
	return out

static func _stream_text(dock) -> String:
	var out = ""
	for child in dock.message_stream.get_children():
		if child is AISidebarReasoningCard:
			out += child.get_text()
		elif child.has_method("get") and "text_content" in child:
			out += str(child.get("text_content"))
	return out

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. summary gösteriliyor (tool event -> action kartı)
	var dock1 = _dock()
	dock1._on_agent_tool_executing("validate_script", {})
	var cards1 = _reasoning_cards(dock1)
	for c in cards1:
		c._ready()
	if cards1.size() == 1 and "Validat" in cards1[0].get_text() and not cards1[0].is_expanded:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (summary shown) failed.")
	dock1.queue_free()

	# 2. ham reasoning UI'a sızmıyor (chunk + final + bubble + export metni)
	var dock2 = _dock()
	dock2._on_agent_chunk_received("", SECRET_MARKER + " bir plan düşünüyorum")
	dock2._on_agent_thinking_received(SECRET_MARKER + " tam gerekçe")
	dock2._on_agent_tool_executing("read_script", {"file_path": "res://a.gd"})
	dock2._on_agent_chunk_received("Görünen cevap.", "")
	if not SECRET_MARKER in _stream_text(dock2):
		passed += 1
	else:
		failed += 1
		errors.append("T2 (no raw reasoning leak) failed.")
	dock2.queue_free()

	# 3. no-reasoning provider normal çalışıyor (tool özeti + cevap akışı)
	var dock3 = _dock()
	dock3._on_agent_tool_executing("analyze_project", {})
	dock3._on_agent_tool_completed("analyze_project", {"success": true, "data": {}, "message": "ok"})
	dock3._on_agent_chunk_received("Analiz bitti.", "")
	var cards3 = _reasoning_cards(dock3)
	var bubble3 = dock3._current_assistant_bubble.text_content if dock3._current_assistant_bubble else ""
	if cards3.size() == 1 and bubble3 == "Analiz bitti.":
		passed += 1
	else:
		failed += 1
		errors.append("T3 (no-reasoning flow) failed.")
	dock3.queue_free()

	# 4. streaming sırasında UI bozulmuyor (tek kart, son action)
	var dock4 = _dock()
	dock4._on_agent_tool_executing("read_script", {"file_path": "res://a.gd"})
	dock4._on_agent_tool_executing("validate_script", {})
	dock4._on_agent_tool_completed("validate_script", {"success": true, "data": {}, "message": "ok"})
	var cards4 = _reasoning_cards(dock4)
	if cards4.size() == 1 and "Validat" in cards4[0].get_text():
		passed += 1
	else:
		failed += 1
		errors.append("T4 (streaming stable) failed.")
	dock4.queue_free()

	# 5. final response ayrı kalır
	var dock5 = _dock()
	dock5._on_agent_tool_executing("read_script", {"file_path": "res://a.gd"})
	dock5._on_agent_text_received("assistant", "Dosya okundu ve hazır.")
	var bubble5 = ""
	for child in dock5.message_stream.get_children():
		if "text_content" in child and not (child is AISidebarReasoningCard):
			bubble5 += str(child.get("text_content"))
	if bubble5 == "Dosya okundu ve hazır.":
		passed += 1
	else:
		failed += 1
		errors.append("T5 (answer separation) failed: '" + bubble5 + "'")
	dock5.queue_free()

	# 6. collapse + cap korunuyor
	var card6 = AISidebarReasoningCard.new()
	card6._ready()
	card6.set_action("▶ " + "x".repeat(5000))
	var collapsed_ok = card6.get_header_text().begins_with("▸")
	card6.set_expanded(true)
	if collapsed_ok and card6.get_text().length() <= AISidebarReasoningCard.MAX_DISPLAY_CHARS + 20 and card6.is_truncated():
		passed += 1
	else:
		failed += 1
		errors.append("T6 (collapse+cap) failed.")
	card6.queue_free()

	# 7. AGY tarzı akış: thinking yok, tool yoksa kart yok
	var dock7 = _dock()
	for i in range(3):
		dock7._on_agent_chunk_received("parça ", "")
	dock7._on_agent_thinking_received("")
	if _reasoning_cards(dock7).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T7 (AGY no card) failed.")
	dock7.queue_free()

	return {"name": "ReasoningUITests", "passed": passed, "failed": failed, "errors": errors}
