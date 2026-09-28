@tool
extends RefCounted
class_name AISidebarProjectSettingsTools

## `manage_project_settings`: ana sahne, pencere boyu gibi ayarlar, input action'lar ve autoload'lar.
## project.godot dosya olarak yazılamaz (PathPolicy); değişiklik Godot'nun ProjectSettings API'siyle
## yapılır ve kaydetmeden önce project.godot yedeklenir (editörün geri alma geçmişine girmez).
## Eklentinin kendi kaydı (editor_plugins) ve runtime köprüsü autoload'u değiştirilemez.

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

const TOOL_NAME := "manage_project_settings"
const BACKUP_DIR := "user://ai_sidebar_backups"
const PROTECTED_PREFIXES: Array[String] = ["editor_plugins/", "autoload/GodotAIRuntimeBridge"]
const ACTIONS: Array[String] = ["get", "set", "add_input_action", "remove_input_action", "add_autoload", "remove_autoload"]

## Testler kaydetmeyi kapatır (depo project.godot'u değişmesin); üretimde daima kaydedilir.
static var save_enabled: bool = true
## plugin.gd verir. Editördeyken autoload eklentinin add_autoload_singleton'ı ile eklenir: yalnız
## ProjectSettings'e yazılan autoload'u editör yeniden başlayana kadar tanımaz ("Identifier not found").
static var editor_plugin: EditorPlugin = null

static func get_schemas() -> Array:
	return [{
		"type": "function",
		"function": {
			"name": TOOL_NAME,
			"description": "Reads or changes project settings through Godot's ProjectSettings API (project.godot itself cannot be written as a file). Actions: get / set a setting (e.g. application/run/main_scene, display/window/size/viewport_width); add_input_action / remove_input_action (keys like W, Space, Up; mouse buttons 1-3); add_autoload / remove_autoload (a singleton script or scene; order: write the singleton script first, add the autoload, then write scripts that use its name — they do not validate before it exists). project.godot is backed up before every change. Use it for the main scene, input actions and autoloads a game needs.",
			"parameters": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ACTIONS, "description": "What to do."},
					"key": {"type": "string", "description": "get / set: setting path, e.g. application/run/main_scene."},
					"value": {"description": "set: new value (string, number, bool). For main_scene a res:// path to an existing scene."},
					"name": {"type": "string", "description": "Input action name (e.g. move_left) or autoload name (e.g. GameState)."},
					"keys": {"type": "array", "items": {"type": "string"}, "description": "add_input_action: key names, e.g. [\"A\", \"Left\"]."},
					"mouse_buttons": {"type": "array", "items": {"type": "integer"}, "description": "add_input_action: optional mouse buttons (1 left, 2 right, 3 middle)."},
					"path": {"type": "string", "description": "add_autoload: res:// path of the script or scene."},
				},
				"required": ["action"],
			},
		},
	}]

## Salt okuma mı (onay ve plan modu için)?
static func is_read_only(args: Dictionary) -> bool:
	return str(args.get("action", "")) == "get"

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != TOOL_NAME:
		return AISidebarToolResult.err("UNKNOWN_TOOL", "Unknown project settings tool: " + tool_name)
	var action := str(args.get("action", ""))
	match action:
		"get":
			var key := str(args.get("key", "")).strip_edges()
			if key.is_empty():
				return AISidebarToolResult.err("INVALID_ARGUMENT", "get needs key (e.g. application/run/main_scene).")
			return AISidebarToolResult.ok({"key": key, "exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key, null)})
		"set":
			return _set_setting(str(args.get("key", "")).strip_edges(), args.get("value", null))
		"add_input_action":
			return _add_input_action(str(args.get("name", "")).strip_edges(), args.get("keys", []), args.get("mouse_buttons", []))
		"remove_input_action":
			return _remove("input/" + str(args.get("name", "")).strip_edges())
		"add_autoload":
			return _add_autoload(str(args.get("name", "")).strip_edges(), str(args.get("path", "")).strip_edges())
		"remove_autoload":
			return _remove("autoload/" + str(args.get("name", "")).strip_edges())
	return AISidebarToolResult.err("INVALID_ARGUMENT", "action must be one of: " + ", ".join(ACTIONS))

static func _protected(key: String) -> bool:
	for prefix: String in PROTECTED_PREFIXES:
		if key.begins_with(prefix):
			return true
	return false

static func _set_setting(key: String, value: Variant) -> Dictionary:
	if key.is_empty() or value == null:
		return AISidebarToolResult.err("INVALID_ARGUMENT", "set needs key and value.")
	if _protected(key) or key.begins_with("input/") or key.begins_with("autoload/"):
		return AISidebarToolResult.err("INVALID_ARGUMENT", "Use add_input_action / add_autoload for input and autoload; editor_plugins and the runtime bridge are protected.")
	if key == "application/run/main_scene":
		var scene := str(value)
		if not scene.begins_with("res://") or not FileAccess.file_exists(scene):
			return AISidebarToolResult.err("FILE_NOT_FOUND", "Main scene must be an existing res:// scene: " + scene)
	var old: Variant = ProjectSettings.get_setting(key, null)
	# Değer mevcut ayarın türüne çevrilir: model "1600" gönderince viewport_width metin olarak kalıyordu.
	if old != null and typeof(value) != typeof(old):
		var text := str(value)
		var ok := true
		match typeof(old):
			TYPE_INT:
				ok = text.is_valid_int()
			TYPE_FLOAT:
				ok = text.is_valid_float()
			TYPE_BOOL:
				ok = text.to_lower() in ["true", "false"]
				value = text.to_lower() == "true"
		if not ok:
			return AISidebarToolResult.err("INVALID_ARGUMENT", "%s expects a %s value, got: %s" % [key, type_string(typeof(old)), text])
		if typeof(old) != TYPE_BOOL:
			value = type_convert(value, typeof(old))
	ProjectSettings.set_setting(key, value)
	return _save({"key": key, "old_value": old, "value": value})

static func _add_input_action(action_name: String, keys: Variant, mouse_buttons: Variant) -> Dictionary:
	if action_name.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "add_input_action needs name.")
	var events: Array = []
	var unknown: Array = []
	if keys is Array:
		for k: Variant in keys:
			var code := OS.find_keycode_from_string(str(k))
			if code == KEY_NONE:
				unknown.append(str(k))
				continue
			var ev := InputEventKey.new()
			ev.device = -1  # editörün eklediği gibi: tüm cihazlar
			ev.physical_keycode = code
			events.append(ev)
	if mouse_buttons is Array:
		for b: Variant in mouse_buttons:
			var button: int = b if b is int else roundi(float(str(b)))
			var mb := InputEventMouseButton.new()
			mb.device = -1
			mb.button_index = button as MouseButton
			events.append(mb)
	if not unknown.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "Unknown key names: %s (use names like W, Space, Up, Escape)." % ", ".join(unknown))
	if events.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "add_input_action needs at least one key or mouse button.")
	var key := "input/" + action_name
	var existed := ProjectSettings.has_setting(key)
	ProjectSettings.set_setting(key, {"deadzone": 0.2, "events": events})
	return _save({"action": action_name, "events": events.size(), "replaced": existed})

static func _add_autoload(autoload_name: String, path: String) -> Dictionary:
	if autoload_name.is_empty() or path.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "add_autoload needs name and path.")
	var key := "autoload/" + autoload_name
	if _protected(key):
		return AISidebarToolResult.err("PERMISSION_DENIED", "This autoload belongs to the plugin and is protected.")
	if not path.begins_with("res://") or not FileAccess.file_exists(path):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Autoload must point to an existing res:// script or scene: " + path)
	if save_enabled and is_instance_valid(editor_plugin):
		var backup := _backup()
		editor_plugin.add_autoload_singleton(autoload_name, path)
		return AISidebarToolResult.ok({"autoload": autoload_name, "path": path, "saved": true, "backup": backup})
	ProjectSettings.set_setting(key, "*" + path)
	return _save({"autoload": autoload_name, "path": path})

static func _remove(key: String) -> Dictionary:
	if key.ends_with("/"):
		return AISidebarToolResult.err("INVALID_ARGUMENT", "remove needs name.")
	if _protected(key):
		return AISidebarToolResult.err("PERMISSION_DENIED", "This setting belongs to the plugin and is protected.")
	if not ProjectSettings.has_setting(key):
		return AISidebarToolResult.err("NOT_FOUND", "No such setting: " + key)
	if key.begins_with("autoload/") and save_enabled and is_instance_valid(editor_plugin):
		var backup := _backup()
		editor_plugin.remove_autoload_singleton(key.trim_prefix("autoload/"))
		return AISidebarToolResult.ok({"removed": key, "saved": true, "backup": backup})
	ProjectSettings.set_setting(key, null)
	return _save({"removed": key})

## project.godot'u yedekleyip ayarları kaydeder.
static func _save(data: Dictionary) -> Dictionary:
	if not save_enabled:
		data["saved"] = false
		return AISidebarToolResult.ok(data)
	var backup := _backup()
	var err := ProjectSettings.save()
	if err != OK:
		return AISidebarToolResult.err("SAVE_FAILED", "ProjectSettings.save() failed (error %d); backup: %s" % [err, backup])
	data["saved"] = true
	data["backup"] = backup
	return AISidebarToolResult.ok(data)

static func _backup() -> String:
	DirAccess.make_dir_recursive_absolute(BACKUP_DIR)
	# Aynı saniyedeki ikinci değişiklik ilk yedeği ezmesin (özgün dosya kaybolurdu).
	var stamp := "%s_%d" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()]
	var target := BACKUP_DIR.path_join("project.godot.%s.bak" % stamp)
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://project.godot"), ProjectSettings.globalize_path(target))
	return target
