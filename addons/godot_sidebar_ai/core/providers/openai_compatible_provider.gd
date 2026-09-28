@tool
extends "res://addons/godot_sidebar_ai/core/providers/ai_provider.gd"
class_name AISidebarOpenAICompatibleProvider

## OpenAI Uyumlu Çok Modlu Sağlayıcı (OpenAI-Compatible Multimodal Provider) (SRP).
## 9Router, OpenRouter, Ollama ve LM Studio ile metin ve görsel (Vision) isteklerini yönetir.

const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarSSEParser = preload("res://addons/godot_sidebar_ai/core/network/sse_parser.gd")

## Model listesinden öğrenilen bağlam pencereleri: {model_id: token}.
var _context_windows: Dictionary = {}
var network_manager: AISidebarNetworkManager
var _provider_req_start_msec: int = 0
var _stream_buffer: String = ""

## Geçici sağlayıcı hatasında (5xx, 429, bağlantı zaman aşımı) sohbet isteği bu aralıklarla (sn) yeniden
## gönderilir; tek bir 502 / 529 uzun bir görevi öldürüyordu (benchmark: 9Router kombosunun upstream'i
## opencode.ai 10 sn'de bağlanamadı). Yalnız yanıt akmaya başlamadan düşen istek yeniden gönderilir.
static var retry_delays: Array = [5.0, 15.0, 30.0]
## Testler zamanlayıcıyı takar (headless test _init'inde SceneTree yok): func(delay: float, cb: Callable).
static var schedule_hook: Callable = Callable()
var _last_chat: Dictionary = {}
var _chat_retries: int = 0
var _chat_streamed: bool = false
var _retry_token: int = 0

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

## Vision yeteneği bilinen modeller (pozitif eşleşme).
const VISION_MODEL_KEYWORDS: Array = [
	"vision", "4o", "flash", "sonnet", "opus", "llava", "vl",
	"claude-3", "gemini", "qwen-vl", "gpt-4.1", "o3", "o4"
]

## Vision yeteneği BİLİNEN şekilde olmayan modeller (negatif eşleşme).
## Pozitif listeden ÖNCE kontrol edilir; çünkü "deepseek-reasoner" gibi
## durumlarda yanlış pozitif üretmemek gerekir.
const NON_VISION_MODEL_KEYWORDS: Array = [
	"whisper", "tts", "embedding", "embed", "rerank",
	"parakeet", "asr", "dall-e", "stable-diffusion"
]

## Model kimliğine göre Vision yeteneğini SAF (yan etkisiz) olarak belirler.
## Bu metot diske erişmez, bu yüzden testlerde ortamdan bağımsız çalışır.
static func model_supports_vision(model_id: String) -> bool:
	var model := model_id.strip_edges().to_lower()
	if model.is_empty():
		return false

	for kw in NON_VISION_MODEL_KEYWORDS:
		if kw in model:
			return false

	for kw in VISION_MODEL_KEYWORDS:
		if kw in model:
			return true

	# Bilinmeyen model kimliği (9Router "a", "code", "fast" gibi yönlendirme
	# takma adları dahil): kararı sunucuya bırak. Burada false dönmek,
	# yetenekli bir modelin görsel desteğini sessizce ve kalıcı olarak
	# kapatıyordu; aşırı kısıtlayıcı varsayım, izin verici olandan daha
	# kötüdür çünkü kullanıcı hatayı görmez, sadece özellik çalışmaz.
	return true

func supports_vision() -> bool:
	var cfg = AISidebarConfig.load_config()

	# 1. Açık kullanıcı geçersiz kılması (override) en yüksek önceliğe sahiptir.
	var override = cfg.get("vision_capable", null)
	if override is bool:
		return override

	# 2. Aksi halde model kimliğinden çıkar.
	return model_supports_vision(str(cfg.get("selected_model", "")))

func cancel() -> void:
	_stream_buffer = ""
	# Bekleyen yeniden deneme iptal edilir (durdurulan görev sonradan istek göndermesin).
	_retry_token += 1
	_last_chat = {}
	if network_manager:
		network_manager.cancel_all()

## Ortak NetworkManager'a _init'te kurulan bağlantıları koparır (emekli provider yanıt almaz).
func dispose() -> void:
	if network_manager:
		if network_manager.request_completed.is_connected(_on_network_completed):
			network_manager.request_completed.disconnect(_on_network_completed)
		if network_manager.response_chunk_received.is_connected(_on_network_chunk):
			network_manager.response_chunk_received.disconnect(_on_network_chunk)
		if network_manager.request_failed.is_connected(_on_network_failed):
			network_manager.request_failed.disconnect(_on_network_failed)

func get_clean_base_url(url: String) -> String:
	return url.strip_edges().trim_suffix("/")

func fetch_models() -> void:
	if not network_manager:
		error_occurred.emit(AISidebarI18n.get_text("provider_network_not_ready"))
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
		models_failed.emit(AISidebarI18n.get_text("provider_models_failed", {"error": str(err)}))

func send_chat(messages: Array, tools_schema: Array) -> void:
	send_multimodal_chat(messages, tools_schema, [])

func send_multimodal_chat(messages: Array, tools_schema: Array, images: Array) -> void:
	if not network_manager:
		error_occurred.emit(AISidebarI18n.get_text("provider_network_not_ready"))
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
		if msg.has("display_text"):
			msg.erase("display_text")
		payload_messages.append(msg)
		
	# Multimodal görsel parçaları dönüştürme ve mesaja ekleme
	if images.size() > 0:
		if not supports_vision():
			error_occurred.emit(AISidebarI18n.get_text("provider_model_no_vision", {"model": model}))
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
	
	# Akışta token kullanımı son parçada gelsin (OpenAI stream_options); uç nokta reddederse Ayarlar →
	# Sağlayıcı → Gelişmiş'ten kapatılır.
	if use_stream and config.get("report_usage", true) == true:
		body_dict["stream_options"] = {"include_usage": true}
	
	if not tools_schema.is_empty():
		body_dict["tools"] = tools_schema
		body_dict["tool_choice"] = "auto"
		
	var body_str = JSON.stringify(body_dict)
	
	_provider_req_start_msec = Time.get_ticks_msec()
	print("[TIMING] %s | LLM_REQUEST_START | model=%s messages=%d tools=%d stream=%s" % [get_ts(), model, payload_messages.size(), tools_schema.size(), str(use_stream)])
	
	_last_chat = {"url": chat_url, "headers": headers, "body": body_str}
	_chat_retries = 0
	_chat_streamed = false
	_retry_token += 1
	var err = network_manager.post_request(chat_url, headers, body_str)
	if err != OK:
		error_occurred.emit(AISidebarI18n.get_text("provider_request_failed", {"error": str(err)}))

func _on_network_chunk(endpoint_type: String, chunk_str: String) -> void:
	if endpoint_type != "chat":
		return
	_chat_streamed = true
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
				if (thinking_delta == null or str(thinking_delta).is_empty()) and delta.has("reasoning_details"):
					thinking_delta = AISidebarSSEParser.extract_reasoning_details(delta["reasoning_details"])
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
						var item_d: Dictionary = item
						_remember_context_window(str(item_d["id"]), item_d)
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
			# Akışın içine gömülü upstream hatası (9Router: "JSON error injected into SSE stream"): yanıt
			# bütünüyle atıldığı için akış başlamış olsa da yeniden gönderilir.
			if _schedule_chat_retry(str(parsed["error"]), true):
				return
			error_occurred.emit(parsed["error"])
		else:
			var usage: Variant = parsed.get("usage", null)
			if usage is Dictionary:
				var usage_d: Dictionary = usage
				usage_reported.emit(usage_d)
			var txt = parsed.get("content", "")
			var tools = parsed.get("tool_calls", [])
			var think_len = str(parsed.get("thinking", "")).length()
			print("[TIMING] %s | PROVIDER_RESPONSE_RECEIVED | total_dur=%dms parse_dur=%dms text_len=%d thinking_len=%d tools=%d" % [get_ts(), total_prov_dur, parse_dur, txt.length(), think_len, tools.size()])
			response_received.emit(
				txt,
				parsed.get("thinking", ""),
				tools
			)

## Model listesinin bildirdiği bağlam penceresi (OpenRouter `context_length`, Groq `context_window`,
## vLLM `max_model_len` …). Bildirilmeyen model için değer tutulmaz (tahmin yok).
func _remember_context_window(model_id: String, item: Dictionary) -> void:
	var sources: Array[Dictionary] = [item]
	var top: Variant = item.get("top_provider", null)
	if top is Dictionary:
		var top_d: Dictionary = top
		sources.append(top_d)
	for src: Dictionary in sources:
		for key: String in ["context_length", "context_window", "max_context_length", "max_model_len"]:
			var v: Variant = src.get(key, null)
			if v is int or v is float:
				var n: float = v
				if n > 0.0:
					_context_windows[model_id] = int(n)
					return

func context_window_for(model: String) -> int:
	var n: int = _context_windows.get(model, 0)
	return n

func _on_network_failed(endpoint_type: String, error_msg: String) -> void:
	_stream_buffer = ""
	print("[TIMING] %s | PROVIDER_NETWORK_FAILED | endpoint=%s err=%s" % [get_ts(), endpoint_type, error_msg])
	if endpoint_type == "models":
		models_failed.emit(AISidebarI18n.get_text("provider_models_failed", {"error": error_msg}))
		return
	if _schedule_chat_retry(error_msg):
		return
	error_occurred.emit(error_msg)

## Geçici hata mı (sunucu / ağ tarafı; yeniden denemek anlamlı)?
static func is_transient_error(error_msg: String) -> bool:
	var m := error_msg.to_lower()
	for key: String in ["http 5", "http 429", "timeout", "timed out", "econnreset", "connection reset", "cannot connect", "fetch failed",
			"injected into sse", "upstream", "unavailable", "overloaded", "empty response"]:
		if m.contains(key):
			return true
	return false

func _schedule_chat_retry(error_msg: String, whole_response_failed: bool = false) -> bool:
	if _last_chat.is_empty() or (_chat_streamed and not whole_response_failed) or _chat_retries >= retry_delays.size() or not is_transient_error(error_msg):
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null and not schedule_hook.is_valid():
		return false
	var delay: float = retry_delays[_chat_retries]
	_chat_retries += 1
	var token := _retry_token
	print("[TIMING] %s | PROVIDER_RETRY | attempt=%d/%d delay=%.0fs err=%s" % [get_ts(), _chat_retries, retry_delays.size(), delay, error_msg.left(120)])
	var resend := func() -> void:
		if token != _retry_token or _last_chat.is_empty() or network_manager == null:
			return
		_stream_buffer = ""
		_chat_streamed = false
		_provider_req_start_msec = Time.get_ticks_msec()
		var headers: PackedStringArray = _last_chat["headers"]
		network_manager.post_request(str(_last_chat["url"]), headers, str(_last_chat["body"]))
	if schedule_hook.is_valid():
		schedule_hook.call(delay, resend)
	else:
		tree.create_timer(delay).timeout.connect(resend)
	return true
