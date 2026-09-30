@tool
extends RefCounted

## audit_runtime_ui: WCAG kontrast hesabı, araç şeması ve yönlendirme (oyun tarafı düğüm taraması editör smoke I11'de).

const AISidebarRuntimeUiAudit = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_ui_audit.gd")
const AISidebarRuntimePhysicsDoctor = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_physics_doctor.gd")
const AISidebarRuntimeState = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_state.gd")
const AISidebarRuntimeBridge = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_bridge.gd")
const AISidebarEditorTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/editor_tools.gd")
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
	# S1b vektör metin olarak (benchmark: model "(776, 176)" ve "776" gönderip yedi deneme harcadı)
	var t1 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "position", "value": "(776, 176)"})
	var t1ok: bool = t1.get("success") == true and host.position.is_equal_approx(Vector2(776, 176))
	var t2 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "position", "value": "Vector2(1, 2)"})
	var t2ok: bool = t2.get("success") == true and host.position.is_equal_approx(Vector2(1, 2))
	var t3 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "position", "value": [5, 6]})
	var t3ok: bool = t3.get("success") == true and host.position.is_equal_approx(Vector2(5, 6))
	var t4 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "position", "value": {"x": 7, "y": 8}})
	var t4ok: bool = t4.get("success") == true and host.position.is_equal_approx(Vector2(7, 8))
	var t5 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "position.x", "value": "776"})
	var t5ok: bool = t5.get("success") == true and is_equal_approx(host.position.x, 776.0) and is_equal_approx(host.position.y, 8.0)
	var t6 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "position", "value": "abc"})
	var t7 := AISidebarRuntimeState.set_value(holder, {"node_path": "Host", "property": "modulate", "value": "1, 0.5, 0.25"})
	var t7ok: bool = t7.get("success") == true and host.modulate.is_equal_approx(Color(1, 0.5, 0.25, 1))
	checks.append(["S1b set_runtime_property: vector from text, array, object; component from text; color from text; nonsense still refused", t1ok and t2ok and t3ok and t4ok and t5ok and t7ok and t6.get("error") == "TYPE_MISMATCH"])
	holder.free()
	# G1 çalışma ağacı çok kardeşte kırpılır ve özetlenir; G2 mutlak yol proje dışında açık hata verir
	var wide := Node.new()
	for i in 90:
		var kid := Node3D.new()
		kid.name = "K%d" % i
		wide.add_child(kid)
	var wtree := AISidebarRuntimeBridge.serialize_tree(wide, 2)
	var kept: Array = wtree["children"]
	checks.append(["G1 wide runtime tree is capped and summarized", kept.size() == AISidebarRuntimeBridge.MAX_TREE_CHILDREN and int(wtree["omitted_children"]) == 90 - AISidebarRuntimeBridge.MAX_TREE_CHILDREN and int(wtree["omitted_by_type"]["Node3D"]) == 50])
	wide.free()
	var outside := AISidebarEditorTools.resolve_screenshot_path("Z:/definitely/outside/shot.png", "user://x.png")
	var inside := AISidebarEditorTools.resolve_screenshot_path(ProjectSettings.globalize_path("res://").path_join("shot_test.png"), "user://x.png")
	checks.append(["G2 absolute screenshot path: outside the project is refused clearly, inside maps to res://", outside["safe"] == false and str(outside["reason"]).contains("absolute path inside the project") and str(inside.get("path", "")).begins_with("res://")])
	var passed := 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "UiAuditTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
