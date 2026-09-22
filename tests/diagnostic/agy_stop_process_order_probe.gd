@tool
extends SceneTree

## AGY stop_process() - GERCEK SIRA ILE BLOKAJ OLCUMU (Duzeltilmis prob)
##
## ONCEKI PROBUN METODOLOJIK HATASI:
##   agy_lifecycle_probe.gd Test B, su sirayi uyguladi:
##       _stop_flag = true  ->  wait_to_finish()
##   Yani _stdio.close() ve OS.kill() cagrilari ATLANDI.
##   Oysa gercek kod (agy_cli_provider.gd -> stop_process, satir 78-93) su sirayi
##   izler:
##       _is_reading = false
##       _stdio.close()          <-- BLOKAJI KIRABILIR
##       _stdio = null
##       OS.kill(_pid)           <-- BLOKAJI KIRABILIR
##       _reader_thread.wait_to_finish()
##   Bu nedenle onceki "4020 ms BLOKLANDI" sonucu GECERSIZ OLABILIR:
##   blokaji kimin actigini (watchdog mi, close mu, kill mi) ayirt etmiyordu.
##
## BU PROB:
##   3 senaryoyu ayri ayri olcer ve hangi cagrinin blokaji actigini izole eder.
##     A) SADECE _stop_flag  -> wait_to_finish()      (en kotu durum)
##     B) close() + SADECE flag -> wait_to_finish()   (close blokaji aciyor mu?)
##     C) close() + kill() + flag -> wait_to_finish() (GERCEK KOD SIRASI)
##   Her senaryoda watchdog YOK; bunun yerine 6s sonra disaridan kill eden
##   bir thread kullanilir ki prob kendini kilitlemesin.

const AGY_MODEL := "gemini-3.8-flash-low"
const HARD_KILL_MS := 6000

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  AGY stop_process() GERCEK SIRA BLOKAJ PROBU                     #")
	print("##################################################################")
	print("  Amac: onceki probun metodolojik hatasini duzeltmek.")
	print("  Soru: blokaji _is_reading=false mi, _stdio.close() mi, yoksa OS.kill() mi aciyor?")
	print("")

	_scenario("A) SADECE flag -> wait_to_finish()  [close/kill YOK]", false, false)
	_scenario("B) close() + flag -> wait_to_finish()  [kill YOK]", true, false)
	_scenario("C) close() + kill() + flag -> wait_to_finish()  [GERCEK KOD]", true, true)

	print("")
	print("##################################################################")
	print("#  YORUM                                                         #")
	print("##################################################################")
	print("  Senaryo C suresi ~0 ms ise: stop_process() GERCEK sirada")
	print("    ana thread'i KILITLEMEZ; onceki 4020 ms sonucu yanlisti.")
	print("  Senaryo C suresi yuksekse: gercek kodda hala blokaj var.")
	print("##################################################################")
	quit(0)

# ---------------------------------------------------------------- senaryo

func _scenario(title: String, do_close: bool, do_kill: bool) -> void:
	print("")
	print("-- %s" % title)
	print("   surec baslatiliyor...")

	var args: PackedStringArray = [
		"--input-format", "stream-json",
		"--output-format", "stream-json",
		"--model", AGY_MODEL
	]
	var pipe = OS.execute_with_pipe("agy", args)
	if pipe.is_empty() or not pipe.has("stdio"):
		print("   !! agy baslatilamadi")
		return
	var stdio: FileAccess = pipe["stdio"]
	var pid: int = pipe.get("pid", -1)
	print("   pid=%d" % pid)

	# init handshake bekle (akiskan)
	var t_init := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_init < 45000:
		if stdio.get_length() > 0:
			break
		OS.delay_msec(20)
	print("   init hazir: %d ms" % (Time.get_ticks_msec() - t_init))

	# Okuyucu thread (gercek _read_worker deseni: bloklayici get_line)
	var state := {"stop": false, "spin": 0, "lines": 0}
	var reader := Thread.new()
	reader.start(func() -> void:
		while not state["stop"]:
			var line := stdio.get_line()
			state["spin"] = int(state["spin"]) + 1
			if line.length() > 0:
				state["lines"] = int(state["lines"]) + 1
	)
	OS.delay_msec(500)
	print("   okuyucu get_line() icinde (spin=%d)" % int(state["spin"]))

	# Zorla oldurme guvenlik agi (prob kendini kilitlemesin)
	var killer := Thread.new()
	killer.start(func() -> void:
		OS.delay_msec(HARD_KILL_MS)
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	)

	# --- OLCUM ---
	var t0 := Time.get_ticks_usec()
	state["stop"] = true                 # _is_reading = false
	if do_close:
		stdio.close()                    # _stdio.close() + _stdio = null
	if do_kill and pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)                     # OS.kill(_pid)
	reader.wait_to_finish()              # _reader_thread.wait_to_finish()
	var dt := (Time.get_ticks_usec() - t0) / 1000.0

	killer.wait_to_finish()

	print("   >>> wait_to_finish() suresi : %.3f ms" % dt)
	print("   >>> get_line() cagri sayisi : %d" % int(state["spin"]))
	print("   >>> okunan satir            : %d" % int(state["lines"]))
	if dt < 50.0:
		print("   >>> SONUC: BLOKAJ YOK. Bu cagri dizisi guvenli.")
	elif dt < 1000.0:
		print("   >>> SONUC: Kucuk gecikme (%.0f ms)." % dt)
	else:
		print("   >>> SONUC: ANA THREAD BLOKLANDI (%.0f ms)." % dt)

	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	print("   (temizlendi)")
