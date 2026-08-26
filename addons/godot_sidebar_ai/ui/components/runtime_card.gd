@tool
extends PanelContainer
class_name AISidebarRuntimeCard

## Çalışma Zamanı ve Test Gözlem Kartı (Runtime & Testing Observation Card) (SRP).
## Oyunun başlatılması, hata taraması ve çalışma zamanı sonuçlarını sade biçimde sunar.

signal meta_clicked(meta: Variant)

var is_expanded: bool = true

var _vbox: VBoxContainer
var _header_btn: Button
var _status_list: VBoxContainer

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.13, 0.15, 0.20, 0.85)
	style.border_color = Color(0.3, 0.5, 0.7, 0.4)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)
	
	_header_btn = Button.new()
	_header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_btn.flat = true
	_header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_btn.focus_mode = Control.FOCUS_NONE
	_header_btn.add_theme_font_size_override("font_size", 11)
	_header_btn.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	_header_btn.text = "▾ Testing"
	_header_btn.pressed.connect(_on_header_pressed)
	_vbox.add_child(_header_btn)
	
	_status_list = VBoxContainer.new()
	_status_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_list.add_theme_constant_override("separation", 2)
	_vbox.add_child(_status_list)

func _on_header_pressed() -> void:
	is_expanded = not is_expanded
	if _status_list:
		_status_list.visible = is_expanded
	_header_btn.text = ("▾ " if is_expanded else "▸ ") + "Testing"

func add_status(icon: String, text: String, color_hex: String = "#c0caf5") -> void:
	if not _status_list:
		return
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_list.add_child(row)
	
	var ic = Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", 11)
	row.add_child(ic)
	
	var lbl = RichTextLabel.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.selection_enabled = true
	lbl.add_theme_font_size_override("normal_font_size", 11)
	lbl.text = "[color=" + color_hex + "]" + text + "[/color]"
	lbl.meta_clicked.connect(func(m): meta_clicked.emit(m))
	row.add_child(lbl)
