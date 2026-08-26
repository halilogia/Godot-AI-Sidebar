@tool
extends RefCounted
class_name AISidebarIconHelper

## Modern Lucide SVG Icon Helper (SRP).
## SVG ikonlarını güvenli şekilde yükler; bulunamazsa UI'ı bozmadan null döner.

static var _icon_cache: Dictionary = {}

static func get_icon(name: String) -> Texture2D:
	if _icon_cache.has(name):
		return _icon_cache[name]
		
	var path = "res://addons/godot_sidebar_ai/assets/icons/" + name + ".svg"
	if ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		if tex:
			_icon_cache[name] = tex
			return tex
			
	return null

static func apply_icon(btn: Button, name: String) -> void:
	if not btn: return
	var ico = get_icon(name)
	if ico:
		btn.icon = ico
