@tool
extends PanelContainer
class_name AISidebarHistoryPanel

## Geçmiş Sohbetleri Listeleme ve Yönetme Paneli (History Drawer / Panel) (SRP).
## Kullanıcının geçmiş sohbetleri filtrelemesini, açmasını, yeniden adlandırmasını ve silmesini sağlar.

signal session_selected(session_id: String)
signal new_chat_requested()
signal session_deleted(session_id: String)
signal session_renamed(session_id: String, new_title: String)
signal close_requested()

const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

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
	custom_minimum_size = Vector2(0, 200)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_FILL
	_setup_ui()
	_setup_dialogs()

func _ready() -> void:
	refresh_list()

func _setup_ui() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.16, 0.98)
	style.border_color = Color(0.24, 0.28, 0.35, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	add_child(main_vbox)
	
	# 1. Başlık Çubuğu
	var header_hbox = HBoxContainer.new()
	header_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	
	var title_lbl = Label.new()
	title_lbl.text = "📚 Chat History"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)
	
	var new_btn = Button.new()
	new_btn.text = "+ New Chat"
	new_btn.flat = true
	new_btn.focus_mode = FOCUS_NONE
	new_btn.add_theme_font_size_override("font_size", 10)
	new_btn.pressed.connect(func(): new_chat_requested.emit())
	header_hbox.add_child(new_btn)
	
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.focus_mode = FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func(): close_requested.emit())
	header_hbox.add_child(close_btn)
	
	main_vbox.add_child(header_hbox)
	
	# 2. Arama Girişi
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search past chats..."
	_search_input.clear_button_enabled = true
	_search_input.add_theme_font_size_override("font_size", 10)
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
	_items_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_items_vbox)
	
	main_vbox.add_child(scroll)

func _setup_dialogs() -> void:
	# Silme Onay Dialogu
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Delete Chat"
	_delete_dialog.dialog_text = "Bu sohbeti kalıcı olarak silmek istediğinize emin misiniz?"
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_dialog)
	
	# Yeniden Adlandırma Dialogu
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Rename Chat"
	var dlg_vbox = VBoxContainer.new()
	var dlg_lbl = Label.new()
	dlg_lbl.text = "Yeni sohbet başlığını girin:"
	dlg_lbl.add_theme_font_size_override("font_size", 11)
	dlg_vbox.add_child(dlg_lbl)
	
	_rename_input = LineEdit.new()
	_rename_input.add_theme_font_size_override("font_size", 11)
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
		empty_lbl.text = "Geçmiş sohbet bulunamadı." if query.is_empty() else "Aramaya uygun sohbet yok."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_items_vbox.add_child(empty_lbl)
		return
		
	for s in filtered:
		var sid = s.get("id", "")
		var is_active = (sid == active_session_id)
		var item_card = _build_session_card(s, is_active)
		_items_vbox.add_child(item_card)

func _build_session_card(s: Dictionary, is_active: bool) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	
	var c_style = StyleBoxFlat.new()
	if is_active:
		c_style.bg_color = Color(0.18, 0.24, 0.35, 0.9)
		c_style.border_color = Color(0.35, 0.6, 0.95, 1.0)
	else:
		c_style.bg_color = Color(0.15, 0.16, 0.19, 0.8)
		c_style.border_color = Color(0.22, 0.24, 0.28, 0.8)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(4)
	c_style.content_margin_left = 6
	c_style.content_margin_right = 6
	c_style.content_margin_top = 4
	c_style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", c_style)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 4)
	card.add_child(hbox)
	
	# Tıklanabilir İçerik Butonu (Seçim)
	var select_btn = Button.new()
	select_btn.flat = true
	select_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	select_btn.focus_mode = FOCUS_NONE
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 1)
	
	var title_lbl = Label.new()
	var prefix = "🟢 " if is_active else "💬 "
	title_lbl.text = prefix + s.get("title", "Untitled")
	title_lbl.add_theme_font_size_override("font_size", 10)
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_vbox.add_child(title_lbl)
	
	var meta_lbl = Label.new()
	var dt_str = s.get("updated_at", "")
	# Format "2026-08-27T21:05:00" -> "2026-08-27 21:05"
	dt_str = dt_str.replace("T", " ").left(16)
	meta_lbl.text = "%s • %d msgs" % [dt_str, s.get("message_count", 0)]
	meta_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	meta_lbl.add_theme_font_size_override("font_size", 8)
	info_vbox.add_child(meta_lbl)
	
	select_btn.add_child(info_vbox)
	var sid = s.get("id", "")
	select_btn.pressed.connect(func(): session_selected.emit(sid))
	hbox.add_child(select_btn)
	
	# Yeniden Adlandırma Butonu
	var ren_btn = Button.new()
	ren_btn.text = "✏️"
	ren_btn.flat = true
	ren_btn.tooltip_text = "Rename Chat"
	ren_btn.focus_mode = FOCUS_NONE
	ren_btn.add_theme_font_size_override("font_size", 9)
	ren_btn.pressed.connect(func(): _prompt_rename(sid, s.get("title", "")))
	hbox.add_child(ren_btn)
	
	# Silme Butonu
	var del_btn = Button.new()
	del_btn.text = "🗑️"
	del_btn.flat = true
	del_btn.tooltip_text = "Delete Chat"
	del_btn.focus_mode = FOCUS_NONE
	del_btn.add_theme_font_size_override("font_size", 9)
	del_btn.pressed.connect(func(): _prompt_delete(sid))
	hbox.add_child(del_btn)
	
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
