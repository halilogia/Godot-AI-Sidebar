@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarUIComponentTools

## scaffold_ui_component: doğrulanmış, parametrik UI bileşenini PackedScene (+ betik) olarak üretir.
## Ajan karmaşık arayüzü sıfırdan hayal etmez; şablon kaydedilmeden önce audit_ui_layout /
## audit_ui_touch kurallarından geçer, P0/P1 bulgu varsa hiçbir şey yazılmaz.

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarUITelemetryTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd")
const AISidebarUIComponentBuilder = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_component_builder.gd")

const TOOL_NAME: String = "scaffold_ui_component"
const DEFAULT_THEME: String = "res://ui/theme.tres"

static func get_schemas() -> Array:
	return [{
		"type": "function",
		"function": {
			"name": TOOL_NAME,
			"description": "Generates a verified, parametric UI component as a PackedScene (+ small GDScript API): healthbar, dialogue_box, inventory_grid, pause_menu, framed_panel, resource_strip, list_row or event_popup. Container-only layout (no manual positions), 44px touch targets, theme variations (run scaffold_ui_theme first for a themed result). The scene is audited (audit_ui_layout + audit_ui_touch) before saving; nothing is written if a P0/P1 issue is found. Prefer this over hand-building these widgets.",
			"parameters": {
				"type": "object",
				"properties": {
					"component": {"type": "string", "enum": AISidebarUIComponentBuilder.COMPONENTS, "description": "Which component to scaffold."},
					"scene_path": {"type": "string", "description": "Target .tscn (default: 'res://ui/components/<component>.tscn'). Script is written next to it as .gd."},
					"name": {"type": "string", "description": "Root node name (default: component's PascalCase name)."},
					"theme_path": {"type": "string", "description": "Theme to assign to the root (default: 'res://ui/theme.tres' if it exists; otherwise built-in fallback spacing)."},
					"max_value": {"type": "number", "description": "healthbar: maximum health (default: 100)."},
					"caption": {"type": "string", "description": "healthbar: caption text (default: 'HP'; empty hides)."},
					"show_value_text": {"type": "boolean", "description": "healthbar: show 'x / y' label (default: true)."},
					"speaker": {"type": "string", "description": "dialogue_box: placeholder speaker name."},
					"sample_text": {"type": "string", "description": "dialogue_box / list_row / event_popup: placeholder body or subtitle text."},
					"next_text": {"type": "string", "description": "dialogue_box / list_row: advance or action button text."},
					"title": {"type": "string", "description": "inventory_grid / pause_menu / framed_panel / list_row / event_popup: title text."},
					"columns": {"type": "integer", "description": "inventory_grid: columns (default: 5, max 12)."},
					"slot_count": {"type": "integer", "description": "inventory_grid: number of slots (default: 20, max 200)."},
					"slot_size": {"type": "number", "description": "inventory_grid: slot edge in px (default: 72, min 44)."},
					"resources": {"type": "array", "items": {"type": "string"}, "description": "resource_strip: resource keys (default: ['gold', 'manpower', 'stability']; max 8)."},
					"buttons": {"type": "array", "items": {"type": "string"}, "description": "pause_menu / event_popup: button labels (default: Resume, Settings, Quit or Accept, Decline; max 8)."}
				},
				"required": ["component"]
			}
		}
	}]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != TOOL_NAME:
		return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen UI bileşen aracı: " + tool_name)
	return _scaffold(args)

static func _scaffold(args: Dictionary) -> Dictionary:
	var component: String = str(args.get("component", "")).strip_edges().to_lower()
	if not component in AISidebarUIComponentBuilder.COMPONENTS:
		return AISidebarToolResult.err("INVALID_COMPONENT", "Geçersiz bileşen '%s'. Seçenekler: %s" % [component, ", ".join(AISidebarUIComponentBuilder.COMPONENTS)])
	var scene_path: String = str(args.get("scene_path", "")).strip_edges()
	if scene_path.is_empty():
		scene_path = "res://ui/components/%s.tscn" % component
	if not scene_path.ends_with(".tscn"):
		return AISidebarToolResult.err("INVALID_PATH", "scene_path .tscn ile bitmelidir: " + scene_path)
	var scene_check: Dictionary = AISidebarPathPolicy.is_safe_to_write(scene_path)
	if not scene_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", str(scene_check["reason"]))
	scene_path = str(scene_check["path"])
	var script_path: String = scene_path.get_basename() + ".gd"
	var script_check: Dictionary = AISidebarPathPolicy.is_safe_to_write(script_path)
	if not script_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", str(script_check["reason"]))
	var built: Dictionary = AISidebarUIComponentBuilder.build(component, args)
	var root: Node = built["root"]
	if root == null:
		return AISidebarToolResult.err("BUILD_FAILED", "Bileşen kurulamadı: " + component)
	var theme_applied: String = _apply_theme(root, str(args.get("theme_path", "")).strip_edges(), built["parts"])
	var verification: Dictionary = verify_component(root)
	if not bool(verification["passed"]):
		root.free()
		return AISidebarToolResult.err("COMPONENT_VERIFICATION_FAILED", "Şablon kendi denetiminden geçmedi (P0/P1 bulgu), hiçbir dosya yazılmadı: " + JSON.stringify(verification["blocking"]))
	var dir_path: String = scene_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var script_file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	if script_file == null:
		root.free()
		return AISidebarToolResult.err("SAVE_FAILED", "Betik yazılamadı: " + script_path)
	script_file.store_string(str(built["script_source"]))
	script_file.close()
	var script: GDScript = ResourceLoader.load(script_path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	if script == null or not script.can_instantiate():
		root.free()
		DirAccess.remove_absolute(script_path)
		return AISidebarToolResult.err("SCRIPT_INVALID", "Üretilen betik derlenmedi: " + script_path)
	root.set_script(script)
	AISidebarUIComponentBuilder.own_all(root, root)
	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(root)
	var node_count: int = _count_nodes(root)
	root.free()
	if pack_err != OK:
		return AISidebarToolResult.err("PACK_FAILED", "Sahne paketlenemedi (hata: %d)." % pack_err)
	var save_err: Error = ResourceSaver.save(packed, scene_path)
	if save_err != OK:
		return AISidebarToolResult.err("SAVE_FAILED", "Sahne kaydedilemedi (hata: %d): %s" % [save_err, scene_path])
	_refresh_editor_files([script_path, scene_path])
	return AISidebarToolResult.ok({
		"component": component, "scene_path": scene_path, "script_path": script_path,
		"node_count": node_count, "api": built["api"], "theme_applied": theme_applied,
		"verification": verification,
		"usage": "instantiate_scene ile ekle (Container içine koy: konumu Container belirler); API: " + ", ".join(PackedStringArray(built["api"]))
	}, "UI bileşeni üretildi ve doğrulandı (%s): %s" % [component, scene_path])

## Kaydetmeden önce: yerleşim + dokunma denetimi. P0/P1 bulgu engeller.
static func verify_component(root: Node) -> Dictionary:
	var layout: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_layout", {"target_node": root, "max_depth": 16, "include_invisible": true})
	var touch: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_touch", {"target_node": root, "include_invisible": true})
	var blocking: Array = []
	var by_priority: Dictionary = {"P0": 0, "P1": 0, "P2": 0}
	for res: Dictionary in [layout, touch]:
		var data: Dictionary = res.get("data", {}) as Dictionary
		for iss: Dictionary in data.get("issues", []):
			var p: String = str(iss.get("priority", "P2"))
			by_priority[p] = int(by_priority.get(p, 0)) + 1
			if p == "P0" or p == "P1":
				blocking.append({"rule_id": iss.get("rule_id", ""), "node_path": iss.get("node_path", ""), "message": iss.get("message", "")})
	var ran: bool = bool(layout.get("success", false)) and bool(touch.get("success", false))
	return {"passed": ran and blocking.is_empty(), "by_priority": by_priority, "blocking": blocking}

static func _apply_theme(root: Node, theme_path: String, parts: Dictionary) -> String:
	var chosen: String = theme_path if not theme_path.is_empty() else DEFAULT_THEME
	if root is Control and ResourceLoader.exists(chosen):
		var th: Theme = ResourceLoader.load(chosen) as Theme
		if th != null:
			(root as Control).theme = th
			return chosen
	AISidebarUIComponentBuilder.apply_fallback_spacing(parts)
	return ""

static func _count_nodes(node: Node) -> int:
	var n: int = 1
	for ch: Node in node.get_children():
		n += _count_nodes(ch)
	return n

static func _refresh_editor_files(paths: Array) -> void:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if fs == null:
		return
	for p: String in paths:
		fs.update_file(p)
