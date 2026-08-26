@tool
extends RefCounted
class_name AISidebarToolBase

## Tüm Araç Modüllerinin soyut temel sınıfı (SRP).

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

static func get_schemas() -> Array:
	return []

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	return AISidebarToolResult.err("NOT_IMPLEMENTED", "Metot tanımlanmamış.")
