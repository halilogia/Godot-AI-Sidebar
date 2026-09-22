@tool
extends SceneTree

## AGY ISINMA ARALIGI (WARMUP GAP) PROBU
##
## SORU:
##   Gercek uygulamada pre_warm() editorde _ready() sirasinda cagrilir
##   (chat_dock.gd satir 141-142). Kullanici "Gonder" tusuna bastiginda
##   aradan genellikle SANIYELER gecer.
##
##   Onceki prob (_ensure_process ile yazma arasinda HIC bekleme yoktu)
##   23682 ms blokaj olctu. Peki surec ZATEN BASLATILMIS ve ARADAN ZAMAN
##   GECMISSE blokaj hala olusuyor mu?
##
##   Bu, kullanicinin gercek deneyimini belirleyen kritik ayrimdir:
##     - Blokaj yoksa  -> pre_warm() maliyeti absorbe ediyor; kullanicinin
##                        gordugu donma baska bir tetikleyiciye bagli
##                        (or. kullanici editor acilir acilmaz gonderdi).
##     - Blokaj varsa  -> AGY stdin'i, ilk mesaj gelene kadar OKUNMUYOR;
##                        bu durumda her yeni surecte ilk Gonder kacilniz
##                        olarak donar.
##
## YONTEM:
##   1. _ensure_process() ile sureci baslat.
##   2. 30 SANIYE bekle (gercek uygulamada kullanicinin yazma suresini
##      taklit eder; pre_warm ile ilk gonderi arasi).
##   3. Buyuk (15 KB) yazma yap ve sureyi olc.
##
## NOT: Uretim kodu DEGISTIRILMEDI. Sadece bu teshis dosyasi eklendi.

const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")

const FALLBACK_MODEL := "gemini-3.8-flash-low"
const GAP_SECONDS := 30
const FILL := 15000

var _provider = null
var _phase: int = 0
var _frames: int = 0
var _t_ensure_usec: int = 0
var _t_launch_msec: int = 0

var _payload: String = ""
var _bytes: int = 0

var _t_write_after_gap: float = -1.0
var _t_flush_after_gap: float = -1.0
var _t_small_before_gap: float = -1.0
var _ensure_ms: float = -1.0
var _chunks: int = 0
var _responses: int = 0

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  AGY ISINMA ARALIGI (WARMUP GAP) PROBU                           #")
	print("##################################################################")
	print("  Senaryo: surec baslat -> %d saniye bekle -> buyuk yazma" % GAP_SECONDS)
	print("  (Bu, gercek uygulamada pre_warm() ile ilk Gonder arasini taklit eder)")
	print("")

	_payload = JSON.stringify({"event": "user", "message": {"content": "c".repeat(FILL)}}) + "\n"
	_bytes = _payload.to_utf8_buffer().size()

	_provider = AISidebarAGYProvider.new()
	_provider.chunk_received.connect(_on_chunk)
	_provider.response_received.connect(_on_response)
	_phase = 1

func _on_chunk(_t: String, _th: String) -> void:
	_chunks += 1

func _on_response(_t: String, _th: String, _tc: Array) -> void:
	_responses += 1

func _process(_delta: float) -> bool:
	if _phase == 0:
		return false
	_frames += 1

	if _frames == 3:
		_launch()
		return false

	# Faz 2: 30 saniye gecince buyuk yazmayi yap
	if _phase == 2:
		var elapsed_s: float = (Time.get_ticks_msec() - _t_launch_msec) / 1000.0
		if elapsed_s >= float(GAP_SECONDS):
			_write_after_gap()
			return false
		return false

	# Faz 3: yaniti bekle, sonra rapor
	if _phase == 3 and Time.get_ticks_msec() - _t_launch_msec > (GAP_SECONDS * 1000 + 45000):
		_report()
		quit(0)
		return false

	if Time.get_ticks_msec() - _t_launch_msec > 180000:
		print("  !! watchdog (180 s)")
		_report()
		quit(0)
		return false

	return false

func _launch() -> void:
	_t_launch_msec = Time.get_ticks_msec()
	var t := Time.get_ticks_usec()
	var ok: bool = _provider._ensure_process(FALLBACK_MODEL)
	_ensure_ms = (Time.get_ticks_usec() - t) / 1000.0
	print("  [%9.3f ms] _ensure_process() ok=%s" % [_ensure_ms, str(ok)])
	if not ok or _provider._stdio == null:
		print("  !! surec baslatilamadi")
		_phase = 9
		return

	# Kucuk yazma ile boru acik mi diye bak (blokaj beklemiyoruz)
	var t2 := Time.get_ticks_usec()
	_provider._stdio.store_string("{\"event\": \"user\", \"message\": {\"content\": \"ping\"}}\n")
	_t_small_before_gap = (Time.get_ticks_usec() - t2) / 1000.0
	print("  [%9.3f ms] kucuk on-yazma (72 bayt)" % _t_small_before_gap)
	print("")
	print("  Simdi %d saniye bekleniyor (gercek kullanimdaki yazma suresi)..." % GAP_SECONDS)
	_phase = 2

func _write_after_gap() -> void:
	var gap_ms: float = (Time.get_ticks_msec() - _t_launch_msec) / 1000.0
	print("")
	print("  === %0.1f saniye gecti; BUYUK YAZMA yapiliyor (%d bayt) ===" % [gap_ms, _bytes])

	var t := Time.get_ticks_usec()
	_provider._stdio.store_string(_payload)
	_t_write_after_gap = (Time.get_ticks_usec() - t) / 1000.0
	print("  [%9.3f ms] store_string(BUYUK) <<< KRITIK OLCUM" % _t_write_after_gap)

	t = Time.get_ticks_usec()
	_provider._stdio.flush()
	_t_flush_after_gap = (Time.get_ticks_usec() - t) / 1000.0
	print("  [%9.3f ms] flush()" % _t_flush_after_gap)

	_phase = 3

func _report() -> void:
	print("")
	print("##################################################################")
	print("#  SONUC                                                         #")
	print("##################################################################")
	print("  _ensure_process()                          : %9.3f ms" % _ensure_ms)
	print("  kucuk on-yazma (hemen sonra)               : %9.3f ms" % _t_small_before_gap)
	print("  %d saniye SONRA buyuk yazma (%d bayt)     : %9.3f ms" % [GAP_SECONDS, _bytes, _t_write_after_gap])
	print("  flush()                                    : %9.3f ms" % _t_flush_after_gap)
	print("  Toplam chunk / yanit                       : %d / %d" % [_chunks, _responses])
	print("")
	print("  --- YORUM ---")
	if _t_write_after_gap < 100.0:
		print("  >>> %d s beklemeden sonra buyuk yazma HIZLI (%0.3f ms)." % [GAP_SECONDS, _t_write_after_gap])
		print("      => Blokaj TEK SEFERLIK ve ZAMANA BAGLI: yalnizca surec")
		print("         baslatildiktan hemen sonra yazilirsa olusuyor.")
		print("      => Gercek uygulamada pre_warm() bu maliyeti ABSORBE EDIYOR.")
	elif _t_write_after_gap > 1000.0:
		print("  >>> %d s beklemeden SONRA da buyuk yazma YAVAS (%0.3f ms)." % [GAP_SECONDS, _t_write_after_gap])
		print("      => AGY stdin'i, ilk mesaj gelene kadar OKUNMUYOR.")
		print("      => Her yeni surecte ilk Gonder KACINILMAZ olarak donar;")
		print("         bekleme suresi sorunu cozmuyor.")
	else:
		print("  >>> Belirsiz: %0.3f ms" % _t_write_after_gap)
	print("##################################################################")
	_phase = 9
