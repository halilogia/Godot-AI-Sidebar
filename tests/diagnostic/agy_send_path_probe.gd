@tool
extends SceneTree

## AGY SAGLAYICI - UCTAN UCA GONDERI YOLU PROBU
##
## NEDEN BU PROB:
##   Kullanici, 10 saniyelik donmayi gozlemledigi anda saglayicinin
##   "Google Antigravity CLI (agy)" oldugunu bildirdi. Onceki entegre probum
##   ise config'deki openai_compatible yolunu olctu. Bu nedenle kullanicinin
##   GERCEK senaryosu HENUZ OLCULMEDI.
##
## KARAR KRITERI:
##   _start_task_prompt() cagrisinin SENKRON donus suresi = kullanicinin
##   "Gonder'e bastim, arayuz dondu" suresi. LLM_REQUEST_START logunun nerede
##   basildigi onemsizdir; onemli olan KONTROLUN EDITORE NE ZAMAN DONDUGUDUR.
##
##   t_sync < 100 ms  -> LLM oncesi blokaj YOK
##   t_sync ~ 10.000 ms -> kullanicinin bildirdigi donma DOGRULANDI

const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

const PROMPT := "Merhaba, kisa bir selam ver."

var _dock: Control = null
var _provider = null
var _runner: AISidebarAgentRunner = null

var _t_sync_start: int = 0
var _t_sync_end: int = 0
var _t_llm_start_called: int = 0
var _t_first_chunk: int = 0
var _t_response: int = 0
var _chunks: int = 0
var _phase: int = 0
var _frames: int = 0
var _turn: int = 0
var _results: Array = []

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  AGY SAGLAYICI - UCTAN UCA GONDERI YOLU PROBU                    #")
	print("##################################################################")

	_dock = ChatDockScene.instantiate()
	if _dock == null:
		print("  !! dock instantiate edilemedi")
		quit(1)
		return
	root.add_child(_dock)

	var cfg = AISidebarConfig.load_config()
	print("  config selected_model = %s" % str(cfg.get("selected_model", "?")))
	print("  (agy provider OFFICIAL_MODELS disindaki modeli gemini-3.8-flash-low'a map eder)")
	print("")

	_dock.agent_context = AISidebarAgentContext.new()

	_provider = AISidebarAGYProvider.new()
	_dock.provider = _provider

	_runner = AISidebarAgentRunner.new(_provider, _dock.agent_context)
	_dock.agent_runner = _runner

	_runner.state_changed.connect(_dock._on_agent_state_changed)
	_runner.chunk_received.connect(_dock._on_agent_chunk_received)
	_runner.text_received.connect(_dock._on_agent_text_received)
	_runner.error_occurred.connect(_on_error)
	_runner.task_completed.connect(_on_complete)
	_provider.chunk_received.connect(_on_chunk)

	print("  --- TEST 1: pre_warm() (surec baslatma) senkron maliyeti ---")
	var t0 := Time.get_ticks_usec()
	var ok: bool = _provider._ensure_process("gemini-3.8-flash-low")
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	print("  _ensure_process() = %.3f ms  (basarili=%s)" % [dt, str(ok)])
	print("  ^ Bu cagri handshake'i BEKLEMEZ; sadece sureci baslatir.")
	print("")

	_phase = 1

func _process(_delta: float) -> bool:
	if _phase == 0:
		return false
	_frames += 1
	if _frames == 3:
		_run_turn()
		return false
	if _phase == 9:
		_finish()
		return false
	if _frames > 300000:
		print("  !! watchdog")
		_finish()
		return false
	return false

func _run_turn() -> void:
	_turn += 1
	_t_sync_start = Time.get_ticks_usec()
	print("")
	print("  === TUR %d: _start_task_prompt() cagriliyor (Gonder tusu) ===" % _turn)
	_dock._start_task_prompt(PROMPT, "", [])
	_t_sync_end = Time.get_ticks_usec()
	print("  === TUR %d SENKRON DONUS : %.3f ms ===" % [_turn, (_t_sync_end - _t_sync_start) / 1000.0])
	_results.append({"turn": _turn, "sync_ms": (_t_sync_end - _t_sync_start) / 1000.0})

func _on_chunk(_t: String, _th: String) -> void:
	_chunks += 1
	if _t_first_chunk == 0:
		_t_first_chunk = Time.get_ticks_usec()

func _on_error(msg: String) -> void:
	print("  [HATA] %s" % msg.left(200))
	_phase = 9

func _on_complete(_m: Dictionary) -> void:
	_t_response = Time.get_ticks_usec()
	_phase = 9

func _finish() -> void:
	print("")
	print("##################################################################")
	print("#  SONUC                                                         #")
	print("##################################################################")
	if _results.is_empty():
		print("  Olcum yapilamadi.")
		print("##################################################################")
		quit(0)
		return

	var r: Dictionary = _results[0]
	var sync_ms: float = r["sync_ms"]
	print("  _start_task_prompt() SENKRON DONUS (donma suresi) : %10.3f ms" % sync_ms)
	if _t_first_chunk > 0:
		print("  ILK CHUNK'a kadar (asenkron)                      : %10.3f ms" % ((_t_first_chunk - _t_sync_end) / 1000.0))
	if _t_response > 0:
		print("  TASK_COMPLETE'e kadar (asenkron)                  : %10.3f ms" % ((_t_response - _t_sync_end) / 1000.0))
	print("  Toplam chunk sayisi                               : %d" % _chunks)
	print("")
	if sync_ms < 100.0:
		print("  >>> SONUC: LLM cagrisi ONCESI ANA THREAD BLOKAJI YOK (%.1f ms)." % sync_ms)
		print("      AGY yolunda da kullanicinin bildirdigi ~10s donma REPRODUCE EDILEMEDI.")
	else:
		print("  >>> SONUC: SENKRON BLOKAJ DOGRULANDI (%.1f ms)!" % sync_ms)
	print("##################################################################")
	quit(0)
