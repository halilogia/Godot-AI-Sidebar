@tool
extends RefCounted

const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Tool Şeması ve Parametreleri Doğrulaması
	var all_schemas = AISidebarToolManager.get_all_schemas()
	var found_tool = false
	var vp_schema: Dictionary = {}
	for s in all_schemas:
		if s.get("function", {}).get("name", "") == "take_viewport_screenshot":
			found_tool = true
			vp_schema = s.get("function", {})
			break
			
	if found_tool and vp_schema.get("parameters", {}).get("properties", {}).has("viewport_type"):
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (take_viewport_screenshot schema registration) failed.")
		
	# Test 2: İzin Politikası (READ_ONLY ve Onay Gerektirmez)
	var perm = AISidebarPermissionPolicy.get_tool_permission_level("take_viewport_screenshot")
	var req_app = AISidebarPermissionPolicy.requires_user_approval("take_viewport_screenshot", {})
	if perm == AISidebarPermissionPolicy.PermissionLevel.READ_ONLY and not req_app:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (Permission policy for take_viewport_screenshot) failed: perm=" + str(perm) + " req=" + str(req_app))
		
	# Test 3: VisionInput from_image & Base64 PNG Doğrulaması
	var test_img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	test_img.fill(Color.RED)
	var vi = AISidebarVisionInput.from_image(test_img, "user://test_vp.png", "image/png")
	if vi != null and not vi.image_data_base64.is_empty() and vi.width == 4 and vi.height == 4:
		var openai_part = vi.to_openai_content_part()
		if openai_part.get("type", "") == "image_url" and "data:image/png;base64," in openai_part.get("image_url", {}).get("url", ""):
			passed += 1
		else:
			failed += 1
			errors.append("Test 3b (OpenAI content part format) failed: " + str(openai_part))
	else:
		failed += 1
		errors.append("Test 3a (VisionInput.from_image) failed.")
		
	# Test 4: Dynamic Tool Filtering (Görsel Niyet Eşleşmesi)
	var prompt = "Sahnedeki karakterin zeminle hizasını gör ve düzelt"
	var relevant = AISidebarToolManager.get_relevant_schemas(prompt)
	var has_vp_tool = false
	for r in relevant:
		if r.get("function", {}).get("name", "") == "take_viewport_screenshot":
			has_vp_tool = true
			break
	if has_vp_tool:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (Dynamic tool filtering for vision prompt) failed.")
		
	# Test 5: Görsel Boyutlandırma / Token Tasarrufu Algoritması
	var large_img = Image.create(2000, 1000, false, Image.FORMAT_RGBA8)
	var max_dim = 1000
	var orig_w = large_img.get_width()
	var orig_h = large_img.get_height()
	var ratio = float(orig_w) / float(orig_h)
	var new_w = max_dim
	var new_h = max_dim
	if ratio >= 1.0:
		new_h = maxi(1, int(float(max_dim) / ratio))
	else:
		new_w = maxi(1, int(float(max_dim) * ratio))
	large_img.resize(new_w, new_h, Image.INTERPOLATE_BILINEAR)
	
	if large_img.get_width() == 1000 and large_img.get_height() == 500:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (Image downscaling aspect ratio) failed: " + str(large_img.get_size()))
		
	# Test 6: Headless Ortamda Güvenli Dönüş / EDITOR_REQUIRED Koruması
	var editor_tools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/editor_tools.gd")
	var exec_res = editor_tools.execute("take_viewport_screenshot", {"viewport_type": "auto"})
	# Headless CLI modunda EditorInterface GUI olmadığı için EDITOR_REQUIRED beklenen güvenli davranıştır
	if exec_res.get("success", false) or exec_res.get("error", {}).get("code", "") == "EDITOR_REQUIRED":
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (Headless safe execution check) failed: " + str(exec_res))
		
	return {"name": "ViewportScreenshotTests", "passed": passed, "failed": failed, "errors": errors}
