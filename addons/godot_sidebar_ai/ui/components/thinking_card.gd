@tool
extends PanelContainer
class_name AISidebarThinkingCard

## İsteğe Bağlı Thinking Paneli (SRP).
## Provider'ın gönderdiği thinking metnini biriktirir; varsayılan collapsed.
## Üçgene basılınca açılır (Antigravity tarzı). Final cevap ve action
## özetinden ayrıdır; transcript'e yazılmaz.

signal meta_clicked(meta: Variant)

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

## Chat alanını ele geçirmemesi için display sınırı.
const MAX_DISPLAY_CHARS: int = 3000

var is_expanded: bool = false

var _text: String = ""
var _truncated: bool = false

var _vbox: VBoxContainer
var _header_btn: Button
var _content_lbl: RichTextLabel

func has_content() -> bool:
	return not _text.strip_edges().is_empty()

func get_text() -> String:
	return _text

func is_truncated() -> bool:
	return _truncated

func reset() -> void:
	_text = ""
	_truncated = false
	set_expanded(false)
	_render()

## Streaming delta'ları biriktirir (cap'e kadar).
func append_thinking(delta: String) -> void:
	if delta == null or delta.is_empty() or _truncated:
		return
	var room = MAX_DISPLAY_CHARS - _text.length()
	if room <= 0:
		_truncated = true
		_render()
		return
	if delta.length() > room:
		_text += delta.left(room)
		_truncated = true
	else:
		_text += delta
	_render()

## Stream dışı final thinking (kart boşsa doldurur; duplicate üretmez).
func set_thinking_final(full_text: String) -> void:
	if has_content():
		return
	if full_text == null:
		return
	var t = full_text.strip_edges()
	if t.is_empty():
		return
	if t.length() > MAX_DISPLAY_CHARS:
		_text = t.left(MAX_DISPLAY_CHARS)
		_truncated = true
	else:
		_text = t
	_render()

func set_expanded(p_expanded: bool) -> void:
	is_expanded = p_expanded
	if _content_lbl:
		_content_lbl.visible = is_expanded
	_update_header()

func get_header_text() -> String:
	if not _header_btn:
		return ""
	return _header_btn.text

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()
	_render()

func _setup_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS))

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XXS)
	add_child(_vbox)

	_header_btn = Button.new()
	_header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_btn.flat = true
	_header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_btn.focus_mode = Control.FOCUS_NONE
	_header_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	_header_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
	_header_btn.pressed.connect(func(): set_expanded(not is_expanded))
	_vbox.add_child(_header_btn)

	_content_lbl = RichTextLabel.new()
	_content_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_lbl.bbcode_enabled = false
	_content_lbl.fit_content = true
	_content_lbl.scroll_active = false
	_content_lbl.selection_enabled = true
	_content_lbl.context_menu_enabled = true
	_content_lbl.shortcut_keys_enabled = true
	_content_lbl.focus_mode = Control.FOCUS_CLICK
	_content_lbl.deselect_on_focus_loss_enabled = false
	_content_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	_content_lbl.add_theme_font_size_override("normal_font_size", AISidebarTheme.FONT_SIZE_SMALL)
	_content_lbl.add_theme_color_override("default_color", AISidebarTheme.COLOR_TEXT_MUTED)
	_content_lbl.visible = is_expanded
	_content_lbl.meta_clicked.connect(func(m): meta_clicked.emit(m))
	_vbox.add_child(_content_lbl)

func _update_header() -> void:
	if not _header_btn:
		return
	var arrow = "▾" if is_expanded else "▸"
	_header_btn.text = arrow + " Thinking"

func _render() -> void:
	_update_header()
	if not _content_lbl:
		return
	var shown = _text
	if _truncated:
		shown += "\n…[truncated]"
	_content_lbl.text = shown
