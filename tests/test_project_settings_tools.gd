@tool
extends RefCounted

## manage_project_settings: ana sahne doğrulaması, input action, autoload, korumalı anahtarlar, izin.
## Kaydetme kapalıdır (depo project.godot'u değişmez); değiştirilen her ayar sonda geri alınır.

const T = preload("res://addons/godot_sidebar_ai/core/tools/primitive/project_settings_tools.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")

static func _run(args: Dictionary) -> Dictionary:
	return T.execute(T.TOOL_NAME, args)

static func run() -> Dictionary:
	var checks: Array = []
	var touched := ["application/run/main_scene", "input/tmp_move_left", "autoload/TmpState", "display/window/size/viewport_width"]
	var saved: Dictionary = {}
	for k: String in touched:
		saved[k] = ProjectSettings.get_setting(k, null)
	T.save_enabled = false

	# T1 ana sahne: olmayan sahne reddedilir, var olan kabul edilir.
	var bad := _run({"action": "set", "key": "application/run/main_scene", "value": "res://nope/Main.tscn"})
	var ok := _run({"action": "set", "key": "application/run/main_scene", "value": "res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn"})
	checks.append(["T1 main scene", not bad["success"] and ok["success"] and ProjectSettings.get_setting("application/run/main_scene") == "res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn"])

	# T2 input action: tuş adları olaya dönüşür; bilinmeyen tuş reddedilir.
	var ia := _run({"action": "add_input_action", "name": "tmp_move_left", "keys": ["A", "Left"], "mouse_buttons": [1]})
	var ev: Dictionary = ProjectSettings.get_setting("input/tmp_move_left", {})
	var bad_key := _run({"action": "add_input_action", "name": "tmp_x", "keys": ["NotAKey"]})
	checks.append(["T2 input action", ia["success"] and (ev.get("events", []) as Array).size() == 3 and not bad_key["success"]])

	# T3 autoload: var olan dosya "*yol" olur; olmayan reddedilir; kaldırma çalışır.
	var al := _run({"action": "add_autoload", "name": "TmpState", "path": "res://addons/godot_sidebar_ai/core/types/tool_result.gd"})
	var al_value := str(ProjectSettings.get_setting("autoload/TmpState", ""))
	var al_bad := _run({"action": "add_autoload", "name": "TmpState2", "path": "res://nope.gd"})
	var rm := _run({"action": "remove_autoload", "name": "TmpState"})
	checks.append(["T3 autoload", al["success"] and al_value.begins_with("*res://") and not al_bad["success"] and rm["success"] and not ProjectSettings.has_setting("autoload/TmpState")])

	# T4 korumalı: eklenti kaydı ve runtime köprüsü değiştirilemez; input/autoload set ile yazılmaz.
	var p1 := _run({"action": "set", "key": "editor_plugins/enabled", "value": "x"})
	var p2 := _run({"action": "remove_autoload", "name": "GodotAIRuntimeBridge"})
	var p3 := _run({"action": "set", "key": "input/jump", "value": "x"})
	checks.append(["T4 protected", not p1["success"] and not p2["success"] and not p3["success"]])

	# T5 izin: Manuel modda değişiklik onay ister, get istemez; ret mesajı aracı gösterir.
	var needs_set := AISidebarPermissionPolicy.requires_user_approval(T.TOOL_NAME, {"action": "set"}, AISidebarPermissionPolicy.AutoApproveMode.MANUAL)
	var needs_get := AISidebarPermissionPolicy.requires_user_approval(T.TOOL_NAME, {"action": "get"}, AISidebarPermissionPolicy.AutoApproveMode.MANUAL)
	var reason := str(AISidebarPathPolicy.is_safe_to_write("res://project.godot").get("reason", ""))
	checks.append(["T5 permission", needs_set and not needs_get and reason.contains(T.TOOL_NAME)])

	# T6 tür: "1600" metni mevcut int ayara int olarak yazılır; sayı olmayan metin reddedilir.
	var w_ok := _run({"action": "set", "key": "display/window/size/viewport_width", "value": "1600"})
	var w_val: Variant = ProjectSettings.get_setting("display/window/size/viewport_width")
	var w_bad := _run({"action": "set", "key": "display/window/size/viewport_width", "value": "wide"})
	checks.append(["T6 type coercion", w_ok["success"] and typeof(w_val) == TYPE_INT and int(w_val) == 1600 and not w_bad["success"]])

	for k: String in touched:
		ProjectSettings.set_setting(k, saved[k])
	ProjectSettings.set_setting("input/tmp_move_left", null)
	T.save_enabled = true

	var passed := 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "ProjectSettingsToolTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
