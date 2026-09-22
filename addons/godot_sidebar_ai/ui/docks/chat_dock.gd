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
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")
const AISidebarMentionManager = preload("res://addons/godot_sidebar_ai/core/chat/mention_manager.gd")
const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarHistoryPanel = preload("res://addons/godot_sidebar_ai/ui/components/history_panel.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")
const AISidebarUITelemetryTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")

@onready var title_label: Label = $MainLayout/HeaderBar/TitleLabel
@onready var status_badge: Label = $MainLayout/HeaderBar/StatusBadge
@onready var new_chat_btn: Button = $MainLayout/HeaderBar/NewChatBtn
@onready var history_btn: Button = $MainLayout/HeaderBar/HistoryBtn
@onready var export_btn: Button = $MainLayout/HeaderBar/ExportBtn
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
var current_session: AISidebarChatSession = null
var history_panel: AISidebarHistoryPanel = null

# Kuyruktaki Mesajlar (FIFO Message Queue)
var _message_queue: Array[Dictionary] = []
var _is_user_stopped: bool = false
var _queue_container: PanelContainer = null
var _queue_title_label: Label = null
var _queue_items_vbox: VBoxContainer = null
var _queue_clear_btn: Button = null

# Pano Görseli Eki (Clipboard Image Attachment)
var _attached_vision_input: AISidebarVisionInput = null
var _last_sent_vision_input: AISidebarVisionInput = null
var _current_user_vision_inputs: Array = []
var _attachment_container: PanelContainer = null
var _attachment_preview: TextureRect = null
var _attachment_label: Label = null
var _attachment_remove_btn: Button = null

var _current_activity_group: AISidebarActivityGroup = null
var _current_runtime_card: AISidebarRuntimeCard = null
var _current_approval_card: AISidebarApprovalCard = null
var _current_assistant_bubble: AISidebarMessageBubble = null
var _auto_scroll_enabled: bool = true

var _active_mention_suggestions: Array[Dictionary] = []
var _active_mention_query_info: Dictionary = {}
var _active_slash_suggestions: Array[Dictionary] = []
var _active_slash_query_info: Dictionary = {}
var _session_base_messages: Array = []

func _exit_tree() -> void:
	if provider and provider.has_method("stop_process"):
		provider.stop_process()

func _setup_provider() -> void:
	var cfg = AISidebarConfig.load_config()
	var prov_type = cfg.get("provider_type", "antigravity_cli")
	
	if provider:
		if provider.has_method("stop_process"):
			provider.stop_process()
		if provider.models_fetched.is_connected(_on_models_fetched):
			provider.models_fetched.disconnect(_on_models_fetched)
			
	if prov_type == "openai_compatible":
		if not network_manager:
			network_manager = AISidebarNetworkManager.new()
			add_child(network_manager)
		provider = AISidebarOpenAICompatibleProvider.new(network_manager)
	else:
		provider = AISidebarAGYProvider.new()
		
	provider.models_fetched.connect(_on_models_fetched)
	if agent_runner:
		agent_runner.set_provider(provider)

func _ready() -> void:
	_setup_history_panel()
	_setup_queue_ui()
	_setup_attachment_ui()
	_apply_theme()
	if not Engine.is_editor_hint():
		return
		
	AISidebarUITelemetryTools.register_sidebar_dock(self)
	
	# 1. Katmanların Başlatılması
	network_manager = AISidebarNetworkManager.new()
	add_child(network_manager)
	
	agent_context = AISidebarAgentContext.new()
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
		export_btn.pressed.connect(_on_export_pressed)
	if input_field:
		input_field.gui_input.connect(_on_input_gui_input)
		input_field.text_changed.connect(_on_input_text_changed)
	if mention_list:
		mention_list.item_activated.connect(_on_mention_item_activated)

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

func _apply_theme() -> void:
	# 1. Root PanelContainer & Background
	add_theme_stylebox_override("panel", AISidebarTheme.create_app_bg_style())
	
	# 2. MainLayout & Container Gaps
	if has_node("MainLayout"):
		$MainLayout.add_theme_constant_override("separation", AISidebarTheme.SPACE_SM)
	if has_node("MainLayout/HeaderBar"):
		$MainLayout/HeaderBar.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	if has_node("MainLayout/ModelBar"):
		$MainLayout/ModelBar.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	if has_node("MainLayout/InputArea"):
		$MainLayout/InputArea.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	if has_node("MainLayout/InputArea/ButtonsBar"):
		$MainLayout/InputArea/ButtonsBar.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)

	# 3. HeaderBar Typography & Buttons
	if title_label:
		title_label.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_HEADER)
		title_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	if status_badge:
		status_badge.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	if new_chat_btn:
		new_chat_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_ghost_button_style(false))
		new_chat_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_ghost_button_style(true))
		new_chat_btn.add_theme_stylebox_override("pressed", AISidebarTheme.create_ghost_button_style(true))
		new_chat_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		new_chat_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
		new_chat_btn.add_theme_color_override("font_hover_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	if history_btn:
		history_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_ghost_button_style(false))
		history_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_ghost_button_style(true))
		history_btn.add_theme_stylebox_override("pressed", AISidebarTheme.create_ghost_button_style(true))
		history_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		history_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
		history_btn.add_theme_color_override("font_hover_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	if export_btn:
		export_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_ghost_button_style(false))
		export_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_ghost_button_style(true))
		export_btn.add_theme_stylebox_override("pressed", AISidebarTheme.create_ghost_button_style(true))
		export_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		export_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
		export_btn.add_theme_color_override("font_hover_color", AISidebarTheme.COLOR_TEXT_PRIMARY)

	# 4. ModelBar
	if model_selector:
		model_selector.add_theme_stylebox_override("normal", AISidebarTheme.create_input_style())
		model_selector.add_theme_stylebox_override("hover", AISidebarTheme.create_card_hover_style())
		model_selector.add_theme_stylebox_override("pressed", AISidebarTheme.create_card_active_style())
		model_selector.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
		model_selector.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	if approve_mode_btn:
		approve_mode_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XXS))
		approve_mode_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_card_hover_style(AISidebarTheme.SPACE_XXS))
		approve_mode_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	if refresh_models_btn:
		refresh_models_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_ghost_button_style(false))
		refresh_models_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_ghost_button_style(true))
		refresh_models_btn.add_theme_stylebox_override("pressed", AISidebarTheme.create_ghost_button_style(true))
	if settings_btn:
		settings_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_ghost_button_style(false))
		settings_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_ghost_button_style(true))
		settings_btn.add_theme_stylebox_override("pressed", AISidebarTheme.create_ghost_button_style(true))

	# 5. Message Stream
	if message_stream:
		message_stream.add_theme_constant_override("separation", AISidebarTheme.SPACE_SM)

	# 6. Mention Popup
	if mention_container:
		mention_container.add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS))
	if mention_list:
		mention_list.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)

	# 7. Input Area & Buttons
	if input_field:
		input_field.add_theme_stylebox_override("normal", AISidebarTheme.create_input_style())
		input_field.add_theme_stylebox_override("focus", AISidebarTheme.create_input_focus_style())
		input_field.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
		input_field.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
		input_field.add_theme_color_override("font_placeholder_color", AISidebarTheme.COLOR_TEXT_MUTED)
	if clear_btn:
		clear_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_ghost_button_style(false))
		clear_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_ghost_button_style(true))
		clear_btn.add_theme_stylebox_override("pressed", AISidebarTheme.create_ghost_button_style(true))
		clear_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
		clear_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
		clear_btn.add_theme_color_override("font_hover_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	if jump_to_bottom_btn:
		jump_to_bottom_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XXS))
		jump_to_bottom_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_card_hover_style(AISidebarTheme.SPACE_XXS))
		jump_to_bottom_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		jump_to_bottom_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)

	_update_send_button_style()

func _update_send_button_style() -> void:
	if not send_btn:
		return
	if agent_runner and agent_runner.is_running():
		var stop_normal = StyleBoxFlat.new()
		stop_normal.bg_color = AISidebarTheme.COLOR_ERROR
		stop_normal.set_corner_radius_all(AISidebarTheme.RADIUS_MD)
		stop_normal.content_margin_left = AISidebarTheme.SPACE_MD
		stop_normal.content_margin_right = AISidebarTheme.SPACE_MD
		stop_normal.content_margin_top = AISidebarTheme.SPACE_XS + 1
		stop_normal.content_margin_bottom = AISidebarTheme.SPACE_XS + 1
		var stop_hover = stop_normal.duplicate()
		stop_hover.bg_color = AISidebarTheme.COLOR_ERROR_HOVER
		send_btn.add_theme_stylebox_override("normal", stop_normal)
		send_btn.add_theme_stylebox_override("hover", stop_hover)
		send_btn.add_theme_stylebox_override("pressed", stop_normal)
	else:
		send_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_accent_button_style(false, false))
		send_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_accent_button_style(true, false))
		send_btn.add_theme_stylebox_override("pressed", AISidebarTheme.create_accent_button_style(false, true))
	send_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_WHITE)
	send_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)

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
	history_panel.close_requested.connect(_on_history_close_requested)

func _setup_queue_ui() -> void:
	if not has_node("MainLayout/InputArea"):
		return
	var input_area = $MainLayout/InputArea
	
	_queue_container = PanelContainer.new()
	_queue_container.name = "QueueContainer"
	_queue_container.visible = false
	_queue_container.add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS))
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XXS)
	
	var header = HBoxContainer.new()
	_queue_title_label = Label.new()
	_queue_title_label.text = "Queued Messages (0)"
	_queue_title_label.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	_queue_title_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	header.add_child(_queue_title_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	_queue_clear_btn = Button.new()
	_queue_clear_btn.text = "Clear All"
	_queue_clear_btn.flat = true
	_queue_clear_btn.focus_mode = Control.FOCUS_NONE
	_queue_clear_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_ghost_button_style(false))
	_queue_clear_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_ghost_button_style(true))
	_queue_clear_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	_queue_clear_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_ERROR)
	_queue_clear_btn.pressed.connect(_clear_all_queue)
	header.add_child(_queue_clear_btn)
	vbox.add_child(header)
	
	_queue_items_vbox = VBoxContainer.new()
	_queue_items_vbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XXS)
	vbox.add_child(_queue_items_vbox)
	
	_queue_container.add_child(vbox)
	input_area.add_child(_queue_container)
	input_area.move_child(_queue_container, 0)

func _setup_attachment_ui() -> void:
	if not input_area or not input_field:
		return
		
	_attachment_container = PanelContainer.new()
	_attachment_container.name = "AttachmentContainer"
	_attachment_container.visible = false
	_attachment_container.add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XXS))
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	
	_attachment_preview = TextureRect.new()
	_attachment_preview.custom_minimum_size = Vector2(32, 32)
	_attachment_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_attachment_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(_attachment_preview)
	
	_attachment_label = Label.new()
	_attachment_label.text = "📷 Pano Görseli"
	_attachment_label.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	_attachment_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	_attachment_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attachment_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_attachment_label.clip_text = true
	hbox.add_child(_attachment_label)
	
	_attachment_remove_btn = Button.new()
	_attachment_remove_btn.text = "✕"
	_attachment_remove_btn.flat = true
	_attachment_remove_btn.focus_mode = Control.FOCUS_NONE
	_attachment_remove_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	_attachment_remove_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_ERROR)
	_attachment_remove_btn.tooltip_text = "Görseli kaldır"
	_attachment_remove_btn.pressed.connect(_clear_attached_image)
	hbox.add_child(_attachment_remove_btn)
	
	_attachment_container.add_child(hbox)
	input_area.add_child(_attachment_container)
	input_area.move_child(_attachment_container, input_field.get_index())

func _attach_vision_input(vi: AISidebarVisionInput) -> void:
	if vi == null:
		return
	_attached_vision_input = vi
	if _attachment_preview:
		_attachment_preview.texture = vi.get_texture()
	if _attachment_label:
		_attachment_label.text = "📷 Pano Görseli (%dx%d)" % [vi.width, vi.height]
	if _attachment_container:
		_attachment_container.visible = true

func _attach_image_from_clipboard(img: Image) -> void:
	if not img or img.is_empty():
		return
	var vi = AISidebarVisionInput.from_image(img)
	_attach_vision_input(vi)

func _clear_attached_image() -> void:
	_attached_vision_input = null
	if _attachment_container:
		_attachment_container.visible = false
	if _attachment_preview:
		_attachment_preview.texture = null

func update_ui_language() -> void:
	if export_btn:
		AISidebarIconHelper.apply_icon(export_btn, "download")
		export_btn.tooltip_text = "Sohbeti Dışa Aktar / Kopyala (Export Chat)"
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
		_update_send_button_style()
			
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
	if current_session and not current_session.telemetry.is_empty():
		session_meta.merge(current_session.telemetry)
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
		status_badge.text = "Exported"
		status_badge.add_theme_color_override("font_color", AISidebarTheme.COLOR_SUCCESS)
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

func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Pano Görseli Yapıştırma (Clipboard Image Paste - Ctrl+V / Cmd+V)
		if (event.ctrl_pressed or event.meta_pressed) and not event.alt_pressed and not event.shift_pressed and event.keycode == KEY_V:
			if DisplayServer.has_method("clipboard_has_image") and DisplayServer.clipboard_has_image():
				var img = DisplayServer.clipboard_get_image()
				if img and not img.is_empty():
					_attach_image_from_clipboard(img)
					accept_event()
					return

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

func _on_mention_item_activated(index: int) -> void:
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

# --- Chat Management Olayları ve Yardımcıları ---

func set_history_view_visible(is_visible: bool) -> void:
	if history_panel:
		history_panel.visible = is_visible
		if is_visible:
			history_panel.set_active_session(current_session.id if current_session else "")
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
	if current_session and current_session.id == session_id:
		return
	_load_session_by_id(session_id)

func _on_history_session_deleted(session_id: String) -> void:
	if current_session and current_session.id == session_id:
		_start_new_chat_session()

func _on_history_session_renamed(session_id: String, new_title: String) -> void:
	if current_session and current_session.id == session_id:
		current_session.title = new_title
		_update_header_title()

func _on_history_close_requested() -> void:
	set_history_view_visible(false)

func _start_new_chat_session() -> void:
	if agent_runner and agent_runner.is_running():
		_is_user_stopped = true
		agent_runner.stop()
		
	if current_session and agent_context and not agent_context.messages.is_empty():
		_save_current_session()
		
	current_session = AISidebarChatSession.new()
	_session_base_messages.clear()
	if agent_context:
		agent_context.clear()
		
	_clear_all_queue()
	_clear_ui_stream()
	_update_header_title()
	if history_panel:
		history_panel.set_active_session(current_session.id)
	set_status_badge(AISidebarI18n.get_text("status_ready"), AISidebarTheme.COLOR_SUCCESS)

func _save_current_session() -> void:
	if current_session == null:
		return
	if agent_context:
		var combined = _session_base_messages.duplicate(true)
		combined.append_array(agent_context.messages)
		current_session.messages = combined
	AISidebarChatManager.save_session(current_session)
	_update_header_title()

func _load_session_by_id(session_id: String) -> void:
	if current_session and current_session.id != session_id and agent_context and not agent_context.messages.is_empty():
		_save_current_session()
		
	if agent_runner and agent_runner.is_running():
		_is_user_stopped = true
		agent_runner.stop()
		
	var loaded = AISidebarChatManager.load_session(session_id)
	if not loaded:
		_start_new_chat_session()
		return
		
	current_session = loaded
	_session_base_messages.clear()
	if agent_context:
		agent_context.clear()
		agent_context.messages = loaded.messages.duplicate(true)
		
	_clear_all_queue()
	_clear_ui_stream()
	_rebuild_ui_stream_from_session(loaded)
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
		
	for m in sess.messages:
		if not m is Dictionary:
			continue
		var role = str(m.get("role", ""))
		var content = m.get("content", "")
		
		if role == "user" or role == "command" or role == "slash_command":
			var txt = ""
			var vision_inputs: Array = []
			if m.has("display_text") and not str(m["display_text"]).is_empty():
				txt = str(m["display_text"])
			elif content is String:
				txt = content
			elif content is Array:
				for part in content:
					if part is Dictionary:
						if part.get("type") == "text":
							txt = str(part.get("text", ""))
						elif part.get("type") == "image_url":
							vision_inputs.append(part)
			if m.has("vision_inputs") and m["vision_inputs"] is Array:
				for vi in m["vision_inputs"]:
					if not vision_inputs.has(vi):
						vision_inputs.append(vi)
			if txt.contains("\n\n==="):
				var parts_prompt = txt.split("\n\n===")
				txt = parts_prompt[0]
			var bubble_role = role
			if bubble_role == "user" and txt.begins_with("/"):
				bubble_role = "command"
			var bubble = AISidebarMessageBubble.new(bubble_role, txt, vision_inputs)
			bubble.meta_clicked.connect(_on_meta_clicked)
			_add_stream_component(bubble)
			
		elif role == "assistant":
			var txt = str(content) if content != null else ""
			if not txt.is_empty():
				var bubble = AISidebarMessageBubble.new("assistant", txt)
				bubble.meta_clicked.connect(_on_meta_clicked)
				_add_stream_component(bubble)
				
			if m.has("tool_calls") and m["tool_calls"] is Array:
				var tcs = m["tool_calls"]
				if tcs.size() > 0:
					var grp = AISidebarActivityGroup.new(false)
					grp.meta_clicked.connect(_on_meta_clicked)
					for tc in tcs:
						if tc is Dictionary:
							var fn = tc.get("name", "")
							var args = tc.get("arguments", {})
							grp.add_activity("✓", _get_human_tool_title(fn, args), 100, JSON.stringify(args))
					grp.complete_group()
					_add_stream_component(grp)
					
		elif role == "tool":
			var fn_name = str(m.get("name", ""))
			var raw_content = m.get("content", "{}")
			var parsed = JSON.parse_string(str(raw_content))
			if fn_name == "ask_user" and parsed is Dictionary and parsed.has("data"):
				var d = parsed["data"]
				var q = str(d.get("question", ""))
				var a = str(d.get("user_answer", ""))
				var card = AISidebarClarificationCard.new(q, [])
				card._ready()
				card.is_answered = true
				if card._options_container:
					card._options_container.visible = false
				if card._input_container:
					card._input_container.visible = false
				if card._status_lbl:
					card._status_lbl.text = "✓ Answered: " + a
					card._status_lbl.visible = true
				_add_stream_component(card)
				
	if not sess.telemetry.is_empty():
		var tc = AISidebarTelemetryCard.new(sess.telemetry)
		_add_stream_component(tc)

func _clear_ui_stream() -> void:
	if message_stream:
		for child in message_stream.get_children():
			child.queue_free()
	_current_activity_group = null
	_current_runtime_card = null
	_current_approval_card = null
	_current_assistant_bubble = null

func _update_header_title() -> void:
	if title_label:
		if current_session and not current_session.title.is_empty() and current_session.title != "New Chat":
			title_label.text = "Godot AI - " + current_session.title
			title_label.tooltip_text = current_session.title
		else:
			title_label.text = "Godot AI"
			title_label.tooltip_text = "Godot AI Assistant"

func _on_send_pressed() -> void:
	if not agent_runner:
		return
		
	if mention_container:
		mention_container.visible = false
		
	var user_text = input_field.text.strip_edges()
	var attached_img = _attached_vision_input
	
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
	_clear_attached_image()
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
		var queue_item = {
			"id": "q_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000),
			"prompt": user_text,
			"display_prompt": user_text,
			"created_at": Time.get_unix_time_from_system(),
			"vision_inputs": vision_inputs
		}
		_message_queue.append(queue_item)
		_update_queue_ui()
		return
		
	# Ajan boşta ise görevi hemen başlat
	_start_task_prompt(user_text, "", vision_inputs)

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
		
		if current_session == null:
			current_session = AISidebarChatSession.new()
			
		if cmd_name == "clear":
			# Önceki sohbet geçmişini base listeye sabitle
			_session_base_messages = current_session.messages.duplicate(true)
			_session_base_messages.append({"role": "command", "content": raw_text})
			_session_base_messages.append({"role": "assistant", "content": reply_text})
			current_session.messages = _session_base_messages.duplicate(true)
			if agent_context:
				agent_context.clear()
		else:
			current_session.messages.append({"role": "command", "content": raw_text})
			current_session.messages.append({"role": "assistant", "content": reply_text})
			
		_save_current_session()
		return
		
	elif action == "run_agent":
		var prompt = result.get("prompt", "")
		var display_prompt = result.get("display_prompt", raw_text)
		
		if agent_runner.is_running():
			var queue_item = {
				"id": "q_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000),
				"prompt": prompt,
				"display_prompt": display_prompt,
				"created_at": Time.get_unix_time_from_system()
			}
			_message_queue.append(queue_item)
			_update_queue_ui()
			return
			
		_start_task_prompt(prompt, display_prompt)

func _start_task_prompt(prompt_text: String, display_prompt: String = "", vision_inputs: Array = []) -> void:
	var final_display = display_prompt if not display_prompt.is_empty() else prompt_text
	last_user_prompt = final_display
	_current_activity_group = null
	_current_runtime_card = null
	_current_approval_card = null
	_is_user_stopped = false
	_current_user_vision_inputs = vision_inputs.duplicate()
	
	if current_session == null:
		current_session = AISidebarChatSession.new()
	_save_current_session()
	
	var resolved_ctx = AISidebarMentionManager.resolve_prompt_context(prompt_text)
	agent_runner.start_task(resolved_ctx["augmented_prompt"], final_display, vision_inputs)

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
		_queue_title_label.text = "Queued Messages (%d)" % _message_queue.size()
		
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
		var label_text = str(item.get("display_prompt", item.get("prompt", ""))).replace("\n", " ")
		prompt_label.text = label_text
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
	_clear_attached_image()
	_current_user_vision_inputs.clear()
	if mention_container:
		mention_container.visible = false
	if agent_runner and agent_runner.is_running():
		_is_user_stopped = true
		agent_runner.stop()
	if agent_context:
		agent_context.clear()
	_session_base_messages.clear()
	if current_session:
		current_session.messages.clear()
		current_session.telemetry.clear()
		_save_current_session()
	_clear_all_queue()
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
	if _auto_scroll_enabled:
		_scroll_to_bottom()

# --- Ajan Sinyal Dinleyicileri (Presentation) ---

func _on_agent_state_changed(new_state: AISidebarAgentRunner.AgentState, state_desc: String) -> void:
	update_ui_language()
	match new_state:
		AISidebarAgentRunner.AgentState.IDLE, AISidebarAgentRunner.AgentState.COMPLETED:
			var mode_txt = AISidebarPermissionPolicy.get_mode_name(AISidebarPermissionPolicy.get_auto_approve_mode())
			set_status_badge(state_desc + " [" + mode_txt + "]", AISidebarTheme.COLOR_SUCCESS)
		AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL:
			set_status_badge("Waiting Approval", AISidebarTheme.COLOR_WARNING)
		AISidebarAgentRunner.AgentState.RUNNING_GAME:
			set_status_badge("Running Game", AISidebarTheme.COLOR_ACCENT)
		AISidebarAgentRunner.AgentState.DEBUGGING:
			set_status_badge("Debugging", AISidebarTheme.COLOR_ERROR)
		AISidebarAgentRunner.AgentState.ERROR:
			set_status_badge(state_desc, AISidebarTheme.COLOR_ERROR)
		_:
			set_status_badge(state_desc, AISidebarTheme.COLOR_WARNING)

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
		set_status_badge("AI Typing...", AISidebarTheme.COLOR_WARNING)
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
		var bubble_role = role
		if bubble_role == "user" and text.begins_with("/"):
			bubble_role = "command"
		var vi_for_bubble = _current_user_vision_inputs.duplicate() if bubble_role == "user" else []
		_current_user_vision_inputs.clear()
		var bubble = AISidebarMessageBubble.new(bubble_role, text, vi_for_bubble)
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
			grp.add_activity("✓", "Undo successful: changes reverted", 50)
		else:
			grp.add_activity("✕", "Undo failed: " + res.get("error", "Error"), 50)

func _on_agent_verification_started(tool_name: String) -> void:
	var grp = _ensure_activity_group()
	grp.add_activity("•", "Verifying " + tool_name + "...", -1)

func _on_agent_verification_completed(tool_name: String, is_valid: bool, msg: String) -> void:
	var grp = _ensure_activity_group()
	var icon = "✓" if is_valid else "!"
	grp.add_activity(icon, "Verification: " + msg, 50)

func _on_agent_runtime_observation(obs: AISidebarRuntimeObservation) -> void:
	if not _current_runtime_card:
		_current_runtime_card = AISidebarRuntimeCard.new()
		_current_runtime_card.meta_clicked.connect(_on_meta_clicked)
		_add_stream_component(_current_runtime_card)
		
	if obs.has_errors():
		_current_runtime_card.add_status("✕", "Runtime Error: " + obs.format_diagnostic_prompt(), "#bf616a")
	else:
		_current_runtime_card.add_status("✓", "No runtime errors detected", "#a3be8c")

func _on_agent_debugging_started(summary: String) -> void:
	var grp = _ensure_activity_group()
	grp.add_activity("•", "Auto-diagnosing runtime error: " + summary, -1)

func _on_agent_step_progress(current_step: int, max_steps: int) -> void:
	set_status_badge("Step " + str(current_step) + " / " + str(max_steps), AISidebarTheme.COLOR_ACCENT)

func _on_agent_task_completed(metrics: Dictionary) -> void:
	_current_assistant_bubble = null
	if _current_activity_group:
		_current_activity_group.complete_group()
		_current_activity_group = null
		
	var telemetry_comp = AISidebarTelemetryCard.new(metrics)
	_add_stream_component(telemetry_comp)
	update_ui_language()
	
	if current_session:
		current_session.telemetry = metrics.duplicate(true)
		_save_current_session()
		if history_panel and history_panel.visible:
			history_panel.refresh_list()
			
	_check_and_dispatch_next_queue()
	_last_sent_vision_input = null

func _on_agent_error(err_msg: String) -> void:
	_current_assistant_bubble = null
	if _current_activity_group:
		_current_activity_group.complete_group()
		_current_activity_group = null
		
	# Hata durumunda veya model reddettiğinde görsel ekinin kaybolmasını önle (P2 UX Fix)
	if _last_sent_vision_input != null and _attached_vision_input == null:
		_attach_vision_input(_last_sent_vision_input)

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
