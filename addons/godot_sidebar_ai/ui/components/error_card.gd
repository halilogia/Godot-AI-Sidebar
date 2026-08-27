@tool
extends PanelContainer
class_name AISidebarErrorCard

## Hata ve Kurtarma Kartı (Error & Recovery Card) (SRP).
## Hataları temiz bir başlıkla sunar, ham exception spam'ini gizler ve Retry butonu sağlar.

signal retry_requested()

const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

var error_message: String = ""
var is_details_expanded: bool = false

var _vbox: VBoxContainer
var _title_lbl: Label
var _msg_lbl: RichTextLabel
var _details_btn: Button
var _details_lbl: RichTextLabel
var _retry_btn: Button

func _init(p_err: String = "") -> void:
	error_message = p_err

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.22, 0.12, 0.12, 0.9)
	style.border_color = Color(0.8, 0.3, 0.3, 0.7)
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", style)
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)
	
	_title_lbl = Label.new()
	_title_lbl.text = "Something went wrong"
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_title_lbl.add_theme_font_size_override("font_size", 12)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_vbox.add_child(_title_lbl)
	
	_msg_lbl = RichTextLabel.new()
	_msg_lbl.text = error_message
	_msg_lbl.bbcode_enabled = true
	_msg_lbl.fit_content = true
	_msg_lbl.scroll_active = false
	_msg_lbl.selection_enabled = true
	_msg_lbl.context_menu_enabled = true
	_msg_lbl.shortcut_keys_enabled = true
	_msg_lbl.focus_mode = Control.FOCUS_CLICK
	_msg_lbl.deselect_on_focus_loss_enabled = false
	_msg_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	_msg_lbl.add_theme_font_size_override("normal_font_size", 11)
	_msg_lbl.add_theme_color_override("default_color", Color(0.9, 0.85, 0.85))
	_vbox.add_child(_msg_lbl)
	
	var actions = HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	_vbox.add_child(actions)
	
	_retry_btn = Button.new()
	_retry_btn.text = "Retry"
	AISidebarIconHelper.apply_icon(_retry_btn, "refresh")
	_retry_btn.focus_mode = Control.FOCUS_NONE
	_retry_btn.add_theme_font_size_override("font_size", 11)
	_retry_btn.pressed.connect(_on_retry_pressed)
	actions.add_child(_retry_btn)

func _on_retry_pressed() -> void:
	retry_requested.emit()
