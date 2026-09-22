@tool
extends SceneTree

## AGY PIPE BACKPRESSURE AYRIM PROBU
##
## ELDEKI OLCUM (agy_send_substep_probe.gd):
##   store_string() = 34792 ms ; diger TUM alt adimlar toplam ~12 ms.
##   Yani 19-35 s senkron blokajin TAMAMI tek bir store_string() cagrisinda.
##
## BU PROBUN AMACI - IKI RAKIP HIPOTEZI AYIRMAK:
##
##   H1) "KILIT": Boru (pipe), AGY init handshake'ini tamamlayana kadar
##       YAZILAMAZ. Bu durumda ILK yazma, boyutu ne olursa olsun bloklar.
##
##   H2) "TAMPON GERI BASINCI (backpressure)": Boru tamponu sinirlidir
##       (Windows'ta tipik 4096 bayt). Kucuk yazma aninda doner; tamponu
##       asan buyuk yazma, AGY stdin'i okumaya baslayana kadar bloklar.
##
## AYRIM TESTI:
##   _ensure_process() hemen sonrasinda ONCE 64 baytlik kucuk bir yazma,
##   SONRA ~15 KB'lik buyuk yazma yapilir.
##     H1 dogruysa  -> kucuk yazma da uzun bloklar (init suresi)
##     H2 dogruysa  -> kucuk yazma ~0 ms, buyuk yazma uzun bloklar
##
##   Ayrica AYNI surecte ikinci (sicak/warm) bir buyuk yazma yapilir:
##     Baglanti isindiktan sonra buyuk yazma hizliysa -> blokaj TEK SEFERLIK
##     (init kaynakli), her cagrida tekrarlanan bir maliyet DEGIL.
##
## NOT: Uretim kodu DEGISTIRILMEDI. Sadece bu teshis dosyasi eklendi.

const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")

const FALLBACK_MODEL := "gemini-3.8-flash-low"
const COLD_FILL := 15000
const SMALL_FILL := 30

var _provider = null
var _phase: int = 0
var _frames: int = 0
var _phase_start: int = 0

var _cold_payload: String = ""
var _small_payload: String = ""

# Olcumler (ms)
var _t_cold_small: float = -1.0
var _t_cold_large: float = -1.0
var _t_cold_flush: float = -1.0
var _t_warm_large: float = -1.0
var _t_warm_flush: float = -1.0
var _t_cold_first_chunk: float = -1.0
var _t_warm_first_chunk: float = -1.0

var _t_ensure: float = -1.0
var _cold_bytes: int = 0
var _small_bytes: int = 0

var _chunks: int = 0
var _responses: int = 0
var _t_last_event: int = 0

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  AGY PIPE BACKPRESSURE AYRIM PROBU                               #")
	print("##################################################################")

	var cold_content: String = "a".repeat(COLD_FILL)
	var small_content: String = "b".repeat(SMALL_FILL)

	_cold_payload = JSON.stringify({"event": "user", "message": {"content": cold_content}}) + "\n"
	_small_payload = JSON.stringify({"event": "user", "message": {"content": small_content}}) + "\n"
	_cold_bytes = _cold_payload.to_utf8_buffer().size()
	_small_bytes = _small_payload.to_utf8_buffer().size()

	_provider = AISidebarAGYProvider.new()
	_provider.chunk_received.connect(_on_chunk)
	_provider.response_received.connect(_on_response)
	_phase = 1

func _on_chunk(_t: String, _th: String) -> void:
	_chunks += 1
	_t_last_event = Time.get_ticks_usec()
	if _phase == 1 and _t_cold_first_chunk < 0.0:
		_t_cold_first_chunk = _t_last_event
	elif _phase == 2 and _t_warm_first_chunk < 0.0:
		_t_warm_first_chunk = _t_last_event

func _on_response(_t: String, _th: String, _tc: Array) -> void:
	_responses += 1
	_t_last_event = Time.get_ticks_usec()

func _process(_delta: float) -> bool:
	if _phase == 0:
		return false
	_frames += 1

	if _frames == 3:
		_run_cold()
		return false

	# Soguk yazmalardan sonra baglantinin kurulmasi icin sabit sure bekle,
	# ardindan sicak turu olc. (Asil olcum store_string sureleridir; yanit
	# sayisi AGY'nin mesaj basina yanit verme davranisina bagli oldugu icin
	# sayac yerine ZAMAN kullanilir.)
	if _phase == 1 and Time.get_ticks_msec() - _phase_start > 20000:
		_run_warm()
		return false

	# Prob bitti mi?
	if _phase == 3:
		_report()
		quit(0)
		return false

	# Sicak yazmadan sonra yanitin gelmesi icin sabit sure bekle.
	if _phase == 2 and Time.get_ticks_msec() - _phase_start > 20000:
		_phase = 3
		return false

	if Time.get_ticks_msec() - _phase_start > 120000:
		print("  !! watchdog (120 s)")
		_report()
		quit(0)
		return false

	return false

func _run_cold() -> void:
	print("")
	print("  === SOGUK SUREc (process yeni basladi) ===")
	print("  kucuk yazma boyutu : %d bayt" % _small_bytes)
	print("  buyuk yazma boyutu : %d bayt" % _cold_bytes)
	print("  (Windows pipe tamponu tipik olarak 4096 bayt)")
	print("")

	var t := Time.get_ticks_usec()
	var ok: bool = _provider._ensure_process(FALLBACK_MODEL)
	_t_ensure = (Time.get_ticks_usec() - t) / 1000.0
	print("  _ensure_process() = %.3f ms (ok=%s)" % [_t_ensure, str(ok)])
	if not ok or _provider._stdio == null:
		print("  !! surec baslatilamadi")
		_phase = 9
		return

	# --- 1) KUCUK YAZMA (init hala surerken) ---
	t = Time.get_ticks_usec()
	_provider._stdio.store_string(_small_payload)
	_t_cold_small = (Time.get_ticks_usec() - t) / 1000.0
	print("  [%9.3f ms] store_string(KUCUK %d bayt)" % [_t_cold_small, _small_bytes])

	# --- 2) BUYUK YAZMA (init hala surerken) ---
	t = Time.get_ticks_usec()
	_provider._stdio.store_string(_cold_payload)
	_t_cold_large = (Time.get_ticks_usec() - t) / 1000.0
	print("  [%9.3f ms] store_string(BUYUK %d bayt) <<< BLOKAJ ARANAN YER" % [_t_cold_large, _cold_bytes])

	t = Time.get_ticks_usec()
	_provider._stdio.flush()
	_t_cold_flush = (Time.get_ticks_usec() - t) / 1000.0
	print("  [%9.3f ms] flush()" % _t_cold_flush)

	_phase_start = Time.get_ticks_msec()
	_phase = 1

func _run_warm() -> void:
	print("")
	print("  === SICAK TUR (ayni surec, baglanti kurulmus) ===")
	var t := Time.get_ticks_usec()
	_provider._stdio.store_string(_cold_payload)
	_t_warm_large = (Time.get_ticks_usec() - t) / 1000.0
	print("  [%9.3f ms] store_string(BUYUK %d bayt) <<< AYNI BOYUT, SICAK" % [_t_warm_large, _cold_bytes])

	t = Time.get_ticks_usec()
	_provider._stdio.flush()
	_t_warm_flush = (Time.get_ticks_usec() - t) / 1000.0
	print("  [%9.3f ms] flush()" % _t_warm_flush)

	_phase_start = Time.get_ticks_msec()
	_phase = 2

func _report() -> void:
	print("")
	print("##################################################################")
	print("#  SONUC - HIPOTEZ AYRIMI                                        #")
	print("##################################################################")
	print("  _ensure_process()                       : %9.3f ms" % _t_ensure)
	print("  SOGUK store_string(KUCUK %5d bayt)    : %9.3f ms" % [_small_bytes, _t_cold_small])
	print("  SOGUK store_string(BUYUK %5d bayt)    : %9.3f ms" % [_cold_bytes, _t_cold_large])
	print("  SOGUK flush()                           : %9.3f ms" % _t_cold_flush)
	print("  SICAK store_string(BUYUK %5d bayt)    : %9.3f ms" % [_cold_bytes, _t_warm_large])
	print("  SICAK flush()                           : %9.3f ms" % _t_warm_flush)
	print("  Toplam chunk / yanit                    : %d / %d" % [_chunks, _responses])
	print("")
	print("  --- HIPOTEZ DEGERLENDIRMESI ---")
	if _t_cold_small >= 0.0 and _t_cold_large >= 0.0:
		if _t_cold_small < 100.0 and _t_cold_large > 1000.0:
			print("  >>> KUCUK yazma HIZLI, BUYUK yazma YAVAS")
			print("      => H2 (TAMPON GERI BASINCI) DESTEKLENDI")
			print("      => Blokaj, boru tamponunun dolmasindan kaynaklaniyor.")
		elif _t_cold_small > 1000.0:
			print("  >>> KUCUK yazma da YAVAS")
			print("      => H1 (KILIT) DESTEKLENDI")
			print("      => Boru, init bitene kadar yazmaya kapali.")
		else:
			print("  >>> Belirsiz: kucuk=%0.3f ms, buyuk=%0.3f ms" % [_t_cold_small, _t_cold_large])
	if _t_warm_large >= 0.0:
		if _t_warm_large < 100.0:
			print("  >>> SICAK tur HIZLI (%0.3f ms) => blokaj TEK SEFERLIK (init kaynakli)," % _t_warm_large)
			print("      her cagrida tekrarlanan bir maliyet DEGIL.")
		else:
			print("  >>> SICAK tur da YAVAS (%0.3f ms) => blokaj surekli." % _t_warm_large)
	print("##################################################################")
	_phase = 9
