@tool
extends Control

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

@onready var title_label: Label = $MainLayout/HeaderBar/TitleLabel
@onready var lang_toggle_btn: Button = $MainLayout/HeaderBar/LangToggleBtn
@onready var status_badge: Label = $MainLayout/HeaderBar/StatusBadge
@onready var model_selector: OptionButton = $MainLayout/ModelBar/ModelSelector
@onready var refresh_models_btn: Button = $MainLayout/ModelBar/RefreshModelsBtn
@onready var settings_btn: Button = $MainLayout/ModelBar/SettingsBtn
@onready var chat_log: RichTextLabel = $MainLayout/ChatLog
@onready var approval_bar: HBoxContainer = $MainLayout/ApprovalBar
@onready var approve_btn: Button = $MainLayout/ApprovalBar/ApproveBtn
@onready var view_diff_btn: Button = $MainLayout/ApprovalBar/ViewDiffBtn
@onready var reject_btn: Button = $MainLayout/ApprovalBar/RejectBtn
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
	agent_runner.text_received.connect(_on_agent_text_received)
	agent_runner.tool_executing.connect(_on_agent_tool_executing)
	agent_runner.tool_completed.connect(_on_agent_tool_completed)
	agent_runner.approval_requested.connect(_on_agent_approval_requested)
	agent_runner.verification_started.connect(_on_agent_verification_started)
	agent_runner.verification_completed.connect(_on_agent_verification_completed)
	agent_runner.runtime_observation_received.connect(_on_agent_runtime_observation)
	agent_runner.debugging_started.connect(_on_agent_debugging_started)
	agent_runner.error_occurred.connect(_on_agent_error)
	agent_runner.task_completed.connect(_on_agent_task_completed)
	provider.models_fetched.connect(_on_models_fetched)

	# 2. UI Olayları
	if chat_log:
		chat_log.meta_clicked.connect(_on_chat_meta_clicked)
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_pressed)
	if send_btn:
		send_btn.pressed.connect(_on_send_pressed)
	if approve_btn:
		approve_btn.pressed.connect(_on_approve_pressed)
	if view_diff_btn:
		view_diff_btn.pressed.connect(_on_view_diff_pressed)
	if reject_btn:
		reject_btn.pressed.connect(_on_reject_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if refresh_models_btn:
		refresh_models_btn.pressed.connect(_on_refresh_models_pressed)
	if lang_toggle_btn:
		lang_toggle_btn.pressed.connect(_on_lang_toggle_pressed)
	if input_field:
		input_field.gui_input.connect(_on_input_gui_input)
	if model_selector:
		model_selector.item_selected.connect(_on_model_selected)
	if settings_dialog:
		settings_dialog.settings_saved.connect(_on_settings_saved)
	if change_set_dialog:
		change_set_dialog.action_approved.connect(_on_approve_pressed)
		change_set_dialog.action_rejected.connect(_on_reject_pressed)

	# 3. Başlangıç Yüklemesi
	update_ui_language()
	_load_cached_models()
	if provider:
		provider.fetch_models()

func update_ui_language() -> void:
	var current_lang = AISidebarI18n.get_current_language().to_upper()
	if lang_toggle_btn:
		lang_toggle_btn.text = current_lang
		lang_toggle_btn.tooltip_text = AISidebarI18n.get_text("tooltip_lang")
		
	if title_label:
		title_label.text = AISidebarI18n.get_text("app_title")
	if model_selector:
		model_selector.tooltip_text = AISidebarI18n.get_text("tooltip_model")
	if refresh_models_btn:
		refresh_models_btn.tooltip_text = AISidebarI18n.get_text("tooltip_refresh")
	if settings_btn:
		settings_btn.tooltip_text = AISidebarI18n.get_text("tooltip_settings")
	if input_field:
		input_field.placeholder_text = AISidebarI18n.get_text("input_placeholder")
	if clear_btn:
		clear_btn.text = AISidebarI18n.get_text("btn_clear")
		
	if send_btn:
		if agent_runner and agent_runner.is_running():
			send_btn.text = "⏹ " + AISidebarI18n.get_text("btn_stop")
			send_btn.tooltip_text = AISidebarI18n.get_text("tooltip_stop")
		else:
			send_btn.text = AISidebarI18n.get_text("btn_send")
			send_btn.tooltip_text = ""

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
	set_status_badge(AISidebarI18n.get_text("status_ready"), Color(0.4, 0.8, 0.4))

func _on_refresh_models_pressed() -> void:
	if provider:
		set_status_badge(AISidebarI18n.get_text("status_refreshing"), Color(1.0, 0.8, 0.2))
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
		if event.keycode == KEY_ENTER and (event.ctrl_pressed or event.shift_pressed):
			accept_event()
			_on_send_pressed()

func _on_send_pressed() -> void:
	if not agent_runner:
		return
		
	if agent_runner.is_running():
		agent_runner.stop()
		return
		
	var user_text = input_field.text.strip_edges()
	if user_text.is_empty():
		return
		
	last_user_prompt = user_text
	input_field.text = ""
	agent_runner.start_task(user_text)

func _on_clear_pressed() -> void:
	if agent_runner and agent_runner.is_running():
		agent_runner.stop()
	if agent_context:
		agent_context.clear()
	if chat_log:
		chat_log.clear()

func _on_approve_pressed() -> void:
	if approval_bar:
		approval_bar.visible = false
	if pending_change_set:
		last_applied_change_set = pending_change_set
	if agent_runner:
		agent_runner.approve_pending_action()

func _on_reject_pressed() -> void:
	if approval_bar:
		approval_bar.visible = false
	if agent_runner:
		agent_runner.reject_pending_action()

func _on_view_diff_pressed() -> void:
	if change_set_dialog:
		change_set_dialog.show_change_set(pending_tool_name, pending_tool_args, pending_change_set)

func _on_chat_meta_clicked(meta: Variant) -> void:
	var m_str = str(meta)
	match m_str:
		"action:approve":
			_on_approve_pressed()
		"action:reject":
			_on_reject_pressed()
		"action:view_diff":
			_on_view_diff_pressed()
		"action:undo":
			if last_applied_change_set:
				var res = last_applied_change_set.rollback()
				if res.get("success", false):
					append_chat_message("↩ Geri Alma", "Son uygulanan değişiklikler başarıyla geri alındı.", "#a3be8c")
				else:
					append_chat_message("❌ Geri Alma", "Geri alma başarısız: " + res.get("error", "Bilinmeyen hata"), "#bf616a")
		_:
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

# --- Ajan Sinyal Dinleyicileri (Presentation) ---

func _on_agent_state_changed(new_state: AISidebarAgentRunner.AgentState, state_desc: String) -> void:
	update_ui_language()
	
	if approval_bar:
		approval_bar.visible = (new_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL)
		
	match new_state:
		AISidebarAgentRunner.AgentState.IDLE, AISidebarAgentRunner.AgentState.COMPLETED:
			set_status_badge(state_desc, Color(0.4, 0.8, 0.4))
		AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL:
			set_status_badge("⏳ " + state_desc, Color(1.0, 0.5, 0.2))
		AISidebarAgentRunner.AgentState.RUNNING_GAME:
			set_status_badge("▶ " + state_desc, Color(0.3, 0.7, 1.0))
		AISidebarAgentRunner.AgentState.DEBUGGING:
			set_status_badge("🐞 " + state_desc, Color(1.0, 0.4, 0.4))
		AISidebarAgentRunner.AgentState.ERROR:
			set_status_badge("❌ " + state_desc, Color(1.0, 0.3, 0.3))
		_:
			set_status_badge("⚡ " + state_desc, Color(1.0, 0.8, 0.2))

func _on_agent_thinking_received(thinking: String) -> void:
	if not chat_log:
		return
	var title = AISidebarI18n.get_text("thinking_title")
	chat_log.append_text("[color=#a6adc8][font_size=11]╭── " + title + " ──[/font_size][/color]\n")
	chat_log.append_text("[color=#9399b2][font_size=11][i]" + thinking + "[/i][/font_size][/color]\n")
	chat_log.append_text("[color=#a6adc8][font_size=11]╰──────────────────────────[/font_size][/color]\n\n")

func _on_agent_text_received(role: String, text: String) -> void:
	if role == "user":
		append_chat_message(AISidebarI18n.get_text("sender_user"), text, "#ffffff")
	else:
		append_chat_message(AISidebarI18n.get_text("sender_assistant"), text, "#88c0d0")

func _on_agent_tool_executing(tool_name: String, args: Dictionary) -> void:
	append_chat_message("⚡ Agent", "İşlem yürütülüyor: [b]" + tool_name + "[/b]", "#d08770")

func _on_agent_approval_requested(tool_name: String, args: Dictionary, cs: AISidebarChangeSet) -> void:
	pending_tool_name = tool_name
	pending_tool_args = args
	pending_change_set = cs
	
	if not chat_log:
		return
		
	chat_log.append_text("[color=#ebcb8b][font_size=12][b]⏳ Değişiklik Onayı Gerekli[/b][/font_size][/color]\n")
	if cs:
		chat_log.append_text(cs.get_bbcode_diff() + "\n")
	else:
		chat_log.append_text("[color=#d8dee9]İşlem: " + tool_name + " (" + JSON.stringify(args) + ")[/color]\n")
		
	chat_log.append_text("[color=#88c0d0][url=action:view_diff]🔍 [b]Diff Gör[/b][/url][/color]   [color=#a3be8c][url=action:approve]✓ [b]Uygula (Approve)[/b][/url][/color]   [color=#bf616a][url=action:reject]✕ [b]Reddet (Reject)[/b][/url][/color]\n\n")
	
	if change_set_dialog:
		change_set_dialog.show_change_set(tool_name, args, cs)

func _on_agent_verification_started(tool_name: String) -> void:
	append_chat_message("🔍 Doğrulama", "İşlem doğrulanıyor: " + tool_name, "#81a1c1")

func _on_agent_verification_completed(tool_name: String, is_valid: bool, msg: String) -> void:
	if is_valid:
		append_chat_message("✓ Doğrulandı", msg, "#a3be8c")
	else:
		append_chat_message("⚠️ Doğrulama Uyarısı", msg, "#bf616a")

func _on_agent_runtime_observation(obs: AISidebarRuntimeObservation) -> void:
	if obs.has_errors():
		append_chat_message("⚠ Çalışma Zamanı Hatası", "Oyun çalışırken hata tespit edildi (" + str(obs.errors.size()) + " hata):\n[color=#bf616a]" + obs.format_diagnostic_prompt() + "[/color]", "#bf616a")

func _on_agent_debugging_started(summary: String) -> void:
	append_chat_message("🐞 Teşhis & Onarım", "Ajan çalışma zamanı hatasını inceliyor: [b]" + summary + "[/b]", "#d08770")

func _on_agent_tool_completed(tool_name: String, result: Dictionary) -> void:
	if result.get("success", false):
		var msg = result.get("message", "")
		if msg.is_empty():
			msg = "Tamamlandı."
		append_chat_message("✓ " + tool_name, msg, "#a3be8c")
	else:
		var err_obj = result.get("error", {})
		var err_msg = "Hata"
		if err_obj is Dictionary and err_obj.has("message"):
			err_msg = err_obj["message"]
		elif result.has("error") and result["error"] is String:
			err_msg = result["error"]
		append_chat_message("❌ " + tool_name, err_msg, "#bf616a")

func _on_agent_task_completed(metrics: Dictionary) -> void:
	if not chat_log:
		return
	var is_ok = metrics.get("success", true)
	var status_hdr = "[b][color=#a3be8c]✓ Görev Tamamlandı[/color][/b]" if is_ok else "[b][color=#bf616a]✕ Görev Sonlandı[/color][/b]"
	var elapsed = str(metrics.get("elapsed_seconds", 0.0)) + "s"
	var llm_s = str(metrics.get("llm_time_s", 0.0)) + "s"
	var tool_s = str(metrics.get("tool_time_s", 0.0)) + "s"
	var file_s = str(metrics.get("file_time_s", 0.0)) + "s"
	var runtime_s = str(metrics.get("runtime_time_s", 0.0)) + "s"
	var wait_s = str(metrics.get("waiting_time_s", 0.0)) + "s"
	
	var llm_turns = str(metrics.get("llm_turns", 0))
	var tool_calls = str(metrics.get("tool_calls", 0))
	var file_ops = str(metrics.get("file_ops", 0))
	var editor_ops = str(metrics.get("editor_ops", 0))
	var verify_cps = str(metrics.get("verification_checkpoints", 0))
	
	chat_log.append_text("[color=#4c566a][font_size=11]╭── 📊 Görev Metrikleri (Telemetri) ──────────────────[/font_size][/color]\n")
	chat_log.append_text(status_hdr + " [color=#81a1c1](Toplam: " + elapsed + ")[/color]\n")
	chat_log.append_text("[font_size=11][color=#d8dee9]• Süre Dağılımı: LLM: " + llm_s + "  |  Araçlar: " + tool_s + " (Dosya: " + file_s + ", Runtime: " + runtime_s + ")  |  Bekleme: " + wait_s + "\n")
	chat_log.append_text("• İşlem Sayısı: " + llm_turns + " LLM Dönüşü · " + tool_calls + " Araç · " + file_ops + " Dosya (File-First) · " + editor_ops + " Editör · " + verify_cps + " Doğrulama[/color][/font_size]\n")
	if last_applied_change_set:
		chat_log.append_text("[color=#88c0d0][url=action:undo]↩ [b]Son Değişikliği Geri Al (Undo)[/b][/url][/color]\n")
	chat_log.append_text("[color=#4c566a][font_size=11]╰─────────────────────────────────────────────────────[/font_size][/color]\n\n")

func _on_agent_error(err_msg: String) -> void:
	append_chat_message(AISidebarI18n.get_text("sender_error"), "❌ " + err_msg, "#bf616a")

func append_chat_message(sender: String, message: String, color_hex: String = "#ffffff") -> void:
	if not chat_log:
		return
	chat_log.append_text("[b][color=" + color_hex + "]" + sender + ":[/color][/b] " + message + "\n\n")

func set_status_badge(txt: String, color: Color) -> void:
	if status_badge:
		status_badge.text = txt
		status_badge.add_theme_color_override("font_color", color)
