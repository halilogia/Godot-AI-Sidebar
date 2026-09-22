@tool
extends PanelContainer
class_name AISidebarTaskChecklist

## Implementation Plan Task Checklist (Opencode tarzı) (SRP).
## Yüksek seviye plan ilerlemesi; ActivityGroup (düşük seviye tool activity) ile
## karıştırılmaz. State'ler AgentRunner/ChatDock eventlerinden türetilir, LLM'e sorulmaz.

signal meta_clicked(meta: Variant)

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

const STATE_PENDING := "pending"
const STATE_RUNNING := "running"
const STATE_COMPLETED := "completed"
const STATE_FAILED := "failed"
const STATE_SKIPPED := "skipped"

var goal: String = ""
var is_expanded: bool = true
var is_finished: bool = false
var stop_reason: String = ""

var _steps: Array[Dictionary] = []

var _vbox: VBoxContainer
var _header_btn: Button
var _items_container: VBoxContainer
var _rows: Array = []

static func state_icon(state: String) -> String:
	match state:
		STATE_COMPLETED:
			return "✓"
		STATE_RUNNING:
			return "▶"
		STATE_FAILED:
			return "✕"
		STATE_SKIPPED:
			return "–"
		_:
			return "☐"

func setup(step_titles: Array, p_goal: String = "") -> void:
	goal = p_goal.strip_edges()
	_steps.clear()
	for s in step_titles:
		var t = str(s).strip_edges()
		if not t.is_empty():
			_steps.append({"title": t.left(200), "state": STATE_PENDING, "error": ""})
	is_finished = false
	stop_reason = ""

func step_count() -> int:
	return _steps.size()

func get_states() -> Array:
	var out: Array = []
	for s in _steps:
		out.append(str(s.get("state", STATE_PENDING)))
	return out

func completed_count() -> int:
	var n = 0
	for s in _steps:
		if str(s.get("state", "")) == STATE_COMPLETED:
			n += 1
	return n

func get_step(idx: int) -> Dictionary:
	if idx < 0 or idx >= _steps.size():
		return {}
	return (_steps[idx] as Dictionary).duplicate(true)

func set_step_state(idx: int, state: String, error: String = "") -> void:
	if idx < 0 or idx >= _steps.size():
		return
	_steps[idx]["state"] = state
	_steps[idx]["error"] = error.strip_edges().left(300)
	_refresh_row(idx)
	_update_header()

func mark_all_completed() -> void:
	for i in range(_steps.size()):
		if str(_steps[i].get("state", "")) != STATE_FAILED:
			_steps[i]["state"] = STATE_COMPLETED
			_steps[i]["error"] = ""
		_refresh_row(i)
	is_finished = true
	_update_header()

## Kalan PENDING adımlar atlandı; RUNNING adım failed_reason ile FAILED olur.
func finish_with_stop(failed_idx: int, reason: String) -> void:
	stop_reason = reason.strip_edges().left(300)
	for i in range(_steps.size()):
		if i == failed_idx:
			_steps[i]["state"] = STATE_FAILED
			_steps[i]["error"] = stop_reason
		elif str(_steps[i].get("state", "")) in [STATE_PENDING, STATE_RUNNING]:
			_steps[i]["state"] = STATE_SKIPPED
			_steps[i]["error"] = ""
		_refresh_row(i)
	is_finished = true
	_update_header()

func set_finished_success() -> void:
	stop_reason = ""
	mark_all_completed()

## Transcript snapshot (export + Copy Task kaynağı).
func to_snapshot() -> Array:
	var out: Array = []
	for s in _steps:
		out.append({"title": str(s.get("title", "")), "state": str(s.get("state", STATE_PENDING))})
	return out

func get_header_text() -> String:
	if not _header_btn:
		return ""
	return _header_btn.text

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()
	for i in range(_steps.size()):
		_render_row(i)
	_update_header()

func _setup_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_SM))

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	add_child(_vbox)

	_header_btn = Button.new()
	_header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_btn.flat = true
	_header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_btn.focus_mode = Control.FOCUS_NONE
	_header_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
	_header_btn.pressed.connect(func(): set_expanded(not is_expanded))
	_vbox.add_child(_header_btn)

	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_items_container.add_theme_constant_override("separation", AISidebarTheme.SPACE_XXS)
	_items_container.visible = is_expanded
	_vbox.add_child(_items_container)

func set_expanded(p_expanded: bool) -> void:
	is_expanded = p_expanded
	if _items_container:
		_items_container.visible = is_expanded
	_update_header()

func _update_header() -> void:
	if not _header_btn:
		return
	var arrow = "▾" if is_expanded else "▸"
	var done = completed_count()
	var total = _steps.size()
	if not stop_reason.is_empty():
		_header_btn.text = arrow + " ✕ stopped at %d/%d — %s" % [done, total, stop_reason]
		_header_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_ERROR)
	elif is_finished:
		_header_btn.text = arrow + " 📋 Tasks ✓ %d/%d" % [done, total]
		_header_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_SUCCESS)
	else:
		var title = "📋 Tasks"
		if not goal.is_empty():
			title = "📋 " + goal.left(60)
		_header_btn.text = arrow + " " + title + " · %d/%d" % [done, total]
		_header_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)

func _render_row(idx: int) -> void:
	if not _items_container:
		return
	while _rows.size() <= idx:
		_rows.append({})
	var entry: Dictionary = {}
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	_items_container.add_child(row)

	var icon_lbl = Label.new()
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	icon_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
	row.add_child(icon_lbl)
	entry["icon"] = icon_lbl

	var title_lbl = RichTextLabel.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.bbcode_enabled = true
	title_lbl.fit_content = true
	title_lbl.scroll_active = false
	title_lbl.selection_enabled = true
	title_lbl.context_menu_enabled = true
	title_lbl.shortcut_keys_enabled = true
	title_lbl.focus_mode = Control.FOCUS_CLICK
	title_lbl.deselect_on_focus_loss_enabled = false
	title_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	title_lbl.add_theme_font_size_override("normal_font_size", AISidebarTheme.FONT_SIZE_BODY)
	title_lbl.meta_clicked.connect(func(m): meta_clicked.emit(m))
	row.add_child(title_lbl)
	entry["title"] = title_lbl

	_rows[idx] = entry
	_refresh_row(idx)

func _refresh_row(idx: int) -> void:
	if idx < 0 or idx >= _steps.size() or idx >= _rows.size():
		return
	var entry: Dictionary = _rows[idx]
	if entry.is_empty() or not is_instance_valid(entry.get("outer", entry.get("icon"))):
		return
	var state = str(_steps[idx].get("state", STATE_PENDING))
	var icon_str = state_icon(state)
	(entry["icon"] as Label).text = icon_str
	if state == STATE_COMPLETED:
		(entry["icon"] as Label).add_theme_color_override("font_color", AISidebarTheme.COLOR_SUCCESS)
	elif state == STATE_FAILED:
		(entry["icon"] as Label).add_theme_color_override("font_color", AISidebarTheme.COLOR_ERROR)
	elif state == STATE_RUNNING:
		(entry["icon"] as Label).add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)
	else:
		(entry["icon"] as Label).add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
	var safe_title = str(_steps[idx].get("title", "")).replace("[", "［").replace("]", "］")
	var err = str(_steps[idx].get("error", ""))
	if not err.is_empty():
		safe_title += "\nError: " + err.replace("[", "［").replace("]", "］")
	(entry["title"] as RichTextLabel).text = "[color=#c0caf5]" + safe_title + "[/color]"
