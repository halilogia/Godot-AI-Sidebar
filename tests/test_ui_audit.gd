@tool
extends RefCounted

## audit_runtime_ui: WCAG kontrast hesabı, araç şeması ve yönlendirme (oyun tarafı düğüm taraması editör smoke I11'de).

const AISidebarRuntimeUiAudit = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_ui_audit.gd")
const AISidebarRuntimePhysicsDoctor = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_physics_doctor.gd")
const AISidebarRuntimeState = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_state.gd")
const AISidebarRuntimeInputTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/runtime_input_tools.gd")

static func run() -> Dictionary:
	var checks: Array = []
	var white_on_black := AISidebarRuntimeUiAudit.contrast(Color.WHITE, 0.0)
	var same := AISidebarRuntimeUiAudit.contrast(Color(0.5, 0.5, 0.5), AISidebarRuntimeUiAudit._luminance(Color(0.5, 0.5, 0.5)))
	var gray_on_tan := AISidebarRuntimeUiAudit.contrast(Color(0.6, 0.6, 0.6), AISidebarRuntimeUiAudit._luminance(Color(0.45, 0.38, 0.3)))
	checks.append(["U1 contrast: white on black 21:1, identical 1:1, gray on tan is below 3:1", absf(white_on_black - 21.0) < 0.01 and absf(same - 1.0) < 0.01 and gray_on_tan < AISidebarRuntimeUiAudit.MIN_CONTRAST])
	checks.append(["U2 unknown background is not judged", AISidebarRuntimeUiAudit.contrast(Color.WHITE, -1.0) < 0.0])
	var found := false
	for s: Dictionary in AISidebarRuntimeInputTools.get_schemas():
		if str((s.get("function", {}) as Dictionary).get("name", "")) == AISidebarRuntimeInputTools.UI_AUDIT_TOOL:
			found = true
	checks.append(["U3 audit_runtime_ui schema is registered", found])
	var wrapped := AISidebarRuntimeInputTools.name_list({"item": ["move_right", "jump"]})
	var listed := AISidebarRuntimeInputTools.name_list("move_right, jump")
	checks.append(["U4 send_input actions accepts {item:[..]} and comma text", wrapped == ["move_right", "jump"] and listed == ["move_right", "jump"] and AISidebarRuntimeInputTools.name_list(5).is_empty()])
	# P1 fizik doktoru: Area layer 1'i dinliyor, oyuncu layer 2'de -> NO_MATCHING_LAYER; şekilsiz gövde -> NO_SHAPE
	var root := Node2D.new()
	var goal := Area2D.new()
	goal.name = "Goal"
	goal.collision_mask = 1
	goal.collision_layer = 4
	var goal_shape := CollisionShape2D.new()
	goal_shape.shape = RectangleShape2D.new()
	goal.add_child(goal_shape)
	goal.body_entered.connect(func(_b: Node2D) -> void: pass)
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = 2
	root.add_child(goal)
	root.add_child(player)
	var rep := AISidebarRuntimePhysicsDoctor.diagnose(root, root)
	var codes: Array[String] = []
	for i: Dictionary in rep["issues"]:
		codes.append(str(i["code"]))
	checks.append(["P1 physics doctor finds layer mismatch and missing shape", "NO_MATCHING_LAYER" in codes and "NO_SHAPE" in codes and AISidebarRuntimePhysicsDoctor.layers_of(5) == [1, 3]])
	player.collision_layer = 1
	var rep2 := AISidebarRuntimePhysicsDoctor.diagnose(root, goal)
	var codes2: Array[String] = []
	for i: Dictionary in rep2["issues"]:
		codes2.append(str(i["code"]))
	checks.append(["P2 matching layers are not accused", not ("NO_MATCHING_LAYER" in codes2)])
	root.free()
	# S1 durum enjeksiyonu: sayı (metinden), vektör bileşeni, tür uyuşmazlığı, engelli özellik
	var host := Node2D.new()
	host.name = "Host"
	var holder := Node.new()
	holder.add_child(host)
	host.position = Vector2(10, 20)
	var r1 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "rotation", "value": "1.5"})
	var r2 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "position.x", "value": 99})
	var r3 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "visible", "value": "abc"})
	var r4 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "script", "value": 1})
	var r5 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "nope", "value": 1})
	checks.append(["S1 set_runtime_property: number from text, vector component, type mismatch, blocked and unknown property", r1.get("success") == true and is_equal_approx(host.rotation, 1.5) and r2.get("success") == true and is_equal_approx(host.position.x, 99.0) and is_equal_approx(host.position.y, 20.0) and r3.get("error") == "TYPE_MISMATCH" and r4.get("error") == "PROPERTY_BLOCKED" and r5.get("error") == "PROPERTY_NOT_FOUND"])
	holder.free()
	var passed := 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "UiAuditTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
