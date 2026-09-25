@tool
extends RefCounted
class_name AISidebarIconHelper

## Modern Lucide SVG Icon Helper (SRP).
## SVG ikonlarını güvenli şekilde yükler; bulunamazsa UI'ı bozmadan null döner.
## İkonlar: assets/icons/ (Lucide, ISC — bkz. assets/icons/LICENSE).

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

const ICON_DIR = "res://addons/godot_sidebar_ai/assets/icons/"
## Satır içi durum ikonlarının varsayılan boyutu (px).
const STATUS_ICON_SIZE: int = 14

static var _icon_cache: Dictionary = {}
static var _tint_cache: Dictionary = {}
static var _color_attr_re: RegEx = null
static var _width_re: RegEx = null

static func get_icon(name: String) -> Texture2D:
	if _icon_cache.has(name):
		return _icon_cache[name]

	var path = ICON_DIR + name + ".svg"

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

## İkonu tek renge boyayıp `size` px genişlikte üretir (SVG'deki stroke/fill renkleri ve
## currentColor değiştirilir; fill="none" korunur). Bulunamazsa null.
static func get_tinted_icon(name: String, color: Color, size: int = 16) -> Texture2D:
	var key = "%s|%s|%d" % [name, color.to_html(false), size]
	if _tint_cache.has(key):
		return _tint_cache[key]
	var path = ICON_DIR + name + ".svg"
	if not FileAccess.file_exists(path):
		return null
	var svg = FileAccess.get_file_as_string(path)
	if svg.is_empty():
		return null
	if _color_attr_re == null:
		_color_attr_re = RegEx.create_from_string("(stroke|fill)=\"(#[0-9a-fA-F]{3,8}|currentColor)\"")
		_width_re = RegEx.create_from_string("<svg[^>]*?\\swidth=\"([0-9.]+)\"")
	svg = _color_attr_re.sub(svg, "$1=\"#" + color.to_html(false) + "\"", true)
	var base_w = 24.0
	var m = _width_re.search(svg)
	if m:
		base_w = maxf(1.0, m.get_string(1).to_float())
	var img = Image.new()
	if img.load_svg_from_string(svg, float(size) / base_w) != OK or img.is_empty():
		return null
	var tex = ImageTexture.create_from_image(img)
	_tint_cache[key] = tex
	return tex

## Durum glifini (activity/checklist/transcript verisi: ✓ ✕ ▶ ! ☐ – •) ikon + renge eşler.
## Tanınmayan glif için {} döner; çağıran metni aynen gösterir.
static func status_icon_spec(glyph: String) -> Dictionary:
	# Emoji takma adları (eski veri) kaçış dizisiyle yazılır: UI kaynağı emoji içermez.
	match glyph:
		"✓", "✔", "\u2705", "check", "success":
			return {"name": "check", "color": AISidebarTheme.COLOR_SUCCESS}
		"✕", "\u274C", "✗", "x", "error", "failed":
			return {"name": "x", "color": AISidebarTheme.COLOR_ERROR}
		"▶", "running", "play":
			return {"name": "loader-circle", "color": AISidebarTheme.COLOR_WARNING}
		"!", "\u26A0", "\u26A0\uFE0F", "warning":
			return {"name": "triangle-alert", "color": AISidebarTheme.COLOR_WARNING}
		"☐", "pending":
			return {"name": "circle", "color": AISidebarTheme.COLOR_TEXT_MUTED}
		"–", "skipped":
			return {"name": "minus", "color": AISidebarTheme.COLOR_TEXT_MUTED}
		"•", "":
			return {"name": "dot", "color": AISidebarTheme.COLOR_TEXT_MUTED}
	return {}

## Durum glifinin boyalı ikonu; tanınmazsa null.
static func get_status_icon(glyph: String, size: int = STATUS_ICON_SIZE) -> Texture2D:
	var spec = status_icon_spec(glyph)
	if spec.is_empty():
		return null
	return get_tinted_icon(spec["name"], spec["color"], size)

## Metnin yanında duran ikon için ortalanmış TextureRect (başta gizli).
static func make_icon_rect(size: int = STATUS_ICON_SIZE) -> TextureRect:
	var rect = TextureRect.new()
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_PASS
	rect.visible = false
	return rect

## TextureRect'e boyalı ikon koyar; name boşsa veya ikon yoksa gizler.
static func set_rect_icon(rect: TextureRect, name: String, color: Color, size: int = STATUS_ICON_SIZE) -> void:
	if not rect:
		return
	var tex = get_tinted_icon(name, color, size) if not name.is_empty() else null
	rect.texture = tex
	rect.visible = tex != null

static func apply_icon(btn: Button, name: String) -> void:
	if not btn: return
	var ico = get_icon(name)
	if ico:
		btn.icon = ico

## Butona boyalı ikon koyar (başlık butonları gibi metinle aynı renkte olması gerekenler).
static func apply_tinted_icon(btn: Button, name: String, color: Color, size: int = STATUS_ICON_SIZE) -> void:
	if not btn:
		return
	btn.icon = get_tinted_icon(name, color, size) if not name.is_empty() else null
