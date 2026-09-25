@tool
extends MarginContainer

## Model yanıtı beklenirken akışın sonunda duran canlı gösterge (SRP): dönen ikon,
## bilinen aşama metni ve geçen süre. Uzun bekleyişte iptal ipucu gösterir.
## Yalnızca gerçekten bilinen durumu yazar; ağ aşaması tahmin edilmez.

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

## Bu süreden (sn) sonra iptal ipucu görünür.
const SLOW_HINT_AFTER_SEC: int = 15
const SPINNER_SIZE: int = 14

var _spinner: TextureRect
var _label: Label
var _hint: Label

func _init() -> void:
	name = "PendingIndicator"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("margin_left", AISidebarTheme.SPACE_MD)
	add_theme_constant_override("margin_top", AISidebarTheme.SPACE_XS)
	add_theme_constant_override("margin_bottom", AISidebarTheme.SPACE_XS)

	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", AISidebarTheme.SPACE_SM)
	add_child(row)

	_spinner = TextureRect.new()
	_spinner.texture = AISidebarIconHelper.get_tinted_icon("loader-circle", AISidebarTheme.COLOR_ACCENT, SPINNER_SIZE)
	_spinner.custom_minimum_size = Vector2(SPINNER_SIZE, SPINNER_SIZE)
	_spinner.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_spinner.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_spinner)

	var texts = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", AISidebarTheme.SPACE_XXS)
	row.add_child(texts)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
	texts.add_child(_label)

	_hint = Label.new()
	_hint.visible = false
	_hint.text = AISidebarI18n.get_text("pending_slow_hint")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_MICRO)
	_hint.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
	texts.add_child(_hint)

	set_phase(AISidebarI18n.get_text("pending_waiting"), 0)

func _process(delta: float) -> void:
	if _spinner:
		_spinner.pivot_offset = _spinner.size / 2.0
		_spinner.rotation = fmod(_spinner.rotation + delta * TAU, TAU)

## Aşama metni ve geçen süre (0 ise süre gösterilmez).
func set_phase(text: String, elapsed_sec: int) -> void:
	_label.text = text + (" · %ds" % elapsed_sec if elapsed_sec > 0 else "")
	_hint.visible = elapsed_sec >= SLOW_HINT_AFTER_SEC

func get_text() -> String:
	return _label.text

func is_hint_visible() -> bool:
	return _hint.visible
