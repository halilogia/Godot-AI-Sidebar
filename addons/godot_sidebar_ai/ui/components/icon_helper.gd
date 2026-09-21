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
	
	# 1. Doğrudan SVG dosyasından ImageTexture üret (Import cache ve headless bağımlılığı olmadan temiz yükleme)
	if FileAccess.file_exists(path):
		var abs_path = ProjectSettings.globalize_path(path)
		var img = Image.load_from_file(abs_path)
		if img and not img.is_empty():
			var tex = ImageTexture.create_from_image(img)
			_icon_cache[name] = tex
			return tex

	# 2. Alternatif: ResourceLoader üzerinden yükleme
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path)
		if res is Texture2D:
			_icon_cache[name] = res
			return res
			
	return null

static func apply_icon(btn: Button, name: String) -> void:
	if not btn: return
	var ico = get_icon(name)
	if ico:
		btn.icon = ico
