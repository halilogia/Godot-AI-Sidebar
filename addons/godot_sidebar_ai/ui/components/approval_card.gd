@tool
extends PanelContainer
class_name AISidebarApprovalCard

## İzin ve Onay Kartı Bileşeni (Approval Card) (SRP).
## Riskli işlemler (dosya silme, sahne mutasyonu vb.) için şık onay kartı.

signal action_approved()
signal action_rejected()
signal view_diff_requested(change_set: AISidebarChangeSet)

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

var tool_name: String = ""
var args: Dictionary = {}
var change_set: AISidebarChangeSet = null

var _vbox: VBoxContainer
var _title_lbl: Label
var _desc_lbl: Label
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
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.20, 0.16, 0.10, 0.95)
	style.border_color = Color(0.9, 0.65, 0.2, 0.7)
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 6)
	add_child(_vbox)
	
	_title_lbl = Label.new()
	_title_lbl.text = "Approval Required"
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	_title_lbl.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_title_lbl)
	
	_desc_lbl = Label.new()
	var action_desc = tool_name
	if tool_name == "delete_node":
		action_desc = "Delete node: " + args.get("node_path", "")
	_desc_lbl.text = action_desc
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.add_theme_font_size_override("font_size", 11)
	_desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	_vbox.add_child(_desc_lbl)
	
	_buttons_bar = HBoxContainer.new()
	_buttons_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_bar.add_theme_constant_override("separation", 8)
	_vbox.add_child(_buttons_bar)
	
	_approve_btn = Button.new()
	_approve_btn.text = "Approve"
	AISidebarIconHelper.apply_icon(_approve_btn, "check")
	_approve_btn.focus_mode = Control.FOCUS_NONE
	_approve_btn.add_theme_font_size_override("font_size", 11)
	_approve_btn.pressed.connect(_on_approve)
	_buttons_bar.add_child(_approve_btn)
	
	_reject_btn = Button.new()
	_reject_btn.text = "Reject"
	AISidebarIconHelper.apply_icon(_reject_btn, "x")
	_reject_btn.focus_mode = Control.FOCUS_NONE
	_reject_btn.add_theme_font_size_override("font_size", 11)
	_reject_btn.pressed.connect(_on_reject)
	_buttons_bar.add_child(_reject_btn)
	
	if change_set:
		_diff_btn = Button.new()
		_diff_btn.text = "View Diff"
		AISidebarIconHelper.apply_icon(_diff_btn, "diff")
		_diff_btn.focus_mode = Control.FOCUS_NONE
		_diff_btn.add_theme_font_size_override("font_size", 11)
		_diff_btn.pressed.connect(func(): view_diff_requested.emit(change_set))
		_buttons_bar.add_child(_diff_btn)

func _on_approve() -> void:
	_approve_btn.disabled = true
	_reject_btn.disabled = true
	action_approved.emit()

func _on_reject() -> void:
	_approve_btn.disabled = true
	_reject_btn.disabled = true
	action_rejected.emit()
