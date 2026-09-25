@tool
extends RefCounted

## Aktif sohbet oturumunun kalıcı durumu (SRP, UI yok): oturum nesnesi, kaydet/yükle,
## temizle ve resume checkpoint'i.
## UI orkestrasyonu (akışı temizleme, rozetler, history paneli) ChatDock'ta kalır.
## Not: ChatManager.save_session başlığı ilk mesajdan üretebilir; kaydeden her yol sonrası
## ChatDock başlığı yeniler.

const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarTaskCheckpoint = preload("res://addons/godot_sidebar_ai/core/chat/task_checkpoint.gd")

var current: AISidebarChatSession = null
## Mesaj ve transcript kaynağı olan AgentContext (headless testlerde null olabilir).
var context = null
## LLM'siz yanıtlanan yerel komutlar (/help): oturumda ve History'de görünür, modele gitmez.
## Her kayıt "anchor" = eklendiği andaki context mesaj sayısı; kayıtta araya bu sırayla girer.
var _local_entries: Array = []

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
	_local_entries.clear()
	if context:
		context.clear()

func save() -> void:
	if current == null:
		return
	if context:
		current.messages = _merge_local_entries(context.messages)
		current.transcript_tasks = context.get_transcript().to_data()
	AISidebarChatManager.save_session(current)

## Diskten yükleyip context'i geri kurar. Bulunamazsa false (mevcut oturum değişmez).
func load_by_id(session_id: String) -> bool:
	var loaded = AISidebarChatManager.load_session(session_id)
	if not loaded:
		return false
	current = loaded
	_local_entries.clear()
	if context:
		context.clear()
		# Yerel komutlar (ve eski oturumlardaki "command" rolü) modele gitmez; ayrı tutulur.
		var ctx_msgs: Array = []
		for m in loaded.messages:
			if m is Dictionary and (bool(m.get("local", false)) or str(m.get("role", "")) == "command"):
				var e: Dictionary = m.duplicate(true)
				e["anchor"] = ctx_msgs.size()
				_local_entries.append(e)
			else:
				ctx_msgs.append(m.duplicate(true) if m is Dictionary else m)
		context.messages = ctx_msgs
		context.get_transcript().load_data(loaded.transcript_tasks)
	return true

## Clear butonu ve /clear: context ve oturum içeriği boşaltılır ve kaydedilir.
func clear_contents() -> void:
	if context:
		context.clear()
	_local_entries.clear()
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

## Yerel yanıtlanan slash komutunu (LLM'siz, örn. /help) oturuma yazar. Context varken
## modele giden mesajlara eklenmez; kayıtta doğru sıraya yerleştirilir (_merge_local_entries).
func record_local_command(raw_text: String, reply_text: String) -> void:
	ensure_session()
	var entries = [
		{"role": "command", "content": raw_text, "local": true},
		{"role": "assistant", "content": reply_text, "local": true},
	]
	if context:
		for e in entries:
			e["anchor"] = context.messages.size()
			_local_entries.append(e)
	else:
		current.messages.append_array(entries)
	save()

## Context mesajlarının arasına yerel kayıtları anchor sırasıyla yerleştirir. Compaction
## context'i kısaltırsa kayıt kaybolmaz, en sona kayar.
func _merge_local_entries(ctx_msgs: Array) -> Array:
	var out: Array = []
	var li := 0
	for i in ctx_msgs.size():
		while li < _local_entries.size() and int(_local_entries[li].get("anchor", 0)) <= i:
			out.append(_without_anchor(_local_entries[li]))
			li += 1
		out.append(ctx_msgs[i].duplicate(true) if ctx_msgs[i] is Dictionary else ctx_msgs[i])
	while li < _local_entries.size():
		out.append(_without_anchor(_local_entries[li]))
		li += 1
	return out

static func _without_anchor(e: Dictionary) -> Dictionary:
	var c = e.duplicate(true)
	c.erase("anchor")
	return c

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
