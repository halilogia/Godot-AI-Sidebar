@tool
extends RefCounted
class_name AISidebarApiTools

## `get_godot_class_info`: çalışan Godot sürümünün gerçek API'si (ClassDB). Model bir sınıfın yöntem,
## özellik, sinyal ya da sabitinden emin değilse uydurmak yerine buna bakar; cevap kurulu motorun
## (ör. 4.7.2) kendisinden gelir, internetteki eski sürüm dokümanından değil. Salt okuma, çevrimdışı.
## Açıklayıcı doküman (ne zaman kullanılır, örnek kod) ClassDB'de yoktur; yalnız API yüzeyi döner.

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

const TOOL_NAME := "get_godot_class_info"
## Liste başına en çok üye (büyük sınıflarda bağlam şişmesin; filter ile daraltılır).
const MAX_PER_LIST := 150

static func get_schemas() -> Array:
	return [{
		"type": "function",
		"function": {
			"name": TOOL_NAME,
			"description": "Returns the real API of a built-in Godot class from the running engine (ClassDB): inheritance chain, methods with argument and return types, properties, signals and constants. Use it before relying on any Godot class, method, property, signal or constant you are not sure about, instead of guessing. By default only the class's own members are listed; set include_inherited to add inherited ones, and filter to narrow by name. An unknown name returns similar class names.",
			"parameters": {
				"type": "object",
				"properties": {
					"class_name": {"type": "string", "description": "Built-in class name, e.g. CharacterBody3D, TileMapLayer, Tween."},
					"filter": {"type": "string", "description": "Optional: only members whose name contains this text (case-insensitive), e.g. velocity."},
					"include_inherited": {"type": "boolean", "description": "Optional: also list members inherited from parent classes. Default false."},
				},
				"required": ["class_name"],
			},
		},
	}]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != TOOL_NAME:
		return AISidebarToolResult.err("UNKNOWN_TOOL", "Unknown API tool: " + tool_name)
	var cls := str(args.get("class_name", "")).strip_edges()
	if cls.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "Required argument: class_name (e.g. CharacterBody3D).")
	var filter := str(args.get("filter", "")).strip_edges().to_lower()
	var inherited: bool = args.get("include_inherited", false) == true
	if not ClassDB.class_exists(cls):
		return _unknown_class(cls)
	var no_inheritance: bool = not inherited
	var chain: Array[String] = []
	var parent := ClassDB.get_parent_class(cls)
	while not parent.is_empty():
		chain.append(parent)
		parent = ClassDB.get_parent_class(parent)
	var info := {
		"class_name": cls,
		"engine": str(Engine.get_version_info().get("string", "")),
		"inherits": chain,
		"members_scope": "own and inherited" if inherited else "own (set include_inherited for parent members)",
		"methods": _methods(cls, no_inheritance, filter),
		"properties": _properties(cls, no_inheritance, filter),
		"signals": _signals(cls, no_inheritance, filter),
		"constants": _constants(cls, no_inheritance, filter),
	}
	if not ClassDB.can_instantiate(cls):
		info["note"] = "Abstract or singleton: cannot be created with new()."
	return AISidebarToolResult.ok(info)

## Bilinmeyen ad: yerleşik sınıflardan en benzer beşi; projedeki class_name ise read_script'e yönlendirir.
static func _unknown_class(cls: String) -> Dictionary:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == cls:
			return AISidebarToolResult.ok({"class_name": cls, "script_class": true, "path": str(entry.get("path", "")), "base": str(entry.get("base", "")), "note": "This is a project script class, not a built-in class: read it with read_script; its base is listed in base."})
	var scored: Array = []
	var low := cls.to_lower()
	for c: String in ClassDB.get_class_list():
		var s := c.to_lower().similarity(low)
		if c.to_lower().contains(low):
			s += 1.0
		scored.append([s, c])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		var sa: float = a[0]
		var sb: float = b[0]
		return sa > sb)
	var suggestions: Array[String] = []
	for i in mini(5, scored.size()):
		suggestions.append(str(scored[i][1]))
	return AISidebarToolResult.err("CLASS_NOT_FOUND", "No built-in class named %s. Similar: %s" % [cls, ", ".join(suggestions)], true, {"suggestions": suggestions})

static func _type_name(d: Dictionary) -> String:
	var t: int = d.get("type", TYPE_NIL)
	var cn := str(d.get("class_name", ""))
	if t == TYPE_OBJECT and not cn.is_empty():
		return cn
	if t == TYPE_NIL:
		var usage: int = d.get("usage", 0)
		return "Variant" if usage & PROPERTY_USAGE_NIL_IS_VARIANT else "void"
	return type_string(t)

static func _matches(name: String, filter: String) -> bool:
	return filter.is_empty() or name.to_lower().contains(filter)

static func _methods(cls: String, no_inheritance: bool, filter: String) -> Array[String]:
	var out: Array[String] = []
	for m: Dictionary in ClassDB.class_get_method_list(cls, no_inheritance):
		var name := str(m.get("name", ""))
		var flags: int = m.get("flags", 0)
		var is_virtual := (flags & METHOD_FLAG_VIRTUAL) != 0
		if (name.begins_with("_") and not is_virtual) or not _matches(name, filter):
			continue
		var params := PackedStringArray()
		var arg_list: Array = m.get("args", [])
		for a: Dictionary in arg_list:
			params.append("%s: %s" % [str(a.get("name", "")), _type_name(a)])
		var ret: Dictionary = m.get("return", {})
		var sig := "%s(%s) -> %s" % [name, ", ".join(params), _type_name(ret)]
		if is_virtual:
			sig += "  [virtual]"
		if (flags & METHOD_FLAG_STATIC) != 0:
			sig = "static " + sig
		out.append(sig)
		if out.size() >= MAX_PER_LIST:
			break
	out.sort()
	return out

static func _properties(cls: String, no_inheritance: bool, filter: String) -> Array[String]:
	var out: Array[String] = []
	var skip := PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP
	for p: Dictionary in ClassDB.class_get_property_list(cls, no_inheritance):
		var usage: int = p.get("usage", 0)
		var name := str(p.get("name", ""))
		if (usage & skip) != 0 or name.begins_with("_") or not _matches(name, filter):
			continue
		out.append("%s: %s" % [name, _type_name(p)])
		if out.size() >= MAX_PER_LIST:
			break
	return out

static func _signals(cls: String, no_inheritance: bool, filter: String) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in ClassDB.class_get_signal_list(cls, no_inheritance):
		var name := str(s.get("name", ""))
		if not _matches(name, filter):
			continue
		var params := PackedStringArray()
		var arg_list: Array = s.get("args", [])
		for a: Dictionary in arg_list:
			params.append("%s: %s" % [str(a.get("name", "")), _type_name(a)])
		out.append("%s(%s)" % [name, ", ".join(params)])
	return out

static func _constants(cls: String, no_inheritance: bool, filter: String) -> Array[String]:
	var out: Array[String] = []
	for c: String in ClassDB.class_get_integer_constant_list(cls, no_inheritance):
		if not _matches(c, filter):
			continue
		var enum_name := ClassDB.class_get_integer_constant_enum(cls, c, no_inheritance)
		var label := ("%s.%s" % [enum_name, c]) if not enum_name.is_empty() else c
		out.append("%s = %d" % [label, ClassDB.class_get_integer_constant(cls, c)])
		if out.size() >= MAX_PER_LIST:
			break
	return out
