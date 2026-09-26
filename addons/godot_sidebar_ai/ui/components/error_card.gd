@tool
extends PanelContainer
class_name AISidebarErrorCard

## Hata ve Kurtarma Kartı (Error & Recovery Card) (SRP).
## Hataları temiz bir başlıkla sunar, ham exception spam'ini gizler ve Retry butonu sağlar.

signal retry_requested()

const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")

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
	theme_type_variation = AISidebarThemeBuilder.CARD_ERROR
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_theme_constant_override("separation", AISidebarTheme.px(4))
	add_child(_vbox)
	
	_title_lbl = Label.new()
	_title_lbl.text = AISidebarI18n.get_text("error_title")
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_title_lbl.theme_type_variation = AISidebarThemeBuilder.TITLE_ERROR
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
	_msg_lbl.theme_type_variation = AISidebarThemeBuilder.RICH_BODY
	_vbox.add_child(_msg_lbl)
	
	var actions = HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", AISidebarTheme.px(8))
	_vbox.add_child(actions)
	
	_retry_btn = Button.new()
	_retry_btn.text = AISidebarI18n.get_text("btn_retry")
	AISidebarIconHelper.apply_icon(_retry_btn, "refresh")
	_retry_btn.focus_mode = Control.FOCUS_ALL
	_retry_btn.theme_type_variation = AISidebarThemeBuilder.BUTTON
	_retry_btn.pressed.connect(_on_retry_pressed)
	actions.add_child(_retry_btn)

func _on_retry_pressed() -> void:
	retry_requested.emit()
