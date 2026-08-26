@tool
extends RefCounted
class_name AISidebarAgentContext

## Ajan Konuşma Bağlamı, Kısa Vadeli Görev Belleği & Sıkıştırma (Memory & Compaction) (SRP).

const AISidebarEditorStateSnapshot = preload("res://addons/godot_sidebar_ai/core/state/editor_state_snapshot.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarSourceMapper = preload("res://addons/godot_sidebar_ai/core/runtime/source_mapper.gd")

var messages: Array = []
var recent_actions: Array = []

func clear() -> void:
	messages.clear()
	recent_actions.clear()

func size() -> int:
	return messages.size()

func add_user_message(text: String, _grounding: bool = false) -> void:
	messages.append({
		"role": "user",
		"content": text
	})
	_auto_compact_if_needed()

func add_assistant_message(text: String) -> void:
	messages.append({
		"role": "assistant",
		"content": text
	})

func add_tool_result_message(tool_name: String, result: Dictionary) -> void:
	recent_actions.append(tool_name)
	messages.append({
		"role": "user",
		"content": "Araç '" + tool_name + "' tamamlandı:\n" + JSON.stringify(result, "\t")
	})
	_auto_compact_if_needed()

func add_runtime_error_context(obs: AISidebarRuntimeObservation) -> void:
	var error_prompt = obs.format_diagnostic_prompt()
	var snippet_prompt = ""
	if obs.errors.size() > 0:
		var e0 = obs.errors[0]
		var f_path = e0.get("file", "")
		var l_num = e0.get("line", 0)
		if not f_path.is_empty() and l_num > 0:
			snippet_prompt = "\n" + AISidebarSourceMapper.get_source_snippet(f_path, l_num, 4)
			
	messages.append({
		"role": "user",
		"content": "⚠️ ÇALIŞMA ZAMANI HATASI TESPİT EDİLDİ:\n" + error_prompt + snippet_prompt + "\n\nLütfen hatayı inceleyip düzeltecek ChangeSet'i önerin."
	})
	_auto_compact_if_needed()

## Model API'sine gönderilmeden önce dinamik editör zeminlemesini (Grounding) enjekte eder
func get_messages_for_api() -> Array:
	var api_messages: Array = []
	
	# Dinamik Editör Durumu (Aktif Sahne, Seçili Düğüm, Açık Script)
	var grounding = AISidebarEditorStateSnapshot.get_grounding_prompt_text()
	api_messages.append({
		"role": "user",
		"content": grounding
	})
	
	for m in messages:
		api_messages.append(m)
		
	return api_messages

## Bağlam Şişmesini Önleyen Otomatik Sıkıştırma (Compaction)
func _auto_compact_if_needed(max_msgs: int = 16) -> void:
	if messages.size() <= max_msgs:
		return
		
	var keep_count = 6
	var old_msgs = messages.slice(0, messages.size() - keep_count)
	var recent_msgs = messages.slice(messages.size() - keep_count)
	
	var summary_text = "[ÖNCEKİ AJAN GÖREV ÖZETİ (" + str(old_msgs.size()) + " adım)]: Kullanıcı istekleri ve araç çalıştırmaları işlendi. Son tamamlanan eylemler: " + ", ".join(recent_actions.slice(-4))
	
	messages = [
		{"role": "user", "content": summary_text}
	]
	messages.append_array(recent_msgs)
