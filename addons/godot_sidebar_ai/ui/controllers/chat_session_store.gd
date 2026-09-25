@tool
extends RefCounted

## Aktif sohbet oturumunun kalıcı durumu (SRP, UI yok): oturum nesnesi, /clear öncesi
## sabitlenen base mesajlar, kaydet/yükle, temizle ve resume checkpoint'i.
## UI orkestrasyonu (akışı temizleme, rozetler, history paneli) ChatDock'ta kalır.
## Not: ChatManager.save_session başlığı ilk mesajdan üretebilir; kaydeden her yol sonrası
## ChatDock başlığı yeniler.

const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarTaskCheckpoint = preload("res://addons/godot_sidebar_ai/core/chat/task_checkpoint.gd")

var current: AISidebarChatSession = null
## Mesaj ve transcript kaynağı olan AgentContext (headless testlerde null olabilir).
var context = null
## /clear komutu öncesi sohbet: kayıtta context mesajlarının önüne eklenir.
var _base_messages: Array = []

func is_current(session_id: String) -> bool:
	return current != null and current.id == session_id

func current_id() -> String:
	return current.id if current else ""

func ensure_session() -> void:
	if current == null:
		current = AISidebarChatSession.new()

## Context'te henüz kaydedilmemiş olabilecek mesaj var mı?
func has_live_messages() -> bool:
	return current != null and context != null and not context.messages.is_empty()

func start_new() -> void:
	current = AISidebarChatSession.new()
	_base_messages.clear()
	if context:
		context.clear()

func save() -> void:
	if current == null:
		return
	if context:
		var combined = _base_messages.duplicate(true)
		combined.append_array(context.messages)
		current.messages = combined
		current.transcript_tasks = context.get_transcript().to_data()
	AISidebarChatManager.save_session(current)

## Diskten yükleyip context'i geri kurar. Bulunamazsa false (mevcut oturum değişmez).
func load_by_id(session_id: String) -> bool:
	var loaded = AISidebarChatManager.load_session(session_id)
	if not loaded:
		return false
	current = loaded
	_base_messages.clear()
	if context:
		context.clear()
		context.messages = loaded.messages.duplicate(true)
		context.get_transcript().load_data(loaded.transcript_tasks)
	return true

## Clear butonu: context, base mesajlar ve oturum içeriği boşaltılır ve kaydedilir.
func clear_contents() -> void:
	if context:
		context.clear()
	_base_messages.clear()
	if current:
		current.messages.clear()
		current.telemetry.clear()
		current.transcript_tasks.clear()
		current.checkpoint = {}
		save()

func rename_if_current(session_id: String, new_title: String) -> bool:
	if not is_current(session_id):
		return false
	current.title = new_title
	return true

## Yerel yanıtlanan slash komutunu (LLM'siz) oturuma yazar. /clear önceki sohbeti
## base listeye sabitler ve context'i boşaltır.
func record_local_command(raw_text: String, reply_text: String, is_clear: bool) -> void:
	ensure_session()
	if is_clear:
		_base_messages = current.messages.duplicate(true)
		_base_messages.append({"role": "command", "content": raw_text})
		_base_messages.append({"role": "assistant", "content": reply_text})
		current.messages = _base_messages.duplicate(true)
		if context:
			context.clear()
	else:
		current.messages.append({"role": "command", "content": raw_text})
		current.messages.append({"role": "assistant", "content": reply_text})
	save()

# --- Resume checkpoint (session'da tek slot) ---

func has_resumable_checkpoint() -> bool:
	return current != null and current.checkpoint is Dictionary and bool(current.checkpoint.get("resumable", false))

func checkpoint_copy() -> Dictionary:
	return (current.checkpoint as Dictionary).duplicate(true)

## Yeni task eskisinin checkpoint'ini geçersiz kılar (devam yolu buradan geçmez).
func begin_new_task() -> void:
	ensure_session()
	current.checkpoint = {}
	save()

## Durmuş tasktan checkpoint üretip oturuma yazar. Üretilemezse {} döner (kayıt yok).
## live: {current_step, max_steps, elapsed_s} (AgentRunner'dan).
func store_pause_checkpoint(live: Dictionary, active_scene_path: String) -> Dictionary:
	if context == null or current == null:
		return {}
	var task = context.get_transcript().get_current_task()
	if task.is_empty():
		return {}
	var cp_live = {
		"current_step": live.get("current_step", 0),
		"maximum_steps": live.get("max_steps", 20),
		"elapsed_s": live.get("elapsed_s", 0),
	}
	cp_live["max_steps"] = cp_live["maximum_steps"]
	var cp = AISidebarTaskCheckpoint.build(task, cp_live, active_scene_path)
	current.checkpoint = cp
	save()
	return cp
