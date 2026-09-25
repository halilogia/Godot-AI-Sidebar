@tool
extends RefCounted

## Mesaj giriş alanının davranışı (SRP): klavye (Enter / Shift+Enter / Ctrl+V),
## @mention ve /slash autocomplete popup'ı, pano görseli eki.
## Düğümler ChatDock sahnesinden gelir; gönderme kararı `send_requested` ile TaskController'a bırakılır.

signal send_requested

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarMentionManager = preload("res://addons/godot_sidebar_ai/core/chat/mention_manager.gd")
const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")

var input_area: VBoxContainer
var input_field: TextEdit
var mention_container: PanelContainer
var mention_list: ItemList

# Pano Görseli Eki (Clipboard Image Attachment)
var attached_vision_input: AISidebarVisionInput = null
var attachment_container: PanelContainer = null
var _attachment_preview: TextureRect = null
var _attachment_label: Label = null
var _attachment_remove_btn: Button = null

var _active_mention_suggestions: Array[Dictionary] = []
var _active_mention_query_info: Dictionary = {}
var _active_slash_suggestions: Array[Dictionary] = []
var _active_slash_query_info: Dictionary = {}

func _init(p_input_area: VBoxContainer, p_input_field: TextEdit, p_mention_container: PanelContainer, p_mention_list: ItemList) -> void:
	input_area = p_input_area
	input_field = p_input_field
	mention_container = p_mention_container
	mention_list = p_mention_list

## Görsel eki şeridini kurar ve giriş sinyallerini bağlar (ChatDock._ready).
func setup_attachment_ui() -> void:
	if not input_area or not input_field:
		return

	attachment_container = PanelContainer.new()
	attachment_container.name = "AttachmentContainer"
	attachment_container.visible = false
	attachment_container.add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XXS))

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)

	_attachment_preview = TextureRect.new()
	_attachment_preview.custom_minimum_size = Vector2(32, 32)
	_attachment_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_attachment_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(_attachment_preview)

	_attachment_label = Label.new()
	_attachment_label.text = "Pano görseli"
	_attachment_label.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	_attachment_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	_attachment_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attachment_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_attachment_label.clip_text = true
	hbox.add_child(_attachment_label)

	_attachment_remove_btn = Button.new()
	AISidebarIconHelper.apply_tinted_icon(_attachment_remove_btn, "x", AISidebarTheme.COLOR_ERROR)
	_attachment_remove_btn.flat = true
	_attachment_remove_btn.focus_mode = Control.FOCUS_NONE
	_attachment_remove_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	_attachment_remove_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_ERROR)
	_attachment_remove_btn.tooltip_text = "Görseli kaldır"
	_attachment_remove_btn.pressed.connect(clear_attached_image)
	hbox.add_child(_attachment_remove_btn)

	attachment_container.add_child(hbox)
	input_area.add_child(attachment_container)
	input_area.move_child(attachment_container, input_field.get_index())

func connect_input_signals() -> void:
	if input_field:
		input_field.gui_input.connect(handle_gui_input)
		input_field.text_changed.connect(_on_input_text_changed)
	if mention_list:
		mention_list.item_activated.connect(activate_suggestion)

func hide_popup() -> void:
	if mention_container:
		mention_container.visible = false

# --- Görsel eki ---

func attach_vision_input(vi: AISidebarVisionInput) -> void:
	if vi == null:
		return
	attached_vision_input = vi
	if _attachment_preview:
		_attachment_preview.texture = vi.get_texture()
	if _attachment_label:
		_attachment_label.text = "Pano görseli (%dx%d)" % [vi.width, vi.height]
	if attachment_container:
		attachment_container.visible = true

func attach_image_from_clipboard(img: Image) -> void:
	if not img or img.is_empty():
		return
	var vi = AISidebarVisionInput.from_image(img)
	if vi == null:
		return
	# Aynı görsel zaten ekliyse tekrar ekleme (yanlışlıkla çift yapıştırma).
	if attached_vision_input and AISidebarVisionInput.is_same_image(vi, attached_vision_input):
		return
	attach_vision_input(vi)

func clear_attached_image() -> void:
	attached_vision_input = null
	if attachment_container:
		attachment_container.visible = false
	if _attachment_preview:
		_attachment_preview.texture = null

# --- Klavye ---

func handle_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Pano Görseli Yapıştırma (Clipboard Image Paste - Ctrl+V / Cmd+V)
		if (event.ctrl_pressed or event.meta_pressed) and not event.alt_pressed and not event.shift_pressed and event.keycode == KEY_V:
			if DisplayServer.has_method("clipboard_has_image") and DisplayServer.clipboard_has_image():
				var img = DisplayServer.clipboard_get_image()
				if img and not img.is_empty():
					attach_image_from_clipboard(img)
					_accept_event()
					return

		var is_enter = (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)

		# Mention Açıkken Klavye Navigasyonu
		if mention_container and mention_container.visible:
			if event.keycode == KEY_ESCAPE:
				_accept_event()
				mention_container.visible = false
				return
			elif event.keycode == KEY_DOWN:
				_accept_event()
				_navigate_mention_list(1)
				return
			elif event.keycode == KEY_UP:
				_accept_event()
				_navigate_mention_list(-1)
				return
			elif event.keycode == KEY_TAB or (is_enter and not (event.ctrl_pressed or event.shift_pressed)):
				var sel = mention_list.get_selected_items()
				if sel.size() > 0:
					_accept_event()
					activate_suggestion(sel[0])
					return
			elif is_enter and event.shift_pressed:
				_accept_event()
				mention_container.visible = false
				input_field.insert_text_at_caret("\n")
				return

		# Enter ve Shift+Enter / Ctrl+Enter Yönetimi
		if is_enter:
			if event.shift_pressed:
				# Shift+Enter -> Yeni satır (Multiline)
				_accept_event()
				input_field.insert_text_at_caret("\n")
			elif not event.alt_pressed:
				# Enter veya Ctrl+Enter -> Mesajı Gönder veya Kuyruğa Al
				_accept_event()
				send_requested.emit()

## Olayı tüket (ağaç dışında — örn. testlerde — sessizce atlanır).
func _accept_event() -> void:
	if input_field and input_field.is_inside_tree():
		input_field.accept_event()

func _navigate_mention_list(dir: int) -> void:
	if not mention_list or mention_list.item_count == 0:
		return
	var cur = 0
	var sel = mention_list.get_selected_items()
	if sel.size() > 0:
		cur = sel[0]
	var next_idx = posmod(cur + dir, mention_list.item_count)
	mention_list.select(next_idx)
	mention_list.ensure_current_is_visible()

# --- Autocomplete ---

func _on_input_text_changed() -> void:
	if not input_field or not mention_container or not mention_list:
		return

	var text = input_field.text
	var caret_line = input_field.get_caret_line()
	var caret_col = input_field.get_caret_column()

	var lines = text.split("\n")
	var absolute_caret_pos = 0
	for i in range(mini(caret_line, lines.size())):
		absolute_caret_pos += lines[i].length() + 1
	absolute_caret_pos += caret_col
	absolute_caret_pos = clampi(absolute_caret_pos, 0, text.length())

	# 1. Önce Slash Command (/) kontrolü
	var slash_q = AISidebarSlashCommandManager.detect_slash_query(text, absolute_caret_pos)
	if slash_q["active"]:
		_active_slash_query_info = slash_q
		_active_mention_query_info.clear()
		_active_slash_suggestions = AISidebarSlashCommandManager.get_suggestions(slash_q["query"])
		_active_mention_suggestions.clear()

		if _active_slash_suggestions.size() > 0:
			mention_list.clear()
			for s in _active_slash_suggestions:
				var label = s["label"] + " — " + s["detail"]
				mention_list.add_item(label)
			mention_list.select(0)
			mention_container.visible = true
			return
		else:
			mention_container.visible = false
			return

	# 2. @Mention kontrolü
	_active_slash_query_info.clear()
	_active_slash_suggestions.clear()
	var q_info = AISidebarMentionManager.detect_mention_query(text, absolute_caret_pos)
	if q_info["active"]:
		_active_mention_query_info = q_info
		_active_mention_suggestions = AISidebarMentionManager.get_suggestions(q_info["query"])
		if _active_mention_suggestions.size() > 0:
			mention_list.clear()
			for s in _active_mention_suggestions:
				var badge = s.get("type_badge", "FILE")
				var label = "[" + badge + "] " + s.get("label", "") + " (" + s.get("detail", "") + ")"
				mention_list.add_item(label)
			mention_list.select(0)
			mention_container.visible = true
		else:
			mention_container.visible = false
	else:
		mention_container.visible = false

func activate_suggestion(index: int) -> void:
	if not input_field:
		if mention_container:
			mention_container.visible = false
		return

	# Eğer aktif olan Slash Command önerisi ise:
	if _active_slash_suggestions.size() > 0:
		if index < 0 or index >= _active_slash_suggestions.size():
			if mention_container: mention_container.visible = false
			return
		var chosen_cmd = _active_slash_suggestions[index]
		var insert_text = chosen_cmd.get("insert_text", "")
		var text = input_field.text
		var start_pos = _active_slash_query_info.get("start_pos", -1)
		var end_pos = _active_slash_query_info.get("end_pos", -1)

		if start_pos >= 0 and end_pos >= start_pos and end_pos <= text.length():
			var new_text = text.substr(0, start_pos) + insert_text + text.substr(end_pos)
			input_field.text = new_text
			var new_caret_pos = start_pos + insert_text.length()
			_set_input_caret_position(new_text, new_caret_pos)

		_active_slash_suggestions.clear()
		_active_slash_query_info.clear()
		if mention_container: mention_container.visible = false
		input_field.grab_focus()
		return

	# @Mention Tamamlama
	if index < 0 or index >= _active_mention_suggestions.size():
		if mention_container:
			mention_container.visible = false
		return

	var chosen = _active_mention_suggestions[index]
	var insert_text = chosen.get("insert_text", "") + " "

	var text = input_field.text
	var start_pos = _active_mention_query_info.get("start_pos", -1)
	var end_pos = _active_mention_query_info.get("end_pos", -1)

	if start_pos >= 0 and end_pos >= start_pos and end_pos <= text.length():
		var new_text = text.substr(0, start_pos) + insert_text + text.substr(end_pos)
		input_field.text = new_text
		var new_caret_pos = start_pos + insert_text.length()
		_set_input_caret_position(new_text, new_caret_pos)

	_active_mention_suggestions.clear()
	_active_mention_query_info.clear()
	if mention_container:
		mention_container.visible = false
	input_field.grab_focus()

func _set_input_caret_position(text: String, new_caret_pos: int) -> void:
	var current_pos = 0
	var target_line = 0
	var target_col = 0
	var lines = text.split("\n")
	for i in range(lines.size()):
		var l_len = lines[i].length()
		if current_pos + l_len >= new_caret_pos:
			target_line = i
			target_col = new_caret_pos - current_pos
			break
		current_pos += l_len + 1
	input_field.set_caret_line(target_line)
	input_field.set_caret_column(target_col)
