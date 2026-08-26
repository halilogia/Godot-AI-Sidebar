@tool
extends RefCounted
class_name AISidebarAIProvider

## Soyut Yapay Zeka Sağlayıcı Arayüzü (Abstract Provider Interface) (SRP).
## Gelecekte OpenAI, Anthropic, Gemini ve Yerel Sağlayıcılar için temel sınıftır.

signal response_received(text_content: String, thinking_content: String, tool_calls: Array)
signal models_fetched(models: Array)
signal error_occurred(error_message: String)

func fetch_models() -> void:
	pass

func send_chat(messages: Array, tools_schema: Array) -> void:
	pass

func cancel() -> void:
	pass
