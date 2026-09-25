@tool
extends RefCounted

## Action / Summary UI: özet gösterimi, ham reasoning sızıntısı yok,
## collapse/cap, cevap ayrımı, AGY boş akışı.

const AISidebarReasoningCard = preload("res://addons/godot_sidebar_ai/ui/components/reasoning_card.gd")
const AISidebarThinkingCard = preload("res://addons/godot_sidebar_ai/ui/components/thinking_card.gd")
const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")

const SECRET_MARKER = "GIZLI_DUSUNCE_XYZ_123"

static func _dock():
	var dock = ChatDockScene.instantiate()
	dock._ready()
	dock._auto_scroll_enabled = false
	for child in dock.message_stream.get_children():
		child.free()
	dock._stream.assistant_bubble = null
	dock._stream.reasoning_card = null
	dock._current_activity_group = null
	dock._stream.reset_stream_buffer()
	return dock

static func _reasoning_cards(dock) -> Array:
	var out: Array = []
	for child in dock.message_stream.get_children():
		if child is AISidebarReasoningCard:
			out.append(child)
	return out

static func _thinking_cards(dock) -> Array:
	var out: Array = []
	for child in dock.message_stream.get_children():
		if child is AISidebarThinkingCard:
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
	dock2._stream.on_chunk_received("", SECRET_MARKER + " bir plan düşünüyorum")
	dock2._stream.on_thinking_received(SECRET_MARKER + " tam gerekçe")
	dock2._on_agent_tool_executing("read_script", {"file_path": "res://a.gd"})
	dock2._stream.on_chunk_received("Görünen cevap.", "")
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
	dock3._stream.on_chunk_received("Analiz bitti.", "")
	var cards3 = _reasoning_cards(dock3)
	var bubble3 = dock3._stream.assistant_bubble.text_content if dock3._stream.assistant_bubble else ""
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
	dock5._stream.on_text_received("assistant", "Dosya okundu ve hazır.")
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
		dock7._stream.on_chunk_received("parça ", "")
	dock7._stream.on_thinking_received("")
	if _reasoning_cards(dock7).is_empty() and _thinking_cards(dock7).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T7 (AGY no card) failed.")
	dock7.queue_free()

	# 8. Thinking kartı: chunk ile oluşur, collapsed başlar, action kartından ayrı
	var dock8 = _dock()
	dock8._stream.on_chunk_received("", "Düşünce parçası.")
	var tcards8 = _thinking_cards(dock8)
	for c in tcards8:
		c._ready()
	if tcards8.size() == 1 and "Düşünce parçası." in tcards8[0].get_text() and not tcards8[0].is_expanded and tcards8[0].get_header_text().begins_with("▸") and _reasoning_cards(dock8).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T8 (thinking card) failed.")
	dock8.queue_free()

	# 9. Thinking birikimi + final duplicate yok
	var dock9 = _dock()
	dock9._stream.on_chunk_received("", "A. ")
	dock9._stream.on_chunk_received("", "B.")
	dock9._stream.on_thinking_received("A. B.")
	var tcards9 = _thinking_cards(dock9)
	if tcards9.size() == 1 and tcards9[0].get_text() == "A. B.":
		passed += 1
	else:
		failed += 1
		errors.append("T9 (thinking aggregation) failed.")
	dock9.queue_free()

	# 10. Thinking cap + boş thinking kart açmaz
	var dock10 = _dock()
	dock10._stream.on_chunk_received("", "")
	dock10._stream.on_thinking_received("   ")
	var card10 = AISidebarThinkingCard.new()
	card10._ready()
	card10.append_thinking("y".repeat(5000))
	if _thinking_cards(dock10).is_empty() and card10.is_truncated() and card10.get_text().length() <= AISidebarThinkingCard.MAX_DISPLAY_CHARS + 20:
		passed += 1
	else:
		failed += 1
		errors.append("T10 (thinking cap+empty) failed.")
	card10.queue_free()
	dock10.queue_free()

	# 11. Yeni LLM turu: sahte "Düşünülüyor" balonu açılmaz; bekleme yalnızca rozette.
	# Gerçek thinking kartı cevabın ÜSTÜNDE kalır (önce düşünce, sonra cevap).
	var dock11 = _dock()
	dock11._stream.on_state_changed(AISidebarAgentRunner.AgentState.PLANNING, "")
	var placeholder_after_planning = dock11.message_stream.get_child_count()
	dock11._stream.on_chunk_received("", "Kullanıcı selam veriyor.")
	dock11._stream.on_chunk_received("Merhaba!", "")
	var t_idx = -1
	var b_idx = -1
	for child in dock11.message_stream.get_children():
		if child is AISidebarThinkingCard and t_idx < 0:
			t_idx = child.get_index()
		if child is AISidebarMessageBubble and b_idx < 0:
			b_idx = child.get_index()
	if placeholder_after_planning == 0 and t_idx >= 0 and b_idx > t_idx:
		passed += 1
	else:
		failed += 1
		errors.append("T11 (thinking above answer, no placeholder) failed: planning_children=%d thinking=%d bubble=%d" % [placeholder_after_planning, t_idx, b_idx])
	dock11._stream.stop_thinking_timer()
	dock11.free()

	# 12. Metinsiz tool turu: akışta asılı kalan bekleme balonu yok
	var dock12 = _dock()
	dock12._stream.on_state_changed(AISidebarAgentRunner.AgentState.PLANNING, "")
	dock12._on_agent_tool_executing("read_script", {"path": "res://a.gd"})
	var stale = 0
	for child in dock12.message_stream.get_children():
		if child is AISidebarMessageBubble:
			stale += 1
	if stale == 0:
		passed += 1
	else:
		failed += 1
		errors.append("T12 (no stale waiting bubble) failed: bubbles=%d" % stale)
	dock12._stream.stop_thinking_timer()
	dock12.free()

	return {"name": "ReasoningUITests", "passed": passed, "failed": failed, "errors": errors}
