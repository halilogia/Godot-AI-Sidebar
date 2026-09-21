@tool
extends PanelContainer
class_name AISidebarHistoryPanel

## Geçmiş Sohbetleri Listeleme ve Yönetme Paneli (History Drawer / Panel) (SRP).
## Merkezi AISidebarTheme sistemiyle tasarlanmış modern, kaydırılabilir geçmiş paneli.

signal session_selected(session_id: String)
signal new_chat_requested()
signal session_deleted(session_id: String)
signal session_renamed(session_id: String, new_title: String)
signal close_requested()

const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

var active_session_id: String = ""

var _search_input: LineEdit
var _items_vbox: VBoxContainer
var _all_sessions: Array[Dictionary] = []

# Dialoglar
var _delete_dialog: ConfirmationDialog
var _session_to_delete: String = ""

var _rename_dialog: ConfirmationDialog
var _rename_input: LineEdit
var _session_to_rename: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	_setup_ui()
	_setup_dialogs()

func _ready() -> void:
	refresh_list()

func _setup_ui() -> void:
	# Arka plan ve kenarlıklar (AISidebarTheme standardı)
	var style = StyleBoxFlat.new()
	style.bg_color = AISidebarTheme.COLOR_BG_APP
	style.border_color = AISidebarTheme.COLOR_BORDER_SUBTLE
	style.set_border_width_all(1)
	style.set_corner_radius_all(AISidebarTheme.RADIUS_MD)
	style.content_margin_left = AISidebarTheme.SPACE_SM
	style.content_margin_right = AISidebarTheme.SPACE_SM
	style.content_margin_top = AISidebarTheme.SPACE_SM
	style.content_margin_bottom = AISidebarTheme.SPACE_SM
	add_theme_stylebox_override("panel", style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_SM)
	add_child(main_vbox)
	
	# 1. Başlık Çubuğu
	var header_hbox = HBoxContainer.new()
	header_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	header_hbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	
	var title_lbl = Label.new()
	title_lbl.text = AISidebarI18n.get_text("history_title")
	title_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SUBHEADER)
	title_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	title_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)
	
	var new_btn = Button.new()
	new_btn.text = AISidebarI18n.get_text("history_btn_new")
	new_btn.tooltip_text = AISidebarI18n.get_text("history_btn_new")
	new_btn.flat = true
	new_btn.focus_mode = FOCUS_NONE
	new_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	new_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_ACCENT)
	new_btn.pressed.connect(func(): new_chat_requested.emit())
	header_hbox.add_child(new_btn)
	
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.tooltip_text = AISidebarI18n.get_text("history_btn_close_tooltip")
	close_btn.flat = true
	close_btn.focus_mode = FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
	close_btn.pressed.connect(func(): close_requested.emit())
	header_hbox.add_child(close_btn)
	
	main_vbox.add_child(header_hbox)
	
	# 2. Arama Girişi (AISidebarTheme input stili)
	_search_input = LineEdit.new()
	_search_input.placeholder_text = AISidebarI18n.get_text("history_search_placeholder")
	_search_input.clear_button_enabled = true
	_search_input.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
	_search_input.add_theme_stylebox_override("normal", AISidebarTheme.create_input_style())
	_search_input.text_changed.connect(_on_search_text_changed)
	main_vbox.add_child(_search_input)
	
	# 3. Kaydırılabilir Sohbet Listesi
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	_items_vbox = VBoxContainer.new()
	_items_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	_items_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	_items_vbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	scroll.add_child(_items_vbox)
	
	main_vbox.add_child(scroll)

func _setup_dialogs() -> void:
	# Silme Onay Dialogu
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = AISidebarI18n.get_text("history_delete_title")
	_delete_dialog.dialog_text = AISidebarI18n.get_text("history_delete_prompt")
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_dialog)
	
	# Yeniden Adlandırma Dialogu
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = AISidebarI18n.get_text("history_rename_title")
	var dlg_vbox = VBoxContainer.new()
	var dlg_lbl = Label.new()
	dlg_lbl.text = AISidebarI18n.get_text("history_rename_prompt")
	dlg_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
	dlg_vbox.add_child(dlg_lbl)
	
	_rename_input = LineEdit.new()
	_rename_input.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
	_rename_input.add_theme_stylebox_override("normal", AISidebarTheme.create_input_style())
	dlg_vbox.add_child(_rename_input)
	_rename_dialog.add_child(dlg_vbox)
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)

func set_active_session(p_id: String) -> void:
	active_session_id = p_id
	_render_items()

func refresh_list() -> void:
	_all_sessions = AISidebarChatManager.list_sessions()
	_render_items()

func _on_search_text_changed(_query: String) -> void:
	_render_items()

func _render_items() -> void:
	if not _items_vbox:
		return
		
	for c in _items_vbox.get_children():
		_items_vbox.remove_child(c)
		c.queue_free()
		
	var query = _search_input.text.strip_edges().to_lower() if _search_input else ""
	var filtered: Array[Dictionary] = []
	for s in _all_sessions:
		var title = s.get("title", "").to_lower()
		var dt = s.get("updated_at", "").to_lower()
		if query.is_empty() or query in title or query in dt:
			filtered.append(s)
			
	if filtered.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = AISidebarI18n.get_text("history_empty") if query.is_empty() else AISidebarI18n.get_text("history_not_found")
		empty_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
		empty_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_items_vbox.add_child(empty_lbl)
		return
		
	for s in filtered:
		var sid = s.get("id", "")
		var is_active = (sid == active_session_id)
		var item_card = _build_session_card(s, is_active)
		_items_vbox.add_child(item_card)

func _build_session_card(s: Dictionary, is_active: bool) -> PanelContainer:
	var sid = s.get("id", "")
	var card = PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.custom_minimum_size = Vector2(0, 42)
	
	card.add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(is_active, AISidebarTheme.SPACE_SM))
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.size_flags_vertical = SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_SM)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(hbox)
	
	# Aktiflik göstergesi (Subtle Accent Bar)
	var bar = Panel.new()
	bar.custom_minimum_size = Vector2(3, 0)
	bar.size_flags_vertical = SIZE_EXPAND_FILL
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = AISidebarTheme.COLOR_ACCENT if is_active else Color.TRANSPARENT
	bar_style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(bar)
	
	# Başlık ve Tarih Bilgisi (SRP: Container doğrudan HBox içinde)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var title_lbl = Label.new()
	title_lbl.text = s.get("title", "Untitled")
	title_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
	title_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY if is_active else AISidebarTheme.COLOR_TEXT_SECONDARY)
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(title_lbl)
	
	var meta_lbl = Label.new()
	var dt_str = s.get("updated_at", "")
	dt_str = dt_str.replace("T", " ").left(16)
	meta_lbl.text = "%s • %d msgs" % [dt_str, s.get("message_count", 0)]
	meta_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
	meta_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_MICRO)
	meta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(meta_lbl)
	
	hbox.add_child(info_vbox)
	
	# Aksiyon Butonları (Yeniden Adlandır / Sil)
	var actions_hbox = HBoxContainer.new()
	actions_hbox.size_flags_vertical = SIZE_SHRINK_CENTER
	actions_hbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XXS)
	
	# Yeniden Adlandırma Butonu
	var ren_btn = Button.new()
	ren_btn.flat = true
	ren_btn.tooltip_text = AISidebarI18n.get_text("history_tooltip_rename")
	ren_btn.focus_mode = FOCUS_NONE
	ren_btn.custom_minimum_size = Vector2(24, 24)
	AISidebarIconHelper.apply_icon(ren_btn, "edit")
	if not ren_btn.icon:
		ren_btn.text = "✎"
		ren_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	ren_btn.pressed.connect(func(): _prompt_rename(sid, s.get("title", "")))
	actions_hbox.add_child(ren_btn)
	
	# Silme Butonu
	var del_btn = Button.new()
	del_btn.flat = true
	del_btn.tooltip_text = AISidebarI18n.get_text("history_tooltip_delete")
	del_btn.focus_mode = FOCUS_NONE
	del_btn.custom_minimum_size = Vector2(24, 24)
	AISidebarIconHelper.apply_icon(del_btn, "trash")
	if not del_btn.icon:
		del_btn.text = "×"
		del_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SUBHEADER)
	del_btn.pressed.connect(func(): _prompt_delete(sid))
	actions_hbox.add_child(del_btn)
	
	hbox.add_child(actions_hbox)
	
	# Kart Seçim Etkileşimi (Tıklama ile sohbeti yükle)
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			session_selected.emit(sid)
	)
	
	# Hover Efekti
	if not is_active:
		card.mouse_entered.connect(func():
			card.add_theme_stylebox_override("panel", AISidebarTheme.create_card_hover_style(AISidebarTheme.SPACE_SM))
		)
		card.mouse_exited.connect(func():
			card.add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_SM))
		)
	
	return card

func _prompt_delete(sid: String) -> void:
	_session_to_delete = sid
	if _delete_dialog:
		_delete_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	if not _session_to_delete.is_empty():
		var sid = _session_to_delete
		_session_to_delete = ""
		AISidebarChatManager.delete_session(sid)
		session_deleted.emit(sid)
		refresh_list()

func _prompt_rename(sid: String, current_title: String) -> void:
	_session_to_rename = sid
	if _rename_input:
		_rename_input.text = current_title
	if _rename_dialog:
		_rename_dialog.popup_centered()

func _on_rename_confirmed() -> void:
	if not _session_to_rename.is_empty() and _rename_input:
		var sid = _session_to_rename
		var new_title = _rename_input.text.strip_edges()
		_session_to_rename = ""
		if not new_title.is_empty():
			AISidebarChatManager.rename_session(sid, new_title)
			session_renamed.emit(sid, new_title)
			refresh_list()
