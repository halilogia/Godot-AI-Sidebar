@tool
extends PanelContainer
class_name AISidebarMessageBubble

## Doğal Konuşma Balonu (User & Assistant Message Bubble) (SRP).
## Seçilebilir metin, kopyalanabilir kod blokları ve tıklanabilir dosya bağlantıları sunar.

signal meta_clicked(meta: Variant)
signal copy_code_requested(code_text: String)

const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarMarkdownRenderer = preload("res://addons/godot_sidebar_ai/ui/presenters/markdown_renderer.gd")

var role: String = "assistant"
var text_content: String = ""
var vision_inputs: Array = []

var _vbox: VBoxContainer
var _header_bar: HBoxContainer
var _role_label: Label
var _copy_btn: Button
var _content_label: RichTextLabel

func _init(p_role: String = "assistant", p_text: String = "", p_vision_inputs: Array = []) -> void:
	role = p_role
	text_content = p_text
	vision_inputs = p_vision_inputs

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()
	_render_content()

func set_message(p_role: String, p_text: String) -> void:
	role = p_role
	text_content = p_text
	_render_content()

func append_text(chunk: String) -> void:
	text_content += chunk
	_render_content()

func finalize_stream(final_text: String) -> void:
	text_content = final_text
	_render_content()

## Metin YALNIZCA yapılandırılmış bir tool-call zarfı mı? ({"tool_calls": [...]})
## Gerçek asistan açıklaması içeren metinlerde her zaman false döner; bu sayede
## "açıklama + tool_call" birlikte geldiğinde açıklama gizlenmez.
static func is_tool_call_envelope(raw_text: String) -> bool:
	if raw_text == null:
		return false
	var txt := raw_text.strip_edges()
	if txt.is_empty():
		return false
	# Markdown kod bloğu sarmalayıcısını soy (```json ... ```)
	if txt.begins_with("```"):
		var first_nl := txt.find("\n")
		if first_nl == -1:
			return false
		txt = txt.substr(first_nl + 1).strip_edges()
		if txt.ends_with("```"):
			txt = txt.substr(0, txt.length() - 3).strip_edges()
	if not txt.begins_with("{"):
		return false
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary and parsed.has("tool_calls") and parsed["tool_calls"] is Array:
		return true
	return false

## Metinden tool-call zarflarini cikarir; gercek asistan metnini korur.
## drop_incomplete_tail: henuz kapanmamis (streaming sirasinda bolunmus) zarf
## kuyrugunu da keser; bu sayede ham JSON hicbir asamada gorunmez.
static func strip_tool_call_envelopes(raw_text: String, drop_incomplete_tail: bool = true) -> String:
	if raw_text == null:
		return ""
	var txt := raw_text
	# 1. Tamamlanmis ```json ... ``` kod bloklari
	var fence_re := RegEx.new()
	fence_re.compile("(?s)```[ \t]*[a-zA-Z]*[ \t]*\r?\n(.*?)```")
	var kept := ""
	var pos := 0
	for m in fence_re.search_all(txt):
		if _is_tool_calls_json(str(m.get_string(1)).strip_edges()):
			kept += txt.substr(pos, m.get_start(0) - pos)
			pos = m.get_end(0)
	kept += txt.substr(pos)
	txt = kept
	# 2. Ciplak {"tool_calls": [...]} nesneleri
	txt = _strip_bare_envelopes(txt, drop_incomplete_tail)
	# 3. Yarim kalmis zarf baslangici (or. '{"tool_')
	if drop_incomplete_tail:
		txt = _drop_incomplete_envelope_tail(txt)
		# 4. Yarim kalmis ```json fence basligi (or. '```json')
		txt = _drop_incomplete_fence_tail(txt)
	return txt

static func _is_tool_calls_json(s: String) -> bool:
	if s.is_empty():
		return false
	var parsed = JSON.parse_string(s)
	return parsed is Dictionary and parsed.has("tool_calls") and parsed["tool_calls"] is Array

static func _strip_bare_envelopes(txt: String, drop_incomplete: bool) -> String:
	var start_re := RegEx.new()
	start_re.compile("\\{[ \t\r\n]*\"tool_calls\"")
	var out := ""
	var cursor := 0
	while cursor < txt.length():
		var m := start_re.search(txt, cursor)
		if m == null:
			out += txt.substr(cursor)
			break
		var start_idx := m.get_start(0)
		out += txt.substr(cursor, start_idx - cursor)
		var end_idx := _find_balanced_object_end(txt, start_idx)
		if end_idx == -1:
			if drop_incomplete:
				break
			out += txt.substr(start_idx)
			break
		var candidate := txt.substr(start_idx, end_idx - start_idx + 1)
		if _is_tool_calls_json(candidate):
			cursor = end_idx + 1
		else:
			out += txt.substr(start_idx, 1)
			cursor = start_idx + 1
	return out

## start_idx'teki '{' ile baslayan dengeli JSON nesnesinin kapanis indeksi (-1: kapanmadi).
static func _find_balanced_object_end(txt: String, start_idx: int) -> int:
	var depth := 0
	var in_str := false
	var esc := false
	for i in range(start_idx, txt.length()):
		var ch := txt[i]
		if in_str:
			if esc:
				esc = false
			elif ch == "\\":
				esc = true
			elif ch == "\"":
				in_str = false
			continue
		if ch == "\"":
			in_str = true
		elif ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				return i
	return -1

## Yarim gelmis bir zarf baslangici ("{" veya `{"tool_`) metnin sonundaysa keser.
static func _drop_incomplete_envelope_tail(txt: String) -> String:
	if not txt.contains("{"):
		return txt
	var idx := 0
	while idx < txt.length():
		var p := txt.find("{", idx)
		if p == -1:
			return txt
		if _could_be_envelope_prefix(txt.substr(p)):
			return txt.substr(0, p)
		idx = p + 1
	return txt

## Bu parca, henuz tamamlanmamis bir tool-call zarf baslangici olabilir mi?
## false ise guvenle gosterilebilir. On-ek eslesmesi yapar: {'{"foo"' -> false}
static func _could_be_envelope_prefix(t: String) -> bool:
	if not t.begins_with("{"):
		return false
	var rest := t.substr(1).lstrip(" \t\r\n")
	if rest.is_empty():
		return true
	if not rest.begins_with("\""):
		return false
	var key := "\"tool_calls\""
	if key.begins_with(rest):
		return true
	if not rest.begins_with(key):
		return false
	var after := rest.substr(key.length()).lstrip(" \t\r\n")
	return after.is_empty() or after.begins_with(":")

## Yarim kalmis ``` fence blogu (akis sirasinda henuz kapanmamis) zarf tasiyorsa keser.
## Kapanmis fence'ler (cift sayida ```) korunur; gercek kod bloklari gizlenmez.
static func _drop_incomplete_fence_tail(txt: String) -> String:
	var marker := "```"
	var total := txt.count(marker)
	if total == 0 or total % 2 == 0:
		return txt
	var open_idx := txt.rfind(marker)
	var body := txt.substr(open_idx + marker.length())
	# Dil etiketini (or. 'json') ve ilk satir sonunu soy
	var lang_re := RegEx.new()
	lang_re.compile("^[ \\t]*[a-zA-Z0-9_+-]*[ \\t]*\\r?\\n?")
	var lm := lang_re.search(body)
	if lm != null:
		body = body.substr(lm.get_end(0))
	var trimmed := body.strip_edges()
	if trimmed.is_empty() or _could_be_envelope_prefix(trimmed):
		return txt.substr(0, open_idx)
	return txt

func _setup_ui() -> void:
	var style: StyleBoxFlat
	if role == "user":
		style = AISidebarTheme.create_bubble_user_style()
	elif role == "command" or role == "slash_command":
		style = AISidebarTheme.create_bubble_command_style()
	else:
		style = AISidebarTheme.create_bubble_assistant_style()
		
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", style)
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	add_child(_vbox)
	
	# Header
	_header_bar = HBoxContainer.new()
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_header_bar)
	
	_role_label = Label.new()
	_role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_role_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_role_label.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	
	if role == "user":
		_role_label.text = "You"
		_role_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_ACCENT)
	elif role == "command" or role == "slash_command":
		_role_label.text = "Slash Command"
		_role_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_ROLE_COMMAND)
	else:
		_role_label.text = "Godot AI"
		_role_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
		
	_header_bar.add_child(_role_label)
	
	_copy_btn = Button.new()
	_copy_btn.flat = true
	_copy_btn.focus_mode = Control.FOCUS_NONE
	_copy_btn.tooltip_text = "Metni Kopyala"
	_copy_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_ghost_button_style(false))
	_copy_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_ghost_button_style(true))
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
	_content_label.shortcut_keys_enabled = true
	_content_label.focus_mode = Control.FOCUS_CLICK
	_content_label.deselect_on_focus_loss_enabled = false
	_content_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_content_label.add_theme_font_size_override("normal_font_size", AISidebarTheme.FONT_SIZE_BODY)
	_content_label.add_theme_color_override("default_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	_content_label.meta_clicked.connect(func(m): meta_clicked.emit(m))
	_vbox.add_child(_content_label)
	
	# Görsel Ekleri (Attached Images)
	if vision_inputs.size() > 0:
		for vi in vision_inputs:
			var tex: ImageTexture = null
			if vi is AISidebarVisionInput:
				tex = vi.get_texture()
			elif vi is Dictionary and vi.get("type") == "image_url":
				var url: String = vi.get("image_url", {}).get("url", "")
				if url.contains("base64,"):
					var b64 = url.split("base64,")[1]
					var raw = Marshalls.base64_to_raw(b64)
					var img = Image.new()
					if img.load_png_from_buffer(raw) == OK or img.load_jpg_from_buffer(raw) == OK:
						tex = ImageTexture.create_from_image(img)
			if tex:
				var img_rect = TextureRect.new()
				img_rect.texture = tex
				img_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				img_rect.custom_minimum_size = Vector2(0, mini(220, int(tex.get_height())))
				img_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				img_rect.mouse_filter = Control.MOUSE_FILTER_PASS
				_vbox.add_child(img_rect)

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
	# Asistan / komut yanıtı Markdown olarak işlenir; kullanıcı metni düz kalır.
	# Her iki yolda köşeli parantezler kaçırılır (metin BBCode enjekte edemez).
	var result = AISidebarMarkdownRenderer.escape_bbcode(raw) if role == "user" else AISidebarMarkdownRenderer.to_bbcode(raw)
	# Dosya yollarını tıklanabilir linke dönüştür (res://...)
	var regex = RegEx.new()
	regex.compile("(res://[a-zA-Z0-9_/\\.\\-]+)")
	result = regex.sub(result, "[color=#88c0d0][url=file:$1]$1[/url][/color]", true)
	
	# Node mention'larını vurgula (@Node:...)
	var node_regex = RegEx.new()
	node_regex.compile("(@Node:[a-zA-Z0-9_/\\.\\-]+)")
	result = node_regex.sub(result, "[color=#e5c07b][b]$1[/b][/color]", true)
	return result
