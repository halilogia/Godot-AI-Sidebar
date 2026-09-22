@tool
extends RefCounted

## Runtime screenshot -> vision zinciri için DETERMINISTIK testler.
## Oyun viewport kaynağı (bridge), vision payload, pending queue,
## vision-capable/non-vision routing.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarRuntimeDebugger = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_debugger.gd")
const AISidebarEditorTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/editor_tools.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")

class MockVisionProvider extends AISidebarAIProvider:
	var multimodal_calls: Array = []
	var chat_calls: Array = []
	func supports_vision() -> bool:
		return true
	func send_multimodal_chat(messages: Array, tools_schema: Array, images: Array) -> void:
		multimodal_calls.append({"images": images.duplicate()})
	func send_chat(messages: Array, tools_schema: Array) -> void:
		chat_calls.append(true)

class MockNoVisionProvider extends AISidebarAIProvider:
	var chat_calls: Array = []
	func send_chat(messages: Array, tools_schema: Array) -> void:
		chat_calls.append(true)

static func _solid_image(w: int, h: int) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.4, 0.8))
	return img

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# A) runtime payload: base64 + has_vision_data
	var img_a = _solid_image(32, 16)
	var res_a = AISidebarRuntimeDebugger.build_runtime_payload("user://test_runtime_payload.png", img_a)
	var data_a = res_a.get("data", {})
	if bool(res_a.get("success", false)) and bool(data_a.get("has_vision_data", false)) and not str(data_a.get("base64", "")).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("A (payload base64+vision flag) failed.")
	if FileAccess.file_exists("user://test_runtime_payload.png"):
		DirAccess.remove_absolute("user://test_runtime_payload.png")

	# B) path + dimensions + capture_target; boş image -> IMAGE_EMPTY
	var img_b = _solid_image(40, 20)
	var res_b = AISidebarRuntimeDebugger.build_runtime_payload("user://test_runtime_dims.png", img_b)
	var data_b = res_b.get("data", {})
	var res_empty = AISidebarRuntimeDebugger.build_runtime_payload("user://x.png", Image.new())
	if data_b is Dictionary and str(data_b.get("path", "")) == "user://test_runtime_dims.png" and int(data_b.get("width", 0)) == 40 and int(data_b.get("height", 0)) == 20 and str(data_b.get("capture_target", "")) == "runtime_viewport" and str(res_empty.get("error", {}).get("code", "")) == "IMAGE_EMPTY":
		passed += 1
	else:
		failed += 1
		errors.append("B (path+dims+target) failed.")
	if FileAccess.file_exists("user://test_runtime_dims.png"):
		DirAccess.remove_absolute("user://test_runtime_dims.png")

	# C) image data pending vision queue'ya giriyor
	var ctx_c = AISidebarAgentContext.new()
	var runner_c = AISidebarAgentRunner.new(MockNoVisionProvider.new(), ctx_c)
	var crafted = {"success": true, "data": {"path": "user://snap.png", "base64": "YWI=", "has_vision_data": true, "width": 8, "height": 4}, "message": "ok"}
	runner_c._complete_tool_turn("take_runtime_screenshot", "call_v", {}, crafted, true, "ok")
	if runner_c._pending_vision_inputs.size() == 1 and str(runner_c._pending_vision_inputs[0].image_path) == "user://snap.png":
		passed += 1
	else:
		failed += 1
		errors.append("C (pending queue) failed: %d" % runner_c._pending_vision_inputs.size())

	# D) vision-capable provider: sonraki turda image gönderiliyor
	var prov_d = MockVisionProvider.new()
	var ctx_d = AISidebarAgentContext.new()
	var runner_d = AISidebarAgentRunner.new(prov_d, ctx_d)
	runner_d._pending_vision_inputs.append(AISidebarVisionInput.new("user://snap.png", "YWI=", 8, 4))
	runner_d._dispatch_llm_turn([], [])
	if prov_d.multimodal_calls.size() == 1 and (prov_d.multimodal_calls[0].get("images", []) as Array).size() == 1 and runner_d._pending_vision_inputs.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("D (multimodal send) failed.")

	# E) vision olmayan provider: gönderilmiyor, transcriptte açık kayıt
	var prov_e = MockNoVisionProvider.new()
	var ctx_e = AISidebarAgentContext.new()
	ctx_e.begin_task("Görsel görev", "")
	var runner_e = AISidebarAgentRunner.new(prov_e, ctx_e)
	runner_e._pending_vision_inputs.append(AISidebarVisionInput.new("user://snap2.png", "YWI=", 8, 4))
	runner_e._dispatch_llm_turn([], [])
	var md_e = AISidebarChatExporter.export_transcript_to_markdown(ctx_e.get_transcript().to_data(), [], {})
	if prov_e.chat_calls.size() == 1 and runner_e._pending_vision_inputs.is_empty() and "NOT sent to model" in md_e and "snap2.png" in md_e:
		passed += 1
	else:
		failed += 1
		errors.append("E (drop with note) failed.")

	# F) sync yol async'e yönlendiriyor; viewport davranışı ayrı
	var res_f = AISidebarEditorTools.execute("take_runtime_screenshot", {})
	if str(res_f.get("error", {}).get("code", "")) == "ASYNC_REQUIRED":
		passed += 1
	else:
		failed += 1
		errors.append("F (async routing) failed: " + str(res_f.get("error", {})))

	return {"name": "RuntimeVisionChainTests", "passed": passed, "failed": failed, "errors": errors}
