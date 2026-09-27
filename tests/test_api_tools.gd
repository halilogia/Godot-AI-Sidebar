@tool
extends RefCounted

## get_godot_class_info: çalışan motorun ClassDB'sinden sınıf API'si; filtre daraltır; bilinmeyen ad benzer
## sınıfları önerir.

const AISidebarApiTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/api_tools.gd")

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	# T1 CharacterBody3D: miras, yöntem imzası, özellik tipi, enum sabiti.
	var r := AISidebarApiTools.execute(AISidebarApiTools.TOOL_NAME, {"class_name": "CharacterBody3D"})
	var d: Dictionary = r.get("data", {})
	var methods: Array = d.get("methods", [])
	var props: Array = d.get("properties", [])
	var consts: Array = d.get("constants", [])
	var inherits: Array = d.get("inherits", [])
	if r.get("success") == true and inherits.has("PhysicsBody3D") and methods.has("move_and_slide() -> bool") and props.has("velocity: Vector3") and consts.has("MotionMode.MOTION_MODE_GROUNDED = 0"):
		passed += 1
	else:
		failed += 1
		errors.append("T1 CharacterBody3D: " + JSON.stringify(d).left(500))

	# T2 Filtre ve sinyal: Area3D body_entered; filtre yalnız eşleşenleri bırakır.
	var a := AISidebarApiTools.execute(AISidebarApiTools.TOOL_NAME, {"class_name": "Area3D", "filter": "body_entered"})
	var ad: Dictionary = a.get("data", {})
	var signals: Array = ad.get("signals", [])
	var a_methods: Array = ad.get("methods", [])
	if signals.size() == 1 and str(signals[0]).begins_with("body_entered(") and a_methods.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T2 filter: " + JSON.stringify(ad).left(400))

	# T3 Bilinmeyen ad: hata + benzer sınıf önerisi.
	var u := AISidebarApiTools.execute(AISidebarApiTools.TOOL_NAME, {"class_name": "CharacterBody"})
	var ue: Dictionary = u.get("error", {}) if u.get("error") is Dictionary else {}
	var sug: Array = (u.get("data", {}) as Dictionary).get("suggestions", []) if u.get("data") is Dictionary else []
	if u.get("success") == false and str(ue.get("code", "")) == "CLASS_NOT_FOUND" and (sug.has("CharacterBody3D") or sug.has("CharacterBody2D")):
		passed += 1
	else:
		failed += 1
		errors.append("T3 unknown: " + JSON.stringify(u).left(400))

	return {"name": "ApiToolsTests", "passed": passed, "failed": failed, "errors": errors}
