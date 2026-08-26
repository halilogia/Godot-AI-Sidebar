@tool
extends RefCounted

const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var vi = AISidebarVisionInput.new("user://test.png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==", 1, 1)
	var openai_part = vi.to_openai_content_part()
	
	if openai_part.get("type", "") == "image_url" and "data:image/png;base64," in openai_part.get("image_url", {}).get("url", ""):
		passed += 1
	else:
		failed += 1
		errors.append("VisionInput OpenAI content formatı geçersiz: " + str(openai_part))
		
	return {"name": "VisionInputTests", "passed": passed, "failed": failed, "errors": errors}
