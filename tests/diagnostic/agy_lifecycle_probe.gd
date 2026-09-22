@tool
extends SceneTree

## AGY Surec Yasam Dongusu - ANA THREAD BLOKAJ PROBU.
##
## HIPOTEZ:
##   agy_cli_provider.gd -> stop_process() icindeki
##       _reader_thread.wait_to_finish()
##   cagrisi, okuyucu thread _stdio.get_line() icinde BLOKE haldeyken
##   Godot ANA THREAD'ini surec cikti uretene kadar (veya olene kadar) KILITLER.
##
##   _is_reading = false yapmak get_line() blokajini KIRMAZ.
##
## Bu prob, gercek koddaki deseni birebir taklit eder ve blokaj suresini olcer.
## Kendi kendini kilitlememek icin bir WATCHDOG 4 sn sonra sureci oldurur.
## Gercek kodda boyle bir watchdog YOKTUR.

const AGY_MODEL := "gemini-3.8-flash-low"
const WATCHDOG_MS := 4000

var _stdio: FileAccess = null
var _pid: int = -1
var _stop_flag: bool = false
var _reader_thread: Thread = null
var _lines_seen: int = 0
var _spin_count: int = 0

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  AGY - ANA THREAD BLOKAJ PROBU                                   #")
	print("##################################################################")

	_test_a_first_line()
	_test_b_blocking_join()

	print("")
	print("##################################################################")
	print("#  YORUM                                                          #")
	print("##################################################################")
	print("  Test B sonucu wait_to_finish() suresi ~%d ms ise:" % WATCHDOG_MS)
	print("    -> get_line() BLOKLAYICIDIR ve stop_process() ana thread'i")
	print("       surec olene/cikti uretene kadar kilitler. Bu, 'LLM oncesi")
	print("       donma' icin GERCEK bir senkron blokaj mekanizmasidir.")
	print("  Test B suresi ~0 ms ve spin_count cok yuksekse:")
	print("    -> get_line() bloklamiyor, dongu BUSY-SPIN yapiyor")
	print("       (CPU %100 -> editor donuk hissedilir).")
	print("##################################################################")
	quit(0)

# ---------------------------------------------------------------- helpers

func _spawn() -> bool:
	var args: PackedStringArray = [
		"--input-format", "stream-json",
		"--output-format", "stream-json",
		"--model", AGY_MODEL
	]
	var t0 := Time.get_ticks_usec()
	var pipe = OS.execute_with_pipe("agy", args)
	var dt := Time.get_ticks_usec() - t0
	if pipe.is_empty() or not pipe.has("stdio"):
		print("  !! agy spawn basarisiz (PATH?)")
		return false
	_stdio = pipe["stdio"]
	_pid = pipe.get("pid", -1)
	print("  OS.execute_with_pipe('agy')        : %8.2f ms  (pid=%d)" % [dt / 1000.0, _pid])
	return true

func _wait_init() -> void:
	# get_length() tampondaki hazir baytlari verir; bloklamaz.
	var t0 := Time.get_ticks_usec()
	var budget_us := 60 * 1000 * 1000
	while Time.get_ticks_usec() - t0 < budget_us:
		if _stdio == null or _stdio.get_length() > 0:
			break
		OS.delay_msec(10)
	var dt := Time.get_ticks_usec() - t0
	print("  agy 'init' hazir olma suresi       : %8.2f ms" % [dt / 1000.0])
	if _stdio and _stdio.get_length() > 0:
		var line := _stdio.get_line()
		print("      init satiri (ilk 90): %s" % line.strip_edges().left(90))

func _kill() -> void:
	_stop_flag = true
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
		_pid = -1
	if _stdio:
		_stdio.close()
		_stdio = null

# ---------------------------------------------------------------- Test A

func _test_a_first_line() -> void:
	print("")
	print("-- TEST A: Spawn + init handshake --------------------------------")
	if not _spawn():
		return
	_wait_init()
	_kill()
	print("  (surec temizlendi)")

# ---------------------------------------------------------------- Test B

func _reader_loop() -> void:
	# agy_cli_provider.gd -> _read_worker ile AYNI desen (bloklayici get_line).
	while not _stop_flag:
		if _stdio == null:
			break
		_spin_count += 1
		var line := _stdio.get_line()
		if line.length() > 0:
			_lines_seen += 1

func _test_b_blocking_join() -> void:
	print("")
	print("-- TEST B: stop_process() -> wait_to_finish() BLOKAJ OLCUMU -------")
	if not _spawn():
		return
	_wait_init()

	# Okuyucu thread baslatilir (kalici provider ile ayni desen)
	_stop_flag = false
	_lines_seen = 0
	_spin_count = 0
	_reader_thread = Thread.new()
	_reader_thread.start(_reader_loop)

	# Thread'in get_line() icine girmesi icin bekle
	OS.delay_msec(600)
	print("  Okuyucu thread calisiyor (spin=%d, satir=%d)" % [_spin_count, _lines_seen])
	print("  Simdi: _is_reading=false  +  wait_to_finish()  (gercek kod deseni)")

	# WATCHDOG: gercek kodda YOKTUR. Probun kendini kilitlememesi icin var.
	var wd := Thread.new()
	var wd_pid := _pid
	wd.start(func():
		OS.delay_msec(WATCHDOG_MS)
		if wd_pid > 0 and OS.is_process_running(wd_pid):
			OS.kill(wd_pid)
	)

	var t0 := Time.get_ticks_usec()
	_stop_flag = true          # _is_reading = false karsiligi
	_reader_thread.wait_to_finish()
	var dt := Time.get_ticks_usec() - t0

	wd.wait_to_finish()
	_reader_thread = null

	print("  >>> wait_to_finish() BLOKAJ suresi : %8.2f ms" % [dt / 1000.0])
	print("  >>> toplam get_line() cagrisi      : %d" % _spin_count)
	print("  >>> okunan satir                   : %d" % _lines_seen)

	if dt >= 1000.0:
		print("  >>> SONUC: ANA THREAD BLOKLANDI. stop_process() tehlikelidir.")
	elif _spin_count > 100:
		print("  >>> SONUC: get_line() bloklamiyor -> BUSY-SPIN (CPU yakimi).")
	else:
		print("  >>> SONUC: blokaj yok / belirsiz.")

	_kill()
	print("  (surec temizlendi)")
