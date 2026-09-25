@tool
extends PanelContainer
class_name AISidebarScreenshotCard

## AI Screenshot Preview Kartı (SRP).
## Küçük thumbnail + kaynak etiketi + gönderim durumu; tıklayınca büyük görüntü.

signal meta_clicked(meta: Variant)

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarStatusIcon = preload("res://addons/godot_sidebar_ai/ui/components/status_icon.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")

var source_kind: String = "runtime_viewport"
var sent_to_model: bool = true
var vision: AISidebarVisionInput = null

var _thumb_btn: Button = null

func _init(p_vision: AISidebarVisionInput = null, p_source: String = "runtime_viewport", p_sent: bool = true) -> void:
	vision = p_vision
	source_kind = p_source
	sent_to_model = p_sent

static func source_label(kind: String) -> String:
	if kind == "editor_viewport":
		return "Editor viewport"
	if kind == "editor":
		return "Editor screen"
	return "Runtime viewport"

## Kaynak etiketinin yanındaki Lucide ikonu.
static func source_icon(kind: String) -> String:
	return "monitor" if kind.begins_with("editor") else "gamepad-2"

func status_text() -> String:
	if sent_to_model:
		return "Queued for next model turn"
	return "Saved only — no vision support"

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS))

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	add_child(hbox)

	_thumb_btn = Button.new()
	_thumb_btn.flat = true
	_thumb_btn.focus_mode = Control.FOCUS_NONE
	_thumb_btn.custom_minimum_size = Vector2(120, 68)
	_thumb_btn.tooltip_text = "Büyütmek için tıkla"
	_thumb_btn.pressed.connect(_on_thumb_pressed)
	hbox.add_child(_thumb_btn)
	if vision:
		var tex = vision.get_texture()
		if tex:
			_thumb_btn.icon = tex
			_thumb_btn.expand_icon = true

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var src_row = HBoxContainer.new()
	src_row.mouse_filter = Control.MOUSE_FILTER_PASS
	src_row.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	vbox.add_child(src_row)
	var src_icon = AISidebarStatusIcon.new()
	src_icon.set_icon(source_icon(source_kind), AISidebarTheme.COLOR_TEXT_SECONDARY)
	src_row.add_child(src_icon)
	var src_lbl = Label.new()
	var dims = ""
	if vision:
		dims = " (%dx%d)" % [vision.width, vision.height]
	src_lbl.text = source_label(source_kind) + dims
	src_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	src_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
	src_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	src_row.add_child(src_lbl)

	var st_color = AISidebarTheme.COLOR_SUCCESS if sent_to_model else AISidebarTheme.COLOR_WARNING
	var st_row = HBoxContainer.new()
	st_row.mouse_filter = Control.MOUSE_FILTER_PASS
	st_row.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	vbox.add_child(st_row)
	var st_icon = AISidebarStatusIcon.new(12)
	st_icon.set_icon("check" if sent_to_model else "triangle-alert", st_color)
	st_row.add_child(st_icon)
	var st_lbl = Label.new()
	st_lbl.text = status_text()
	st_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	st_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	st_lbl.add_theme_color_override("font_color", st_color)
	st_row.add_child(st_lbl)

func _on_thumb_pressed() -> void:
	if vision == null:
		return
	var tree = get_tree()
	if tree == null:
		return
	var tex = vision.get_texture()
	if tex == null:
		return
	var dlg = AcceptDialog.new()
	dlg.title = source_label(source_kind)
	dlg.min_size = Vector2(480, 320)
	var rect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(460, 300)
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dlg.add_child(rect)
	tree.root.add_child(dlg)
	dlg.popup_centered()
	dlg.close_requested.connect(func(): dlg.queue_free())
