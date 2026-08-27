@tool
extends RefCounted
class_name AISidebarAIProvider

## Soyut Yapay Zeka Sağlayıcı Arayüzü & Yetenek Yöneticisi (Abstract Provider Interface & Capabilities) (SRP).

const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")

signal chunk_received(text_delta: String, thinking_delta: String)
signal response_received(text_content: String, thinking_content: String, tool_calls: Array)
signal models_fetched(models: Array)
signal error_occurred(error_message: String)

func supports_vision() -> bool:
	return false

func supports_tool_calling() -> bool:
	return true

func supports_streaming() -> bool:
	return true

func fetch_models() -> void:
	pass

func send_chat(messages: Array, tools_schema: Array) -> void:
	pass

func send_multimodal_chat(messages: Array, tools_schema: Array, images: Array) -> void:
	if not supports_vision():
		error_occurred.emit("Mevcut sağlayıcı veya seçili model görsel (Vision) desteğine sahip değil.")
		return
	send_chat(messages, tools_schema)

func cancel() -> void:
	pass
