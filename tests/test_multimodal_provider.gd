@tool
extends RefCounted

const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")

class MockNetworkManager extends AISidebarNetworkManager:
	var last_body: Dictionary = {}
	var last_url: String = ""
	
	func post_request(url: String, _headers: PackedStringArray, body_json: String) -> Error:
		last_url = url
		var parsed = JSON.parse_string(body_json)
		if parsed is Dictionary:
			last_body = parsed
		return OK

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var prov = AISidebarOpenAICompatibleProvider.new(null)
	
	# Test 1: Capability Detection (all models keyword has vision)
	if prov.supports_vision():
		passed += 1
	else:
		failed += 1
		errors.append("Vision capability tespiti başarısız.")
		
	# Test 2: Multimodal Vision Input generation
	var v_input = AISidebarVisionInput.new("user://screenshot.png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==", 1920, 1080)
	var content_part = v_input.to_openai_content_part()
	
	if content_part.get("type", "") == "image_url" and "data:image/png;base64," in content_part.get("image_url", {}).get("url", ""):
		passed += 1
	else:
		failed += 1
		errors.append("Multimodal image_url parçası formatı hatalı: " + str(content_part))

	# Test 3: OpenAICompatibleProvider multimodal payload generation & network delivery
	var mock_nm = MockNetworkManager.new()
	var prov_with_net = AISidebarOpenAICompatibleProvider.new(mock_nm)
	var messages = [{"role": "user", "content": "What is this image?"}]
	prov_with_net.send_multimodal_chat(messages, [], [v_input])
	
	var sent_msgs = mock_nm.last_body.get("messages", [])
	var user_msg = sent_msgs[-1] if sent_msgs.size() > 0 else {}
	var user_content = user_msg.get("content", [])
	
	var has_img_part = false
	if user_content is Array:
		for part in user_content:
			if part is Dictionary and part.get("type") == "image_url":
				if "data:image/png;base64," in part.get("image_url", {}).get("url", ""):
					has_img_part = true
					break
					
	if has_img_part and mock_nm.last_url.ends_with("/chat/completions"):
		passed += 1
	else:
		failed += 1
		errors.append("OpenAI provider multimodal payload has_img_part failed: " + str(user_content))
		
	return {"name": "MultimodalProviderTests", "passed": passed, "failed": failed, "errors": errors}
