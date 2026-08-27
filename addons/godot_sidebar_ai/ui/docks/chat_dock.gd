@tool
extends Control

## Godot AI Sidebar - Profesyonel AI IDE Sohbet ve Orkestrasyon Paneli (SRP).
## Cursor / Claude Code tarzı doğal konuşma, katlanabilir aktivite kartları, diff ve geri alma sunar.

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarChangeSetDialog = preload("res://addons/godot_sidebar_ai/ui/dialogs/change_set_dialog.gd")
const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")

# Modüler UI Bileşenleri
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarChangesCard = preload("res://addons/godot_sidebar_ai/ui/components/changes_card.gd")
const AISidebarApprovalCard = preload("res://addons/godot_sidebar_ai/ui/components/approval_card.gd")
const AISidebarRuntimeCard = preload("res://addons/godot_sidebar_ai/ui/components/runtime_card.gd")
const AISidebarTelemetryCard = preload("res://addons/godot_sidebar_ai/ui/components/telemetry_card.gd")
const AISidebarErrorCard = preload("res://addons/godot_sidebar_ai/ui/components/error_card.gd")
const AISidebarClarificationCard = preload("res://addons/godot_sidebar_ai/ui/components/clarification_card.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")
const AISidebarMentionManager = preload("res://addons/godot_sidebar_ai/core/chat/mention_manager.gd")

@onready var title_label: Label = $MainLayout/HeaderBar/TitleLabel
@onready var status_badge: Label = $MainLayout/HeaderBar/StatusBadge
@onready var export_btn: Button = $MainLayout/HeaderBar/ExportBtn
@onready var lang_toggle_btn: Button = $MainLayout/HeaderBar/LangToggleBtn
@onready var model_selector: OptionButton = $MainLayout/ModelBar/ModelSelector
@onready var refresh_models_btn: Button = $MainLayout/ModelBar/RefreshModelsBtn
@onready var settings_btn: Button = $MainLayout/ModelBar/SettingsBtn

@onready var chat_scroll: ScrollContainer = $MainLayout/ChatScroll
@onready var message_stream: VBoxContainer = $MainLayout/ChatScroll/MessageStream
@onready var jump_to_bottom_btn: Button = $MainLayout/InputArea/ButtonsBar/JumpToBottomBtn

@onready var mention_container: PanelContainer = $MainLayout/InputArea/MentionContainer
@onready var mention_list: ItemList = $MainLayout/InputArea/MentionContainer/MentionList
@onready var input_field: TextEdit = $MainLayout/InputArea/InputField
@onready var clear_btn: Button = $MainLayout/InputArea/ButtonsBar/ClearBtn
@onready var send_btn: Button = $MainLayout/InputArea/ButtonsBar/SendBtn

@onready var settings_dialog: AcceptDialog = $SettingsDialog
@onready var change_set_dialog: AISidebarChangeSetDialog = $ChangeSetDialog

var network_manager: AISidebarNetworkManager
var provider: AISidebarAIProvider
var agent_context: AISidebarAgentContext
var agent_runner: AISidebarAgentRunner

var current_model_list: Array = []
var pending_change_set: AISidebarChangeSet = null
var last_applied_change_set: AISidebarChangeSet = null
var pending_tool_name: String = ""
var pending_tool_args: Dictionary = {}
var last_user_prompt: String = ""

# Kuyruktaki Mesajlar (FIFO Message Queue)
var _message_queue: Array[Dictionary] = []
var _is_user_stopped: bool = false
var _queue_container: PanelContainer = null
var _queue_title_label: Label = null
var _queue_items_vbox: VBoxContainer = null
var _queue_clear_btn: Button = null

var _current_activity_group: AISidebarActivityGroup = null
var _current_runtime_card: AISidebarRuntimeCard = null
var _current_approval_card: AISidebarApprovalCard = null
var _current_assistant_bubble: AISidebarMessageBubble = null
var _auto_scroll_enabled: bool = true

var _active_mention_suggestions: Array[Dictionary] = []
var _active_mention_query_info: Dictionary = {}

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
		
	# 1. Katmanların Başlatılması
	network_manager = AISidebarNetworkManager.new()
	add_child(network_manager)
	
	provider = AISidebarOpenAICompatibleProvider.new(network_manager)
	agent_context = AISidebarAgentContext.new()
	agent_runner = AISidebarAgentRunner.new(provider, agent_context)
	
	# Sinyal Bağlantıları
	agent_runner.state_changed.connect(_on_agent_state_changed)
	agent_runner.thinking_received.connect(_on_agent_thinking_received)
	agent_runner.chunk_received.connect(_on_agent_chunk_received)
	agent_runner.text_received.connect(_on_agent_text_received)
	agent_runner.tool_executing.connect(_on_agent_tool_executing)
	agent_runner.tool_completed.connect(_on_agent_tool_completed)
	agent_runner.approval_requested.connect(_on_agent_approval_requested)
	agent_runner.clarification_requested.connect(_on_agent_clarification_requested)
	agent_runner.changes_applied.connect(_on_agent_changes_applied)
	agent_runner.verification_started.connect(_on_agent_verification_started)
	agent_runner.verification_completed.connect(_on_agent_verification_completed)
	agent_runner.runtime_observation_received.connect(_on_agent_runtime_observation)
	agent_runner.debugging_started.connect(_on_agent_debugging_started)
	agent_runner.error_occurred.connect(_on_agent_error)
	agent_runner.task_completed.connect(_on_agent_task_completed)
	agent_runner.step_progress.connect(_on_agent_step_progress)
	provider.models_fetched.connect(_on_models_fetched)

	# 2. UI Olayları
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_pressed)
	if send_btn:
		send_btn.pressed.connect(_on_send_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if refresh_models_btn:
		refresh_models_btn.pressed.connect(_on_refresh_models_pressed)
	if lang_toggle_btn:
		lang_toggle_btn.pressed.connect(_on_lang_toggle_pressed)
	if export_btn:
		export_btn.pressed.connect(_on_export_pressed)
	if input_field:
		input_field.gui_input.connect(_on_input_gui_input)
		input_field.text_changed.connect(_on_input_text_changed)
	if mention_list:
		mention_list.item_activated.connect(_on_mention_item_activated)
	if mention_container:
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
		style.border_color = Color(0.3, 0.45, 0.65, 0.8)
		style.set_border_width_all(1)
		style.content_margin_left = 4
		style.content_margin_top = 4
		style.content_margin_right = 4
		style.content_margin_bottom = 4
		mention_container.add_theme_stylebox_override("panel", style)
	if model_selector:
		model_selector.item_selected.connect(_on_model_selected)
	if settings_dialog:
		settings_dialog.settings_saved.connect(_on_settings_saved)
	if jump_to_bottom_btn:
		jump_to_bottom_btn.pressed.connect(_on_jump_to_bottom_pressed)
	if chat_scroll:
		var v_bar = chat_scroll.get_v_scroll_bar()
		if v_bar:
			v_bar.value_changed.connect(_on_scroll_value_changed)

	mouse_filter = Control.MOUSE_FILTER_PASS
	if has_node("MainLayout"):
		$MainLayout.mouse_filter = Control.MOUSE_FILTER_PASS
	if chat_scroll:
		chat_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	if message_stream:
		message_stream.mouse_filter = Control.MOUSE_FILTER_PASS

	_setup_queue_ui()

	# 3. Başlangıç Yüklemesi
	update_ui_language()
	_load_cached_models()
	if provider:
		provider.fetch_models()

func _setup_queue_ui() -> void:
	if not has_node("MainLayout/InputArea"):
		return
	var input_area = $MainLayout/InputArea
	
	_queue_container = PanelContainer.new()
	_queue_container.visible = false
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.bg_color = Color(0.14, 0.16, 0.22, 0.95)
	style.border_color = Color(0.35, 0.45, 0.6, 0.7)
	style.set_border_width_all(1)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	_queue_container.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	
	var header = HBoxContainer.new()
	_queue_title_label = Label.new()
	_queue_title_label.text = "📋 Queued Messages (0)"
	_queue_title_label.add_theme_font_size_override("font_size", 10)
	_queue_title_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	header.add_child(_queue_title_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	_queue_clear_btn = Button.new()
	_queue_clear_btn.text = "Clear All"
	_queue_clear_btn.flat = true
	_queue_clear_btn.focus_mode = Control.FOCUS_NONE
	_queue_clear_btn.add_theme_font_size_override("font_size", 9)
	_queue_clear_btn.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
	_queue_clear_btn.pressed.connect(_clear_all_queue)
	header.add_child(_queue_clear_btn)
	vbox.add_child(header)
	
	_queue_items_vbox = VBoxContainer.new()
	_queue_items_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_queue_items_vbox)
	
	_queue_container.add_child(vbox)
	input_area.add_child(_queue_container)
	input_area.move_child(_queue_container, 0)

func update_ui_language() -> void:
	var current_lang = AISidebarI18n.get_current_language().to_upper()
	if lang_toggle_btn:
		lang_toggle_btn.text = current_lang
		lang_toggle_btn.tooltip_text = AISidebarI18n.get_text("tooltip_lang")
	if export_btn:
		AISidebarIconHelper.apply_icon(export_btn, "download")
		export_btn.tooltip_text = "Sohbeti Dışa Aktar / Kopyala (Export Chat)"
		
	if title_label:
		title_label.text = AISidebarI18n.get_text("app_title")
	if model_selector:
		model_selector.tooltip_text = AISidebarI18n.get_text("tooltip_model")
	if refresh_models_btn:
		refresh_models_btn.tooltip_text = AISidebarI18n.get_text("tooltip_refresh")
		AISidebarIconHelper.apply_icon(refresh_models_btn, "refresh")
	if settings_btn:
		settings_btn.tooltip_text = AISidebarI18n.get_text("tooltip_settings")
		AISidebarIconHelper.apply_icon(settings_btn, "settings")
	if input_field:
		input_field.placeholder_text = AISidebarI18n.get_text("input_placeholder")
	if clear_btn:
		clear_btn.text = AISidebarI18n.get_text("btn_clear")
		AISidebarIconHelper.apply_icon(clear_btn, "trash")
		
	if send_btn:
		if agent_runner and agent_runner.is_running():
			send_btn.text = "Stop"
			AISidebarIconHelper.apply_icon(send_btn, "stop")
			send_btn.tooltip_text = "Görevi Durdur"
		else:
			send_btn.text = "Send"
			AISidebarIconHelper.apply_icon(send_btn, "send")
			send_btn.tooltip_text = ""

func _on_export_pressed() -> void:
	var msgs: Array = []
	if agent_context:
		msgs = agent_context.messages
		
	if msgs.is_empty():
		return
		
	var cfg = AISidebarConfig.load_config()
	var session_meta = {
		"model": cfg.get("selected_model", "all"),
		"exported_at": Time.get_datetime_string_from_system()
	}
	var md = AISidebarChatExporter.export_to_markdown(msgs, session_meta)
	DisplayServer.clipboard_set(md)
	var save_res = AISidebarChatExporter.save_to_file(md, "md")
	
	if export_btn:
		AISidebarIconHelper.apply_icon(export_btn, "check")
		var t = get_tree()
		if t:
			var timer = t.create_timer(1.5)
			timer.timeout.connect(func():
				if is_instance_valid(export_btn):
					AISidebarIconHelper.apply_icon(export_btn, "download")
			)
			
	if status_badge:
		var prev = status_badge.text
		status_badge.text = "Exported ✓"
		var t = get_tree()
		if t:
			var timer = t.create_timer(2.0)
			timer.timeout.connect(func():
				if is_instance_valid(status_badge):
					status_badge.text = prev
			)

func _load_cached_models() -> void:
	var cfg = AISidebarConfig.load_config()
	var cached: Array = cfg.get("cached_models", ["all", "free"])
	_populate_model_selector(cached)

func _populate_model_selector(models: Array) -> void:
	if not model_selector:
		return
		
	current_model_list = models
	model_selector.clear()
	
	var cfg = AISidebarConfig.load_config()
	var selected_model = cfg.get("selected_model", "all")
	var selected_idx = 0
	
	for i in range(models.size()):
		var m_name = str(models[i])
		model_selector.add_item(m_name, i)
		if m_name == selected_model:
			selected_idx = i
			
	if model_selector.item_count > 0:
		model_selector.selected = selected_idx

func _on_models_fetched(models: Array) -> void:
	var cfg = AISidebarConfig.load_config()
	cfg["cached_models"] = models
	AISidebarConfig.save_config(cfg)
	
	_populate_model_selector(models)
	set_status_badge("Ready", Color(0.4, 0.8, 0.4))

func _on_refresh_models_pressed() -> void:
	if provider:
		set_status_badge("Refreshing...", Color(1.0, 0.8, 0.2))
		provider.fetch_models()

func _on_settings_pressed() -> void:
	if settings_dialog:
		settings_dialog.open_settings()

func _on_settings_saved() -> void:
	update_ui_language()
	if provider:
		provider.fetch_models()

func _on_lang_toggle_pressed() -> void:
	AISidebarI18n.toggle_language()
	update_ui_language()

func _on_model_selected(index: int) -> void:
	if index >= 0 and index < current_model_list.size():
		var chosen = current_model_list[index]
		var cfg = AISidebarConfig.load_config()
		cfg["selected_model"] = chosen
		AISidebarConfig.save_config(cfg)

func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var is_enter = (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)
		
		# Mention Açıkken Klavye Navigasyonu
		if mention_container and mention_container.visible:
			if event.keycode == KEY_ESCAPE:
				accept_event()
				mention_container.visible = false
				return
			elif event.keycode == KEY_DOWN:
				accept_event()
				_navigate_mention_list(1)
				return
			elif event.keycode == KEY_UP:
				accept_event()
				_navigate_mention_list(-1)
				return
			elif event.keycode == KEY_TAB or (is_enter and not (event.ctrl_pressed or event.shift_pressed)):
				var sel = mention_list.get_selected_items()
				if sel.size() > 0:
					accept_event()
					_on_mention_item_activated(sel[0])
					return
			elif is_enter and event.shift_pressed:
				accept_event()
				mention_container.visible = false
				input_field.insert_text_at_caret("\n")
				return
				
		# Enter ve Shift+Enter / Ctrl+Enter Yönetimi
		if is_enter:
			if event.shift_pressed:
				# Shift+Enter -> Yeni satır (Multiline)
				accept_event()
				input_field.insert_text_at_caret("\n")
			elif not event.alt_pressed:
				# Enter veya Ctrl+Enter -> Mesajı Gönder veya Kuyruğa Al
				accept_event()
				_on_send_pressed()

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

func _on_mention_item_activated(index: int) -> void:
	if index < 0 or index >= _active_mention_suggestions.size() or not input_field:
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
		var current_pos = 0
		var target_line = 0
		var target_col = 0
		var lines = new_text.split("\n")
		for i in range(lines.size()):
			var l_len = lines[i].length()
			if current_pos + l_len >= new_caret_pos:
				target_line = i
				target_col = new_caret_pos - current_pos
				break
			current_pos += l_len + 1
		input_field.set_caret_line(target_line)
		input_field.set_caret_column(target_col)
		
	if mention_container:
		mention_container.visible = false
	input_field.grab_focus()

func _on_send_pressed() -> void:
	if not agent_runner:
		return
		
	if mention_container:
		mention_container.visible = false
		
	var user_text = input_field.text.strip_edges()
	
	# Eğer metin boşsa ve kullanıcı 'Stop' butonuna bastıysa:
	if user_text.is_empty():
		if agent_runner.is_running():
			_is_user_stopped = true
			agent_runner.stop()
			update_ui_language()
		return
		
	input_field.text = ""
	_is_user_stopped = false
	
	# Eğer ajan şu anda başka bir görev çalıştırıyorsa -> Mesajı Kuyruğa Al
	if agent_runner.is_running():
		var queue_item = {
			"id": "q_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000),
			"prompt": user_text,
			"created_at": Time.get_unix_time_from_system()
		}
		_message_queue.append(queue_item)
		_update_queue_ui()
		return
		
	# Ajan boşta ise görevi hemen başlat
	_start_task_prompt(user_text)

func _start_task_prompt(prompt_text: String) -> void:
	last_user_prompt = prompt_text
	_current_activity_group = null
	_current_runtime_card = null
	_current_approval_card = null
	_is_user_stopped = false
	
	var resolved_ctx = AISidebarMentionManager.resolve_prompt_context(prompt_text)
	agent_runner.start_task(resolved_ctx["augmented_prompt"], prompt_text)

func _update_queue_ui() -> void:
	if not _queue_container or not _queue_items_vbox:
		return
		
	for child in _queue_items_vbox.get_children():
		child.queue_free()
		
	if _message_queue.is_empty():
		_queue_container.visible = false
		return
		
	_queue_container.visible = true
	if _queue_title_label:
		_queue_title_label.text = "📋 Queued Messages (%d)" % _message_queue.size()
		
	for i in range(_message_queue.size()):
		var item = _message_queue[i]
		var item_row = HBoxContainer.new()
		item_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var num_label = Label.new()
		num_label.text = str(i + 1) + "."
		num_label.add_theme_font_size_override("font_size", 10)
		num_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		item_row.add_child(num_label)
		
		var prompt_label = Label.new()
		prompt_label.text = str(item.get("prompt", "")).replace("\n", " ")
		prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prompt_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		prompt_label.clip_text = true
		prompt_label.add_theme_font_size_override("font_size", 10)
		item_row.add_child(prompt_label)
		
		var cancel_btn = Button.new()
		cancel_btn.text = "✕"
		cancel_btn.flat = true
		cancel_btn.focus_mode = Control.FOCUS_NONE
		cancel_btn.add_theme_font_size_override("font_size", 10)
		cancel_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		cancel_btn.tooltip_text = "Bu sıradaki mesajı iptal et"
		var item_id = item.get("id", "")
		cancel_btn.pressed.connect(func(): _cancel_queued_message(item_id))
		item_row.add_child(cancel_btn)
		
		_queue_items_vbox.add_child(item_row)

func _cancel_queued_message(item_id: String) -> void:
	for i in range(_message_queue.size()):
		if _message_queue[i].get("id", "") == item_id:
			_message_queue.remove_at(i)
			break
	_update_queue_ui()

func _clear_all_queue() -> void:
	_message_queue.clear()
	_update_queue_ui()

func _check_and_dispatch_next_queue() -> void:
	if _is_user_stopped:
		return
		
	if _message_queue.size() > 0:
		var next_item = _message_queue.pop_front()
		_update_queue_ui()
		if next_item is Dictionary and next_item.has("prompt"):
			var next_prompt = str(next_item["prompt"])
			var t = get_tree()
			if t:
				t.create_timer(0.05).timeout.connect(func():
					_start_task_prompt(next_prompt)
				)
			else:
				_start_task_prompt(next_prompt)

func _on_clear_pressed() -> void:
	if mention_container:
		mention_container.visible = false
	if agent_runner and agent_runner.is_running():
		_is_user_stopped = true
		agent_runner.stop()
	if agent_context:
		agent_context.clear()
	_message_queue.clear()
	_update_queue_ui()
	if message_stream:
		for child in message_stream.get_children():
			child.queue_free()
	_current_activity_group = null
	_current_runtime_card = null
	_current_approval_card = null

func _on_jump_to_bottom_pressed() -> void:
	_scroll_to_bottom()
	if jump_to_bottom_btn:
		jump_to_bottom_btn.visible = false

func _on_scroll_value_changed(val: float) -> void:
	if not chat_scroll:
		return
	var v_bar = chat_scroll.get_v_scroll_bar()
	if not v_bar:
		return
	var max_val = v_bar.max_value - v_bar.page
	var is_near_bottom = (max_val - val) < 40.0
	_auto_scroll_enabled = is_near_bottom
	if jump_to_bottom_btn:
		jump_to_bottom_btn.visible = not is_near_bottom

func _scroll_to_bottom() -> void:
	if not chat_scroll:
		return
	chat_scroll.set_deferred("scroll_vertical", 999999)

func _add_stream_component(comp: Control) -> void:
	if not message_stream:
		return
	message_stream.add_child(comp)
	if _auto_scroll_enabled:
		_scroll_to_bottom()

# --- Ajan Sinyal Dinleyicileri (Presentation) ---

func _on_agent_state_changed(new_state: AISidebarAgentRunner.AgentState, state_desc: String) -> void:
	update_ui_language()
	match new_state:
		AISidebarAgentRunner.AgentState.IDLE, AISidebarAgentRunner.AgentState.COMPLETED:
			set_status_badge(state_desc, Color(0.4, 0.8, 0.4))
		AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL:
			set_status_badge("⏳ Waiting Approval", Color(1.0, 0.5, 0.2))
		AISidebarAgentRunner.AgentState.RUNNING_GAME:
			set_status_badge("▶ Running Game", Color(0.3, 0.7, 1.0))
		AISidebarAgentRunner.AgentState.DEBUGGING:
			set_status_badge("🐞 Debugging", Color(1.0, 0.4, 0.4))
		AISidebarAgentRunner.AgentState.ERROR:
			set_status_badge("❌ " + state_desc, Color(1.0, 0.3, 0.3))
		_:
			set_status_badge("⚡ " + state_desc, Color(1.0, 0.8, 0.2))

func _on_agent_thinking_received(thinking: String) -> void:
	pass

func _on_agent_chunk_received(text_delta: String, thinking_delta: String) -> void:
	if not text_delta.is_empty():
		if _current_activity_group:
			_current_activity_group.complete_group()
			_current_activity_group = null
			
		if _current_assistant_bubble == null or not is_instance_valid(_current_assistant_bubble):
			_current_assistant_bubble = AISidebarMessageBubble.new("assistant", "")
			_current_assistant_bubble.meta_clicked.connect(_on_meta_clicked)
			_add_stream_component(_current_assistant_bubble)
			
		_current_assistant_bubble.append_text(text_delta)
		set_status_badge("⚡ AI Typing...", Color(1.0, 0.8, 0.2))
		if _auto_scroll_enabled:
			_scroll_to_bottom()

func _on_agent_text_received(role: String, text: String) -> void:
	if _current_activity_group:
		_current_activity_group.complete_group()
		_current_activity_group = null
		
	if role == "assistant":
		if _current_assistant_bubble != null and is_instance_valid(_current_assistant_bubble):
			_current_assistant_bubble.finalize_stream(text)
			_current_assistant_bubble = null
		else:
			var bubble = AISidebarMessageBubble.new(role, text)
			bubble.meta_clicked.connect(_on_meta_clicked)
			_add_stream_component(bubble)
	else:
		_current_assistant_bubble = null
		var bubble = AISidebarMessageBubble.new(role, text)
		bubble.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(bubble)

func _ensure_activity_group() -> AISidebarActivityGroup:
	if not _current_activity_group:
		_current_activity_group = AISidebarActivityGroup.new(true)
		_current_activity_group.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(_current_activity_group)
	return _current_activity_group

func _on_agent_tool_executing(tool_name: String, args: Dictionary) -> void:
	_current_assistant_bubble = null
	var grp = _ensure_activity_group()
	var human_title = _get_human_tool_title(tool_name, args)
	grp.add_activity("▶", human_title, -1, JSON.stringify(args))

func _on_agent_tool_completed(tool_name: String, result: Dictionary) -> void:
	var grp = _ensure_activity_group()
	var is_ok = result.get("success", false)
	var icon = "✓" if is_ok else "❌"
	var human_title = _get_human_tool_title(tool_name, {})
	var msg = result.get("message", "")
	if not msg.is_empty():
		human_title = msg
	grp.add_activity(icon, human_title, 100, JSON.stringify(result))

func _get_human_tool_title(tool_name: String, args: Dictionary) -> String:
	match tool_name:
		"create_or_update_script":
			var p = args.get("file_path", "")
			return "Updated " + p.get_file() if not p.is_empty() else "Updated script"
		"write_files":
			var f_arr = args.get("files", [])
			return "Batch wrote " + str(f_arr.size()) + " files"
		"create_scene":
			var sp = args.get("scene_path", "")
			return "Created scene " + sp.get_file()
		"save_scene":
			return "Saved active scene"
		"analyze_project":
			return "Inspected project structure"
		"get_project_files":
			return "Scanned project files"
		"read_script":
			return "Read script: " + args.get("file_path", "").get_file()
		"validate_script":
			return "Validated GDScript source"
		"play_game":
			return "Launched game instance"
		"stop_game":
			return "Stopped running game"
		"get_runtime_errors":
			return "Checked runtime logs"
		"delete_node":
			return "Deleted node: " + args.get("node_path", "")
		_:
			return tool_name

func _on_agent_clarification_requested(question: String, options: Array, clarification_id: String) -> void:
	_current_assistant_bubble = null
	if _current_activity_group:
		_current_activity_group.complete_group()
		_current_activity_group = null
		
	var card = AISidebarClarificationCard.new(question, options)
	card.response_submitted.connect(func(ans: String):
		if agent_runner:
			agent_runner.submit_clarification_response(ans)
	)
	_add_stream_component(card)
	if _auto_scroll_enabled:
		_scroll_to_bottom()
	update_ui_language()

func _on_agent_approval_requested(tool_name: String, args: Dictionary, cs: AISidebarChangeSet) -> void:
	# Duplicate approval request deduping: Aynı bekleyen işlem için ikinci kart oluşturma
	if _current_approval_card != null and is_instance_valid(_current_approval_card) and not _current_approval_card.is_resolved:
		if pending_tool_name == tool_name and pending_tool_args == args:
			return
			
	pending_tool_name = tool_name
	pending_tool_args = args
	pending_change_set = cs
	
	_current_approval_card = AISidebarApprovalCard.new(tool_name, args, cs)
	_current_approval_card.action_approved.connect(_on_approve_pressed)
	_current_approval_card.action_rejected.connect(_on_reject_pressed)
	_current_approval_card.view_diff_requested.connect(_on_view_diff_pressed)
	_add_stream_component(_current_approval_card)
	# NOT: change_set_dialog otomatik AÇILMAZ; yalnızca kullanıcı karttaki [View Diff] butonuna basarsa açılır.

func _on_approve_pressed() -> void:
	if _current_approval_card and is_instance_valid(_current_approval_card):
		_current_approval_card.mark_approved()
	if pending_change_set:
		last_applied_change_set = pending_change_set
	if agent_runner:
		agent_runner.approve_pending_action()

func _on_reject_pressed() -> void:
	if _current_approval_card and is_instance_valid(_current_approval_card):
		_current_approval_card.mark_rejected()
	if agent_runner:
		agent_runner.reject_pending_action()

func _on_view_diff_pressed(cs: AISidebarChangeSet = null) -> void:
	var cs_to_show = cs if cs else (pending_change_set if pending_change_set else last_applied_change_set)
	if change_set_dialog:
		change_set_dialog.show_change_set(pending_tool_name, pending_tool_args, cs_to_show)

func _on_agent_changes_applied(cs: AISidebarChangeSet) -> void:
	last_applied_change_set = cs
	if not cs:
		return
	var card = AISidebarChangesCard.new(cs)
	card.view_diff_requested.connect(func(c): _on_view_diff_pressed(c))
	card.undo_requested.connect(func(c): _on_undo_pressed(c))
	card.meta_clicked.connect(_on_meta_clicked)
	_add_stream_component(card)

func _on_undo_pressed(cs: AISidebarChangeSet) -> void:
	if cs:
		var res = cs.rollback()
		var grp = _ensure_activity_group()
		if res.get("success", false):
			grp.add_activity("↩", "Undo successful: changes reverted", 50)
		else:
			grp.add_activity("❌", "Undo failed: " + res.get("error", "Error"), 50)

func _on_agent_verification_started(tool_name: String) -> void:
	var grp = _ensure_activity_group()
	grp.add_activity("🔍", "Verifying " + tool_name + "...", -1)

func _on_agent_verification_completed(tool_name: String, is_valid: bool, msg: String) -> void:
	var grp = _ensure_activity_group()
	var icon = "✓" if is_valid else "⚠️"
	grp.add_activity(icon, "Verification: " + msg, 50)

func _on_agent_runtime_observation(obs: AISidebarRuntimeObservation) -> void:
	if not _current_runtime_card:
		_current_runtime_card = AISidebarRuntimeCard.new()
		_current_runtime_card.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(_current_runtime_card)
		
	if obs.has_errors():
		_current_runtime_card.add_status("❌", "Runtime Error: " + obs.format_diagnostic_prompt(), "#bf616a")
	else:
		_current_runtime_card.add_status("✓", "No runtime errors detected", "#a3be8c")

func _on_agent_debugging_started(summary: String) -> void:
	var grp = _ensure_activity_group()
	grp.add_activity("🐞", "Auto-diagnosing runtime error: " + summary, -1)

func _on_agent_step_progress(current_step: int, max_steps: int) -> void:
	set_status_badge("⚡ Agent Step " + str(current_step) + " / " + str(max_steps), Color(1.0, 0.8, 0.2))

func _on_agent_task_completed(metrics: Dictionary) -> void:
	_current_assistant_bubble = null
	if _current_activity_group:
		_current_activity_group.complete_group()
		_current_activity_group = null
		
	var telemetry_comp = AISidebarTelemetryCard.new(metrics)
	_add_stream_component(telemetry_comp)
	update_ui_language()
	
	_check_and_dispatch_next_queue()

func _on_agent_error(err_msg: String) -> void:
	_current_assistant_bubble = null
	if _current_activity_group:
		_current_activity_group.complete_group()
		_current_activity_group = null
		
	var err_comp = AISidebarErrorCard.new(err_msg)
	err_comp.retry_requested.connect(func():
		if not last_user_prompt.is_empty():
			agent_runner.start_task(last_user_prompt)
	)
	_add_stream_component(err_comp)
	update_ui_language()
	
	_check_and_dispatch_next_queue()

func _on_meta_clicked(meta: Variant) -> void:
	var m_str = str(meta)
	if m_str.begins_with("file:"):
		var fpath = m_str.trim_prefix("file:")
		if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
			if fpath.ends_with(".gd"):
				var res = load(fpath)
				if res is Script and EditorInterface.has_method("edit_script"):
					EditorInterface.edit_script(res)
			elif fpath.ends_with(".tscn"):
				if EditorInterface.has_method("open_scene_from_path"):
					EditorInterface.open_scene_from_path(fpath)

func set_status_badge(txt: String, color: Color) -> void:
	if status_badge:
		status_badge.text = txt
		status_badge.add_theme_color_override("font_color", color)
