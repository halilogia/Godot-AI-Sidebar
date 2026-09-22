@tool
extends SceneTree

## ENTEGRE FAZ-A / FAZ-B AYRIM PROBU (GERCEK DOCK SINIFLARI)
##
## NEDEN GEREKLI:
##   Ayrı ayrı olculen fonksiyonlarin toplami 4.8 ms cikti. Ancak kullanici
##   gercek GUI'de ~10 s freeze bildiriyor. Aradaki fark, gercek sinyal
##   zincirinin (state_changed -> update_ui_language -> bubble olusturma ->
##   scroll) ve gercek saglayici yolu uzerinden olculmelidir.
##
## ONEMLI SINIRLAMA (durustluk notu):
##   chat_dock.gd -> _ready() satir 151:  "if not Engine.is_editor_hint(): return"
##   oldugu icin headless ortamda _ready() ERKEN DONER ve agent_runner kurulmaz.
##   Bu prob, _ready()'nin atladigi kurulumu GERCEK fonksiyonlari cagirarak
##   elle tekrarlar. Yani:
##     - Gercek siniflar, gercek sinyal baglantilari, gercek UI bilesenleri
##     - AMA EditorInterface'e bagli kisimlar (mention node scan, editor
##       render, Output panel) headless'te YOKTUR.
##   Bu nedenle sonuc, editor ortamina gore IYIMSERDIR (alt sinir).
##
## OLCULEN:
##   T0 kullanici gonder'e basti
##   T1 _on_send_pressed() senkron kismi bitti
##   T2 LLM_REQUEST_START logu atildi
##   T3 PROVIDER_RESPONSE_RECEIVED
##   T4 TASK_COMPLETE

const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

var _dock: Control = null
var _nm: AISidebarNetworkManager = null
var _provider = null
var _runner: AISidebarAgentRunner = null

var _t_send: int = 0
var _t_sync_done: int = 0
var _t_llm_start: int = 0
var _t_first_response: int = 0
var _t_complete: int = 0
var _frames: int = 0
var _done: bool = false
var _deadline_ms: int = 0

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  ENTEGRE FAZ-A / FAZ-B AYRIM PROBU (GERCEK DOCK)                 #")
	print("##################################################################")

	var inst = ChatDockScene.instantiate()
	if inst == null:
		print("  !! dock sahnesi instantiate edilemedi")
		quit(1)
		return
	_dock = inst
	root.add_child(_dock)

	# _ready() headless'te erken dondu; kurulumu GERCEK fonksiyonlarla tekrarla.
	var cfg = AISidebarConfig.load_config()
	var prov_type = str(cfg.get("provider_type", "antigravity_cli"))
	print("  provider_type = %s" % prov_type)
	print("  model         = %s" % str(cfg.get("selected_model", "?")))
	print("")

	_nm = AISidebarNetworkManager.new()
	root.add_child(_nm)
	_dock.network_manager = _nm

	_dock.agent_context = AISidebarAgentContext.new()

	if prov_type == "openai_compatible":
		_provider = AISidebarOpenAICompatibleProvider.new(_nm)
	else:
		_provider = AISidebarAGYProvider.new()
	_dock.provider = _provider
	_dock._setup_provider()

	_runner = AISidebarAgentRunner.new(_dock.provider, _dock.agent_context)
	_dock.agent_runner = _runner

	_runner.state_changed.connect(_dock._on_agent_state_changed)
	_runner.chunk_received.connect(_dock._on_agent_chunk_received)
	_runner.text_received.connect(_dock._on_agent_text_received)
	_runner.error_occurred.connect(_dock._on_agent_error)
	_runner.task_completed.connect(_on_task_completed)

	# Uyariciyi (pre_warm) tetiklememek icin kucuk bekleme; sonra gonderi testi
	_deadline_ms = Time.get_ticks_msec() + 60000
	print("  Kurulum tamam. Gonderi testi basliyor...")
	print("")

func _process(_delta: float) -> bool:
	if _done:
		return false
	if Time.get_ticks_msec() > _deadline_ms:
		print("  !! watchdog: 60s asildi, cikiliyor")
		_report()
		quit(0)
		return false

	if _frames == 0:
		# Ilk karede gonderi bastir
		_send_now()
	elif _t_first_response > 0 and _t_complete > 0:
		_report()
		quit(0)
		return false

	_frames += 1
	return false

func _send_now() -> void:
	if _dock.input_field == null:
		print("  !! input_field yok")
		_done = true
		quit(1)
		return
	_dock.input_field.text = "Merhaba, kisa bir selam ver."
	print("")
	print("  >>> _on_send_pressed() cagriliyor (T0)")
	_t_send = Time.get_ticks_usec()
	_dock._on_send_pressed()
	_t_sync_done = Time.get_ticks_usec()
	var sync_ms = (_t_sync_done - _t_send) / 1000.0
	print("  <<< _on_send_pressed() SENKRON BITTI : %.3f ms" % sync_ms)

func _on_task_completed(_metrics: Dictionary) -> void:
	_t_complete = Time.get_ticks_usec()

func _report() -> void:
	print("")
	print("##################################################################")
	print("#  SONUC                                                         #")
	print("##################################################################")
	if _t_send == 0:
		print("  Olcum yapilamadi.")
		print("##################################################################")
		return

	if _t_send == 0:
		print("  Olcum yapilamadi.")
		print("##################################################################")
		return

	print("  FAZ A (T0 -> gonderi senkron bitisi)        : %8.3f ms" % ((_t_sync_done - _t_send) / 1000.0))
	if _t_first_response > 0:
		print("  FAZ B (senkron bitis -> PROVIDER_RESPONSE) : %8.3f ms" % ((_t_first_response - _t_sync_done) / 1000.0))
	if _t_complete > 0 and _t_send > 0:
		print("  TOPLAM (T0 -> TASK_COMPLETE)               : %8.3f ms" % ((_t_complete - _t_send) / 1000.0))
	print("  Islenen kare sayisi                        : %d" % _frames)
	print("")
	print("  Kritik ayrim: FAZ A 10.000 ms mertebesinde mi?")
	var faz_a_ms = (_t_sync_done - _t_send) / 1000.0
	if faz_a_ms < 100.0:
		print("  >>> HAYIR. Gercek entegre gonderi yolu %.1f ms surdu." % faz_a_ms)
		print("      LLM cagrisi ONCESI ana thread blokaji YOK.")
		print("      Kullanicinin algiladigi '10 s donma' bu katmanda DEGIL.")
	else:
		print("  >>> EVET. Faz A %.1f ms. Ana supheli bu yol." % faz_a_ms)
	print("##################################################################")

var _t2: int = 0
