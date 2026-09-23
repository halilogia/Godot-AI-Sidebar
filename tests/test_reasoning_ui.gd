@tool
extends RefCounted

## Reasoning / Thinking UI: propagation, aggregation, cap, separation.

const AISidebarReasoningCard = preload("res://addons/godot_sidebar_ai/ui/components/reasoning_card.gd")
const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")

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

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. reasoning event -> kart oluşur, collapsed başlar
	var dock1 = _dock()
	dock1._on_agent_chunk_received("", "Önce dosyayı okuyacağım.")
	var cards1 = _reasoning_cards(dock1)
	for c in cards1:
		c._ready()
	if cards1.size() == 1 and "Önce dosyayı" in cards1[0].get_text() and not cards1[0].is_expanded and cards1[0].get_header_text().begins_with("▸"):
		passed += 1
	else:
		failed += 1
		errors.append("T1 (reasoning creates collapsed card) failed.")
	dock1.queue_free()

	# 2. reasoning yoksa kart yok, normal akış bozulmaz
	var dock2 = _dock()
	dock2._on_agent_chunk_received("", "")
	dock2._on_agent_thinking_received("")
	dock2._on_agent_chunk_received("Merhaba dünya", "")
	if _reasoning_cards(dock2).is_empty() and dock2._current_assistant_bubble != null:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (no-reasoning provider) failed.")
	dock2.queue_free()

	# 3. streaming aggregation (sıralı birikim)
	var dock3 = _dock()
	dock3._on_agent_chunk_received("", "Adım 1. ")
	dock3._on_agent_chunk_received("", "Adım 2. ")
	dock3._on_agent_chunk_received("", "Adım 3.")
	var cards3 = _reasoning_cards(dock3)
	if cards3.size() == 1 and cards3[0].get_text() == "Adım 1. Adım 2. Adım 3.":
		passed += 1
	else:
		failed += 1
		errors.append("T3 (streaming aggregation) failed.")
	dock3.queue_free()

	# 4. final thinking duplicate üretmez (delta toplamı korunur)
	var dock4 = _dock()
	dock4._on_agent_chunk_received("", "Parça A. ")
	dock4._on_agent_chunk_received("", "Parça B.")
	dock4._on_agent_thinking_received("Parça A. Parça B.")
	var cards4 = _reasoning_cards(dock4)
	if cards4.size() == 1 and cards4[0].get_text() == "Parça A. Parça B.":
		passed += 1
	else:
		failed += 1
		errors.append("T4 (no duplication) failed: '" + (cards4[0].get_text() if cards4.size() > 0 else "?") + "'")
	dock4.queue_free()

	# 5. stream-dışı final reasoning kartı doldurur
	var dock5 = _dock()
	dock5._on_agent_thinking_received("Tam metin gerekçe.")
	var cards5 = _reasoning_cards(dock5)
	if cards5.size() == 1 and cards5[0].get_text() == "Tam metin gerekçe.":
		passed += 1
	else:
		failed += 1
		errors.append("T5 (final-only reasoning) failed.")
	dock5.queue_free()

	# 6. display cap (3000) + truncation işareti
	var card6 = AISidebarReasoningCard.new()
	card6._ready()
	card6.append_reasoning("x".repeat(5000))
	if card6.get_text().length() <= AISidebarReasoningCard.MAX_DISPLAY_CHARS + 20 and card6.is_truncated() and "[truncated]" in card6._content_lbl.text:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (display cap) failed: len=%d" % card6.get_text().length())
	card6.queue_free()

	# 7. final cevap ayrı kalır (reasoning bubble'a karışmaz)
	var dock7 = _dock()
	dock7._on_agent_chunk_received("", "Gizli gerekçe.")
	dock7._on_agent_chunk_received("Görünen cevap.", "")
	var bubble_txt = dock7._current_assistant_bubble.text_content if dock7._current_assistant_bubble else ""
	if bubble_txt == "Görünen cevap." and not "Gizli" in bubble_txt:
		passed += 1
	else:
		failed += 1
		errors.append("T7 (answer separation) failed: '" + bubble_txt + "'")
	dock7.queue_free()

	# 8. AGY tarzı boş thinking akışı: kart yok, crash yok
	var dock8 = _dock()
	for i in range(5):
		dock8._on_agent_chunk_received("parça ", "")
	dock8._on_agent_thinking_received("")
	dock8._on_agent_text_received("assistant", "Son cevap.")
	if _reasoning_cards(dock8).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T8 (AGY empty thinking) failed.")
	dock8.queue_free()

	return {"name": "ReasoningUITests", "passed": passed, "failed": failed, "errors": errors}
