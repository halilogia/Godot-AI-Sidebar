@tool
extends Control

## Godot AI Sidebar - Profesyonel AI IDE Sohbet ve Orkestrasyon Paneli (SRP).
## Cursor / Claude Code tarzı doğal konuşma, katlanabilir aktivite kartları, diff ve geri alma sunar.

const AISidebarChangeSetDialog = preload("res://addons/godot_sidebar_ai/ui/dialogs/change_set_dialog.gd")
const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

# Modüler UI Bileşenleri
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarTelemetryCard = preload("res://addons/godot_sidebar_ai/ui/components/telemetry_card.gd")
const AISidebarErrorCard = preload("res://addons/godot_sidebar_ai/ui/components/error_card.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarTaskCheckpoint = preload("res://addons/godot_sidebar_ai/core/chat/task_checkpoint.gd")
const AISidebarMentionManager = preload("res://addons/godot_sidebar_ai/core/chat/mention_manager.gd")
const AISidebarInputComposer = preload("res://addons/godot_sidebar_ai/ui/components/input_composer.gd")
const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
const AISidebarHistoryPanel = preload("res://addons/godot_sidebar_ai/ui/components/history_panel.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")
const AISidebarUITelemetryTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
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

var network_manager: AISidebarNetworkManager
var provider: AISidebarAIProvider
var agent_context: AISidebarAgentContext
var agent_runner: AISidebarAgentRunner

## Model listesi / seçimi ve onay modu butonu.
var _model_bar: AISidebarModelBarController = AISidebarModelBarController.new()
var last_user_prompt: String = ""

# Sohbet Oturumu ve Geçmiş Yönetimi (Chat Management)
## Aktif oturumun kalıcı durumu (kaydet/yükle/temizle/checkpoint).
var _sessions: AISidebarChatSessionStore = AISidebarChatSessionStore.new()
var history_panel: AISidebarHistoryPanel = null
## Export / Copy Chat / per-task copy / history export eylemleri.
var _export_actions: AISidebarChatExportActions = null

# Kuyruktaki Mesajlar (FIFO Message Queue)
var _queue_panel: AISidebarMessageQueuePanel = AISidebarMessageQueuePanel.new()
var _is_user_stopped: bool = false

# Pano Görseli Eki (Clipboard Image Attachment)
var _last_sent_vision_input: AISidebarVisionInput = null
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
	if provider and provider.has_method("stop_process"):
		provider.stop_process()

func _notification(what: int) -> void:
	# InputArea yoksa kuyruk paneli ağaca hiç eklenmez; sahipsiz kalmasın.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_queue_panel) and _queue_panel.get_parent() == null:
		_queue_panel.free()

func _setup_provider() -> void:
	var cfg = AISidebarConfig.load_config()
	var prov_type = cfg.get("provider_type", "antigravity_cli")
	
	if provider:
		if provider.has_method("stop_process"):
			provider.stop_process()
		if provider.models_fetched.is_connected(_model_bar.on_models_fetched):
			provider.models_fetched.disconnect(_model_bar.on_models_fetched)
		if provider.has_signal("readiness_changed") and provider.readiness_changed.is_connected(_on_provider_readiness_changed):
			provider.readiness_changed.disconnect(_on_provider_readiness_changed)
		
	if _stream:
		_stream.agy_preparing = false
			
	if prov_type == "openai_compatible":
		if not network_manager:
			network_manager = AISidebarNetworkManager.new()
			add_child(network_manager)
		provider = AISidebarOpenAICompatibleProvider.new(network_manager)
	else:
		provider = AISidebarAGYProvider.new()
		
	provider.models_fetched.connect(_model_bar.on_models_fetched)
	if provider.has_signal("readiness_changed"):
		provider.readiness_changed.connect(_on_provider_readiness_changed)
	if provider.has_method("pre_warm"):
		provider.pre_warm()
	if agent_runner:
		agent_runner.set_provider(provider)

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
	_activity.supports_vision = func(): return provider != null and provider.has_method("supports_vision") and provider.supports_vision()
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
	_model_bar.is_agent_idle = func(): return agent_runner != null and not agent_runner.is_running()
	_setup_history_panel()
	_setup_queue_ui()
	_composer = AISidebarInputComposer.new(input_area, input_field, mention_container, mention_list)
	_composer.setup_attachment_ui()
	AISidebarChatDockTheme.apply(self)
	if not Engine.is_editor_hint():
		return
		
	AISidebarUITelemetryTools.register_sidebar_dock(self)
	
	# 1. Katmanların Başlatılması
	network_manager = AISidebarNetworkManager.new()
	add_child(network_manager)
	
	agent_context = AISidebarAgentContext.new()
	_sessions.context = agent_context
	_export_actions.agent_context = agent_context
	_checklist_tracker.context = agent_context
	_activity.context = agent_context
	_interaction.context = agent_context
	_setup_provider()
	agent_runner = AISidebarAgentRunner.new(provider, agent_context)
	_interaction.runner = agent_runner
	
	_connect_agent_runner()

	# 2. UI Olayları
	if new_chat_btn:
		new_chat_btn.pressed.connect(_on_new_chat_pressed)
	if history_btn:
		history_btn.pressed.connect(_on_toggle_history_pressed)
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_pressed)
	if send_btn:
		send_btn.pressed.connect(_on_send_pressed)
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
	_composer.send_requested.connect(_on_send_pressed)

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
	if provider:
		provider.fetch_models()

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
	agent_runner.error_occurred.connect(_on_agent_error)
	agent_runner.task_completed.connect(_on_agent_task_completed)
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
	if provider:
		set_status_badge("Refreshing...", AISidebarTheme.COLOR_WARNING)
		provider.fetch_models()

func _on_settings_pressed() -> void:
	if settings_dialog:
		settings_dialog.open_settings()

func _on_settings_saved() -> void:
	update_ui_language()
	_setup_provider()
	if provider:
		provider.fetch_models()

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
	if agent_runner and agent_runner.is_running():
		_is_user_stopped = true
		agent_runner.stop()
		
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
		
	if agent_runner and agent_runner.is_running():
		_is_user_stopped = true
		agent_runner.stop()
		
	if not _sessions.load_by_id(session_id):
		_start_new_chat_session()
		return
	var loaded = _sessions.current
		
	_queue_panel.clear_all()
	_clear_ui_stream()
	_rebuild_ui_stream_from_session(loaded)
	_show_welcome_card_if_empty()
	if _sessions.has_resumable_checkpoint():
		_show_paused_badge(int(loaded.checkpoint.get("current_step", 0)), int(loaded.checkpoint.get("max_steps", 20)))
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
	if not provider or not provider.has_method("is_ready"):
		return
	_stream.agy_preparing = not provider.is_ready()
	if _stream.agy_preparing:
		set_status_badge(AISidebarI18n.get_text("status_agy_preparing"), AISidebarTheme.COLOR_WARNING)
	elif agent_runner and agent_runner.is_running():
		# Ajan calisiyor: thinking rozetine geri don (timer zaten isliyor).
		set_status_badge("Thinking...", AISidebarTheme.COLOR_WARNING)
	else:
		# Ajan beklemede: hazirlik bitti, bos durum rozetini geri yukle.
		var mode_txt = AISidebarPermissionPolicy.get_mode_name(AISidebarPermissionPolicy.get_auto_approve_mode())
		set_status_badge(AISidebarI18n.get_text("status_ready") + " [" + mode_txt + "]", AISidebarTheme.COLOR_SUCCESS)

func _update_header_title() -> void:
	if title_label:
		var sess = _sessions.current
		if sess and not sess.title.is_empty() and sess.title != "New Chat":
			title_label.text = "Godot AI - " + sess.title
			title_label.tooltip_text = sess.title
		else:
			title_label.text = "Godot AI"
			title_label.tooltip_text = "Godot AI Assistant"

func _on_send_pressed() -> void:
	if not agent_runner:
		return
		
	_composer.hide_popup()
		
	var user_text = input_field.text.strip_edges()
	var attached_img = _composer.attached_vision_input
	
	# Eğer metin boşsa ama ekli görsel varsa varsayılan soru metni ata
	if user_text.is_empty() and attached_img != null:
		user_text = "Bu görseli incele ve yardımcı ol."
	
	# Eğer metin boşsa ve kullanıcı 'Stop' butonuna bastıysa:
	if user_text.is_empty():
		if agent_runner.is_running():
			_is_user_stopped = true
			agent_runner.stop()
			update_ui_language()
		return
		
	input_field.text = ""
	_last_sent_vision_input = attached_img
	_composer.clear_attached_image()
	_is_user_stopped = false
	
	var vision_inputs: Array = []
	if attached_img != null:
		vision_inputs.append(attached_img)
	
	# 1. Slash Command Kontrolü (/)
	if user_text.begins_with("/"):
		var parsed_cmd = AISidebarSlashCommandManager.parse(user_text)
		if parsed_cmd.get("is_command", false):
			_handle_slash_command_execution(parsed_cmd, user_text)
			return
			
	# 2. Normal Mesaj Akışı: Eğer ajan şu anda başka bir görev çalıştırıyorsa -> Mesajı Kuyruğa Al
	if agent_runner.is_running():
		_queue_panel.enqueue(user_text, user_text, vision_inputs)
		return
		
	# 3. Continuation: boştayken resume komutu + resumable checkpoint varsa devam et
	if not agent_runner.is_running() and AISidebarTaskCheckpoint.is_resume_command(user_text) and _sessions.has_resumable_checkpoint():
		input_field.text = ""
		_resume_paused_task(user_text)
		return

	# Ajan boşta ise görevi hemen başlat
	_start_task_prompt(user_text, "", vision_inputs)

func _active_scene_path_now() -> String:
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_edited_scene_root"):
		var edited = EditorInterface.get_edited_scene_root()
		if edited:
			return str(edited.scene_file_path)
	return ""

## Durmuş tasktan checkpoint üret, session'a yaz, Paused rozeti göster.
func _refresh_pause_checkpoint() -> void:
	if agent_runner == null:
		return
	var live = {
		"current_step": agent_runner.current_step,
		"max_steps": agent_runner.max_steps,
		"elapsed_s": agent_runner.get_elapsed_s(),
	}
	var cp = _sessions.store_pause_checkpoint(live, _active_scene_path_now())
	if cp.is_empty():
		return
	_update_header_title()
	if bool(cp.get("resumable", false)):
		_show_paused_badge(int(cp.get("current_step", 0)), int(cp.get("max_steps", 20)))

func _show_paused_badge(cur: int, mx: int) -> void:
	if not status_badge:
		return
	status_badge.text = "Paused — Step %d/%d" % [cur, mx]
	status_badge.tooltip_text = "Devam etmek için 'devam et' yazın. Başka bir mesaj yeni task başlatır."
	status_badge.add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)

func _resume_paused_task(user_text: String) -> void:
	if _sessions.current == null:
		return
	var cp = _sessions.checkpoint_copy()
	_hide_welcome_card()
	_last_sent_vision_input = null
	_is_user_stopped = false
	_stream.user_vision_inputs.clear()
	var msg = AISidebarTaskCheckpoint.build_resume_message(cp)
	if agent_runner and agent_runner.resume_task(cp, msg, user_text):
		return
	# Checkpoint geçersizse güvenli düşüş: normal yeni task.
	_start_task_prompt(user_text, "", [])

func _handle_slash_command_execution(parsed_cmd: Dictionary, raw_text: String) -> void:
	if parsed_cmd.has("error"):
		# Bilinmeyen slash komutu
		var cmd_bubble = AISidebarMessageBubble.new("command", raw_text)
		cmd_bubble.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(cmd_bubble)
		
		var err_msg = parsed_cmd["error"] + "\n\nKullanılabilir komutları görmek için `/help` yazabilirsiniz."
		var err_bubble = AISidebarMessageBubble.new("assistant", err_msg)
		err_bubble.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(err_bubble)
		return
		
	var cmd_name = parsed_cmd["name"]
	var cmd_args = parsed_cmd["args"]
	var exec_context = {"agent_context": agent_context}
	var result = AISidebarSlashCommandManager.execute_command(cmd_name, cmd_args, exec_context)
	var action = result.get("action", "")
	
	if action == "clear_chat":
		_on_clear_pressed()
		return
		
	if action == "local_response":
		var cmd_bubble = AISidebarMessageBubble.new("command", raw_text)
		cmd_bubble.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(cmd_bubble)
		
		var reply_text = result.get("message", "")
		var assistant_bubble = AISidebarMessageBubble.new("assistant", reply_text)
		assistant_bubble.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(assistant_bubble)
		
		_sessions.record_local_command(raw_text, reply_text)
		_update_header_title()
		return
		
	elif action == "run_agent":
		var prompt = result.get("prompt", "")
		var display_prompt = result.get("display_prompt", raw_text)
		
		if agent_runner.is_running():
			_queue_panel.enqueue(prompt, display_prompt)
			return
			
		_start_task_prompt(prompt, display_prompt)

func _start_task_prompt(prompt_text: String, display_prompt: String = "", vision_inputs: Array = []) -> void:
	_hide_welcome_card()
	var final_display = display_prompt if not display_prompt.is_empty() else prompt_text
	last_user_prompt = final_display
	_activity.begin_task()
	_stream.begin_task()
	_checklist_tracker.reset()
	_interaction.begin_task()
	_is_user_stopped = false
	_stream.user_vision_inputs = vision_inputs.duplicate()
	
	# Yeni task eskisini geçersiz kılar (devam yolu buradan geçmez).
	_sessions.begin_new_task()
	_update_header_title()

	var resolved_ctx = AISidebarMentionManager.resolve_prompt_context(prompt_text)
	if agent_context:
		agent_context.begin_task(prompt_text, final_display)
	agent_runner.start_task(resolved_ctx["augmented_prompt"], final_display, vision_inputs)

func _check_and_dispatch_next_queue() -> void:
	if _is_user_stopped:
		return
		
	if _queue_panel.count() > 0:
		var next_item = _queue_panel.pop_next()
		if next_item is Dictionary and next_item.has("prompt"):
			var next_prompt = str(next_item["prompt"])
			var next_disp = str(next_item.get("display_prompt", next_prompt))
			var q_vision = next_item.get("vision_inputs", [])
			var t = get_tree()
			if t:
				t.create_timer(0.05).timeout.connect(func():
					_start_task_prompt(next_prompt, next_disp, q_vision)
				)
			else:
				_start_task_prompt(next_prompt, next_disp, q_vision)

func _on_clear_pressed() -> void:
	_composer.clear_attached_image()
	_stream.user_vision_inputs.clear()
	_composer.hide_popup()
	if agent_runner and agent_runner.is_running():
		_is_user_stopped = true
		agent_runner.stop()
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

func _on_agent_task_completed(metrics: Dictionary) -> void:
	_stream.end_task()
	_activity.clear_running()
	var t_ok = bool(metrics.get("success", false))
	var completion = str(metrics.get("completion", "success" if t_ok else "failed"))
	var show_ok = t_ok and completion == "success"
	var done_reason = str(metrics.get("completion_reason", metrics.get("stop_reason", "")))
	_checklist_tracker.finish(show_ok, done_reason)
	_checklist_tracker.clear_tool_args()
	if agent_context and agent_context.get_transcript().has_running_task():
		var t_status = "completed" if show_ok else ("incomplete" if completion == "incomplete" else "failed")
		agent_context.end_task(t_status, done_reason, metrics)
	_activity.finish_task(str(metrics.get("stop_reason", "")))
		
	var telemetry_comp = AISidebarTelemetryCard.new(metrics)
	if agent_context:
		telemetry_comp.task_id = str(agent_context.get_transcript().get_current_task().get("id", ""))
	telemetry_comp.copy_task_requested.connect(_export_actions.copy_single_task)
	_add_stream_component(telemetry_comp)
	update_ui_language()
	
	if _sessions.current:
		_sessions.current.telemetry = metrics.duplicate(true)
		if t_ok:
			# Başarıyla biten taskın resume ihtiyacı kalmaz.
			_sessions.current.checkpoint = {}
		else:
			_refresh_pause_checkpoint()
		_save_current_session()
		if history_panel and history_panel.visible:
			history_panel.refresh_list()
			
	_check_and_dispatch_next_queue()
	_last_sent_vision_input = null

func _on_agent_error(err_msg: String) -> void:
	_stream.end_task()
	_activity.clear_running()
	_checklist_tracker.finish(false, err_msg)
	_checklist_tracker.clear_tool_args()
	if agent_context and agent_context.get_transcript().has_running_task():
		var e_status = "cancelled" if _is_user_stopped else "failed"
		agent_context.end_task(e_status, err_msg)
	# Stop/fail sonrası kaldığı noktadan devam için checkpoint üret.
	_refresh_pause_checkpoint()
	_activity.stop_on_error(err_msg)
		
	# Hata durumunda veya model reddettiğinde görsel ekinin kaybolmasını önle (P2 UX Fix)
	if _last_sent_vision_input != null and _composer.attached_vision_input == null:
		_composer.attach_vision_input(_last_sent_vision_input)

	var err_comp = AISidebarErrorCard.new(err_msg)
	var vi_to_retry = _last_sent_vision_input
	err_comp.retry_requested.connect(func():
		if not last_user_prompt.is_empty():
			var vi_arr: Array = [vi_to_retry] if vi_to_retry != null else []
			agent_runner.start_task(last_user_prompt, "", vi_arr)
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
