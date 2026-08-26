@tool
extends RefCounted
class_name AISidebarAgentContext

## Ajanın konuşma geçmişi ve bağlam (Context) yöneticisi (SRP).

const AISidebarEditorStateSnapshot = preload("res://addons/godot_sidebar_ai/core/state/editor_state_snapshot.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarSourceMapper = preload("res://addons/godot_sidebar_ai/core/runtime/source_mapper.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")

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

## Çalışma zamanı hatasını ve kaynak kod parçasını bağlama otomatik ekler (Error -> Context -> Fix)
func add_runtime_error_context(obs: AISidebarRuntimeObservation) -> void:
	var diag_text = obs.format_diagnostic_prompt()
	var snippets: PackedStringArray = []
	
	for err in obs.errors:
		var f_path = err.get("file", "")
		var l_num = err.get("line", 0)
		if not f_path.is_empty() and l_num > 0:
			snippets.append(AISidebarSourceMapper.get_source_snippet(f_path, l_num))
			
	var full_msg = diag_text
	if snippets.size() > 0:
		full_msg += "\n\nİLGİLİ KAYNAK KOD PARÇALARI:\n" + "\n\n".join(snippets)
		
	full_msg += "\n\nLütfen bu hatayı analiz edin ve gerekli düzeltmeyi (ChangeSet) önerin."
	
	messages.append({
		"role": "user",
		"content": full_msg
	})

## Görsel girdi içeren multimodal kullanıcı mesajı ekler
func add_multimodal_user_message(text: String, vision_input: AISidebarVisionInput) -> void:
	var content_array: Array = [
		{"type": "text", "text": text}
	]
	if vision_input:
		content_array.append(vision_input.to_openai_content_part())
		
	messages.append({
		"role": "user",
		"content": content_array
	})

func get_messages_for_api() -> Array:
	return messages.duplicate(true)

func clear() -> void:
	messages.clear()
	_is_first_message = true

func size() -> int:
	return messages.size()
