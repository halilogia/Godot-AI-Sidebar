@tool
extends PanelContainer
class_name AISidebarChangesCard

## Değişiklik Kartı Bileşeni (Changes Card) (SRP).
## Dosya delta farklarını (+eklenen -silinen) kompakt rozetlerle gösterir,
## [View Diff] ve [Undo] butonları sunar.

signal view_diff_requested(change_set: AISidebarChangeSet)
signal undo_requested(change_set: AISidebarChangeSet)
signal meta_clicked(meta: Variant)
signal file_clicked(file_path: String)

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

var change_set: AISidebarChangeSet
var is_expanded: bool = true

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
	style.bg_color = Color(0.14, 0.16, 0.20, 0.95)
	style.border_color = Color(0.3, 0.4, 0.55, 0.6)
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
	_vbox.add_theme_constant_override("separation", 6)
	add_child(_vbox)
	
	_header_lbl = RichTextLabel.new()
	_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_lbl.bbcode_enabled = true
	_header_lbl.fit_content = true
	_header_lbl.scroll_active = false
	_header_lbl.selection_enabled = true
	_header_lbl.context_menu_enabled = true
	_header_lbl.shortcut_keys_enabled = true
	_header_lbl.focus_mode = Control.FOCUS_CLICK
	_header_lbl.deselect_on_focus_loss_enabled = false
	_header_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	_header_lbl.add_theme_font_size_override("normal_font_size", 12)
	_header_lbl.meta_clicked.connect(func(m): meta_clicked.emit(m))
	_vbox.add_child(_header_lbl)
	
	_files_list = VBoxContainer.new()
	_files_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_files_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_files_list.add_theme_constant_override("separation", 3)
	_vbox.add_child(_files_list)
	
	_actions_bar = HBoxContainer.new()
	_actions_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_bar.add_theme_constant_override("separation", 8)
	_vbox.add_child(_actions_bar)
	
	_diff_btn = Button.new()
	_diff_btn.text = "View Diff"
	AISidebarIconHelper.apply_icon(_diff_btn, "diff")
	_diff_btn.focus_mode = Control.FOCUS_NONE
	_diff_btn.add_theme_font_size_override("font_size", 11)
	_diff_btn.pressed.connect(_on_diff_pressed)
	_actions_bar.add_child(_diff_btn)
	
	_undo_btn = Button.new()
	_undo_btn.text = "Undo"
	AISidebarIconHelper.apply_icon(_undo_btn, "undo")
	_undo_btn.focus_mode = Control.FOCUS_NONE
	_undo_btn.add_theme_font_size_override("font_size", 11)
	_undo_btn.pressed.connect(_on_undo_pressed)
	_actions_bar.add_child(_undo_btn)

func render_changes(cs: AISidebarChangeSet) -> void:
	change_set = cs
	if not _header_lbl or not _files_list:
		return
		
	for c in _files_list.get_children():
		c.queue_free()
		
	var deltas = cs.get_file_deltas()
	var total_files = deltas.size()
	
	_header_lbl.text = "[color=#88c0d0][b]▾ Changes (" + str(total_files) + " " + ("file" if total_files == 1 else "files") + ")[/b][/color]"
	
	for d in deltas:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 6)
		
		var name_lbl = RichTextLabel.new()
		name_lbl.bbcode_enabled = true
		name_lbl.fit_content = true
		name_lbl.scroll_active = false
		name_lbl.selection_enabled = true
		name_lbl.context_menu_enabled = true
		name_lbl.shortcut_keys_enabled = true
		name_lbl.focus_mode = Control.FOCUS_CLICK
		name_lbl.deselect_on_focus_loss_enabled = false
		name_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.add_theme_font_size_override("normal_font_size", 11)
		var p = str(d["path"])
		name_lbl.text = "• [url=file:" + p + "]" + p + "[/url]"
		name_lbl.meta_clicked.connect(func(m): 
			meta_clicked.emit(m)
			file_clicked.emit(p)
		)
		row.add_child(name_lbl)
		
		var delta_lbl = RichTextLabel.new()
		delta_lbl.bbcode_enabled = true
		delta_lbl.fit_content = true
		delta_lbl.scroll_active = false
		delta_lbl.selection_enabled = true
		delta_lbl.context_menu_enabled = true
		delta_lbl.shortcut_keys_enabled = true
		delta_lbl.focus_mode = Control.FOCUS_CLICK
		delta_lbl.deselect_on_focus_loss_enabled = false
		delta_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		delta_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		delta_lbl.add_theme_font_size_override("normal_font_size", 11)
		delta_lbl.text = "[color=#a3be8c]+" + str(d["added"]) + "[/color] [color=#bf616a]-" + str(d["removed"]) + "[/color]"
		row.add_child(delta_lbl)
		
		_files_list.add_child(row)

func _on_diff_pressed() -> void:
	view_diff_requested.emit(change_set)

func _on_undo_pressed() -> void:
	_undo_btn.disabled = true
	_undo_btn.text = "Undone"
	undo_requested.emit(change_set)
