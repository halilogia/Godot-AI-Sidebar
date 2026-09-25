@tool
extends Control

## Godot AI Sidebar - Profesyonel AI IDE Sohbet ve Orkestrasyon Paneli (SRP).
## Cursor / Claude Code tarzı doğal konuşma, katlanabilir aktivite kartları, diff ve geri alma sunar.

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarChangeSetDialog = preload("res://addons/godot_sidebar_ai/ui/dialogs/change_set_dialog.gd")
const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")
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
const AISidebarPlanCard = preload("res://addons/godot_sidebar_ai/ui/components/plan_card.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")
const AISidebarTaskCheckpoint = preload("res://addons/godot_sidebar_ai/core/chat/task_checkpoint.gd")
const AISidebarScreenshotCard = preload("res://addons/godot_sidebar_ai/ui/components/screenshot_card.gd")
const AISidebarReasoningCard = preload("res://addons/godot_sidebar_ai/ui/components/reasoning_card.gd")
const AISidebarThinkingCard = preload("res://addons/godot_sidebar_ai/ui/components/thinking_card.gd")
const AISidebarTaskChecklist = preload("res://addons/godot_sidebar_ai/ui/components/task_checklist.gd")
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
const AISidebarToolPresentation = preload("res://addons/godot_sidebar_ai/ui/presenters/tool_presentation.gd")
const AISidebarPlanChecklistTracker = preload("res://addons/godot_sidebar_ai/ui/presenters/plan_checklist_tracker.gd")
const AISidebarMessageQueuePanel = preload("res://addons/godot_sidebar_ai/ui/components/message_queue_panel.gd")
const AISidebarChatExportActions = preload("res://addons/godot_sidebar_ai/ui/controllers/chat_export_actions.gd")
const AISidebarChatSessionStore = preload("res://addons/godot_sidebar_ai/ui/controllers/chat_session_store.gd")
const AISidebarSessionReplayRenderer = preload("res://addons/godot_sidebar_ai/ui/presenters/session_replay_renderer.gd")

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

var current_model_list: Array = []
var pending_change_set: AISidebarChangeSet = null
var last_applied_change_set: AISidebarChangeSet = null
var pending_tool_name: String = ""
var pending_tool_args: Dictionary = {}
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
var _current_user_vision_inputs: Array = []

var _current_activity_group: AISidebarActivityGroup = null
var _current_reasoning_card: AISidebarReasoningCard = null
var _current_thinking_card: AISidebarThinkingCard = null
## Bu LLM turunda gerçek thinking verisi görüldü mü? (badge dürüstlüğü için)
var _thinking_seen_this_turn: bool = false
## Onaylı plan checklist'inin tool olaylarıyla ilerletilmesi.
var _checklist_tracker: AISidebarPlanChecklistTracker = AISidebarPlanChecklistTracker.new()
## Running satırının indeksi (tool_completed geldiğinde yerinde güncellenir, satır çoğalmaz).
var _activity_running_idx: int = -1
var _activity_running_tool: String = ""
var _activity_tool_start_msec: int = 0
var _current_runtime_card: AISidebarRuntimeCard = null
var _current_approval_card: AISidebarApprovalCard = null
var _current_plan_card: AISidebarPlanCard = null
var _current_assistant_bubble: AISidebarMessageBubble = null
## Streaming sırasında biriken ham metin (tool-call zarfı tespiti için tampon).
var _stream_buffer: String = ""
## Bu akış turunun saf tool-call zarfı olduğu kesinleşti mi? (balon hiç oluşturulmaz)
var _stream_is_envelope: bool = false
var _auto_scroll_enabled: bool = true
var _welcome_card: AISidebarWelcomeCard = null
var _thinking_timer: Timer = null
var _thinking_elapsed_sec: int = 0
## AGY alt sureci 'init' handshake'ini tamamlayana kadar true kalir.
## Yalnizca status rozeti metnini bilgilendirici yapar; thinking timer'i BOZMAZ.
var _agy_preparing: bool = false


func _exit_tree() -> void:
	_stop_thinking_timer()
	if _thinking_timer and is_instance_valid(_thinking_timer):
		_thinking_timer.queue_free()
		_thinking_timer = null
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
		if provider.models_fetched.is_connected(_on_models_fetched):
			provider.models_fetched.disconnect(_on_models_fetched)
		if provider.has_signal("readiness_changed") and provider.readiness_changed.is_connected(_on_provider_readiness_changed):
			provider.readiness_changed.disconnect(_on_provider_readiness_changed)
		
	_agy_preparing = false
			
	if prov_type == "openai_compatible":
		if not network_manager:
			network_manager = AISidebarNetworkManager.new()
			add_child(network_manager)
		provider = AISidebarOpenAICompatibleProvider.new(network_manager)
	else:
		provider = AISidebarAGYProvider.new()
		
	provider.models_fetched.connect(_on_models_fetched)
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
	_setup_provider()
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
	agent_runner.plan_proposed.connect(_on_agent_plan_proposed)
	agent_runner.changes_applied.connect(_on_agent_changes_applied)
	agent_runner.verification_started.connect(_on_agent_verification_started)
	agent_runner.verification_completed.connect(_on_agent_verification_completed)
	agent_runner.runtime_observation_received.connect(_on_agent_runtime_observation)
	agent_runner.debugging_started.connect(_on_agent_debugging_started)
	agent_runner.error_occurred.connect(_on_agent_error)
	agent_runner.task_completed.connect(_on_agent_task_completed)
	agent_runner.step_progress.connect(_on_agent_step_progress)

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
		approve_mode_btn.pressed.connect(_on_approve_mode_pressed)
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

	# 5. Başlangıç Yüklemesi
	update_ui_language()
	_load_cached_models()
	if provider:
		provider.fetch_models()

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
			
	_update_approve_mode_ui()

func _update_approve_mode_ui() -> void:
	if not approve_mode_btn:
		return
	var mode = AISidebarPermissionPolicy.get_auto_approve_mode()
	match mode:
		AISidebarPermissionPolicy.AutoApproveMode.MANUAL:
			approve_mode_btn.text = AISidebarI18n.get_text("mode_manual")
			approve_mode_btn.tooltip_text = AISidebarI18n.get_text("tooltip_approve_mode") + ": " + AISidebarI18n.get_text("mode_manual") + " (Her riskli işlemde onay sorulur)"
			approve_mode_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)
		AISidebarPermissionPolicy.AutoApproveMode.AUTO:
			approve_mode_btn.text = AISidebarI18n.get_text("mode_auto")
			approve_mode_btn.tooltip_text = AISidebarI18n.get_text("tooltip_approve_mode") + ": " + AISidebarI18n.get_text("mode_auto") + " (Güvenli kod/dosya yazımları otomatik, silme onaylı)"
			approve_mode_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_SUCCESS)
		AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO:
			approve_mode_btn.text = AISidebarI18n.get_text("mode_full_auto")
			approve_mode_btn.tooltip_text = AISidebarI18n.get_text("tooltip_approve_mode") + ": " + AISidebarI18n.get_text("mode_full_auto") + " (Tüm araçlar otomatik onaylanır, PathPolicy kalkanı devrededir)"
			approve_mode_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_MODE_FULL_AUTO)

func _on_approve_mode_pressed() -> void:
	var current_mode = AISidebarPermissionPolicy.get_auto_approve_mode()
	var next_mode = AISidebarPermissionPolicy.AutoApproveMode.MANUAL
	match current_mode:
		AISidebarPermissionPolicy.AutoApproveMode.MANUAL:
			next_mode = AISidebarPermissionPolicy.AutoApproveMode.AUTO
		AISidebarPermissionPolicy.AutoApproveMode.AUTO:
			next_mode = AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO
		AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO:
			next_mode = AISidebarPermissionPolicy.AutoApproveMode.MANUAL
	AISidebarPermissionPolicy.set_auto_approve_mode(next_mode)
	_update_approve_mode_ui()
	if agent_runner and not agent_runner.is_running():
		var mode_txt = AISidebarPermissionPolicy.get_mode_name(next_mode)
		set_status_badge(AISidebarI18n.get_text("status_ready") + " [" + mode_txt + "]", AISidebarTheme.COLOR_SUCCESS)

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
	set_status_badge("Ready", AISidebarTheme.COLOR_SUCCESS)

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

func _on_model_selected(index: int) -> void:
	if index >= 0 and index < current_model_list.size():
		var chosen = current_model_list[index]
		var cfg = AISidebarConfig.load_config()
		cfg["selected_model"] = chosen
		AISidebarConfig.save_config(cfg)

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
	_current_activity_group = null
	_current_reasoning_card = null
	_current_thinking_card = null
	_thinking_seen_this_turn = false
	_checklist_tracker.reset()
	_activity_running_idx = -1
	_activity_running_tool = ""
	_activity_tool_start_msec = 0
	_current_runtime_card = null
	_current_approval_card = null
	_current_plan_card = null
	_current_assistant_bubble = null
	_welcome_card = null
	_reset_stream_buffer()

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

func _setup_thinking_timer() -> void:
	if _thinking_timer != null:
		return
	_thinking_timer = Timer.new()
	_thinking_timer.wait_time = 1.0
	_thinking_timer.one_shot = false
	_thinking_timer.timeout.connect(_on_thinking_tick)
	add_child(_thinking_timer)

func _start_thinking_timer() -> void:
	_setup_thinking_timer()
	_thinking_elapsed_sec = 0
	_thinking_timer.start()

func _stop_thinking_timer() -> void:
	if _thinking_timer and is_instance_valid(_thinking_timer):
		_thinking_timer.stop()
	_thinking_elapsed_sec = 0

func _on_thinking_tick() -> void:
	_thinking_elapsed_sec += 1
	if _current_assistant_bubble and is_instance_valid(_current_assistant_bubble):
		if _current_assistant_bubble.text_content.begins_with("Düşünülüyor"):
			_current_assistant_bubble.set_message("assistant", "Düşünülüyor (%ds)..." % _thinking_elapsed_sec)
	# AGY 'init' handshake'i surerken durum rozetinde hazirlik bilgisi gosterilir.
	# Thinking timer DURDURULMAZ; yalnizca rozet metni degisir.
	if _agy_preparing:
		set_status_badge(AISidebarI18n.get_text("status_agy_preparing"), AISidebarTheme.COLOR_WARNING)
	elif _thinking_seen_this_turn:
		set_status_badge("Thinking (%ds)..." % _thinking_elapsed_sec, AISidebarTheme.COLOR_WARNING)
	else:
		set_status_badge("Waiting... (%ds)..." % _thinking_elapsed_sec, AISidebarTheme.COLOR_WARNING)

## AGY provider hazirlik durumu degisti (STARTING / INITIALIZING / READY).
## Yalnizca bilgilendirici rozet metni guncellenir; ajan durumu DEGISTIRILMEZ.
func _on_provider_readiness_changed(state: int, _message: String) -> void:
	if not provider or not provider.has_method("is_ready"):
		return
	_agy_preparing = not provider.is_ready()
	if _agy_preparing:
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
	status_badge.text = "⏸ Paused — Step %d/%d" % [cur, mx]
	status_badge.tooltip_text = "Devam etmek için 'devam et' yazın. Başka bir mesaj yeni task başlatır."
	status_badge.add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)

func _resume_paused_task(user_text: String) -> void:
	if _sessions.current == null:
		return
	var cp = _sessions.checkpoint_copy()
	_hide_welcome_card()
	_last_sent_vision_input = null
	_is_user_stopped = false
	_current_user_vision_inputs.clear()
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
	
	if action == "local_response":
		var cmd_bubble = AISidebarMessageBubble.new("command", raw_text)
		cmd_bubble.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(cmd_bubble)
		
		var reply_text = result.get("message", "")
		var assistant_bubble = AISidebarMessageBubble.new("assistant", reply_text)
		assistant_bubble.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(assistant_bubble)
		
		# /clear önceki sohbeti base listeye sabitler (ChatSessionStore).
		_sessions.record_local_command(raw_text, reply_text, cmd_name == "clear")
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
	_current_activity_group = null
	_current_reasoning_card = null
	_current_thinking_card = null
	_checklist_tracker.reset()
	_current_runtime_card = null
	_current_approval_card = null
	_is_user_stopped = false
	_current_user_vision_inputs = vision_inputs.duplicate()
	
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
	_current_user_vision_inputs.clear()
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

func _scroll_to_bottom() -> void:
	if not chat_scroll:
		return
	chat_scroll.set_deferred("scroll_vertical", 999999)

func _add_stream_component(comp: Control) -> void:
	if not message_stream:
		return
	message_stream.add_child(comp)
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
	match new_state:
		AISidebarAgentRunner.AgentState.IDLE, AISidebarAgentRunner.AgentState.COMPLETED:
			_stop_thinking_timer()
			var mode_txt = AISidebarPermissionPolicy.get_mode_name(AISidebarPermissionPolicy.get_auto_approve_mode())
			set_status_badge(state_desc + " [" + mode_txt + "]", AISidebarTheme.COLOR_SUCCESS)
		AISidebarAgentRunner.AgentState.PLANNING:
			# Yeni LLM turu: thinking kartı sıfırlanır (sonraki thinking yeni kart açar),
			# rozet yanıt gelene kadar "Waiting" gösterir (thinking varsayılmaz).
			_thinking_seen_this_turn = false
			_current_thinking_card = null
			_start_thinking_timer()
			set_status_badge("Waiting...", AISidebarTheme.COLOR_WARNING)
			if _current_assistant_bubble == null or not is_instance_valid(_current_assistant_bubble):
				_current_assistant_bubble = AISidebarMessageBubble.new("assistant", "Düşünülüyor...")
				_current_assistant_bubble.meta_clicked.connect(_on_meta_clicked)
				_add_stream_component(_current_assistant_bubble)
		AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL:
			_stop_thinking_timer()
			set_status_badge("Waiting Approval", AISidebarTheme.COLOR_WARNING)
		AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL:
			_stop_thinking_timer()
			set_status_badge(AISidebarI18n.get_text("status_waiting_plan"), AISidebarTheme.COLOR_WARNING)
		AISidebarAgentRunner.AgentState.RUNNING_GAME:
			_stop_thinking_timer()
			set_status_badge("Running Game", AISidebarTheme.COLOR_ACCENT)
		AISidebarAgentRunner.AgentState.DEBUGGING:
			_stop_thinking_timer()
			set_status_badge("Debugging", AISidebarTheme.COLOR_ERROR)
		AISidebarAgentRunner.AgentState.ERROR:
			_stop_thinking_timer()
			set_status_badge(state_desc, AISidebarTheme.COLOR_ERROR)
		_:
			set_status_badge(state_desc, AISidebarTheme.COLOR_WARNING)

## Canlı reasoning kartı (task başına tek; thinking yoksa oluşmaz).
func _ensure_reasoning_card() -> AISidebarReasoningCard:
	if _current_reasoning_card == null or not is_instance_valid(_current_reasoning_card):
		_current_reasoning_card = AISidebarReasoningCard.new()
		_current_reasoning_card.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(_current_reasoning_card)
	return _current_reasoning_card

## Eylem özeti yaz (ham reasoning asla karta girmez).
func _set_action_summary(line: String) -> void:
	if line == null or line.strip_edges().is_empty():
		return
	_ensure_reasoning_card().set_action(line.strip_edges().left(300))

## İsteğe bağlı thinking kartı (LLM turu başına bir; thinking yoksa oluşmaz).
func _ensure_thinking_card() -> AISidebarThinkingCard:
	if _current_thinking_card == null or not is_instance_valid(_current_thinking_card):
		_current_thinking_card = AISidebarThinkingCard.new()
		_current_thinking_card.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(_current_thinking_card)
	return _current_thinking_card

func _on_agent_thinking_received(thinking: String) -> void:
	if thinking == null or thinking.strip_edges().is_empty():
		return
	_thinking_seen_this_turn = true
	set_status_badge("Thinking...", AISidebarTheme.COLOR_WARNING)
	# Stream dışı final thinking: kart boşsa doldur (delta'larla duplicate olmaz).
	_ensure_thinking_card().set_thinking_final(thinking)

func _on_agent_chunk_received(text_delta: String, thinking_delta: String) -> void:
	_stop_thinking_timer()
	if thinking_delta != null and not thinking_delta.strip_edges().is_empty():
		_thinking_seen_this_turn = true
		set_status_badge("Thinking...", AISidebarTheme.COLOR_WARNING)
		_ensure_thinking_card().append_thinking(thinking_delta)
	if text_delta.is_empty():
		return
		
	if _current_activity_group:
		_current_activity_group.complete_group()
		_current_activity_group = null
		
	_stream_buffer += text_delta
	_render_stream_buffer()

## Tampondaki metinden tool-call zarflarini cikarip gorunur kismi balona yazar.
## Gorunur metin yoksa (saf zarf veya henuz yarim JSON) balon hic gosterilmez.
func _render_stream_buffer() -> void:
	var visible := AISidebarMessageBubble.strip_tool_call_envelopes(_stream_buffer, true).strip_edges()
	if visible.is_empty():
		# Saf zarf / yarim JSON: kullaniciya hicbir sey gosterme.
		if _current_assistant_bubble != null and is_instance_valid(_current_assistant_bubble):
			_current_assistant_bubble.queue_free()
			_current_assistant_bubble = null
		return
	if _current_assistant_bubble != null and is_instance_valid(_current_assistant_bubble):
		_current_assistant_bubble.set_message("assistant", visible)
	else:
		_current_assistant_bubble = AISidebarMessageBubble.new("assistant", visible)
		_current_assistant_bubble.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(_current_assistant_bubble)
	set_status_badge("AI Typing...", AISidebarTheme.COLOR_WARNING)
	if _auto_scroll_enabled:
		_scroll_to_bottom()

## Akış tamponunu sıfırla (yeni metin turu / temizleme).
func _reset_stream_buffer() -> void:
	_stream_buffer = ""
	_stream_is_envelope = false

func _on_agent_text_received(role: String, text: String) -> void:
	if _current_activity_group:
		_current_activity_group.complete_group()
		_current_activity_group = null
		
	if role == "assistant":
		# Ham tool-call zarflari metinden cikarilir; kullanici yalnizca gercek
		# asistan metnini gorur. Zarf hic yoksa metin aynen korunur.
		var clean_text := AISidebarMessageBubble.strip_tool_call_envelopes(text, false).strip_edges()
		if clean_text.is_empty():
			# Metnin tamami zarf (veya yarim JSON): hicbir sey gosterme.
			if _current_assistant_bubble != null and is_instance_valid(_current_assistant_bubble):
				_current_assistant_bubble.queue_free()
			_current_assistant_bubble = null
			_reset_stream_buffer()
			return
		if _current_assistant_bubble != null and is_instance_valid(_current_assistant_bubble):
			_current_assistant_bubble.finalize_stream(clean_text)
			_current_assistant_bubble = null
		else:
			var bubble = AISidebarMessageBubble.new(role, clean_text)
			bubble.meta_clicked.connect(_on_meta_clicked)
			_add_stream_component(bubble)
		_reset_stream_buffer()
	else:
		_current_assistant_bubble = null
		_reset_stream_buffer()
		var bubble_role = role
		if bubble_role == "user" and text.begins_with("/"):
			bubble_role = "command"
		var vi_for_bubble = _current_user_vision_inputs.duplicate() if bubble_role == "user" else []
		_current_user_vision_inputs.clear()
		var bubble = AISidebarMessageBubble.new(bubble_role, text, vi_for_bubble)
		bubble.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(bubble)

func _ensure_activity_group() -> AISidebarActivityGroup:
	if not _current_activity_group or not is_instance_valid(_current_activity_group) or not _current_activity_group.is_active:
		_current_activity_group = AISidebarActivityGroup.new(true)
		_current_activity_group.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(_current_activity_group)
		_activity_running_idx = -1
		_activity_running_tool = ""
	return _current_activity_group

func _on_agent_tool_executing(tool_name: String, args: Dictionary) -> void:
	_current_assistant_bubble = null
	# ask_user / propose_plan kart olarak gösterilir; activity satırı şişirmesin.
	if tool_name == "ask_user" or tool_name == "propose_plan":
		return
	var grp = _ensure_activity_group()
	grp.set_expanded(true)
	var human_title = AISidebarToolPresentation.human_title(tool_name, args)
	var details = "tool: " + tool_name + "\nargs: " + AISidebarActivityGroup.redact_secrets(JSON.stringify(args))
	if details.length() > 1500:
		details = details.left(1500) + "..."
	_activity_running_tool = tool_name
	_activity_tool_start_msec = Time.get_ticks_msec()
	_activity_running_idx = grp.add_activity("▶", "Running " + human_title, -1, details)
	_checklist_tracker.on_tool_start(tool_name, args)
	_set_action_summary("▶ " + human_title)
	if agent_context:
		agent_context.get_transcript().record("tool_executing", {"tool": tool_name, "title": human_title.left(200), "args": AISidebarActivityGroup.redact_secrets(JSON.stringify(args)).left(800)})
		agent_context.get_transcript().record("activity", {"icon": "▶", "title": "Running " + human_title.left(200)})

func _on_agent_tool_completed(tool_name: String, result: Dictionary) -> void:
	if tool_name == "ask_user" or tool_name == "propose_plan":
		return
	var grp = _ensure_activity_group()
	var err_code = ""
	if result.get("error") is Dictionary:
		err_code = str((result.get("error") as Dictionary).get("code", ""))
	var is_deferred = err_code.begins_with("DEFERRED")
	var outcome = AISidebarTaskTranscript.effective_tool_outcome(result)
	var is_ok = bool(outcome["success"])
	var icon = "•" if is_deferred else ("✓" if is_ok else "✕")
	var human_title = AISidebarToolPresentation.human_title(tool_name, {})
	var msg = str(result.get("message", "")).strip_edges()
	if not msg.is_empty() and msg.length() < 200 and not msg.contains("\"tool_calls\""):
		human_title = msg
	var elapsed = 100
	if _activity_tool_start_msec > 0:
		elapsed = Time.get_ticks_msec() - _activity_tool_start_msec
	_activity_tool_start_msec = 0
	var err_summary = "" if is_ok else AISidebarToolPresentation.tool_error(result)
	var details = AISidebarToolPresentation.tech_details(tool_name, {}, result)
	if _activity_running_idx >= 0 and _activity_running_tool == tool_name and _activity_running_idx < grp.get_item_count():
		grp.update_activity(_activity_running_idx, icon, human_title, elapsed, details, err_summary)
	else:
		grp.add_activity(icon, human_title + ("" if is_ok else ("\nError: " + err_summary)), elapsed, details)
	_activity_running_idx = -1
	_activity_running_tool = ""
	var action_base = AISidebarToolPresentation.human_title(tool_name, {})
	var action_line = icon + " " + action_base
	if not msg.is_empty() and msg != action_base:
		action_line += " — " + str(msg.split("\n")[0]).left(120)
	_set_action_summary(action_line)
	# Ertelenen çağrı hiç çalışmadı: checklist'i kirletme, sadece activity'de göster.
	if not is_deferred:
		_checklist_tracker.on_tool_done(tool_name, is_ok, err_summary)
	if agent_context:
		var completed_data = {"tool": tool_name, "title": human_title.left(200), "success": is_ok, "error": err_summary.left(500), "duration_ms": elapsed}
		var shot_path = AISidebarToolPresentation.screenshot_image_path(tool_name, result)
		if not shot_path.is_empty():
			completed_data["has_image"] = true
			completed_data["image_path"] = shot_path.left(300)
		agent_context.get_transcript().record("tool_completed", completed_data)
		agent_context.get_transcript().record("activity", {"icon": icon, "title": (human_title + ("" if is_ok else (" — Error: " + err_summary))).left(300)})
	_show_screenshot_preview(tool_name, result)

## AI screenshot'u chatte thumbnail kart olarak gösterir.
func _show_screenshot_preview(tool_name: String, result: Dictionary) -> void:
	var shot_path = AISidebarToolPresentation.screenshot_image_path(tool_name, result)
	if shot_path.is_empty():
		return
	var data = result.get("data", {}) as Dictionary
	var vi = null
	if not str(data.get("base64", "")).is_empty():
		vi = AISidebarVisionInput.new(
			shot_path,
			str(data.get("base64", "")),
			int(data.get("width", 0)),
			int(data.get("height", 0))
		)
	else:
		vi = AISidebarVisionInput.from_file(shot_path)
	if vi == null or vi.image_data_base64.is_empty():
		return
	var kind = str(data.get("capture_target", ""))
	if kind.is_empty():
		if tool_name == "take_viewport_screenshot":
			kind = "editor_viewport"
		elif tool_name == "take_editor_screenshot":
			kind = "editor"
		else:
			kind = "runtime_viewport"
	var capable = provider != null and provider.has_method("supports_vision") and provider.supports_vision()
	var card = AISidebarScreenshotCard.new(vi, kind, capable)
	card.meta_clicked.connect(_on_meta_clicked)
	_add_stream_component(card)

func _on_agent_clarification_requested(question: String, options: Array, clarification_id: String) -> void:
	_current_assistant_bubble = null
	_activity_running_idx = -1
	_activity_running_tool = ""
	if _current_activity_group:
		_current_activity_group.add_activity("✓", "Asked clarification", 50, "question: " + question.left(500))
		_current_activity_group.complete_group()
		_current_activity_group = null
	_set_action_summary("❓ " + question.left(120))
	if agent_context:
		agent_context.get_transcript().record("clarification_requested", {"question": question.left(500), "options": options.duplicate(), "id": clarification_id})

	var card = AISidebarClarificationCard.new(question, options)
	card.response_submitted.connect(func(ans: String):
		var grp = _ensure_activity_group()
		grp.add_activity("✓", "User selected: " + AISidebarActivityGroup.summarize_error(ans, 120), 50, "answer: " + str(ans).left(500))
		if agent_context:
			agent_context.get_transcript().record("clarification_answered", {"answer": str(ans).left(500)})
			agent_context.get_transcript().record("activity", {"icon": "✓", "title": ("User selected: " + ans).left(200)})
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
	if agent_context:
		agent_context.get_transcript().record("approval_requested", {"tool": tool_name})
	# NOT: change_set_dialog otomatik AÇILMAZ; yalnızca kullanıcı karttaki [View Diff] butonuna basarsa açılır.

func _on_approve_pressed() -> void:
	if _current_approval_card and is_instance_valid(_current_approval_card):
		_current_approval_card.mark_approved()
	if pending_change_set:
		last_applied_change_set = pending_change_set
	if agent_context:
		agent_context.get_transcript().record("approval_granted", {"tool": pending_tool_name})
	if agent_runner:
		agent_runner.approve_pending_action()

func _on_reject_pressed() -> void:
	if _current_approval_card and is_instance_valid(_current_approval_card):
		_current_approval_card.mark_rejected()
	if agent_context:
		agent_context.get_transcript().record("approval_rejected", {"tool": pending_tool_name})
	if agent_runner:
		agent_runner.reject_pending_action()

## Ajandan uygulama planı geldi. Execution HENÜZ başlamadı;
## kullanıcı onayı bekleniyor.
func _on_agent_plan_proposed(plan) -> void:
	_current_assistant_bubble = null
	if _current_activity_group:
		_current_activity_group.complete_group()
		_current_activity_group = null

	if not guard_plan_card_integrity(plan):
		return

	if agent_context:
		var p_steps = 0
		var p_files = 0
		var p_goal = ""
		if plan.get("steps") is Array:
			p_steps = (plan.get("steps") as Array).size()
		if plan.get("affected_files") is Array:
			p_files = (plan.get("affected_files") as Array).size()
		if plan.get("goal") != null:
			p_goal = str(plan.get("goal"))
		elif plan.get("title") != null:
			p_goal = str(plan.get("title"))
		agent_context.get_transcript().record("plan_proposed", {"steps": p_steps, "files": p_files, "goal": p_goal.left(300)})
	_set_action_summary("📋 Plan proposed — onay bekleniyor")
	_current_plan_card = AISidebarPlanCard.new(plan)
	_current_plan_card.plan_applied.connect(_on_plan_applied)
	_current_plan_card.plan_cancelled.connect(_on_plan_cancelled)
	_add_stream_component(_current_plan_card)
	if _auto_scroll_enabled:
		_scroll_to_bottom()

## Plan verisi kullanıcıya gösterilebilecek kadar anlamlı mı?
## (Eksik plan için boş kart göstermemek adına basit bir bütünlük kontrolü.)
func guard_plan_card_integrity(plan) -> bool:
	if plan == null or not plan.has_method("is_valid"):
		return false
	return plan.is_valid()

func _on_plan_applied() -> void:
	if _current_plan_card and is_instance_valid(_current_plan_card):
		_current_plan_card.mark_applied()
	if agent_context:
		agent_context.get_transcript().record("plan_approved", {})
		agent_context.get_transcript().record("activity", {"icon": "✓", "title": "Plan approved by user"})
	if _current_plan_card and is_instance_valid(_current_plan_card) and _current_plan_card.plan:
		var checklist = AISidebarTaskChecklist.new()
		checklist.setup(_current_plan_card.plan.steps, _current_plan_card.plan.goal)
		checklist.meta_clicked.connect(_on_meta_clicked)
		_checklist_tracker.checklist = checklist
		_add_stream_component(checklist)
		_checklist_tracker.attach(checklist)
	if agent_runner:
		agent_runner.approve_plan()

func _on_plan_cancelled() -> void:
	if _current_plan_card and is_instance_valid(_current_plan_card):
		_current_plan_card.mark_cancelled()
	if agent_context:
		agent_context.get_transcript().record("plan_rejected", {"reason": "User cancelled the plan."})
		agent_context.get_transcript().record("activity", {"icon": "✕", "title": "Plan rejected by user"})
	if agent_runner:
		agent_runner.reject_plan()

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
			grp.add_activity("✓", "Undo successful: changes reverted", 50)
		else:
			grp.add_activity("✕", "Undo failed: " + res.get("error", "Error"), 50)

func _on_agent_verification_started(tool_name: String) -> void:
	var grp = _ensure_activity_group()
	grp.add_activity("•", "Verifying " + tool_name + "...", -1)
	_set_action_summary("▶ Verifying " + tool_name)
	if agent_context:
		agent_context.get_transcript().record("verification_started", {"tool": tool_name})
		agent_context.get_transcript().record("activity", {"icon": "▶", "title": "Verifying " + tool_name})

func _on_agent_verification_completed(tool_name: String, is_valid: bool, msg: String) -> void:
	var grp = _ensure_activity_group()
	var icon = "✓" if is_valid else "!"
	grp.add_activity(icon, "Verification: " + msg, 50)
	_set_action_summary((icon + " Verification: " + msg).split("\n")[0])
	if agent_context:
		agent_context.get_transcript().record("verification_completed", {"tool": tool_name, "valid": is_valid, "message": msg.left(500)})
		agent_context.get_transcript().record("activity", {"icon": icon, "title": ("Verification: " + msg).left(300)})

func _on_agent_runtime_observation(obs: AISidebarRuntimeObservation) -> void:
	if not _current_runtime_card:
		_current_runtime_card = AISidebarRuntimeCard.new()
		_current_runtime_card.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(_current_runtime_card)
		
	if obs.has_errors():
		_current_runtime_card.add_status("✕", "Runtime Error: " + obs.format_diagnostic_prompt(), "#bf616a")
	else:
		_current_runtime_card.add_status("✓", "No runtime errors detected", "#a3be8c")
	if agent_context:
		agent_context.get_transcript().record("runtime_observation", {"summary": obs.format_diagnostic_prompt().left(1000), "has_errors": obs.has_errors()})

func _on_agent_debugging_started(summary: String) -> void:
	var grp = _ensure_activity_group()
	grp.add_activity("•", "Auto-diagnosing runtime error: " + summary, -1)
	if agent_context:
		agent_context.get_transcript().record("debugging_started", {"summary": summary.left(500)})

func _on_agent_step_progress(current_step: int, max_steps: int) -> void:
	set_status_badge("Step " + str(current_step) + " / " + str(max_steps), AISidebarTheme.COLOR_ACCENT)
	if _current_activity_group and is_instance_valid(_current_activity_group):
		_current_activity_group.set_step_progress(current_step, max_steps)

func _on_agent_task_completed(metrics: Dictionary) -> void:
	_current_assistant_bubble = null
	_current_reasoning_card = null
	_current_thinking_card = null
	_activity_running_idx = -1
	_activity_running_tool = ""
	var t_ok = bool(metrics.get("success", false))
	var completion = str(metrics.get("completion", "success" if t_ok else "failed"))
	var show_ok = t_ok and completion == "success"
	var done_reason = str(metrics.get("completion_reason", metrics.get("stop_reason", "")))
	_checklist_tracker.finish(show_ok, done_reason)
	_checklist_tracker.clear_tool_args()
	if agent_context and agent_context.get_transcript().has_running_task():
		var t_status = "completed" if show_ok else ("incomplete" if completion == "incomplete" else "failed")
		agent_context.end_task(t_status, done_reason, metrics)
	if _current_activity_group:
		var stop_reason = str(metrics.get("stop_reason", ""))
		if not stop_reason.is_empty():
			_current_activity_group.set_stop_reason(stop_reason)
		_current_activity_group.complete_group()
		_current_activity_group = null
		
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

## Limit / durma nedenini activity'de görünür satır + başlık olarak işler.
func report_task_stop(stop_reason: String, keep_open: bool = true) -> void:
	var grp = _ensure_activity_group()
	grp.add_activity("✕", "Task stopped\nError: " + AISidebarActivityGroup.summarize_error(stop_reason), 0, "stop_reason: " + stop_reason.left(500))
	grp.set_stop_reason(stop_reason)
	grp.complete_group_keep_open(keep_open)
	if keep_open:
		_current_activity_group = grp
	else:
		_current_activity_group = null

func _on_agent_error(err_msg: String) -> void:
	_current_assistant_bubble = null
	_current_reasoning_card = null
	_current_thinking_card = null
	_activity_running_idx = -1
	_activity_running_tool = ""
	_checklist_tracker.finish(false, err_msg)
	_checklist_tracker.clear_tool_args()
	if agent_context and agent_context.get_transcript().has_running_task():
		var e_status = "cancelled" if _is_user_stopped else "failed"
		agent_context.end_task(e_status, err_msg)
	# Stop/fail sonrası kaldığı noktadan devam için checkpoint üret.
	_refresh_pause_checkpoint()
	if _current_activity_group:
		if AISidebarToolPresentation.is_task_limit_error(err_msg):
			var grp = _current_activity_group
			grp.add_activity("✕", "Task stopped\nError: " + AISidebarActivityGroup.summarize_error(err_msg), 0, "stop_reason: " + err_msg.left(500))
			grp.set_stop_reason(err_msg)
			grp.complete_group_keep_open(true)
			# keep_open: limit satırı görünür kalsın diye grup referansı korunur,
			# sıradaki task yeni grup açar (ensure içinde is_active kontrolü yok;
			# task_completed / yeni executing yeni grup kurar).
		else:
			_current_activity_group.complete_group()
			_current_activity_group = null
		
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
