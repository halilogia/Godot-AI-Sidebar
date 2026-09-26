@tool
extends RefCounted

## take_editor_screenshot: gerçek editörün (yan panel dahil) görüntüsü dış ajana görüntü olarak gider.
## Kırpma saf fonksiyonu, araç şeması (region), köprüde açık olması ve editör dışı hata yolu.

const AISidebarRuntimeDebugger = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_debugger.gd")
const AISidebarEditorTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/editor_tools.gd")
const AISidebarExternalAgentGateway = preload("res://addons/godot_sidebar_ai/core/bridge/external_agent_gateway.gd")

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	# T1 Kırpma: içeride kırpar, taşanı sınıra kısar, boş dikdörtgende görüntüyü aynen verir.
	var img := Image.create(100, 80, false, Image.FORMAT_RGBA8)
	var inner := AISidebarRuntimeDebugger.crop_image(img, Rect2i(10, 5, 30, 20))
	var clipped := AISidebarRuntimeDebugger.crop_image(img, Rect2i(90, 70, 50, 50))
	var whole := AISidebarRuntimeDebugger.crop_image(img, Rect2i())
	var outside := AISidebarRuntimeDebugger.crop_image(img, Rect2i(500, 500, 10, 10))
	if inner.get_size() == Vector2i(30, 20) and clipped.get_size() == Vector2i(10, 10) and whole.get_size() == Vector2i(100, 80) and outside.get_size() == Vector2i(100, 80):
		passed += 1
	else:
		failed += 1
		errors.append("T1 crop: inner=%s clipped=%s whole=%s outside=%s" % [inner.get_size(), clipped.get_size(), whole.get_size(), outside.get_size()])

	# T2 Şema region=window|sidebar sunar; araç köprüde açıktır (dış ajan editörü görebilir).
	var region_enum: Array = []
	for s: Dictionary in AISidebarEditorTools.get_schemas():
		var fn: Dictionary = s["function"]
		if str(fn["name"]) == "take_editor_screenshot":
			var params: Dictionary = fn["parameters"]
			var props: Dictionary = params["properties"]
			var region: Dictionary = props.get("region", {})
			region_enum = region.get("enum", [])
	if region_enum == ["window", "sidebar"] and AISidebarExternalAgentGateway.EXPOSED_TOOLS.has("take_editor_screenshot"):
		passed += 1
	else:
		failed += 1
		errors.append("T2 schema/exposure: enum=%s" % [region_enum])

	# T3 Editör dışında açık hata verir (sessizce boş görüntü dönmez).
	var res := AISidebarRuntimeDebugger.take_editor_screenshot("user://_test_editor_shot.png", Rect2i(0, 0, 10, 10))
	if res.get("success", true) == false and str(res).contains("EDITOR_REQUIRED"):
		passed += 1
	else:
		failed += 1
		errors.append("T3 non-editor: " + str(res))

	return {"name": "EditorScreenshotTests", "passed": passed, "failed": failed, "errors": errors}
