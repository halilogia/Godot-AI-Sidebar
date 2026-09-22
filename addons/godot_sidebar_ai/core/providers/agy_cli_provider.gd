@tool
extends "res://addons/godot_sidebar_ai/core/providers/ai_provider.gd"
class_name AISidebarAGYProvider

## Resmi Google Antigravity CLI (agy) Kalıcı Alt Süreç Sağlayıcısı (Persistent Subprocess Adapter) (SRP).
## 9Router veya harici HTTP proxy katmanlarına ihtiyaç duymadan, yerel 'agy' CLI'ını
## izole bir sandbox çalışma dizininde ve çift yönlü NDJSON stream akışıyla çalıştırır.

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

const OFFICIAL_MODELS: Array = [
	"gemini-3.8-flash-low",
	"gemini-3.8-flash-medium",
	"gemini-3.8-flash-high",
	"gemini-3.7-flash-low",
	"gemini-3.7-flash-medium",
	"gemini-3.7-flash-high",
	"claude-sonnet-4-6",
	"claude-opus-4-6-thinking",
	"gemini-3.6-flash-low",
	"gemini-3.6-flash-medium",
	"gemini-3.6-flash-high",
	"gemini-3.1-pro-low",
	"gemini-3.1-pro-high"
]

var _pipe_dict: Dictionary = {}
var _stdio: FileAccess = null
var _pid: int = -1
var _active_model: String = ""
var _reader_thread: Thread = null
var _is_reading: bool = false
var _current_turn_text: String = ""
var _sandbox_dir: String = ""

func _init() -> void:
	_ensure_sandbox_dir()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_is_reading = false
		if _stdio:
			_stdio.close()
			_stdio = null
		if _pid > 0 and OS.is_process_running(_pid):
			OS.kill(_pid)
			_pid = -1
		if _reader_thread and _reader_thread.is_started():
			_reader_thread.wait_to_finish()
			_reader_thread = null

func _ensure_sandbox_dir() -> String:
	if _sandbox_dir.is_empty():
		var user_dir = OS.get_user_data_dir()
		_sandbox_dir = user_dir.path_join("agy_sandbox")
		if not DirAccess.dir_exists_absolute(_sandbox_dir):
			DirAccess.make_dir_recursive_absolute(_sandbox_dir)
	return _sandbox_dir

func supports_vision() -> bool:
	# AGY CLI stream-json stdin arayüzü doğrudan görsel/multimodal veri aktarımını desteklemez.
	# Görsel analizi için OpenAI-uyumlu sağlayıcı (9Router, OpenRouter vb.) kullanılmalıdır.
	return false

func supports_tool_calling() -> bool:
	return true

func supports_streaming() -> bool:
	return true

func fetch_models() -> void:
	models_fetched.emit(OFFICIAL_MODELS)

func cancel() -> void:
	# Mevcut isteği iptal et veya prosesi yeniden başlat
	stop_process()

func stop_process() -> void:
	_is_reading = false
	if _stdio:
		_stdio.close()
		_stdio = null
		
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
		_pid = -1
		
	if _reader_thread and _reader_thread.is_started():
		_reader_thread.wait_to_finish()
		_reader_thread = null
		
	_pipe_dict.clear()
	_active_model = ""

func _ensure_process(target_model: String) -> bool:
	if _pid > 0 and OS.is_process_running(_pid) and _stdio != null and _active_model == target_model:
		return true

	stop_process()

	var sandbox = _ensure_sandbox_dir()
	var args: PackedStringArray = [
		"--input-format", "stream-json",
		"--output-format", "stream-json",
		"--model", target_model
	]

	# Godot 4.4/4.7 execute_with_pipe
	# cwd Windows temp sandbox dizini olarak ayarlanır
	var pipe = OS.execute_with_pipe("agy", args)
	if pipe.is_empty() or not pipe.has("stdio"):
		error_occurred.emit("Antigravity CLI ('agy') başlatılamadı. Lütfen 'agy'nin sistem PATH'inde olduğundan ve oturum açıldığından emin olun.")
		return false

	_pipe_dict = pipe
	_stdio = pipe["stdio"]
	_pid = pipe.get("pid", -1)
	_active_model = target_model
	_is_reading = true

	_reader_thread = Thread.new()
	_reader_thread.start(_read_worker)
	return true

func _read_worker() -> void:
	while _is_reading and _stdio != null and _pid > 0 and OS.is_process_running(_pid):
		var line = _stdio.get_line()
		if line.is_empty() and not OS.is_process_running(_pid):
			break

		var trimmed = line.strip_edges()
		if trimmed.is_empty():
			continue

		var json_obj = JSON.parse_string(trimmed)
		if not (json_obj is Dictionary):
			continue

		var evt = json_obj.get("event", "")
		if evt == "step_update":
			var step_update = json_obj.get("step_update", {})
			var text_delta = step_update.get("text_delta", "")
			if text_delta != null and not str(text_delta).is_empty():
				_current_turn_text += str(text_delta)
				call_deferred("_safe_emit_chunk", str(text_delta), "")
		elif evt == "result":
			var res_obj = json_obj.get("result", {})
			var raw_response = res_obj.get("response", _current_turn_text)
			var status = res_obj.get("status", "SUCCESS")
			
			if status != "SUCCESS":
				call_deferred("_safe_emit_error", "Antigravity oturum hatası: " + str(status))
			else:
				var parsed_tools = extract_tool_calls(raw_response)
				var clean_text = extract_clean_text(raw_response, parsed_tools.size() > 0)
				call_deferred("_safe_emit_response", clean_text, "", parsed_tools)
			_current_turn_text = ""

func _safe_emit_chunk(delta_text: String, delta_thinking: String) -> void:
	chunk_received.emit(delta_text, delta_thinking)

func _safe_emit_response(text_content: String, thinking_content: String, tool_calls: Array) -> void:
	response_received.emit(text_content, thinking_content, tool_calls)

func _safe_emit_error(msg: String) -> void:
	error_occurred.emit(msg)

func send_chat(messages: Array, tools_schema: Array) -> void:
	send_multimodal_chat(messages, tools_schema, [])

func send_multimodal_chat(messages: Array, tools_schema: Array, images: Array) -> void:
	if images.size() > 0:
		error_occurred.emit("Antigravity CLI (agy) sağlayıcısı şu anda doğrudan görsel (Vision) girdilerini desteklememektedir. Görsel analizi için lütfen Ayarlar'dan OpenAI-Uyumlu Sağlayıcıyı (9Router/OpenRouter/Ollama) seçin.")
		return

	var cfg = AISidebarConfig.load_config()
	var model = cfg.get("selected_model", "gemini-3.8-flash-low")
	if not model in OFFICIAL_MODELS:
		model = "gemini-3.8-flash-low"

	if not _ensure_process(model):
		return

	_current_turn_text = ""
	var prompt = _format_prompt(messages, tools_schema, images, cfg)
	var payload_dict = {
		"event": "user",
		"message": {
			"content": prompt
		}
	}
	var payload_str = JSON.stringify(payload_dict) + "\n"

	if _stdio:
		_stdio.store_string(payload_str)
		_stdio.flush()
	else:
		error_occurred.emit("Antigravity CLI stdio pipe bağlantısı kurulamadı.")

func _format_prompt(messages: Array, tools_schema: Array, images: Array, cfg: Dictionary) -> String:
	var buffer: PackedStringArray = []

	# Sistem Yönergesi
	var sys_prompt = cfg.get("system_prompt", "")
	if not sys_prompt.is_empty():
		buffer.append("=== SYSTEM DIRECTIVE ===")
		buffer.append(sys_prompt)
		buffer.append("")

	# Tool Şemaları ve Çağırma Protokolü
	if tools_schema.size() > 0:
		buffer.append("=== AVAILABLE GODOT TOOLS ===")
		buffer.append("Aşağıdaki araçları kullanarak Godot editöründe işlem yapabilirsin:")
		for item in tools_schema:
			var fn = item.get("function", item)
			var fn_name = fn.get("name", "")
			var fn_desc = fn.get("description", "")
			var fn_params = fn.get("parameters", {})
			buffer.append("- %s: %s" % [fn_name, fn_desc])
			if fn_params.has("properties"):
				buffer.append("  Parametreler: " + JSON.stringify(fn_params.get("properties", {})))

		buffer.append("")
		buffer.append("=== TOOL CALLING INSTRUCTIONS ===")
		buffer.append("Bir araç çalıştırman gerektiğinde, yanıtını KESİNLİKLE aşağıdaki JSON formatında ver:")
		buffer.append("```json\n{\n  \"tool_calls\": [\n    {\n      \"name\": \"arac_adi\",\n      \"arguments\": {\"arg1\": \"deger\"}\n    }\n  ]\n}\n```")
		buffer.append("Eğer araç çağırmana gerek yoksa, sadece doğrudan kullanıcıya hitap eden açıklama metnini yaz.")
		buffer.append("")

	# Konuşma Geçmişi
	buffer.append("=== CONVERSATION HISTORY ===")
	for msg in messages:
		var role = msg.get("role", "user")
		var content = msg.get("content", "")
		if content is Array:
			var text_parts: PackedStringArray = []
			for p in content:
				if p is Dictionary and p.get("type") == "text":
					text_parts.append(p.get("text", ""))
			content = " ".join(text_parts)
		buffer.append("[%s]: %s" % [role.to_upper(), str(content)])

	return "\n".join(buffer)

static func extract_tool_calls(response_text: String) -> Array:
	var tool_calls: Array = []
	if response_text.is_empty():
		return tool_calls

	# 1. Kod bloğu içinde ```json ... ``` arama
	var json_str = ""
	var start_idx = response_text.find("```json")
	if start_idx != -1:
		var content_start = start_idx + 7
		var end_idx = response_text.find("```", content_start)
		if end_idx != -1:
			json_str = response_text.substr(content_start, end_idx - content_start).strip_edges()
	else:
		# 2. Kod bloğu olmadan ham { "tool_calls": ... } arama
		var bracket_start = response_text.find("{\"tool_calls\"")
		if bracket_start == -1:
			bracket_start = response_text.find("{ \"tool_calls\"")
		if bracket_start != -1:
			var bracket_end = response_text.rfind("}")
			if bracket_end > bracket_start:
				json_str = response_text.substr(bracket_start, bracket_end - bracket_start + 1).strip_edges()

	if not json_str.is_empty():
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary and parsed.has("tool_calls") and parsed["tool_calls"] is Array:
			for tc in parsed["tool_calls"]:
				if tc is Dictionary and tc.has("name"):
					var tc_dict = {
						"id": tc.get("id", "call_" + str(Time.get_ticks_msec())),
						"name": str(tc.get("name", "")),
						"arguments": tc.get("arguments", {})
					}
					tool_calls.append(tc_dict)

	return tool_calls

static func extract_clean_text(response_text: String, has_tools: bool) -> String:
	if not has_tools:
		return response_text

	# Tool bloğundan önceki veya sonraki kullanıcıya yönelik açıklama metnini ayıkla
	var start_idx = response_text.find("```json")
	if start_idx != -1:
		var prefix = response_text.substr(0, start_idx).strip_edges()
		var end_idx = response_text.find("```", start_idx + 7)
		var suffix = ""
		if end_idx != -1:
			suffix = response_text.substr(end_idx + 3).strip_edges()
		var combined = (prefix + "\n" + suffix).strip_edges()
		return combined

	return ""
