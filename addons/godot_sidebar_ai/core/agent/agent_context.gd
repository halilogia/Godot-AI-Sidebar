@tool
extends RefCounted
class_name AISidebarAgentContext

## Ajanın konuşma geçmişi ve bağlam (Context) yöneticisi (SRP).

const AISidebarEditorStateSnapshot = preload("res://addons/godot_sidebar_ai/core/state/editor_state_snapshot.gd")

var messages: Array = []
var _is_first_message: bool = true

func add_user_message(text: String, include_grounding: bool = true) -> void:
	var final_content = text
	if _is_first_message and include_grounding:
		var grounding = AISidebarEditorStateSnapshot.get_grounding_prompt_text()
		final_content = grounding + "\n\nKullanıcı İsteği: " + text
		_is_first_message = false
		
	messages.append({
		"role": "user",
		"content": final_content
	})

func add_assistant_message(text: String) -> void:
	if not text.is_empty():
		messages.append({
			"role": "assistant",
			"content": text
		})

func add_tool_result_message(tool_name: String, tool_output: Dictionary) -> void:
	messages.append({
		"role": "user",
		"content": "Tool '" + tool_name + "' output: " + JSON.stringify(tool_output) + "\nPlease analyze this result and proceed with the next step of the plan or answer the user."
	})

func get_messages_for_api() -> Array:
	return messages.duplicate(true)

func clear() -> void:
	messages.clear()
	_is_first_message = true

func size() -> int:
	return messages.size()
