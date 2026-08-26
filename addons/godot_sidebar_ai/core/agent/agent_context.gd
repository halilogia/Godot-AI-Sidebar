@tool
extends RefCounted
class_name AISidebarAgentContext

## Ajan Konuşma Bağlamı, OpenAI Uyumlu Tool Call & Bellek Yöneticisi (SRP).

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

## OpenAI Uyumlu Assistant Tool Call mesajı ekler
func add_assistant_tool_call_message(text: String, tool_calls: Array) -> void:
	var tc_payload: Array = []
	for tc in tool_calls:
		var tc_id = tc.get("id", "")
		if tc_id.is_empty():
			tc_id = "call_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
		tc["id"] = tc_id # ID'yi nesne üzerinde de sabitle
		
		var args_str = ""
		if tc.get("arguments") is Dictionary:
			args_str = JSON.stringify(tc["arguments"])
		elif tc.get("arguments") is String:
			args_str = tc["arguments"]
		else:
			args_str = "{}"
			
		tc_payload.append({
			"id": tc_id,
			"type": "function",
			"function": {
				"name": tc.get("name", ""),
				"arguments": args_str
			}
		})
		
	var msg: Dictionary = {
		"role": "assistant",
		"tool_calls": tc_payload
	}
	if not text.is_empty():
		msg["content"] = text
	else:
		msg["content"] = null
		
	messages.append(msg)

## OpenAI Uyumlu Tool Sonucu mesajı ekler
func add_tool_result_message(tool_call_id: String, tool_name: String, result: Dictionary) -> void:
	recent_actions.append(tool_name)
	var final_id = tool_call_id
	if final_id.is_empty():
		final_id = "call_default"
		
	messages.append({
		"role": "tool",
		"tool_call_id": final_id,
		"name": tool_name,
		"content": JSON.stringify(result)
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

## Model API'sine gönderilmeden önce dinamik editör zeminlemesini (Grounding) ekler
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
func _auto_compact_if_needed(max_msgs: int = 18) -> void:
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
