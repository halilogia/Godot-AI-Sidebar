@tool
extends "res://addons/godot_sidebar_ai/core/providers/ai_provider.gd"
class_name AISidebarOpenAICompatibleProvider

## OpenAI Uyumlu Çok Modlu Sağlayıcı (OpenAI-Compatible Multimodal Provider) (SRP).
## 9Router, OpenRouter, Ollama ve LM Studio ile metin ve görsel (Vision) isteklerini yönetir.

const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarSSEParser = preload("res://addons/godot_sidebar_ai/core/network/sse_parser.gd")

var network_manager: AISidebarNetworkManager

func _init(p_network_manager: AISidebarNetworkManager = null) -> void:
	network_manager = p_network_manager
	if network_manager:
		network_manager.request_completed.connect(_on_network_completed)
		network_manager.request_failed.connect(_on_network_failed)

func supports_vision() -> bool:
	var cfg = AISidebarConfig.load_config()
	var model = cfg.get("selected_model", "all").to_lower()
	var vision_keywords = ["vision", "4o", "flash", "sonnet", "opus", "llava", "vl", "claude-3", "gemini", "qwen-vl", "all"]
	for kw in vision_keywords:
		if kw in model:
			return true
	return false

func cancel() -> void:
	if network_manager:
		network_manager.cancel_all()

func get_clean_base_url(url: String) -> String:
	return url.strip_edges().trim_suffix("/")

func fetch_models() -> void:
	if not network_manager:
		error_occurred.emit("Ağ yöneticisi başlatılmamış.")
		return
		
	var config = AISidebarConfig.load_config()
	var base_url = get_clean_base_url(config.get("base_url", "http://localhost:20128/v1"))
	var api_key = config.get("api_key", "").strip_edges()
	
	var models_url = base_url + "/models"
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
		
	var err = network_manager.get_request(models_url, headers)
	if err != OK:
		error_occurred.emit("Modeller çekilemedi (Hata: " + str(err) + ")")

func send_chat(messages: Array, tools_schema: Array) -> void:
	send_multimodal_chat(messages, tools_schema, [])

func send_multimodal_chat(messages: Array, tools_schema: Array, images: Array) -> void:
	if not network_manager:
		error_occurred.emit("Ağ yöneticisi başlatılmamış.")
		return
		
	var config = AISidebarConfig.load_config()
	var base_url = get_clean_base_url(config.get("base_url", "http://localhost:20128/v1"))
	var api_key = config.get("api_key", "").strip_edges()
	var model = config.get("selected_model", "all")
	if model.is_empty():
		model = "all"
		
	var chat_url = base_url + "/chat/completions"
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
		
	var payload_messages: Array = []
	var sys_prompt: String = config.get("system_prompt", "")
	if not sys_prompt.is_empty():
		payload_messages.append({"role": "system", "content": sys_prompt})
		
	for i in range(messages.size()):
		var msg = messages[i].duplicate(true)
		
		# Eğer son kullanıcı mesajı ise ve görseller varsa multimodal parts dizisine dönüştür
		if i == messages.size() - 1 and msg.get("role", "") == "user" and images.size() > 0:
			if not supports_vision():
				error_occurred.emit("Seçili model (" + model + ") görsel (Vision) desteğine sahip değil.")
				return
				
			var raw_content = msg.get("content", "")
			var parts: Array = []
			
			if raw_content is String:
				parts.append({"type": "text", "text": raw_content})
			elif raw_content is Array:
				parts.append_array(raw_content)
				
			for img in images:
				if img is AISidebarVisionInput:
					parts.append(img.to_openai_content_part())
					
			msg["content"] = parts
			
		payload_messages.append(msg)
		
	var body_dict: Dictionary = {
		"model": model,
		"messages": payload_messages,
		"temperature": config.get("temperature", 0.2)
	}
	
	if not tools_schema.is_empty():
		body_dict["tools"] = tools_schema
		body_dict["tool_choice"] = "auto"
		
	var body_str = JSON.stringify(body_dict)
	var err = network_manager.post_request(chat_url, headers, body_str)
	if err != OK:
		error_occurred.emit("İstek başlatılamadı (Hata: " + str(err) + ")")

func _on_network_completed(endpoint_type: String, response_code: int, response_str: String) -> void:
	if endpoint_type == "models":
		var json_res = JSON.parse_string(response_str)
		var model_ids: Array = []
		if json_res is Dictionary:
			if json_res.has("data") and json_res["data"] is Array:
				for item in json_res["data"]:
					if item is Dictionary and item.has("id"):
						model_ids.append(item["id"])
			elif json_res.has("models") and json_res["models"] is Array:
				for item in json_res["models"]:
					if item is Dictionary and item.has("name"):
						model_ids.append(item["name"])
					elif item is String:
						model_ids.append(item)
		if model_ids.is_empty():
			model_ids = ["all", "free"]
		models_fetched.emit(model_ids)
		
	elif endpoint_type == "chat":
		var parsed = AISidebarSSEParser.parse_response(response_str)
		if parsed.has("error"):
			error_occurred.emit("API Hatası: " + str(parsed["error"]))
		else:
			response_received.emit(
				parsed.get("content", ""),
				parsed.get("thinking", ""),
				parsed.get("tool_calls", [])
			)

func _on_network_failed(endpoint_type: String, error_msg: String) -> void:
	error_occurred.emit(error_msg)
