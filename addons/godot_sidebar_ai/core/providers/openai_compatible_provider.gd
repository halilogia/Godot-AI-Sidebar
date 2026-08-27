@tool
extends "res://addons/godot_sidebar_ai/core/providers/ai_provider.gd"
class_name AISidebarOpenAICompatibleProvider

## OpenAI Uyumlu Çok Modlu Sağlayıcı (OpenAI-Compatible Multimodal Provider) (SRP).
## 9Router, OpenRouter, Ollama ve LM Studio ile metin ve görsel (Vision) isteklerini yönetir.

const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarSSEParser = preload("res://addons/godot_sidebar_ai/core/network/sse_parser.gd")

var network_manager: AISidebarNetworkManager
var _provider_req_start_msec: int = 0
var _stream_buffer: String = ""

static func get_ts() -> String:
	var dt = Time.get_time_dict_from_system()
	var ms = Time.get_ticks_msec() % 1000
	return "%02d:%02d:%02d.%03d" % [dt.hour, dt.minute, dt.second, ms]

func _init(p_network_manager: AISidebarNetworkManager = null) -> void:
	network_manager = p_network_manager
	if network_manager:
		network_manager.request_completed.connect(_on_network_completed)
		network_manager.response_chunk_received.connect(_on_network_chunk)
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
	_stream_buffer = ""
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
	var headers: PackedStringArray = ["Content-Type: application/json", "Connection: close"]
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
		
	_stream_buffer = ""
	var config = AISidebarConfig.load_config()
	var base_url = get_clean_base_url(config.get("base_url", "http://localhost:20128/v1"))
	var api_key = config.get("api_key", "").strip_edges()
	var model = config.get("selected_model", "all")
	if model.is_empty():
		model = "all"
		
	var chat_url = base_url + "/chat/completions"
	var headers: PackedStringArray = ["Content-Type: application/json", "Connection: close"]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
		
	var payload_messages: Array = []
	var sys_prompt: String = config.get("system_prompt", "")
	if not sys_prompt.is_empty():
		payload_messages.append({"role": "system", "content": sys_prompt})
		
	for i in range(messages.size()):
		var msg = messages[i].duplicate(true)
		payload_messages.append(msg)
		
	# Multimodal görsel parçaları dönüştürme ve mesaja ekleme
	if images.size() > 0:
		if not supports_vision():
			error_occurred.emit("Seçili model (" + model + ") görsel (Vision) desteğine sahip değil.")
			return
			
		var vision_parts: Array = []
		for img in images:
			if img is AISidebarVisionInput:
				vision_parts.append(img.to_openai_content_part())
				
		# Eğer son mesaj bir 'user' mesajıysa doğrudan içine ekle
		if payload_messages.size() > 0 and payload_messages[-1].get("role", "") == "user":
			var last_msg = payload_messages[-1]
			var raw_content = last_msg.get("content", "")
			var parts: Array = []
			if raw_content is String:
				parts.append({"type": "text", "text": raw_content})
			elif raw_content is Array:
				parts.append_array(raw_content)
			parts.append_array(vision_parts)
			last_msg["content"] = parts
		else:
			# Eğer son mesaj 'tool' veya 'assistant' ise (araç çalıştıktan sonra gelen görsel gözlem):
			# OpenAI standartlarına uygun olarak yeni bir 'user' gözlem mesajı oluştur
			var parts: Array = [
				{"type": "text", "text": "Alınan güncel viewport ekran görüntüsü:"}
			]
			parts.append_array(vision_parts)
			payload_messages.append({
				"role": "user",
				"content": parts
			})
		
	var use_stream = config.get("stream", true)
	var body_dict: Dictionary = {
		"model": model,
		"messages": payload_messages,
		"temperature": config.get("temperature", 0.2),
		"stream": use_stream
	}
	
	if not tools_schema.is_empty():
		body_dict["tools"] = tools_schema
		body_dict["tool_choice"] = "auto"
		
	var body_str = JSON.stringify(body_dict)
	
	_provider_req_start_msec = Time.get_ticks_msec()
	print("[TIMING] %s | LLM_REQUEST_START | model=%s messages=%d tools=%d stream=%s" % [get_ts(), model, payload_messages.size(), tools_schema.size(), str(use_stream)])
	
	var err = network_manager.post_request(chat_url, headers, body_str)
	if err != OK:
		error_occurred.emit("İstek başlatılamadı (Hata: " + str(err) + ")")

func _on_network_chunk(endpoint_type: String, chunk_str: String) -> void:
	if endpoint_type != "chat":
		return
		
	_stream_buffer += chunk_str
	var lines = _stream_buffer.split("\n")
	# Son tamamlanmamış olabilecek satırı tamponda tut
	_stream_buffer = lines[-1]
	
	for i in range(lines.size() - 1):
		var line = lines[i].strip_edges()
		if line.begins_with("data:"):
			var json_str = line.trim_prefix("data:").strip_edges()
			if json_str == "[DONE]" or json_str.is_empty():
				continue
			var chunk = JSON.parse_string(json_str)
			if chunk is Dictionary and chunk.has("choices") and chunk["choices"].size() > 0:
				var c = chunk["choices"][0]
				var delta = c.get("delta", {})
				var text_delta = delta.get("content", "")
				var thinking_delta = delta.get("reasoning_content", delta.get("reasoning", ""))
				if text_delta != null and not str(text_delta).is_empty():
					chunk_received.emit(str(text_delta), "")
				if thinking_delta != null and not str(thinking_delta).is_empty():
					chunk_received.emit("", str(thinking_delta))

func _on_network_completed(endpoint_type: String, response_code: int, response_str: String) -> void:
	_stream_buffer = ""
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
		var t_start_parse = Time.get_ticks_msec()
		var parsed = AISidebarSSEParser.parse_response(response_str)
		var parse_dur = Time.get_ticks_msec() - t_start_parse
		var total_prov_dur = Time.get_ticks_msec() - _provider_req_start_msec
		
		if parsed.has("error"):
			print("[TIMING] %s | PROVIDER_PARSE_ERROR | err=%s" % [get_ts(), parsed["error"]])
			error_occurred.emit(parsed["error"])
		else:
			var txt = parsed.get("content", "")
			var tools = parsed.get("tool_calls", [])
			print("[TIMING] %s | PROVIDER_RESPONSE_RECEIVED | total_dur=%dms parse_dur=%dms text_len=%d tools=%d" % [get_ts(), total_prov_dur, parse_dur, txt.length(), tools.size()])
			response_received.emit(
				txt,
				parsed.get("thinking", ""),
				tools
			)

func _on_network_failed(endpoint_type: String, error_msg: String) -> void:
	_stream_buffer = ""
	print("[TIMING] %s | PROVIDER_NETWORK_FAILED | endpoint=%s err=%s" % [get_ts(), endpoint_type, error_msg])
	error_occurred.emit(error_msg)
