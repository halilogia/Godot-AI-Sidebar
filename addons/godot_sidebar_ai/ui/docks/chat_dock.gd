@tool
extends Control

## Godot AI Sidebar - Profesyonel AI IDE Sohbet ve Orkestrasyon Paneli (SRP).
## Cursor / Claude Code tarzı doğal konuşma, katlanabilir aktivite kartları, diff ve geri alma sunar.

const AISidebarChangeSetDialog = preload("res://addons/godot_sidebar_ai/ui/dialogs/change_set_dialog.gd")
const AISidebarAgentHost = preload("res://addons/godot_sidebar_ai/core/agent/agent_host.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

# Modüler UI Bileşenleri
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarInputComposer = preload("res://addons/godot_sidebar_ai/ui/components/input_composer.gd")
const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
const AISidebarHistoryPanel = preload("res://addons/godot_sidebar_ai/ui/components/history_panel.gd")
const AISidebarUITelemetryTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarWelcomeCard = preload("res://addons/godot_sidebar_ai/ui/components/welcome_card.gd")
const AISidebarChatDockTheme = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock_theme.gd")
const AISidebarPlanChecklistTracker = preload("res://addons/godot_sidebar_ai/ui/presenters/plan_checklist_tracker.gd")
const AISidebarMessageQueuePanel = preload("res://addons/godot_sidebar_ai/ui/components/message_queue_panel.gd")
const AISidebarChatExportActions = preload("res://addons/godot_sidebar_ai/ui/controllers/chat_export_actions.gd")
const AISidebarChatSessionStore = preload("res://addons/godot_sidebar_ai/ui/controllers/chat_session_store.gd")
const AISidebarSessionReplayRenderer = preload("res://addons/godot_sidebar_ai/ui/presenters/session_replay_renderer.gd")
const AISidebarAgentStreamPresenter = preload("res://addons/godot_sidebar_ai/ui/presenters/agent_stream_presenter.gd")
const AISidebarAgentActivityPresenter = preload("res://addons/godot_sidebar_ai/ui/presenters/agent_activity_presenter.gd")
const AISidebarAgentInteractionPresenter = preload("res://addons/godot_sidebar_ai/ui/presenters/agent_interaction_presenter.gd")
const AISidebarModelBarController = preload("res://addons/godot_sidebar_ai/ui/controllers/model_bar_controller.gd")
const AISidebarTaskController = preload("res://addons/godot_sidebar_ai/ui/controllers/task_controller.gd")

@onready var title_label: Label = $MainLayout/HeaderBar/TitleLabel
@onready var status_badge: Label = $MainLayout/HeaderBar/StatusBadge
@onready var new_chat_btn: Button = $MainLayout/HeaderBar/NewChatBtn
@onready var history_btn: Button = $MainLayout/HeaderBar/HistoryBtn
@onready var export_btn: Button = $MainLayout/HeaderBar/ExportBtn
@onready var copy_task_btn: Button = $MainLayout/HeaderBar/CopyTaskBtn
@onready var model_bar: HBoxContainer = get_node_or_null("MainLayout/ModelBar")
@onready var model_selector: OptionButton = $MainLayout/ModelBar/ModelSelector
@onready var approve_mode_btn: Button = $MainLayout/ModelBar/ApproveModeBtn
@onready var refresh_models_btn: Button = $MainLayout/ModelBar/RefreshModelsBtn
@onready var settings_btn: Button = $MainLayout/ModelBar/SettingsBtn

@onready var input_area: VBoxContainer = get_node_or_null("MainLayout/InputArea")
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

## Ajan katmanı (provider, context, runner); plugin.gd kurar ve _ready'den önce enjekte eder.
var agent_host: AISidebarAgentHost = null
var agent_context: AISidebarAgentContext
var agent_runner: AISidebarAgentRunner

## Model listesi / seçimi ve onay modu butonu.
var _model_bar: AISidebarModelBarController = AISidebarModelBarController.new()

# Sohbet Oturumu ve Geçmiş Yönetimi (Chat Management)
## Aktif oturumun kalıcı durumu (kaydet/yükle/temizle/checkpoint).
var _sessions: AISidebarChatSessionStore = AISidebarChatSessionStore.new()
var history_panel: AISidebarHistoryPanel = null
## Export / Copy Chat / per-task copy / history export eylemleri.
var _export_actions: AISidebarChatExportActions = null

# Kuyruktaki Mesajlar (FIFO Message Queue)
var _queue_panel: AISidebarMessageQueuePanel = AISidebarMessageQueuePanel.new()

## Görev akışı: gönder, slash, kuyruk, devam et, task bitişi/hata; _ready'de kurulur.
var _tasks: AISidebarTaskController = null
## Giriş alanı davranışı (klavye, autocomplete, görsel eki); _ready'de kurulur.
var _composer: AISidebarInputComposer = null
## Cevap akışı, thinking/reasoning kartları ve bekleme rozeti; _ready'de kurulur.
var _stream: AISidebarAgentStreamPresenter = null

## Activity grubu, tool satırları, doğrulama/runtime/debug ve screenshot önizlemesi.
var _activity: AISidebarAgentActivityPresenter = AISidebarAgentActivityPresenter.new()
## Onaylı plan checklist'inin tool olaylarıyla ilerletilmesi.
var _checklist_tracker: AISidebarPlanChecklistTracker = AISidebarPlanChecklistTracker.new()
## Soru, onay, plan ve değişiklik kartları (kararlar AgentRunner'a iletilir).
var _interaction: AISidebarAgentInteractionPresenter = AISidebarAgentInteractionPresenter.new()
var _auto_scroll_enabled: bool = true
var _welcome_card: AISidebarWelcomeCard = null


func _exit_tree() -> void:
	if agent_host:
		agent_host.stop_provider_process()

func _notification(what: int) -> void:
	# InputArea yoksa kuyruk paneli ağaca hiç eklenmez; sahipsiz kalmasın.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_queue_panel) and _queue_panel.get_parent() == null:
		_queue_panel.free()

## Provider'ı config'e göre yeniden kurdurur; eski provider'dan kalan hazırlık durumu sıfırlanır.
## Çalışan görev önce kullanıcı adına durdurulur (Paused; "devam et" ile yeni provider'da sürer):
## eski provider'ın isteğine yanıt verecek kimse kalmayabilir.
func _rebuild_provider() -> void:
	if _tasks:
		_tasks.stop_by_user()
	if _stream:
		_stream.agy_preparing = false
	if agent_host:
		agent_host.rebuild_provider()

func _ready() -> void:
	_export_actions = AISidebarChatExportActions.new()
	_export_actions.get_session = func(): return _sessions.current
	_export_actions.status_badge = status_badge
	_export_actions.export_btn = export_btn
	_export_actions.copy_task_btn = copy_task_btn
	add_child(_export_actions)
	_stream = AISidebarAgentStreamPresenter.new()
	_stream.add_component = _add_stream_component
	_stream.on_meta_clicked = _on_meta_clicked
	_stream.set_status = set_status_badge
	_stream.scroll_if_following = _scroll_if_following
	_stream.answer_text_started.connect(_activity.close_group)
	add_child(_stream)
	_activity.add_component = _add_stream_component
	_activity.on_meta_clicked = _on_meta_clicked
	_activity.set_status = set_status_badge
	_activity.supports_vision = func(): return agent_host != null and agent_host.supports_vision()
	_activity.stream = _stream
	_activity.checklist_tracker = _checklist_tracker
	_interaction.add_component = _add_stream_component
	_interaction.on_meta_clicked = _on_meta_clicked
	_interaction.scroll_if_following = _scroll_if_following
	_interaction.refresh_ui = update_ui_language
	_interaction.stream = _stream
	_interaction.activity = _activity
	_interaction.checklist_tracker = _checklist_tracker
	_interaction.change_set_dialog = change_set_dialog
	_model_bar.model_selector = model_selector
	_model_bar.approve_mode_btn = approve_mode_btn
	_model_bar.set_status = set_status_badge
	_setup_history_panel()
	_setup_queue_ui()
	_composer = AISidebarInputComposer.new(input_area, input_field, mention_container, mention_list)
	_composer.setup_attachment_ui()
	_tasks = AISidebarTaskController.new()
	_tasks.input_field = input_field
	_tasks.status_badge = status_badge
	_tasks.composer = _composer
	_tasks.queue_panel = _queue_panel
	_tasks.sessions = _sessions
	_tasks.export_actions = _export_actions
	_tasks.history_panel = history_panel
	_tasks.stream = _stream
	_tasks.activity = _activity
	_tasks.interaction = _interaction
	_tasks.checklist_tracker = _checklist_tracker
	_tasks.add_component = _add_stream_component
	_tasks.on_meta_clicked = _on_meta_clicked
	_tasks.refresh_ui = update_ui_language
	_tasks.hide_welcome = _hide_welcome_card
	_tasks.update_header = _update_header_title
	_tasks.save_session = _save_current_session
	_tasks.clear_chat = _on_clear_pressed
	add_child(_tasks)
	AISidebarChatDockTheme.apply(self)
	if not Engine.is_editor_hint():
		return
		
	AISidebarUITelemetryTools.register_sidebar_dock(self)
	
	# 1. Ajan katmanı: plugin.gd (kompozisyon kökü) kurar ve enjekte eder. Önce bağlanılır,
	# sonra provider kurulur; böylece pre_warm'ın hazırlık olayı rozete ulaşır.
	if agent_host:
		attach_agent_host(agent_host)
		_rebuild_provider()

	# 2. UI Olayları
	if new_chat_btn:
		new_chat_btn.pressed.connect(_on_new_chat_pressed)
	if history_btn:
		history_btn.pressed.connect(_on_toggle_history_pressed)
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_pressed)
	if send_btn:
		send_btn.pressed.connect(_tasks.submit_input)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if approve_mode_btn:
		approve_mode_btn.pressed.connect(_model_bar.on_approve_mode_pressed)
	if refresh_models_btn:
		refresh_models_btn.pressed.connect(_on_refresh_models_pressed)
	if export_btn:
		export_btn.pressed.connect(_export_actions.export_chat)
	if copy_task_btn:
		copy_task_btn.pressed.connect(_export_actions.copy_chat)
	_composer.connect_input_signals()
	_composer.send_requested.connect(_tasks.submit_input)

	# 4. Oturumu Başlat (Her açılışta daima temiz ve yeni bir sohbet başlat)
	_start_new_chat_session()
	if model_selector:
		model_selector.item_selected.connect(_model_bar.on_model_selected)
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

	# 5. Başlangıç Yüklemesi
	update_ui_language()
	_model_bar.load_cached_models()
	if agent_host and agent_host.has_provider():
		agent_host.fetch_models()

## Ajan katmanını dock birimlerine bağlar: context ve runner presenter / controller'lara verilir,
## host'un model listesi ve hazırlık olayları ile runner sinyalleri dinlenir.
func attach_agent_host(host: AISidebarAgentHost) -> void:
	agent_host = host
	agent_context = host.context
	_sessions.context = agent_context
	_export_actions.agent_context = agent_context
	_checklist_tracker.context = agent_context
	_activity.context = agent_context
	_interaction.context = agent_context
	_tasks.context = agent_context
	host.models_fetched.connect(_model_bar.on_models_fetched)
	host.readiness_changed.connect(_on_provider_readiness_changed)
	agent_runner = host.runner
	_interaction.runner = agent_runner
	_tasks.runner = agent_runner
	_connect_agent_runner()

## AgentRunner sinyallerini presenter'lara ve ChatDock orkestrasyonuna bağlar.
func _connect_agent_runner() -> void:
	agent_runner.state_changed.connect(_on_agent_state_changed)
	agent_runner.thinking_received.connect(_stream.on_thinking_received)
	agent_runner.chunk_received.connect(_stream.on_chunk_received)
	agent_runner.text_received.connect(_stream.on_text_received)
	agent_runner.tool_executing.connect(_activity.on_tool_executing)
	agent_runner.tool_completed.connect(_activity.on_tool_completed)
	agent_runner.approval_requested.connect(_interaction.on_approval_requested)
	agent_runner.clarification_requested.connect(_interaction.on_clarification_requested)
	agent_runner.plan_proposed.connect(_interaction.on_plan_proposed)
	agent_runner.changes_applied.connect(_interaction.on_changes_applied)
	agent_runner.verification_started.connect(_activity.on_verification_started)
	agent_runner.verification_completed.connect(_activity.on_verification_completed)
	agent_runner.runtime_observation_received.connect(_activity.on_runtime_observation)
	agent_runner.debugging_started.connect(_activity.on_debugging_started)
	agent_runner.error_occurred.connect(_tasks.on_error)
	agent_runner.task_completed.connect(_tasks.on_task_completed)
	agent_runner.step_progress.connect(_activity.on_step_progress)

func _setup_history_panel() -> void:
	if history_panel or not has_node("MainLayout"):
		return
	history_panel = AISidebarHistoryPanel.new()
	history_panel.name = "HistoryPanel"
	history_panel.visible = false
	$MainLayout.add_child(history_panel)
	$MainLayout.move_child(history_panel, 2)
	
	history_panel.session_selected.connect(_on_history_session_selected)
	history_panel.new_chat_requested.connect(_on_new_chat_pressed)
	history_panel.session_deleted.connect(_on_history_session_deleted)
	history_panel.session_renamed.connect(_on_history_session_renamed)
	history_panel.session_export_requested.connect(_export_actions.export_history_session)
	history_panel.close_requested.connect(_on_history_close_requested)

func _setup_queue_ui() -> void:
	if not has_node("MainLayout/InputArea"):
		return
	var input_area = $MainLayout/InputArea
	input_area.add_child(_queue_panel)
	input_area.move_child(_queue_panel, 0)

func update_ui_language() -> void:
	if export_btn:
		AISidebarIconHelper.apply_icon(export_btn, "download")
		export_btn.tooltip_text = "Sohbeti Dışa Aktar / Kopyala (Export Chat)"
	if copy_task_btn:
		AISidebarIconHelper.apply_icon(copy_task_btn, "copy")
		copy_task_btn.tooltip_text = "Tüm sohbet transcriptini kopyala (Copy Chat)"
	if history_btn:
		AISidebarIconHelper.apply_icon(history_btn, "history")
		history_btn.text = "" if history_btn.icon else "Hist"
		history_btn.tooltip_text = AISidebarI18n.get_text("history_title")
	if new_chat_btn:
		new_chat_btn.tooltip_text = AISidebarI18n.get_text("history_btn_new")
		
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
		AISidebarChatDockTheme.apply_send_button(send_btn, agent_runner != null and agent_runner.is_running())
			
	_model_bar.update_approve_mode_ui()

func _on_refresh_models_pressed() -> void:
	if agent_host and agent_host.has_provider():
		set_status_badge("Refreshing...", AISidebarTheme.COLOR_WARNING)
		agent_host.fetch_models()

func _on_settings_pressed() -> void:
	if settings_dialog:
		settings_dialog.open_settings()

func _on_settings_saved() -> void:
	update_ui_language()
	_rebuild_provider()
	if agent_host and agent_host.has_provider():
		agent_host.fetch_models()

# --- Chat Management Olayları ve Yardımcıları ---

func set_history_view_visible(is_visible: bool) -> void:
	if history_panel:
		history_panel.visible = is_visible
		if is_visible:
			history_panel.set_active_session(_sessions.current_id())
			history_panel.refresh_list()
	if chat_scroll:
		chat_scroll.visible = not is_visible
	if input_area:
		input_area.visible = not is_visible
	if model_bar:
		model_bar.visible = not is_visible

func _on_new_chat_pressed() -> void:
	set_history_view_visible(false)
	_start_new_chat_session()

func _on_toggle_history_pressed() -> void:
	if not history_panel:
		return
	set_history_view_visible(not history_panel.visible)

func _on_history_session_selected(session_id: String) -> void:
	set_history_view_visible(false)
	if _sessions.is_current(session_id):
		return
	_load_session_by_id(session_id)

func _on_history_session_deleted(session_id: String) -> void:
	if _sessions.is_current(session_id):
		_start_new_chat_session()

func _on_history_session_renamed(session_id: String, new_title: String) -> void:
	if _sessions.rename_if_current(session_id, new_title):
		_update_header_title()

func _on_history_close_requested() -> void:
	set_history_view_visible(false)

func _start_new_chat_session() -> void:
	_tasks.stop_by_user()
		
	if _sessions.has_live_messages():
		_save_current_session()
		
	_sessions.start_new()
		
	_queue_panel.clear_all()
	_clear_ui_stream()
	_show_welcome_card_if_empty()
	_update_header_title()
	if history_panel:
		history_panel.set_active_session(_sessions.current_id())
	set_status_badge(AISidebarI18n.get_text("status_ready"), AISidebarTheme.COLOR_SUCCESS)

## Kaydet + başlığı yenile (kayıt başlığı ilk mesajdan üretebilir).
func _save_current_session() -> void:
	_sessions.save()
	_update_header_title()

func _load_session_by_id(session_id: String) -> void:
	if not _sessions.is_current(session_id) and _sessions.has_live_messages():
		_save_current_session()
		
	_tasks.stop_by_user()
		
	if not _sessions.load_by_id(session_id):
		_start_new_chat_session()
		return
	var loaded = _sessions.current
		
	_queue_panel.clear_all()
	_clear_ui_stream()
	_rebuild_ui_stream_from_session(loaded)
	_show_welcome_card_if_empty()
	if _sessions.has_resumable_checkpoint():
		_tasks.show_paused_badge(int(loaded.checkpoint.get("current_step", 0)), int(loaded.checkpoint.get("max_steps", 20)))
	_update_header_title()
	if history_panel:
		history_panel.set_active_session(loaded.id)
		if history_panel.visible:
			history_panel.refresh_list()
	set_status_badge(AISidebarI18n.get_text("status_ready"), AISidebarTheme.COLOR_SUCCESS)
	if _auto_scroll_enabled:
		_scroll_to_bottom()

func _rebuild_ui_stream_from_session(sess: AISidebarChatSession) -> void:
	if not message_stream or not sess:
		return
	for comp in AISidebarSessionReplayRenderer.build(sess, _on_meta_clicked):
		_add_stream_component(comp)

func _clear_ui_stream() -> void:
	if message_stream:
		for child in message_stream.get_children():
			child.queue_free()
	_activity.reset()
	_checklist_tracker.reset()
	_interaction.reset()
	_stream.reset()
	_welcome_card = null

func _show_welcome_card_if_empty() -> void:
	if _sessions.current == null or _sessions.current.messages.is_empty():
		if _welcome_card == null or not is_instance_valid(_welcome_card):
			_welcome_card = AISidebarWelcomeCard.new()
			_welcome_card.prompt_selected.connect(_on_welcome_prompt_selected)
			_add_stream_component(_welcome_card)

func _hide_welcome_card() -> void:
	if _welcome_card and is_instance_valid(_welcome_card):
		_welcome_card.queue_free()
		_welcome_card = null

func _on_welcome_prompt_selected(prompt_text: String) -> void:
	if input_field:
		input_field.text = prompt_text
		input_field.grab_focus()
		input_field.set_caret_column(prompt_text.length())

## AGY provider hazirlik durumu degisti (STARTING / INITIALIZING / READY).
## Yalnizca bilgilendirici rozet metni guncellenir; ajan durumu DEGISTIRILMEZ.
func _on_provider_readiness_changed(state: int, _message: String) -> void:
	if not agent_host or not agent_host.has_readiness_state():
		return
	_stream.agy_preparing = not agent_host.is_provider_ready()
	if _stream.agy_preparing:
		set_status_badge(AISidebarI18n.get_text("status_agy_preparing"), AISidebarTheme.COLOR_WARNING)
	elif agent_runner and agent_runner.is_running():
		# Ajan calisiyor: thinking rozetine geri don (timer zaten isliyor).
		set_status_badge("Thinking...", AISidebarTheme.COLOR_WARNING)
	else:
		# Ajan beklemede: hazirlik bitti, bos durum rozetini geri yukle.
		set_status_badge(AISidebarI18n.get_text("status_ready"), AISidebarTheme.COLOR_SUCCESS)

func _update_header_title() -> void:
	if title_label:
		var sess = _sessions.current
		if sess and not sess.title.is_empty() and sess.title != "New Chat":
			title_label.text = "Godot AI - " + sess.title
			title_label.tooltip_text = sess.title
		else:
			title_label.text = "Godot AI"
			title_label.tooltip_text = "Godot AI Assistant"

func _on_clear_pressed() -> void:
	_composer.clear_attached_image()
	_stream.user_vision_inputs.clear()
	_composer.hide_popup()
	_tasks.stop_by_user()
	_sessions.clear_contents()
	_queue_panel.clear_all()
	_clear_ui_stream()
	_update_header_title()

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

## Kullanıcı en alttaysa (otomatik kaydırma açık) akışı aşağı kaydırır.
func _scroll_if_following() -> void:
	if _auto_scroll_enabled:
		_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	if not chat_scroll:
		return
	chat_scroll.set_deferred("scroll_vertical", 999999)

func _add_stream_component(comp: Control) -> void:
	if not message_stream:
		return
	message_stream.add_child(comp)
	if _stream:
		_stream.on_component_added(comp)
	# Task Checklist her zaman stream'in en altında kalır (aynı instance taşınır).
	if comp != _checklist_tracker.checklist:
		_move_checklist_to_bottom()
	if _auto_scroll_enabled:
		_scroll_to_bottom()

## Checklist'i message stream'in en sonuna taşır; yoksa/boşsa no-op.
func _move_checklist_to_bottom() -> void:
	if _checklist_tracker.checklist == null or not is_instance_valid(_checklist_tracker.checklist):
		return
	if message_stream == null:
		return
	if _checklist_tracker.checklist.get_parent() != message_stream:
		return
	if _checklist_tracker.checklist.step_count() <= 0:
		return
	message_stream.move_child(_checklist_tracker.checklist, -1)

# --- Ajan Sinyal Dinleyicileri (Presentation) ---

func _on_agent_state_changed(new_state: AISidebarAgentRunner.AgentState, state_desc: String) -> void:
	update_ui_language()
	_stream.on_state_changed(new_state, state_desc)
	# Durdurulan task devam ettirilebilir durumdaysa boşta rozeti "Hazır" değil "Paused" kalır
	# (runner stop sonrası IDLE'a geçer; aksi halde Paused rozeti hemen ezilirdi).
	if new_state == AISidebarAgentRunner.AgentState.IDLE or new_state == AISidebarAgentRunner.AgentState.COMPLETED:
		if _sessions.has_resumable_checkpoint():
			var cp = _sessions.current.checkpoint
			_tasks.show_paused_badge(int(cp.get("current_step", 0)), int(cp.get("max_steps", 20)))

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
