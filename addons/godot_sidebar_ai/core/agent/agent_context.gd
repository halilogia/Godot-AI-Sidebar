@tool
extends RefCounted
class_name AISidebarAgentContext

## Ajan Konuşma Bağlamı, OpenAI Uyumlu Tool Call & Bellek Yöneticisi (SRP).

const AISidebarEditorStateSnapshot = preload("res://addons/godot_sidebar_ai/core/state/editor_state_snapshot.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarSourceMapper = preload("res://addons/godot_sidebar_ai/core/runtime/source_mapper.gd")
const AISidebarContextCompactor = preload("res://addons/godot_sidebar_ai/core/agent/context_compactor.gd")

const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")

var messages: Array = []
var recent_actions: Array = []
## Compaction'a uğramayan tam transcript (Everything Export / Copy Task kaynağı).
var transcript: AISidebarTaskTranscript = null

func _init() -> void:
	transcript = AISidebarTaskTranscript.new()

func get_transcript() -> AISidebarTaskTranscript:
	if transcript == null:
		transcript = AISidebarTaskTranscript.new()
	return transcript

func begin_task(prompt: String, display_prompt: String = "") -> String:
	return get_transcript().begin_task(prompt, display_prompt)

func end_task(status: String, stop_reason: String = "", metrics: Dictionary = {}) -> void:
	get_transcript().end_task(status, stop_reason, metrics)

func clear() -> void:
	messages.clear()
	recent_actions.clear()
	get_transcript().clear()

func size() -> int:
	return messages.size()

func add_user_message(text: String, _grounding: bool = false, display_text: String = "", vision_inputs: Array = []) -> void:
	var msg = {
		"role": "user",
		"content": text
	}
	if not display_text.is_empty():
		msg["display_text"] = display_text
	if vision_inputs.size() > 0:
		var v_parts: Array = []
		for vi in vision_inputs:
			if vi is AISidebarVisionInput:
				v_parts.append(vi.to_openai_content_part())
			elif vi is Dictionary:
				v_parts.append(vi)
		msg["vision_inputs"] = v_parts
	messages.append(msg)
	get_transcript().record("user", {"text": AISidebarTaskTranscript.truncate_text(text, 2000), "display_text": AISidebarTaskTranscript.truncate_text(display_text, 500), "has_images": vision_inputs.size() > 0})
	_auto_compact_if_needed()

func add_assistant_message(text: String) -> void:
	messages.append({
		"role": "assistant",
		"content": text
	})
	get_transcript().record("assistant", {"text": AISidebarTaskTranscript.truncate_text(text, 2000)})

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
	var tc_summary: Array = []
	for tc in tool_calls:
		var tc_entry = {"name": str(tc.get("name", "")), "id": str(tc.get("id", ""))}
		# Plan ve clarification içerikleri export için gerekli; diğer araçların
		# büyük argümanları (dosya içerikleri) transcript'i şişirmesin.
		var tc_nm = str(tc.get("name", ""))
		if tc_nm == "propose_plan" or tc_nm == "ask_user":
			tc_entry["args"] = AISidebarTaskTranscript.truncate_text(JSON.stringify(tc.get("arguments", {})), 4000)
		tc_summary.append(tc_entry)
	get_transcript().record("tool_call", {"text": AISidebarTaskTranscript.truncate_text(text, 1000), "calls": tc_summary})

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
	var res_data = {
		"tool": tool_name,
		"success": bool(result.get("success", false)),
		"message": AISidebarTaskTranscript.truncate_text(str(result.get("message", "")), 500),
	}
	if tool_name == "ask_user" and result.get("data") is Dictionary:
		var d: Dictionary = result["data"]
		res_data["question"] = AISidebarTaskTranscript.truncate_text(str(d.get("question", "")), 500)
		res_data["user_answer"] = AISidebarTaskTranscript.truncate_text(str(d.get("user_answer", "")), 500)
	get_transcript().record("tool_result", res_data)
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
	get_transcript().record("runtime_observation", {"summary": AISidebarTaskTranscript.truncate_text(error_prompt, 1000), "has_errors": true})
	_auto_compact_if_needed()

## Model API'sine gönderilmeden önce dinamik editör zeminlemesini (Grounding) ekler
## ve eski tool sonuçlarını token optimizasyonu için sıkıştırır (Context Compaction).
func get_messages_for_api(keep_recent_tools: int = 2) -> Array:
	var api_messages: Array = []
	
	# Dinamik Editör Durumu (Aktif Sahne, Seçili Düğüm, Açık Script)
	var grounding = AISidebarEditorStateSnapshot.get_grounding_prompt_text()
	api_messages.append({
		"role": "user",
		"content": grounding
	})
	
	# Eski tool çıktılarını yapılandırılmış özetlere dönüştür
	var compacted_msgs = AISidebarContextCompactor.compact_messages(messages, keep_recent_tools)
	for m in compacted_msgs:
		var m_copy = m.duplicate(true)
		if m_copy.has("vision_inputs"):
			m_copy.erase("vision_inputs")
		api_messages.append(m_copy)
		
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
