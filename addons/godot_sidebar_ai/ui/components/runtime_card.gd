@tool
extends PanelContainer
class_name AISidebarRuntimeCard

## Çalışma Zamanı ve Test Gözlem Kartı (Runtime & Testing Observation Card) (SRP).
## Oyunun başlatılması, hata taraması ve çalışma zamanı sonuçlarını sade biçimde sunar.

signal meta_clicked(meta: Variant)

const AISidebarStatusIcon = preload("res://addons/godot_sidebar_ai/ui/components/status_icon.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")

var is_expanded: bool = true

var _vbox: VBoxContainer
var _header_btn: Button
var _status_list: VBoxContainer

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	theme_type_variation = AISidebarThemeBuilder.CARD_SUBTLE
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_theme_constant_override("separation", AISidebarTheme.px(4))
	add_child(_vbox)
	
	_header_btn = Button.new()
	_header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_btn.flat = true
	_header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_btn.focus_mode = Control.FOCUS_NONE  # focus: akıştaki açılır başlık; tıklamak yazma odağını almasın
	_header_btn.theme_type_variation = AISidebarThemeBuilder.LINK_BUTTON
	_header_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TONE_INFO_TEXT)
	_header_btn.text = "▾ " + AISidebarI18n.get_text("runtime_testing")
	_header_btn.pressed.connect(_on_header_pressed)
	_vbox.add_child(_header_btn)
	
	_status_list = VBoxContainer.new()
	_status_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_status_list.add_theme_constant_override("separation", AISidebarTheme.px(2))
	_vbox.add_child(_status_list)

func _on_header_pressed() -> void:
	is_expanded = not is_expanded
	if _status_list:
		_status_list.visible = is_expanded
	_header_btn.text = ("▾ " if is_expanded else "▸ ") + AISidebarI18n.get_text("runtime_testing")

func add_status(icon: String, text: String, color_hex: String = "#c0caf5") -> void:
	if not _status_list:
		return
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_status_list.add_child(row)
	
	var ic = AISidebarStatusIcon.new()
	row.add_child(ic)
	ic.set_status(icon, Color.html(color_hex))
	
	var lbl = RichTextLabel.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.selection_enabled = true
	lbl.context_menu_enabled = true
	lbl.shortcut_keys_enabled = true
	lbl.focus_mode = Control.FOCUS_CLICK
	lbl.deselect_on_focus_loss_enabled = false
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl.theme_type_variation = AISidebarThemeBuilder.RICH_BODY
	lbl.text = "[color=" + color_hex + "]" + text + "[/color]"
	lbl.meta_clicked.connect(func(m): meta_clicked.emit(m))
	row.add_child(lbl)
