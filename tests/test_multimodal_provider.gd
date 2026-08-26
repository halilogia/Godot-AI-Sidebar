@tool
extends RefCounted

const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")

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
		
	return {"name": "MultimodalProviderTests", "passed": passed, "failed": failed, "errors": errors}
