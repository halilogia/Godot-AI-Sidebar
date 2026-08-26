@tool
extends PanelContainer
class_name AISidebarChangesCard

## Görsel Değişiklik Kartı (Changes Card & File Deltas) (SRP).
## Dosya delta farklarını (+12 -2) listeler, View Diff ve Undo butonlarını sunar.

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")

signal view_diff_requested(change_set: AISidebarChangeSet)
signal undo_requested(change_set: AISidebarChangeSet)
signal meta_clicked(meta: Variant)

var change_set: AISidebarChangeSet

var _vbox: VBoxContainer
var _header_lbl: RichTextLabel
var _files_list: VBoxContainer
var _actions_bar: HBoxContainer
var _diff_btn: Button
var _undo_btn: Button

func _init(p_change_set: AISidebarChangeSet = null) -> void:
	change_set = p_change_set

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()
	if change_set:
		render_changes(change_set)

func _setup_ui() -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.12, 0.16, 0.20, 0.9)
	style.border_color = Color(0.3, 0.5, 0.65, 0.5)
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
	
	_header_lbl = RichTextLabel.new()
	_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_lbl.bbcode_enabled = true
	_header_lbl.fit_content = true
	_header_lbl.scroll_active = false
	_header_lbl.add_theme_font_size_override("normal_font_size", 12)
	_vbox.add_child(_header_lbl)
	
	_files_list = VBoxContainer.new()
	_files_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_files_list.add_theme_constant_override("separation", 3)
	_vbox.add_child(_files_list)
	
	_actions_bar = HBoxContainer.new()
	_actions_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_bar.add_theme_constant_override("separation", 8)
	_vbox.add_child(_actions_bar)
	
	_diff_btn = Button.new()
	_diff_btn.text = "🔍 View Diff"
	_diff_btn.focus_mode = Control.FOCUS_NONE
	_diff_btn.add_theme_font_size_override("font_size", 11)
	_diff_btn.pressed.connect(_on_diff_pressed)
	_actions_bar.add_child(_diff_btn)
	
	_undo_btn = Button.new()
	_undo_btn.text = "↩ Undo"
	_undo_btn.focus_mode = Control.FOCUS_NONE
	_undo_btn.add_theme_font_size_override("font_size", 11)
	_undo_btn.pressed.connect(_on_undo_pressed)
	_actions_bar.add_child(_undo_btn)

func _on_diff_pressed() -> void:
	view_diff_requested.emit(change_set)

func _on_undo_pressed() -> void:
	undo_requested.emit(change_set)

func render_changes(cs: AISidebarChangeSet) -> void:
	change_set = cs
	if not _header_lbl or not _files_list:
		return
		
	for child in _files_list.get_children():
		child.queue_free()
		
	var deltas = cs.get_file_deltas()
	_header_lbl.text = "[b][color=#88c0d0]▾ Changes (" + str(deltas.size()) + " files)[/color][/b]"
	
	for d in deltas:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_files_list.add_child(row)
		
		var name_lbl = RichTextLabel.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.bbcode_enabled = true
		name_lbl.fit_content = true
		name_lbl.scroll_active = false
		name_lbl.selection_enabled = true
		name_lbl.add_theme_font_size_override("normal_font_size", 11)
		name_lbl.text = "  • [url=file:" + d["path"] + "][color=#d8dee9]" + d["file_name"] + "[/color][/url]"
		name_lbl.meta_clicked.connect(func(m): meta_clicked.emit(m))
		row.add_child(name_lbl)
		
		var delta_lbl = RichTextLabel.new()
		delta_lbl.bbcode_enabled = true
		delta_lbl.fit_content = true
		delta_lbl.scroll_active = false
		delta_lbl.add_theme_font_size_override("normal_font_size", 11)
		delta_lbl.text = "[color=#a3be8c]+" + str(d["added"]) + "[/color]  [color=#bf616a]-" + str(d["removed"]) + "[/color]"
		row.add_child(delta_lbl)
