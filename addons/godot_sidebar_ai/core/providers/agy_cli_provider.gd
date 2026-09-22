@tool
extends "res://addons/godot_sidebar_ai/core/providers/ai_provider.gd"
class_name AISidebarAGYProvider

## Resmi Google Antigravity CLI (agy) Kalıcı Alt Süreç Sağlayıcısı (Persistent Subprocess Adapter) (SRP).
## 9Router veya harici HTTP proxy katmanlarına ihtiyaç duymadan, yerel 'agy' CLI'ını
## izole bir sandbox çalışma dizininde ve çift yönlü NDJSON stream akışıyla çalıştırır.

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

## AGY alt sureci hazirlik durumu (readiness state machine).
##
## NEDEN GEREKLI:
##   OS.execute_with_pipe() ~8 ms'de doner, ancak AGY stream-json 'init'
##   handshake'ini ~4-23 s'de tamamlar ve bu sure boyunca stdin'i OKUMAZ.
##   Windows pipe tamponu sinirlidir (~4 KB); handshake bitmeden buyuk bir
##   istek yazilirsa store_string() ANA THREAD'i bloklar (olculdu: 23.7 s
##   -> editor donar, caret blink etmez). Bu yuzden READY olmadan yazma YAPILMAZ.
enum AgyState { STARTING, INITIALIZING, READY }

## Hazirlik durumu degistiginde yayilir (UI durum rozetine baglanir).
signal readiness_changed(state: int, message: String)

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
var _state: int = AgyState.STARTING
var _pending_payload: String = ""
var _has_pending: bool = false
## Proses jenerasyonu: her stop_process()'te artar. Reader thread bu degeri
## yakalayarak call_deferred eder; eski prosesin gecikmis 'init' bildirimi
## yeni prosesi YANLISLIKLA READY isaretleyemez (model degisimi / restart).
var _generation: int = 0

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
	_state = AgyState.STARTING
	_pending_payload = ""
	_has_pending = false
	# Bu ana kadar yayilmis tum reader-thread bildirimlerini gecersiz kil.
	_generation += 1

func pre_warm() -> void:
	var cfg = AISidebarConfig.load_config()
	var model = cfg.get("selected_model", "gemini-3.8-flash-low")
	if not model in OFFICIAL_MODELS:
		model = "gemini-3.8-flash-low"
	_ensure_process(model)

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

	# ONEMLI: 'init' handshake TAMAMLANMADAN READY SAYILMAZ.
	# AGY stdout'a {"event":"init",...} yayinlayana kadar stdin okunmaz,
	# bu yuzden bu asamada yazma yapilirsa ana thread bloklanir.
	# NOT: _set_state kullanilir ki UI 'AGY hazirlaniyor...' rozetini
	# pre_warm() sirasinda da gostersin.
	_set_state(AgyState.INITIALIZING, "")

	_reader_thread = Thread.new()
	# Generation'i thread'e bagla: restart sonrasi eski 'init' yok sayilir.
	_reader_thread.start(_read_worker.bind(_generation))
	return true

func _read_worker(gen: int) -> void:
	while _is_reading and _stdio != null and _pid > 0 and OS.is_process_running(_pid):
		var line = _stdio.get_line()
		if line.is_empty() and not OS.is_process_running(_pid):
			break

		var trimmed = line.strip_edges()
		if trimmed.is_empty():
			continue

		var json = JSON.new()
		var parse_err = json.parse(trimmed)
		if parse_err != OK:
			continue
		var json_obj = json.data
		if not (json_obj is Dictionary):
			continue

		var evt = json_obj.get("event", "")
		if evt == "init":
			# AGY stream-json handshake'i TAMAMLANDI: gercek hazirlik sinyali.
			# Bu andan itibaren AGY stdin'i okur ve yazma bloklamaz.
			call_deferred("_on_agy_ready", gen)
		elif evt == "step_update":
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

	# Bekleyen istek varken okuma dongusu beklenmedik sekilde bittiyse
	# (or. AGY 'init' gonderemeden oldu) istegi sessizce kaybetme.
	if _has_pending and _is_reading:
		call_deferred("_on_agy_start_failed", gen)

func _safe_emit_chunk(delta_text: String, delta_thinking: String) -> void:
	chunk_received.emit(delta_text, delta_thinking)

func _safe_emit_response(text_content: String, thinking_content: String, tool_calls: Array) -> void:
	response_received.emit(text_content, thinking_content, tool_calls)

func _safe_emit_error(msg: String) -> void:
	error_occurred.emit(msg)

func _set_state(new_state: int, message: String) -> void:
	if _state == new_state:
		return
	_state = new_state
	readiness_changed.emit(new_state, message)

## AGY stdin'i yazmaya hazir mi (yani 'init' handshake'i tamamlandi mi)?
func is_ready() -> bool:
	return _state == AgyState.READY

## AGY 'init' handshake'ini tamamlayamadan sonlandi; bekleyen istek iptal edilir.
func _on_agy_start_failed(gen: int) -> void:
	# Eski bir prosesin bildirimi ise yok say (restart yarisi).
	if gen != _generation:
		return
	_has_pending = false
	_pending_payload = ""
	_set_state(AgyState.STARTING, "")
	error_occurred.emit("Antigravity CLI ('agy') başlatılamadı (init tamamlanmadı).")

## Reader thread -> ana thread kopru: AGY 'init' handshake'i tamamlandi.
## call_deferred ile cagrilir (reader thread'den sinyal yaymak guvenli degil).
func _on_agy_ready(gen: int) -> void:
	# Eski bir prosesin gecikmis 'init' bildirimi ise yok say.
	# Aksi halde model degisimi/restart sonrasi yeni proses READY sanilir
	# ve handshake bitmeden yazilarak ana thread bloklanirdi.
	if gen != _generation:
		return
	_set_state(AgyState.READY, "")
	# Bekleyen istek varsa (kullanici READY olmadan gonderdiyse) simdi gonder.
	if _has_pending:
		var payload = _pending_payload
		_pending_payload = ""
		_has_pending = false
		_write_payload(payload)

## READY ise dogrudan yazar; degilse istegi TEK bir pending olarak kuyruga alir.
## Boylece pipe tamponu dolmaz ve ana thread bloklanmaz.
func _write_or_queue(payload: String) -> void:
	if _state == AgyState.READY:
		_write_payload(payload)
	else:
		# Yalnizca en son istek tutulur (tek pending request).
		_pending_payload = payload
		_has_pending = true
		# Ayni durumda olsak bile UI'ya bildir: kullaniciya "hazirlaniyor"
		# geri bildirimi verilmesi bekleyen istege baglidir, duruma degil.
		readiness_changed.emit(AgyState.INITIALIZING, "")

## Gercek yazma. Yalnizca READY durumunda cagrilir.
func _write_payload(payload: String) -> void:
	if _stdio:
		_stdio.store_string(payload)
		_stdio.flush()
	else:
		error_occurred.emit("Antigravity CLI stdio pipe bağlantısı kurulamadı.")

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

	# KRITIK: AGY READY DEGILSE store_string() CAGRILMAZ.
	# Handshake surerken yazmak pipe tamponunu doldurur ve ana thread'i
	# bloklar (olculdu: 23.7 s editor donmasi). Bunun yerine kuyruga alinir
	# ve _on_agy_ready() geldiginde otomatik gonderilir.
	_write_or_queue(payload_str)

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
