@tool
extends HBoxContainer

## Satır başı durum göstergesi (SRP): durum glifini (✓ ✕ ▶ ! ☐ – •) boyalı Lucide ikonu
## olarak çizer. Glif veri modelinde (activity/checklist/transcript) aynen kalır; burada
## yalnızca görünüm eşlenir. Tanınmayan glif metin olarak görünür (sessiz kayıp yok).

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

## Gösterilen glif (veri).
var glyph: String = ""

var _rect: TextureRect
var _fallback: Label
var _size: int

func _init(p_size: int = AISidebarIconHelper.STATUS_ICON_SIZE) -> void:
	_size = p_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Çok satırlı başlıklarda ikon ilk satırla hizalı kalır.
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_rect = AISidebarIconHelper.make_icon_rect(_size)
	_rect.custom_minimum_size = Vector2(_size, _size + 4)
	add_child(_rect)
	_fallback = Label.new()
	_fallback.mouse_filter = Control.MOUSE_FILTER_PASS
	_fallback.visible = false
	_fallback.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
	add_child(_fallback)

## Tanınmayan glifte metin rengi fallback_color olur.
func set_status(p_glyph: String, fallback_color: Color = AISidebarTheme.COLOR_WARNING) -> void:
	glyph = p_glyph
	var tex = AISidebarIconHelper.get_status_icon(p_glyph, _size)
	_rect.texture = tex
	_rect.visible = tex != null
	_fallback.visible = tex == null
	if tex == null:
		_fallback.text = p_glyph
		_fallback.add_theme_color_override("font_color", fallback_color)

## Glif yerine doğrudan ikon adı ve renk.
func set_icon(icon_name: String, color: Color) -> void:
	glyph = ""
	AISidebarIconHelper.set_rect_icon(_rect, icon_name, color, _size)
	_fallback.visible = false

func has_icon() -> bool:
	return _rect.visible and _rect.texture != null
