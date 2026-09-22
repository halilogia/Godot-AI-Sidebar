@tool
extends RefCounted

## Chat Image UX: exporter squelch, screenshot preview kartı, duplicate guard.

const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarScreenshotCard = preload("res://addons/godot_sidebar_ai/ui/components/screenshot_card.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")
const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")
const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")

static func _solid(w: int, h: int, c: Color) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(c)
	return img

static func _shot_result() -> Dictionary:
	var img = _solid(16, 8, Color(0.2, 0.4, 0.8))
	var b64 = Marshalls.raw_to_base64(img.save_png_to_buffer())
	return {"success": true, "data": {"path": "user://snap.png", "base64": b64, "has_vision_data": true, "width": 16, "height": 8, "capture_target": "runtime_viewport"}, "message": "ok"}

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Markdown base64 basmıyor, placeholder koyuyor; JSON aynen koruyor
	var hist1 = [{"role": "tool", "name": "take_runtime_screenshot", "tool_call_id": "c1", "content": JSON.stringify(_shot_result())}]
	var md1 = AISidebarChatExporter.export_to_markdown(hist1)
	var js1 = AISidebarChatExporter.export_to_json(hist1)
	var blob = str(_shot_result()["data"]["base64"])
	if not blob in md1 and "[image data omitted in Markdown]" in md1 and "📷 Screenshot" in md1 and blob in js1:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (markdown squelch, json intact) failed.")

	# 2. Screenshot kartı: kaynak + durum etiketleri
	var vi2 = AISidebarVisionInput.new("user://a.png", Marshalls.raw_to_base64(_solid(8, 4, Color.RED).save_png_to_buffer()), 8, 4)
	var card_rt = AISidebarScreenshotCard.new(vi2, "runtime_viewport", true)
	card_rt._ready()
	var card_ed = AISidebarScreenshotCard.new(vi2, "editor_viewport", false)
	card_ed._ready()
	if "Runtime" in AISidebarScreenshotCard.source_label("runtime_viewport") and "Editor" in AISidebarScreenshotCard.source_label("editor_viewport") and "Queued" in card_rt.status_text() and "Saved only" in card_ed.status_text():
		passed += 1
	else:
		failed += 1
		errors.append("T2 (card labels) failed.")
	card_rt.queue_free()
	card_ed.queue_free()

	# 3. Duplicate guard karşılaştırması
	var vi_a = AISidebarVisionInput.from_image(_solid(8, 8, Color.GREEN))
	var vi_b = AISidebarVisionInput.from_image(_solid(8, 8, Color.GREEN))
	var vi_c = AISidebarVisionInput.from_image(_solid(8, 8, Color.BLUE))
	if AISidebarVisionInput.is_same_image(vi_a, vi_b) and not AISidebarVisionInput.is_same_image(vi_a, vi_c) and not AISidebarVisionInput.is_same_image(vi_a, null):
		passed += 1
	else:
		failed += 1
		errors.append("T3 (duplicate guard) failed.")

	# 4. Transcript tool_completed image bilgisi exporta yansıyor
	var tr4 = AISidebarTaskTranscript.new()
	tr4.begin_task("t", "")
	tr4.record("tool_completed", {"tool": "take_runtime_screenshot", "title": "Shot", "success": true, "error": "", "duration_ms": 50, "has_image": true, "image_path": "user://snap.png"})
	tr4.end_task("completed", "", {"success": true})
	var md4 = AISidebarChatExporter.export_transcript_to_markdown(tr4.to_data(), [], {})
	if "📷 Screenshot" in md4 and "snap.png" in md4:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (transcript image line) failed.")

	# 5. Dock: başarılı screenshot -> preview kartı; başarısız/normal tool -> yok
	var dock = ChatDockScene.instantiate()
	if dock == null:
		failed += 1
		errors.append("T5 dock instantiate failed.")
		return {"name": "ChatImageUXTests", "passed": passed, "failed": failed, "errors": errors}
	dock._ready()
	dock._auto_scroll_enabled = false
	for child in dock.message_stream.get_children():
		child.free()
	dock._on_agent_tool_completed("take_runtime_screenshot", _shot_result())
	var found_card = null
	for child in dock.message_stream.get_children():
		if child is AISidebarScreenshotCard:
			found_card = child
	var n_before = dock.message_stream.get_child_count()
	dock._on_agent_tool_completed("read_script", {"success": true, "data": {}, "message": "ok"})
	dock._on_agent_tool_completed("take_runtime_screenshot", {"success": false, "error": {"code": "X", "message": "bad"}, "data": {}})
	var n_after = dock.message_stream.get_child_count()
	if found_card != null and "Runtime" in found_card.source_label(found_card.source_kind) and not found_card.sent_to_model and n_after == n_before:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (dock preview hook) failed.")
	for child in dock.message_stream.get_children():
		child.free()
	dock.queue_free()

	return {"name": "ChatImageUXTests", "passed": passed, "failed": failed, "errors": errors}
