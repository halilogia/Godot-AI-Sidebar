@tool
extends SceneTree

## AGY GONDERI YOLU - ALT ADIM SURESI PROBU
##
## AMAC:
##   agy_send_path_probe.gd, _start_task_prompt() cagrisinin ~19003 ms
##   SENKRON olarak bloklandigini olctu. Ancak bu 19 saniyenin HANGI alt
##   adimda harcandigini olcmedi.
##
##   Log zaman cizelgesi ilk ipucunu veriyor:
##     TASK_START        20:08:27.789
##     LLM_REQUEST_START 20:08:27.805   -> send cagrisina kadar HER SEY 16 ms
##     (sync donus ~20:08:46.78, yani 19 s SONRA)
##     ILK CHUNK  sync+2134 ms
##     TASK_COMPLETE sync+2170 ms
##
##   Yani 19 saniye, LLM_REQUEST_START SONRASINDA harcaniyor:
##   get_messages_for_api() + provider.send_chat() icinde.
##
##   Bu prob ayni gercek sinif zincirini kullanarak su alt adimlari AYRI AYRI
##   olcer ve ardindan AGY yanitinin yazma islemine GORE ne zaman geldigini
##   olcer:
##     load_config -> _ensure_process -> get_messages_for_api
##     -> get_relevant_schemas -> _format_prompt -> JSON.stringify
##     -> store_string -> flush -> [AGY yaniti]
##
## TEST EDILEN HIPOTEZ:
##   AGY surecinin stdin borusu (pipe) tamponu, AGY 'init' handshake'ini
##   tamamlayip stdin'i okumaya baslayana kadar dolar; bu yuzden
##   store_string()/flush() ana thread'i bloklar. Once AGY okumaya baslar,
##   yanit ~2 s icinde gelir.
##
## NOT: Uretim kodu DEGISTIRILMEDI. Sadece bu teshis dosyasi eklendi.

const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")

const PROMPT := "Merhaba, kisa bir selam ver."
const FALLBACK_MODEL := "gemini-3.8-flash-low"

var _dock: Control = null
var _provider = null
var _phase: int = 0
var _frames: int = 0
var _t0: int = 0
var _t_flush_end: int = 0
var _t_first_chunk: int = 0
var _t_response: int = 0
var _t_phase2_start: int = 0
var _chunks: int = 0
var _response_text: String = ""

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  AGY GONDERI YOLU - ALT ADIM SURESI PROBU                        #")
	print("##################################################################")
	_dock = ChatDockScene.instantiate()
	if _dock == null:
		print("  !! dock instantiate edilemedi")
		quit(1)
		return
	root.add_child(_dock)
	_dock.agent_context = AISidebarAgentContext.new()
	_provider = AISidebarAGYProvider.new()
	_provider.chunk_received.connect(_on_chunk)
	_provider.response_received.connect(_on_response)
	_phase = 1

func _process(_delta: float) -> bool:
	if _phase == 0:
		return false
	_frames += 1
	if _frames == 3:
		_run()
		return false
	if _phase == 2:
		# AGY yaniti call_deferred ile geldigi icin ana dongu serbest kalmali;
		# bu yuzden blocking bekleme YAPILMAZ, her frame yoklanir.
		# NOT: headless'ta frame'ler cok hizli akar, bu yuzden watchdog
		# frame sayisi degil GERCEK ZAMAN ile olculur.
		if _t_response > 0:
			_report()
			quit(0)
			return false
		if Time.get_ticks_msec() - _t_phase2_start > 90000:
			print("  !! watchdog (90 s) - yanit gelmedi")
			_report()
			quit(0)
			return false
		return false
	if _phase == 9:
		quit(0)
		return false
	return false

func _ms(since_usec: int) -> float:
	return (Time.get_ticks_usec() - since_usec) / 1000.0

func _on_chunk(_t: String, _th: String) -> void:
	_chunks += 1
	if _t_first_chunk == 0:
		_t_first_chunk = Time.get_ticks_usec()

func _on_response(text: String, _th: String, _tc: Array) -> void:
	if _t_response == 0:
		_t_response = Time.get_ticks_usec()
		_response_text = text

func _run() -> void:
	_t0 = Time.get_ticks_usec()

	var cfg: Dictionary = AISidebarConfig.load_config()
	print("  [%9.3f ms] load_config()" % _ms(_t0))
	print("  config selected_model = %s" % str(cfg.get("selected_model", "?")))

	# Gercek send_multimodal_chat() ile ayni model cozumleme mantigi:
	# OFFICIAL_MODELS disindaki her model fallback'e map edilir.
	var model: String = str(cfg.get("selected_model", FALLBACK_MODEL))
	var official: Array = AISidebarAGYProvider.OFFICIAL_MODELS
	if not model in official:
		print("  ('%s' OFFICIAL_MODELS disinda -> '%s')" % [model, FALLBACK_MODEL])
		model = FALLBACK_MODEL

	print("  ----------------------------------------------------------")
	var t: int = Time.get_ticks_usec()
	var ok: bool = _provider._ensure_process(model)
	print("  [%9.3f ms] _ensure_process(%s) ok=%s" % [_ms(t), model, str(ok)])
	if not ok or _provider._stdio == null:
		print("  !! surec/stdio hazir degil, olcum durduruldu")
		_phase = 9
		return
	print("           (reader thread aktif = %s)" % str(_provider._reader_thread != null and _provider._reader_thread.is_started()))
	print("  ----------------------------------------------------------")

	_dock.agent_context.add_user_message(PROMPT, false, PROMPT, [])

	t = Time.get_ticks_usec()
	var messages: Array = _dock.agent_context.get_messages_for_api()
	print("  [%9.3f ms] get_messages_for_api() -> %d mesaj" % [_ms(t), messages.size()])

	var context_text: String = ""
	for msg in messages:
		if msg.get("role", "") == "user":
			var c = msg.get("content", "")
			if c is String:
				context_text += " " + c

	t = Time.get_ticks_usec()
	var tools_schema: Array = AISidebarToolManager.get_relevant_schemas(context_text, [])
	print("  [%9.3f ms] get_relevant_schemas() -> %d arac" % [_ms(t), tools_schema.size()])

	t = Time.get_ticks_usec()
	var prompt_str: String = _provider._format_prompt(messages, tools_schema, [], cfg)
	print("  [%9.3f ms] _format_prompt() -> %d karakter" % [_ms(t), prompt_str.length()])

	t = Time.get_ticks_usec()
	var payload: String = JSON.stringify({"event": "user", "message": {"content": prompt_str}}) + "\n"
	print("  [%9.3f ms] JSON.stringify() -> %d bayt" % [_ms(t), payload.to_utf8_buffer().size()])

	print("  ----------------------------------------------------------")
	t = Time.get_ticks_usec()
	_provider._stdio.store_string(payload)
	print("  [%9.3f ms] <<< store_string()" % _ms(t))

	t = Time.get_ticks_usec()
	_provider._stdio.flush()
	_t_flush_end = Time.get_ticks_usec()
	print("  [%9.3f ms] <<< flush()" % _ms(t))
	print("  ----------------------------------------------------------")
	print("")
	print("  YAZMA SONRASI (asenkron) fazina geciliyor; AGY yaniti bekleniyor...")
	print("  TOPLAM SENKRON BLOKAJ (T0 -> flush donusu) : %9.3f ms" % ((_t_flush_end - _t0) / 1000.0))

	# Yazma tamamlandi; bundan sonrasi TAMAMEN asenkron.
	# _process() her frame bu durumu yoklar ve yanit gelince _report() cagirir.
	_t_phase2_start = Time.get_ticks_msec()
	_phase = 2

func _report() -> void:
	print("")
	print("##################################################################")
	print("#  SONUC                                                         #")
	print("##################################################################")
	print("  TOPLAM SENKRON BLOKAJ (T0 -> flush donusu) : %9.3f ms" % ((_t_flush_end - _t0) / 1000.0))
	if _t_first_chunk > 0:
		print("  flush -> ILK CHUNK                          : %9.3f ms" % ((_t_first_chunk - _t_flush_end) / 1000.0))
	else:
		print("  flush -> ILK CHUNK                          : chunk gelmedi")
	if _t_response > 0:
		print("  flush -> RESPONSE (tam yanit)               : %9.3f ms" % ((_t_response - _t_flush_end) / 1000.0))
	else:
		print("  flush -> RESPONSE (tam yanit)               : yanit gelmedi")
	print("  Toplam chunk sayisi                         : %d" % _chunks)
	if not _response_text.is_empty():
		print("  Yanit metni (ilk 120 karakter)              : %s" % _response_text.left(120).replace("\n", " "))
	print("##################################################################")
	_phase = 9
