@tool
extends PanelContainer
class_name AISidebarApprovalCard

## İzin ve Onay Kartı Bileşeni (Approval Card) (SRP).
## Riskli işlemler (dosya silme, script ezme, sahne mutasyonu) için TEK YETKİLİ etkileşim kartıdır.
## Modal popup açılmaz; onay doğrudan bu kart üzerinden yönetilir.

signal action_approved()
signal action_rejected()
signal view_diff_requested(change_set: AISidebarChangeSet)

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarStatusIcon = preload("res://addons/godot_sidebar_ai/ui/components/status_icon.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")

var tool_name: String = ""
var args: Dictionary = {}
var change_set: AISidebarChangeSet = null
var is_resolved: bool = false

var _vbox: VBoxContainer
var _title_lbl: Label
var _title_icon: AISidebarStatusIcon
var _desc_lbl: RichTextLabel
var _buttons_bar: HBoxContainer
var _approve_btn: Button
var _reject_btn: Button
var _diff_btn: Button

func _init(p_tool: String = "", p_args: Dictionary = {}, p_cs: AISidebarChangeSet = null) -> void:
	tool_name = p_tool
	args = p_args
	change_set = p_cs

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	theme_type_variation = AISidebarThemeBuilder.CARD_WARNING
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_XS + 2))
	add_child(_vbox)
	
	var title_row = HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_XS + 2))
	_vbox.add_child(title_row)
	_title_icon = AISidebarStatusIcon.new(AISidebarTheme.ICON_SIZE_LG)
	_title_icon.set_icon("shield-alert", AISidebarTheme.COLOR_TONE_WARNING_TEXT)
	title_row.add_child(_title_icon)
	_title_lbl = Label.new()
	_title_lbl.text = AISidebarI18n.get_text("approval_title")
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_title_lbl.theme_type_variation = AISidebarThemeBuilder.TITLE_WARNING
	title_row.add_child(_title_lbl)
	
	_desc_lbl = RichTextLabel.new()
	var action_desc = tool_name
	if tool_name == "delete_node":
		action_desc = "Delete node: " + args.get("node_path", "")
	elif tool_name == "delete_file":
		action_desc = "Delete file: " + args.get("file_path", "")
	elif tool_name == "create_or_update_script":
		action_desc = "Update file: " + args.get("file_path", "")
	elif tool_name == "replace_file_content":
		action_desc = "Surgically update file: " + args.get("file_path", "")
	elif tool_name == "add_rule":
		action_desc = AISidebarI18n.get_text("approval_add_rule", {"scope": str(args.get("scope", "project")), "rule": str(args.get("rule", ""))})
	_desc_lbl.text = action_desc
	_desc_lbl.bbcode_enabled = true
	_desc_lbl.fit_content = true
	_desc_lbl.scroll_active = false
	_desc_lbl.selection_enabled = true
	_desc_lbl.context_menu_enabled = true
	_desc_lbl.shortcut_keys_enabled = true
	_desc_lbl.focus_mode = Control.FOCUS_CLICK
	_desc_lbl.deselect_on_focus_loss_enabled = false
	_desc_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	_desc_lbl.theme_type_variation = AISidebarThemeBuilder.RICH_BODY
	_vbox.add_child(_desc_lbl)
	
	_buttons_bar = HBoxContainer.new()
	_buttons_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_bar.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	_vbox.add_child(_buttons_bar)
	
	_approve_btn = Button.new()
	_approve_btn.text = AISidebarI18n.get_text("btn_approve")
	AISidebarIconHelper.apply_icon(_approve_btn, "check")
	_approve_btn.focus_mode = Control.FOCUS_NONE
	_approve_btn.theme_type_variation = AISidebarThemeBuilder.PRIMARY_BUTTON
	_approve_btn.pressed.connect(_on_approve)
	_buttons_bar.add_child(_approve_btn)
	
	_reject_btn = Button.new()
	_reject_btn.text = AISidebarI18n.get_text("btn_reject")
	AISidebarIconHelper.apply_icon(_reject_btn, "x")
	_reject_btn.focus_mode = Control.FOCUS_NONE
	_reject_btn.theme_type_variation = AISidebarThemeBuilder.BUTTON
	_reject_btn.pressed.connect(_on_reject)
	_buttons_bar.add_child(_reject_btn)
	
	if change_set:
		_diff_btn = Button.new()
		_diff_btn.text = AISidebarI18n.get_text("btn_view_diff")
		AISidebarIconHelper.apply_icon(_diff_btn, "diff")
		_diff_btn.focus_mode = Control.FOCUS_NONE
		_diff_btn.theme_type_variation = AISidebarThemeBuilder.GHOST_BUTTON
		_diff_btn.pressed.connect(func(): view_diff_requested.emit(change_set))
		_buttons_bar.add_child(_diff_btn)

func mark_approved() -> void:
	is_resolved = true
	if _title_lbl:
		_title_lbl.text = AISidebarI18n.get_text("approval_approved")
		_title_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_TONE_SUCCESS_TEXT)
		_title_icon.set_icon("check", AISidebarTheme.COLOR_TONE_SUCCESS_TEXT)
	if _approve_btn:
		_approve_btn.disabled = true
		_approve_btn.visible = false
	if _reject_btn:
		_reject_btn.disabled = true
		_reject_btn.visible = false

func mark_rejected() -> void:
	is_resolved = true
	if _title_lbl:
		_title_lbl.text = AISidebarI18n.get_text("approval_rejected")
		_title_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_TONE_ERROR_TEXT)
		_title_icon.set_icon("x", AISidebarTheme.COLOR_TONE_ERROR_TEXT)
	if _approve_btn:
		_approve_btn.disabled = true
		_approve_btn.visible = false
	if _reject_btn:
		_reject_btn.disabled = true
		_reject_btn.visible = false

func _on_approve() -> void:
	if is_resolved:
		return
	mark_approved()
	action_approved.emit()

func _on_reject() -> void:
	if is_resolved:
		return
	mark_rejected()
	action_rejected.emit()
