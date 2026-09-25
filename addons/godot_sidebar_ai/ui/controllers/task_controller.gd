@tool
extends Node

## Görev akışı (SRP): girişten gönderme (slash komut / kuyruk / devam et / yeni task),
## task başlatma ve devam ettirme, kuyruk dağıtımı, pause checkpoint + Paused rozeti,
## task bitişi ve hata orkestrasyonu (oturum kaydı, telemetri kartı, görsel ekinin
## korunması, yeniden deneme). Görünüm sunumu presenter'larda; ChatDock bağlar.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarTaskCheckpoint = preload("res://addons/godot_sidebar_ai/core/chat/task_checkpoint.gd")
const AISidebarMentionManager = preload("res://addons/godot_sidebar_ai/core/chat/mention_manager.gd")
const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarTelemetryCard = preload("res://addons/godot_sidebar_ai/ui/components/telemetry_card.gd")
const AISidebarErrorCard = preload("res://addons/godot_sidebar_ai/ui/components/error_card.gd")
const AISidebarInputComposer = preload("res://addons/godot_sidebar_ai/ui/components/input_composer.gd")
const AISidebarMessageQueuePanel = preload("res://addons/godot_sidebar_ai/ui/components/message_queue_panel.gd")
const AISidebarHistoryPanel = preload("res://addons/godot_sidebar_ai/ui/components/history_panel.gd")
const AISidebarChatSessionStore = preload("res://addons/godot_sidebar_ai/ui/controllers/chat_session_store.gd")
const AISidebarChatExportActions = preload("res://addons/godot_sidebar_ai/ui/controllers/chat_export_actions.gd")
const AISidebarAgentStreamPresenter = preload("res://addons/godot_sidebar_ai/ui/presenters/agent_stream_presenter.gd")
const AISidebarAgentActivityPresenter = preload("res://addons/godot_sidebar_ai/ui/presenters/agent_activity_presenter.gd")
const AISidebarAgentInteractionPresenter = preload("res://addons/godot_sidebar_ai/ui/presenters/agent_interaction_presenter.gd")
const AISidebarPlanChecklistTracker = preload("res://addons/godot_sidebar_ai/ui/presenters/plan_checklist_tracker.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

# --- ChatDock'tan gelen bağımlılıklar ---
var input_field: TextEdit = null
var status_badge: Label = null
var composer: AISidebarInputComposer = null
var queue_panel: AISidebarMessageQueuePanel = null
var sessions: AISidebarChatSessionStore = null
var export_actions: AISidebarChatExportActions = null
var history_panel: AISidebarHistoryPanel = null
var stream: AISidebarAgentStreamPresenter = null
var activity: AISidebarAgentActivityPresenter = null
var interaction: AISidebarAgentInteractionPresenter = null
var checklist_tracker: AISidebarPlanChecklistTracker = null
## AgentContext / AgentRunner (headless testlerde null olabilir).
var context = null
var runner: AISidebarAgentRunner = null
## func(comp: Control) — bileşeni message stream'e ekler.
var add_component: Callable = func(_c): pass
## func(meta) — kartlardaki bağlantı tıklamaları.
var on_meta_clicked: Callable = func(_m): pass
## func() — dock metin/ikon/buton durumlarını yeniler.
var refresh_ui: Callable = func(): pass
var hide_welcome: Callable = func(): pass
var update_header: Callable = func(): pass
## func() — oturumu kaydedip başlığı yeniler.
var save_session: Callable = func(): pass
## func() — Clear butonu yolu (/clear).
var clear_chat: Callable = func(): pass

# --- Görev durumu ---
var last_user_prompt: String = ""
## Son başlatılan task'ın asıl isteği (retry için): {"prompt", "display", "vision"}.
## last_user_prompt ekrandaki metindir (ör. "/analyze"); modele giden istem burada tutulur.
var last_request: Dictionary = {}
## Kullanıcı Stop'a bastı: hata "cancelled" sayılır, kuyruk kendiliğinden dağıtılmaz.
var is_user_stopped: bool = false
# Pano Görseli Eki (Clipboard Image Attachment): hata olursa eke geri konur, retry'da tekrar gönderilir.
var last_sent_vision_input: AISidebarVisionInput = null

func _init() -> void:
	name = "TaskController"

## Çalışan task'ı kullanıcı adına durdurur (New Chat / History / Clear yolları).
func stop_by_user() -> void:
	if runner and runner.is_running():
		is_user_stopped = true
		runner.stop()

func submit_input() -> void:
	if not runner:
		return
		
	composer.hide_popup()
		
	var user_text = input_field.text.strip_edges()
	var attached_img = composer.attached_vision_input
	
	# Eğer metin boşsa ama ekli görsel varsa varsayılan soru metni ata
	if user_text.is_empty() and attached_img != null:
		user_text = "Bu görseli incele ve yardımcı ol."
	
	# Eğer metin boşsa ve kullanıcı 'Stop' butonuna bastıysa:
	if user_text.is_empty():
		if runner.is_running():
			is_user_stopped = true
			runner.stop()
			refresh_ui.call()
		return
		
	input_field.text = ""
	last_sent_vision_input = attached_img
	composer.clear_attached_image()
	is_user_stopped = false
	
	var vision_inputs: Array = []
	if attached_img != null:
		vision_inputs.append(attached_img)
	
	# 1. Slash Command Kontrolü (/)
	if user_text.begins_with("/"):
		var parsed_cmd = AISidebarSlashCommandManager.parse(user_text)
		if parsed_cmd.get("is_command", false):
			handle_slash_command(parsed_cmd, user_text)
			return
			
	# 2. Normal Mesaj Akışı: Eğer ajan şu anda başka bir görev çalıştırıyorsa -> Mesajı Kuyruğa Al
	if runner.is_running():
		queue_panel.enqueue(user_text, user_text, vision_inputs)
		return
		
	# 3. Continuation: boştayken resume komutu + resumable checkpoint varsa devam et
	if not runner.is_running() and AISidebarTaskCheckpoint.is_resume_command(user_text) and sessions.has_resumable_checkpoint():
		input_field.text = ""
		_resume_paused_task(user_text)
		return

	# Ajan boşta ise görevi hemen başlat
	start_task_prompt(user_text, "", vision_inputs)

func _active_scene_path_now() -> String:
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_edited_scene_root"):
		var edited = EditorInterface.get_edited_scene_root()
		if edited:
			return str(edited.scene_file_path)
	return ""

## Durmuş tasktan checkpoint üret, session'a yaz, Paused rozeti göster.
func refresh_pause_checkpoint() -> void:
	if runner == null:
		return
	var live = {
		"current_step": runner.current_step,
		"max_steps": runner.max_steps,
		"elapsed_s": runner.get_elapsed_s(),
	}
	var cp = sessions.store_pause_checkpoint(live, _active_scene_path_now())
	if cp.is_empty():
		return
	update_header.call()
	if bool(cp.get("resumable", false)):
		show_paused_badge(int(cp.get("current_step", 0)), int(cp.get("max_steps", 20)))

func show_paused_badge(cur: int, mx: int) -> void:
	if not status_badge:
		return
	status_badge.text = "Paused — Step %d/%d" % [cur, mx]
	status_badge.tooltip_text = "Devam etmek için 'devam et' yazın. Başka bir mesaj yeni task başlatır."
	status_badge.add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)

func _resume_paused_task(user_text: String) -> void:
	if sessions.current == null:
		return
	var cp = sessions.checkpoint_copy()
	hide_welcome.call()
	last_sent_vision_input = null
	is_user_stopped = false
	stream.user_vision_inputs.clear()
	var msg = AISidebarTaskCheckpoint.build_resume_message(cp)
	if runner and runner.resume_task(cp, msg, user_text):
		return
	# Checkpoint geçersizse güvenli düşüş: normal yeni task.
	start_task_prompt(user_text, "", [])

func handle_slash_command(parsed_cmd: Dictionary, raw_text: String) -> void:
	if parsed_cmd.has("error"):
		# Bilinmeyen slash komutu
		var cmd_bubble = AISidebarMessageBubble.new("command", raw_text)
		cmd_bubble.meta_clicked.connect(on_meta_clicked)
		add_component.call(cmd_bubble)
		
		var err_msg = parsed_cmd["error"] + "\n\nKullanılabilir komutları görmek için `/help` yazabilirsiniz."
		var err_bubble = AISidebarMessageBubble.new("assistant", err_msg)
		err_bubble.meta_clicked.connect(on_meta_clicked)
		add_component.call(err_bubble)
		return
		
	var cmd_name = parsed_cmd["name"]
	var cmd_args = parsed_cmd["args"]
	var exec_context = {"agent_context": context}
	var result = AISidebarSlashCommandManager.execute_command(cmd_name, cmd_args, exec_context)
	var action = result.get("action", "")
	
	if action == "clear_chat":
		clear_chat.call()
		return
		
	if action == "local_response":
		var cmd_bubble = AISidebarMessageBubble.new("command", raw_text)
		cmd_bubble.meta_clicked.connect(on_meta_clicked)
		add_component.call(cmd_bubble)
		
		var reply_text = result.get("message", "")
		var assistant_bubble = AISidebarMessageBubble.new("assistant", reply_text)
		assistant_bubble.meta_clicked.connect(on_meta_clicked)
		add_component.call(assistant_bubble)
		
		sessions.record_local_command(raw_text, reply_text)
		update_header.call()
		return
		
	elif action == "run_agent":
		var prompt = result.get("prompt", "")
		var display_prompt = result.get("display_prompt", raw_text)
		
		if runner.is_running():
			queue_panel.enqueue(prompt, display_prompt)
			return
			
		start_task_prompt(prompt, display_prompt)

func start_task_prompt(prompt_text: String, display_prompt: String = "", vision_inputs: Array = []) -> void:
	hide_welcome.call()
	var final_display = display_prompt if not display_prompt.is_empty() else prompt_text
	last_user_prompt = final_display
	last_request = {"prompt": prompt_text, "display": display_prompt, "vision": vision_inputs.duplicate()}
	activity.begin_task()
	stream.begin_task()
	checklist_tracker.reset()
	interaction.begin_task()
	is_user_stopped = false
	stream.user_vision_inputs = vision_inputs.duplicate()
	
	# Yeni task eskisini geçersiz kılar (devam yolu buradan geçmez).
	sessions.begin_new_task()
	update_header.call()

	var resolved_ctx = AISidebarMentionManager.resolve_prompt_context(prompt_text)
	if context:
		context.begin_task(prompt_text, final_display)
	runner.start_task(resolved_ctx["augmented_prompt"], final_display, vision_inputs)

func dispatch_next_queued() -> void:
	if is_user_stopped:
		return
		
	if queue_panel.count() > 0:
		var next_item = queue_panel.pop_next()
		if next_item is Dictionary and next_item.has("prompt"):
			var next_prompt = str(next_item["prompt"])
			var next_disp = str(next_item.get("display_prompt", next_prompt))
			var q_vision = next_item.get("vision_inputs", [])
			var t = get_tree()
			if t:
				t.create_timer(0.05).timeout.connect(func():
					start_task_prompt(next_prompt, next_disp, q_vision)
				)
			else:
				start_task_prompt(next_prompt, next_disp, q_vision)

func on_task_completed(metrics: Dictionary) -> void:
	stream.end_task()
	activity.clear_running()
	var t_ok = bool(metrics.get("success", false))
	var completion = str(metrics.get("completion", "success" if t_ok else "failed"))
	var show_ok = t_ok and completion == "success"
	var done_reason = str(metrics.get("completion_reason", metrics.get("stop_reason", "")))
	checklist_tracker.finish(show_ok, done_reason)
	checklist_tracker.clear_tool_args()
	if context and context.get_transcript().has_running_task():
		var t_status = "completed" if show_ok else ("incomplete" if completion == "incomplete" else "failed")
		context.end_task(t_status, done_reason, metrics)
	activity.finish_task(str(metrics.get("stop_reason", "")))
		
	var telemetry_comp = AISidebarTelemetryCard.new(metrics)
	if context:
		telemetry_comp.task_id = str(context.get_transcript().get_current_task().get("id", ""))
	telemetry_comp.copy_task_requested.connect(export_actions.copy_single_task)
	add_component.call(telemetry_comp)
	refresh_ui.call()
	
	if sessions.current:
		sessions.current.telemetry = metrics.duplicate(true)
		if t_ok:
			# Başarıyla biten taskın resume ihtiyacı kalmaz.
			sessions.current.checkpoint = {}
		else:
			refresh_pause_checkpoint()
		save_session.call()
		if history_panel and history_panel.visible:
			history_panel.refresh_list()
			
	dispatch_next_queued()
	last_sent_vision_input = null

func on_error(err_msg: String) -> void:
	stream.end_task()
	activity.clear_running()
	checklist_tracker.finish(false, err_msg)
	checklist_tracker.clear_tool_args()
	if context and context.get_transcript().has_running_task():
		var e_status = "cancelled" if is_user_stopped else "failed"
		context.end_task(e_status, err_msg)
	# Stop/fail sonrası kaldığı noktadan devam için checkpoint üret.
	refresh_pause_checkpoint()
	activity.stop_on_error(err_msg)
		
	# Hata durumunda veya model reddettiğinde görsel ekinin kaybolmasını önle (P2 UX Fix)
	if last_sent_vision_input != null and composer.attached_vision_input == null:
		composer.attach_vision_input(last_sent_vision_input)

	var err_comp = AISidebarErrorCard.new(err_msg)
	err_comp.retry_requested.connect(retry_last_task)
	add_component.call(err_comp)
	refresh_ui.call()
	
	dispatch_next_queued()

## Hata kartındaki Retry: son isteği normal task hattından (mention çözümleme, yeni transcript
## görevi, checkpoint sıfırlama, görsel eki) yeniden başlatır. Ajan çalışıyorsa yok sayılır.
func retry_last_task() -> void:
	if last_request.is_empty() or runner == null or runner.is_running():
		return
	start_task_prompt(str(last_request["prompt"]), str(last_request["display"]), (last_request["vision"] as Array).duplicate())
