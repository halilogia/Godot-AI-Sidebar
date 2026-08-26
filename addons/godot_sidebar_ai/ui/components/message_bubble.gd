@tool
extends PanelContainer
class_name AISidebarMessageBubble

## Doğal Konuşma Balonu (User & Assistant Message Bubble) (SRP).
## Seçilebilir metin, kopyalanabilir kod blokları ve tıklanabilir dosya bağlantıları sunar.

signal meta_clicked(meta: Variant)
signal copy_code_requested(code_text: String)

const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

var role: String = "assistant"
var text_content: String = ""

var _vbox: VBoxContainer
var _header_bar: HBoxContainer
var _role_label: Label
var _copy_btn: Button
var _content_label: RichTextLabel

func _init(p_role: String = "assistant", p_text: String = "") -> void:
	role = p_role
	text_content = p_text

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()
	_render_content()

func set_message(p_role: String, p_text: String) -> void:
	role = p_role
	text_content = p_text
	_render_content()

func _setup_ui() -> void:
	# Stil ve Kenarlık
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	
	if role == "user":
		style.bg_color = Color(0.18, 0.22, 0.28, 0.85)
		style.border_color = Color(0.35, 0.45, 0.6, 0.6)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.14, 0.16, 0.20, 0.85)
		style.border_color = Color(0.24, 0.28, 0.35, 0.4)
		style.set_border_width_all(1)
		
	add_theme_stylebox_override("panel", style)
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)
	
	# Header
	_header_bar = HBoxContainer.new()
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(_header_bar)
	
	_role_label = Label.new()
	_role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_role_label.add_theme_font_size_override("font_size", 11)
	
	if role == "user":
		_role_label.text = "You"
		_role_label.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	else:
		_role_label.text = "Godot AI"
		_role_label.add_theme_color_override("font_color", Color(0.53, 0.75, 0.82))
		
	_header_bar.add_child(_role_label)
	
	_copy_btn = Button.new()
	_copy_btn.flat = true
	_copy_btn.focus_mode = Control.FOCUS_NONE
	_copy_btn.tooltip_text = "Metni Kopyala"
	AISidebarIconHelper.apply_icon(_copy_btn, "copy")
	_copy_btn.pressed.connect(_on_copy_pressed)
	_header_bar.add_child(_copy_btn)
	
	# İçerik
	_content_label = RichTextLabel.new()
	_content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_label.bbcode_enabled = true
	_content_label.fit_content = true
	_content_label.scroll_active = false
	_content_label.selection_enabled = true
	_content_label.context_menu_enabled = true
	_content_label.add_theme_font_size_override("normal_font_size", 12)
	_content_label.meta_clicked.connect(func(m): meta_clicked.emit(m))
	_vbox.add_child(_content_label)

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(text_content)
	AISidebarIconHelper.apply_icon(_copy_btn, "check")
	var t = get_tree()
	if t:
		var timer = t.create_timer(1.2)
		timer.timeout.connect(func(): 
			if is_instance_valid(_copy_btn):
				AISidebarIconHelper.apply_icon(_copy_btn, "copy")
		)

func _render_content() -> void:
	if not _content_label:
		return
		
	var formatted = _format_text_with_links_and_code(text_content)
	_content_label.text = formatted

func _format_text_with_links_and_code(raw: String) -> String:
	var result = raw
	# Dosya yollarını tıklanabilir linke dönüştür (res://...)
	var regex = RegEx.new()
	regex.compile("(res://[a-zA-Z0-9_/\\.\\-]+)")
	result = regex.sub(result, "[color=#88c0d0][url=file:$1]$1[/url][/color]", true)
	return result
