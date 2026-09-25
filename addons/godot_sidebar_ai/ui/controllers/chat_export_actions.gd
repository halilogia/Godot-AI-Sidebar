@tool
extends Node

## Sohbet dışa aktarma / kopyalama eylemleri (SRP): Export (md+json), Copy Chat,
## per-task Copy, History panelinden eski session export'u (FileDialog) ve durum rozeti flaşı.
## Veri kaynağı: AgentContext transcript'i ve aktif ChatSession (ChatDock'tan callable ile okunur).

const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

var agent_context: AISidebarAgentContext = null
## Aktif ChatSession'ı döndürür (oturum değiştikçe güncel kalsın diye callable).
var get_session: Callable = func(): return null
var status_badge: Label = null
var export_btn: Button = null
var copy_task_btn: Button = null

var _export_file_dialog: FileDialog = null
var _pending_history_export: Dictionary = {}

func _init() -> void:
	name = "ChatExportActions"

func _session():
	return get_session.call()

## Export: transcript + mesajları md/json olarak kaydeder ve md'yi panoya kopyalar.
func export_chat() -> void:
	var current_session = _session()
	var msgs: Array = []
	var transcript_tasks: Array = []
	if agent_context:
		msgs = agent_context.messages
		transcript_tasks = agent_context.get_transcript().to_data()
	if current_session and not current_session.transcript_tasks.is_empty() and transcript_tasks.is_empty():
		transcript_tasks = current_session.transcript_tasks.duplicate(true)

	if msgs.is_empty() and transcript_tasks.is_empty():
		return

	var cfg = AISidebarConfig.load_config()
	var session_meta = {
		"model": cfg.get("selected_model", "all"),
		"exported_at": Time.get_datetime_string_from_system()
	}
	if current_session and not current_session.telemetry.is_empty():
		session_meta.merge(current_session.telemetry)
	var md = AISidebarChatExporter.export_transcript_to_markdown(transcript_tasks, msgs, session_meta)
	DisplayServer.clipboard_set(md)
	AISidebarChatExporter.save_to_file(md, "md")
	var js = AISidebarChatExporter.export_transcript_to_json(transcript_tasks, msgs, session_meta)
	AISidebarChatExporter.save_to_file(js, "json")

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
		status_badge.text = AISidebarI18n.get_text("export_done")
		status_badge.add_theme_color_override("font_color", AISidebarTheme.COLOR_SUCCESS)
		var t = get_tree()
		if t:
			var timer = t.create_timer(2.0)
			timer.timeout.connect(func():
				if is_instance_valid(status_badge):
					status_badge.text = prev
			)

## Copy Chat: tüm taskların kronolojik transcriptini panoya kopyalar.
func copy_chat() -> void:
	if not agent_context:
		return
	var current_session = _session()
	var tasks = agent_context.get_transcript().to_data()
	if tasks.is_empty() and current_session and not current_session.transcript_tasks.is_empty():
		tasks = current_session.transcript_tasks.duplicate(true)
	if tasks.is_empty():
		flash_status_text("No chat yet")
		return
	var md = AISidebarChatExporter.export_full_chat_chronological(tasks)
	DisplayServer.clipboard_set(md)
	if copy_task_btn:
		copy_task_btn.text = AISidebarI18n.get_text("copy_done")
		var t = get_tree()
		if t:
			var timer = t.create_timer(1.5)
			timer.timeout.connect(func():
				if is_instance_valid(copy_task_btn):
					copy_task_btn.text = ""
			)
	flash_status_text("Chat copied")

## Per-task Copy: telemetry kartındaki task_id canlı transcriptten çözülür.
## Running task'ta kart yoktur (canlı mutasyon); bitmiş/durmuş tasklar kopyalanır.
func copy_single_task(task_id: String) -> void:
	if not agent_context:
		return
	var task = agent_context.get_transcript().get_task_by_id(task_id)
	if task.is_empty():
		flash_status_text("Task not found")
		return
	var md = AISidebarChatExporter.export_single_task_chronological(task)
	DisplayServer.clipboard_set(md)
	flash_status_text("Task copied")

## History panelinden eski session exportu: yükle -> içerik kur -> FileDialog.
func export_history_session(session_id: String, format: String) -> void:
	_pending_history_export.clear()
	var sess = AISidebarChatManager.load_session(session_id)
	if sess == null:
		flash_status_text("Export failed: session not found")
		return
	var built = AISidebarChatExporter.build_history_export(sess, format)
	if not bool(built.get("ok", false)):
		flash_status_text("Export failed: " + str(built.get("error", "unknown")))
		return
	_pending_history_export = built
	_ensure_export_file_dialog()
	_export_file_dialog.current_file = str(built.get("filename", "chat_export.md"))
	var flt = "*.json" if str(built.get("format", "md")) == "json" else "*.md"
	_export_file_dialog.filters = PackedStringArray([flt])
	_export_file_dialog.popup_centered()

func _ensure_export_file_dialog() -> void:
	if _export_file_dialog and is_instance_valid(_export_file_dialog):
		return
	_export_file_dialog = FileDialog.new()
	_export_file_dialog.title = "Export Chat"
	_export_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_file_dialog.file_selected.connect(_on_export_file_chosen)
	_export_file_dialog.canceled.connect(_on_export_file_canceled)
	add_child(_export_file_dialog)

func _on_export_file_chosen(path: String) -> void:
	var content = str(_pending_history_export.get("content", ""))
	_pending_history_export.clear()
	if content.is_empty():
		flash_status_text("Export failed: empty content")
		return
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		flash_status_text("Export failed: cannot write file")
		return
	f.store_string(content)
	f.close()
	flash_status_text("Chat exported: " + path.get_file())

func _on_export_file_canceled() -> void:
	_pending_history_export.clear()

## Durum rozetinde 2 sn geçici başarı metni gösterir, sonra önceki metne döner.
func flash_status_text(txt: String) -> void:
	if not status_badge:
		return
	var prev = status_badge.text
	status_badge.text = txt
	status_badge.add_theme_color_override("font_color", AISidebarTheme.COLOR_SUCCESS)
	var t = get_tree()
	if t:
		var timer = t.create_timer(2.0)
		timer.timeout.connect(func():
			if is_instance_valid(status_badge):
				status_badge.text = prev
		)
