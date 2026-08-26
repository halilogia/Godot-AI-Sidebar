@tool
extends PanelContainer
class_name AISidebarActivityGroup

## Katlanabilir Ajan Aktivite Grubu (Collapsible Activity / Working Group) (SRP).
## Ana görünümde sade insan-okunabilir durumları, tıklandığında ise teknik araç ayrıntılarını sunar.

signal meta_clicked(meta: Variant)

var is_expanded: bool = false
var is_active: bool = true

var _vbox: VBoxContainer
var _header_btn: Button
var _items_container: VBoxContainer
var _items: Array[Dictionary] = []

func _init(p_is_expanded: bool = false) -> void:
	is_expanded = p_is_expanded

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.12, 0.14, 0.17, 0.8)
	style.border_color = Color(0.22, 0.25, 0.3, 0.4)
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
	_header_btn.pressed.connect(_on_header_pressed)
	_vbox.add_child(_header_btn)
	
	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.add_theme_constant_override("separation", 2)
	_items_container.visible = is_expanded
	_vbox.add_child(_items_container)
	
	_update_header()

func add_activity(icon: String, human_title: String, duration_ms: int = -1, tech_details: String = "") -> void:
	var item = {
		"icon": icon,
		"title": human_title,
		"duration": duration_ms,
		"details": tech_details,
		"expanded": false
	}
	_items.append(item)
	_render_item(item)
	_update_header()

func complete_group() -> void:
	is_active = false
	_update_header()

func _update_header() -> void:
	if not _header_btn:
		return
	var arrow = "▾" if is_expanded else "▸"
	var state_txt = "Working" if is_active else "Activity"
	var count_txt = " (" + str(_items.size()) + " steps)" if _items.size() > 0 else ""
	_header_btn.text = arrow + " " + state_txt + count_txt
	
	if is_active:
		_header_btn.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	else:
		_header_btn.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))

func _on_header_pressed() -> void:
	is_expanded = not is_expanded
	if _items_container:
		_items_container.visible = is_expanded
	_update_header()

func _render_item(item: Dictionary) -> void:
	if not _items_container:
		return
		
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.add_child(row)
	
	var icon_lbl = Label.new()
	icon_lbl.text = item["icon"]
	icon_lbl.add_theme_font_size_override("font_size", 11)
	if item["icon"] == "✓":
		icon_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5))
	elif item["icon"] == "❌":
		icon_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	else:
		icon_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
	row.add_child(icon_lbl)
	
	var title_lbl = RichTextLabel.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.bbcode_enabled = true
	title_lbl.fit_content = true
	title_lbl.scroll_active = false
	title_lbl.selection_enabled = true
	title_lbl.add_theme_font_size_override("normal_font_size", 11)
	title_lbl.text = "[color=#c0caf5]" + item["title"] + "[/color]"
	title_lbl.meta_clicked.connect(func(m): meta_clicked.emit(m))
	row.add_child(title_lbl)
	
	if item["duration"] >= 0:
		var dur_lbl = Label.new()
		dur_lbl.text = "%.1fs" % (item["duration"] / 1000.0)
		dur_lbl.add_theme_font_size_override("font_size", 10)
		dur_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		row.add_child(dur_lbl)
