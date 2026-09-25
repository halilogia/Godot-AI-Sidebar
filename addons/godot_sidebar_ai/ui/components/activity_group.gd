@tool
extends PanelContainer
class_name AISidebarActivityGroup

## Katlanabilir Ajan Aktivite Grubu (Collapsible Activity / Working Group) (SRP).
## Ana görünümde sade insan-okunabilir durumları, tıklandığında ise teknik araç ayrıntılarını sunar.

signal meta_clicked(meta: Variant)

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")
const AISidebarStatusIcon = preload("res://addons/godot_sidebar_ai/ui/components/status_icon.gd")

var is_expanded: bool = false
var is_active: bool = true

var _vbox: VBoxContainer
var _header_btn: Button
var _items_container: VBoxContainer
var _items: Array[Dictionary] = []
var _item_rows: Array = []
var _current_step: int = -1
var _max_steps: int = -1
var _stop_reason: String = ""

func _init(p_is_expanded: bool = false) -> void:
	is_expanded = p_is_expanded

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

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
	_header_btn.pressed.connect(_on_header_pressed)
	_vbox.add_child(_header_btn)
	
	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_items_container.add_theme_constant_override("separation", AISidebarTheme.SPACE_XXS)
	_items_container.visible = is_expanded
	_vbox.add_child(_items_container)
	
	_update_header()

## Adım ekler ve satır indeksini döner (running -> completed güncellemesi için).
func add_activity(icon: String, human_title: String, duration_ms: int = -1, tech_details: String = "") -> int:
	var item = {
		"icon": _normalize_icon(icon),
		"title": human_title,
		"duration": duration_ms,
		"details": redact_secrets(tech_details),
		"expanded": false
	}
	_items.append(item)
	var idx = _items.size() - 1
	_render_item(item, idx)
	_update_header()
	return idx

## Running satırını gerçek sonuçla günceller (ikon + başlık + hata özeti + detay).
## Başarılı tool asla kırmızı X almaz; hata varsa kısa özet başlığa eklenir.
func update_activity(idx: int, icon: String, human_title: String, duration_ms: int = -1, tech_details: String = "", error_summary: String = "") -> void:
	if idx < 0 or idx >= _items.size():
		return
	var item: Dictionary = _items[idx]
	item["icon"] = _normalize_icon(icon)
	var title = human_title
	var err = error_summary.strip_edges()
	if not err.is_empty() and not title.contains(err.left(40)):
		title += "\nError: " + err
	item["title"] = title
	item["duration"] = duration_ms
	if not tech_details.is_empty():
		item["details"] = redact_secrets(tech_details)
	_items[idx] = item
	_refresh_item(idx)
	_update_header()

func get_item_count() -> int:
	return _items.size()

func get_item(idx: int) -> Dictionary:
	if idx < 0 or idx >= _items.size():
		return {}
	return (_items[idx] as Dictionary).duplicate(true)

func is_details_expanded(idx: int) -> bool:
	if idx < 0 or idx >= _items.size():
		return false
	return bool((_items[idx] as Dictionary).get("expanded", false))

func set_step_progress(current_step: int, max_steps: int) -> void:
	_current_step = current_step
	_max_steps = max_steps
	_update_header()

## Task durma nedeni (ör. "Tool-call limit reached: 20/20"). Başlıkta görünür kalır.
func set_stop_reason(reason: String) -> void:
	_stop_reason = reason.strip_edges()
	_update_header()

func complete_group() -> void:
	complete_group_keep_open(false)

## Görev bitiminde varsayılan olarak kapatır; keep_open=true ise (limit/hata)
## durma nedeni görünür kalsın diye açık bırakır.
func complete_group_keep_open(keep_open: bool = false) -> void:
	is_active = false
	# Antigravity tarzı: görev biterken aktivite listesi varsayılan olarak kapanır.
	# Kullanıcı başlığa tıklayarak ayrıntıları tekrar açabilir.
	set_expanded(keep_open)

## Credential sızıntısını engelle (tek kaynak: AISidebarTaskTranscript.redact_secrets).
static func redact_secrets(raw: String) -> String:
	return AISidebarTaskTranscript.redact_secrets(raw)

static func summarize_error(raw: String, max_len: int = 180) -> String:
	if raw == null:
		return ""
	var s = str(raw).strip_edges().replace("\n", " ").replace("\r", " ")
	while s.contains("  "):
		s = s.replace("  ", " ")
	if s.length() > max_len:
		s = s.left(max_len).strip_edges() + "..."
	return s

## Grubu tek noktadan aç/kapat (otomatik collapse ve kullanıcı tıklaması).
func set_expanded(p_expanded: bool) -> void:
	is_expanded = p_expanded
	if _items_container:
		_items_container.visible = is_expanded
	_update_header()

func get_header_text() -> String:
	if not _header_btn:
		return ""
	return _header_btn.text

func _normalize_icon(icon: String) -> String:
	match icon:
		"✓", "✔", "check", "success":
			return "✓"
		"\u274C", "✕", "✗", "x", "error", "failed":
			return "✕"
		"▶", "running", "play", "•", "...":
			return "▶"
		"!":
			return "!"
		_:
			return icon if not icon.is_empty() else "•"

func _update_header() -> void:
	if not _header_btn:
		return
	var arrow = "▾" if is_expanded else "▸"
	var state_txt = "Working" if is_active else "Activity"
	var count_txt = " · " + str(_items.size()) + " steps" if _items.size() > 0 else ""
	var txt = arrow + " " + state_txt + count_txt
	if not _stop_reason.is_empty():
		txt += " — " + _stop_reason
	_header_btn.text = txt

	if not _stop_reason.is_empty():
		_header_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_ERROR)
	elif is_active:
		_header_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)
	else:
		_header_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)

func _on_header_pressed() -> void:
	set_expanded(not is_expanded)

func _render_item(item: Dictionary, idx: int) -> void:
	if not _items_container:
		return
	while _item_rows.size() <= idx:
		_item_rows.append({})
	var entry: Dictionary = {}
	var outer = VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_PASS
	outer.add_theme_constant_override("separation", 0)
	_items_container.add_child(outer)
	entry["outer"] = outer
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	outer.add_child(row)

	var status_icon = AISidebarStatusIcon.new()
	row.add_child(status_icon)
	entry["icon"] = status_icon

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

	var dur_lbl = Label.new()
	dur_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	dur_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	dur_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
	row.add_child(dur_lbl)
	entry["duration"] = dur_lbl

	var details_btn = Button.new()
	details_btn.flat = true
	details_btn.focus_mode = Control.FOCUS_NONE
	details_btn.visible = false
	details_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	details_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
	outer.add_child(details_btn)
	entry["details_btn"] = details_btn

	var details_lbl = RichTextLabel.new()
	details_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_lbl.bbcode_enabled = false
	details_lbl.fit_content = true
	details_lbl.scroll_active = false
	details_lbl.selection_enabled = true
	details_lbl.visible = false
	details_lbl.add_theme_font_size_override("normal_font_size", AISidebarTheme.FONT_SIZE_SMALL)
	outer.add_child(details_lbl)
	entry["details_lbl"] = details_lbl

	var btn_idx = idx
	details_btn.pressed.connect(func(): _on_details_toggled(btn_idx))
	_item_rows[idx] = entry
	_refresh_item(idx)

func _refresh_item(idx: int) -> void:
	if idx < 0 or idx >= _items.size() or idx >= _item_rows.size():
		return
	var item: Dictionary = _items[idx]
	var entry: Dictionary = _item_rows[idx]
	if entry.is_empty() or not is_instance_valid(entry.get("outer")):
		return
	entry["icon"].set_status(str(item.get("icon", "•")))
	var safe_title = str(item.get("title", "")).replace("[", "［").replace("]", "］").replace("\n", "\n")
	(entry["title"] as RichTextLabel).text = "[color=#c0caf5]" + safe_title + "[/color]"
	var dur = int(item.get("duration", -1))
	if dur >= 0:
		(entry["duration"] as Label).text = "%.1fs" % (dur / 1000.0)
		(entry["duration"] as Label).visible = true
	else:
		(entry["duration"] as Label).visible = false
	var details = str(item.get("details", ""))
	var expanded = bool(item.get("expanded", false))
	if details.is_empty():
		(entry["details_btn"] as Button).visible = false
		(entry["details_lbl"] as RichTextLabel).visible = false
	else:
		(entry["details_btn"] as Button).visible = true
		var arrow = "▾" if expanded else "▸"
		(entry["details_btn"] as Button).text = arrow + " Technical details"
		(entry["details_lbl"] as RichTextLabel).visible = expanded
		if expanded:
			(entry["details_lbl"] as RichTextLabel).text = details.left(2000)

func _on_details_toggled(idx: int) -> void:
	if idx < 0 or idx >= _items.size():
		return
	_items[idx]["expanded"] = not bool(_items[idx].get("expanded", false))
	_refresh_item(idx)
