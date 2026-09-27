@tool
extends RefCounted
class_name AISidebarAIProvider

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

## Soyut Yapay Zeka Sağlayıcı Arayüzü & Yetenek Yöneticisi (Abstract Provider Interface & Capabilities) (SRP).

const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")

signal chunk_received(text_delta: String, thinking_delta: String)
signal response_received(text_content: String, thinking_content: String, tool_calls: Array)
signal models_fetched(models: Array)
## Model listesi alınamadı (ajan çalışmıyorken error_occurred görmezden gelinir; bu sinyal arayüze gider).
signal models_failed(error_message: String)
signal error_occurred(error_message: String)
## Sağlayıcının bildirdiği token kullanımı (ham `usage`; AISidebarContextBudget.normalize işler). Yanıttan
## önce yayılır: bağlam koruması bir sonraki istekten önce sıkıştırabilsin. Bildirmeyen sağlayıcı yaymaz.
signal usage_reported(usage: Dictionary)

func supports_vision() -> bool:
	return false

func supports_tool_calling() -> bool:
	return true

func supports_streaming() -> bool:
	return true

func fetch_models() -> void:
	pass

## Modelin bağlam penceresi (token), sağlayıcı model listesinde bildirdiyse; bilinmiyorsa 0.
func context_window_for(_model: String) -> int:
	return 0

func send_chat(messages: Array, tools_schema: Array) -> void:
	pass

func send_multimodal_chat(messages: Array, tools_schema: Array, images: Array) -> void:
	if not supports_vision():
		error_occurred.emit(AISidebarI18n.get_text("provider_no_vision"))
		return
	send_chat(messages, tools_schema)

func cancel() -> void:
	pass

## Provider emekliye ayrılırken çağrılır: paylaşılan kaynaklara (ör. NetworkManager) kurduğu
## bağlantıları koparır. Nesne başka bir yerde tutulsa bile artık olay almaz.
func dispose() -> void:
	pass
