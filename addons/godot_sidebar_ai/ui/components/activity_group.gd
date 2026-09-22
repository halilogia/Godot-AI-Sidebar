@tool
extends PanelContainer
class_name AISidebarActivityGroup

## Katlanabilir Ajan Aktivite Grubu (Collapsible Activity / Working Group) (SRP).
## Ana görünümde sade insan-okunabilir durumları, tıklandığında ise teknik araç ayrıntılarını sunar.

signal meta_clicked(meta: Variant)

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

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
	# Antigravity tarzı: görev biterken aktivite listesi varsayılan olarak kapanır.
	# Kullanıcı başlığa tıklayarak ayrıntıları tekrar açabilir.
	set_expanded(false)

## Grubu tek noktadan aç/kapat (otomatik collapse ve kullanıcı tıklaması).
func set_expanded(p_expanded: bool) -> void:
	is_expanded = p_expanded
	if _items_container:
		_items_container.visible = is_expanded
	_update_header()

func _update_header() -> void:
	if not _header_btn:
		return
	var arrow = "▾" if is_expanded else "▸"
	var state_txt = "Working" if is_active else "Activity"
	var count_txt = " (" + str(_items.size()) + " steps)" if _items.size() > 0 else ""
	_header_btn.text = arrow + " " + state_txt + count_txt
	
	if is_active:
		_header_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)
	else:
		_header_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)

func _on_header_pressed() -> void:
	set_expanded(not is_expanded)

func _render_item(item: Dictionary) -> void:
	if not _items_container:
		return
		
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	_items_container.add_child(row)
	
	var icon_lbl = Label.new()
	icon_lbl.text = item["icon"]
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	icon_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
	if item["icon"] == "✓":
		icon_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_SUCCESS)
	elif item["icon"] == "❌":
		icon_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_ERROR)
	else:
		icon_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)
	row.add_child(icon_lbl)
	
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
	title_lbl.text = "[color=#c0caf5]" + item["title"] + "[/color]"
	title_lbl.meta_clicked.connect(func(m): meta_clicked.emit(m))
	row.add_child(title_lbl)
	
	if item["duration"] >= 0:
		var dur_lbl = Label.new()
		dur_lbl.text = "%.1fs" % (item["duration"] / 1000.0)
		dur_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		dur_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		dur_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
		row.add_child(dur_lbl)
