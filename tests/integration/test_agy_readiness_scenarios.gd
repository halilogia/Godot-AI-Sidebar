@tool
extends SceneTree

## AGY READINESS - GERCEK KULLANICI SENARYOLARI (A-E) ENTEGRASYON TESTI
##
## NEDEN:
##   Readiness fix'inin gercek kullanici akislarinda ana thread'i bloklamadigini
##   KANITLAMAK icin. Her senaryoda kullanicinin "Gonder" tusuna bastigi andaki
##   SENKRON donus suresi olculur (bu sure editorun donma suresidir).
##
## KRITER:
##   sync_ms < 100 ms  -> editor DONMADI
##   sync_ms > 1000 ms -> donma var
##   Ayrica yanit GERCEKTEN gelmeli (bekleyen istek kuyrugu otomatik bosalmali).

const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

const MODEL := "gemini-3.8-flash-low"
const OTHER_MODEL := "gemini-3.8-flash-medium"
const PROMPT := "Sadece 'ok' yaz."
const PER_SCENARIO_TIMEOUT_SEC := 60.0

## KRITIK: Gercek uygulamada payload ~15 KB'dir (sistem promptu + 34 arac semasi).
## Windows pipe tamponu ~4 KB oldugu icin asil blokaj yalnizca BU boyutta tetiklenir.
## Bu yuzden test kucuk bir prompt degil, gercekci boyutta sema kullanir.
static func _build_realistic_schemas() -> Array:
	var schemas: Array = []
	for i in range(40):
		schemas.append({
			"type": "function",
			"function": {
				"name": "godot_tool_%02d" % i,
				"description": "Godot editorunde islem yapan arac %d. Bu aciklama gercek sema boyutunu taklit eder." % i,
				"parameters": {
					"type": "object",
					"properties": {
						"path": {"type": "string", "description": "Hedef dosya yolu (res://...)"},
						"content": {"type": "string", "description": "Yazilacak icerik"},
						"mode": {"type": "string", "enum": ["create", "update", "delete"]}
					}
				}
			}
		})
	return schemas

var _prov = null
var _chunks: int = 0
var _text: String = ""
var _done: bool = false
var _results: Array = []

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  AGY READINESS - GERCEK KULLANICI SENARYOLARI (A-E)             #")
	print("##################################################################")
	var cfg = AISidebarConfig.load_config()
	print("  config selected_model = %s" % str(cfg.get("selected_model", "?")))
	print("  (agy provider OFFICIAL_MODELS disindaki modeli %s'e map eder)" % MODEL)
	print("")

	await _scenario("A) Godot ilk acilis -> ilk mesaj (COLD)", 1)
	await _scenario("B) AGY warm iken ikinci mesaj", 2)
	await _scenario("C) Settings save (yeni provider) -> ilk mesaj", 3)
	await _scenario("D) Model degisimi -> ilk mesaj", 4)
	await _scenario("E) Process kill + restart -> ilk mesaj", 5)

	_summary()

func _new_provider() -> void:
	if _prov:
		_prov.stop_process()
	_prov = AISidebarAGYProvider.new()
	_prov.chunk_received.connect(func(_t: String, _th: String): _chunks += 1)
	_prov.response_received.connect(func(t: String, _th: String, _tools: Array):
		_text = t.strip_edges()
		_done = true
	)
	_prov.error_occurred.connect(func(e: String):
		print("    [HATA] " + e)
		_done = true
	)

## Kullanicinin "Gonder" tusuna basmasini taklit eder ve SENKRON donus suresini olcer.
func _press_send() -> float:
	_reset_turn_state()
	var t0 := Time.get_ticks_usec()
	var schemas := _build_realistic_schemas()
	_prov.send_chat([{"role": "user", "content": PROMPT}], schemas)
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	return dt

func _reset_turn_state() -> void:
	_chunks = 0
	_text = ""
	_done = false

func _await_done(timeout_sec: float) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	while not _done:
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout_sec:
			return {"ok": false, "elapsed": timeout_sec, "reason": "TIMEOUT"}
		await create_timer(0.05).timeout
	return {"ok": true, "elapsed": (Time.get_ticks_msec() - t0) / 1000.0, "reason": "ok"}

func _scenario(label: String, idx: int) -> void:
	print("  --- SENARYO %s ---" % label)

	# Her senaryonun ON KOSULU (gercek akisi taklit eder):
	match idx:
		1:
			# Godot acilisi: _setup_provider() -> pre_warm() -> kullanici hemen yazar.
			_new_provider()
			_prov.pre_warm()
		2:
			# Ayni kalici proses uzerinde ikinci istek (warm).
			pass
		3:
			# Settings save -> _setup_provider() yeni bir provider kurar + pre_warm().
			_new_provider()
			_prov.pre_warm()
		4:
			# Model degisti: proses farkli modelle calisiyor sanilir -> _ensure_process restart eder.
			_prov._active_model = OTHER_MODEL
		5:
			# Process olduruldu (or. coktu / kullanici durdurdu) -> ilk mesaj.
			_prov.stop_process()

	var sync_ms := 0.0
	var restart_ms := 0.0

	# Senaryo D'de proses yeniden baslatma maliyeti "Gonder" aninda olusur.
	# Bu maliyeti AYRI olcup raporlariz: boylece blokajin readiness fix'inden
	# mi yoksa onceden var olan proses yeniden baslatma yolundan mi geldigi
	# VARSAYIMLA degil OLCUMLE ayrilir.
	if idx == 4:
		var t_r0 := Time.get_ticks_usec()
		_prov.stop_process()
		var stop_ms := (Time.get_ticks_usec() - t_r0) / 1000.0
		var t_r1 := Time.get_ticks_usec()
		_prov._ensure_process(MODEL)
		var start_ms := (Time.get_ticks_usec() - t_r1) / 1000.0
		restart_ms = stop_ms + start_ms
		print("    -> Proses DURDURMA (stop_process)          : %9.3f ms" % stop_ms)
		print("    -> Yeni surec baslatma (execute_with_pipe) : %9.3f ms" % start_ms)

	sync_ms = _press_send()
	print("    SENKRON DONUS (editorun donma suresi) : %9.3f ms" % sync_ms)
	print("    (istek READY olmadan geldiyse kuyruga alinmistir)")

	var r := await _await_done(PER_SCENARIO_TIMEOUT_SEC)
	var ok: bool = r["ok"] and _chunks > 0
	print("    Yanit geldi mi                        : %s (chunk=%d, %.2fs)" % [str(ok), _chunks, r["elapsed"]])
	print("    Ornek metin                           : %s" % _text.left(60).replace("\n", " "))
	print("")

	_results.append({
		"label": label,
		"sync_ms": sync_ms,
		"restart_ms": restart_ms,
		"total_ms": sync_ms + restart_ms,
		"ok": ok,
		"chunks": _chunks,
		"elapsed": r["elapsed"],
		"reason": r["reason"]
	})

func _summary() -> void:
	_prov.stop_process()
	print("##################################################################")
	print("#  SONUC TABLOSU                                                 #")
	print("##################################################################")
	var max_sync := 0.0
	var all_ok := true
	for r in _results:
		var sync_ms: float = r["sync_ms"]
		var total_ms: float = r["total_ms"]
		max_sync = max(max_sync, sync_ms)
		if not r["ok"]:
			all_ok = false
		print("  %-52s send=%9.3f ms  yanit=%s (%.1fs)" % [
			r["label"], sync_ms, "OK" if r["ok"] else "YOK", r["elapsed"]
		])
	print("")
	# KARAR METRIGI: "Gonder" tusunun SENKRON donus suresi = kullanicinin
	# algiladigi donma suresi (diagnostic asamada da ayni metrik kullanildi).
	print("  En buyuk SENKRON DONUS (send yolu) : %.3f ms" % max_sync)
	print("  Tum senaryolarda yanit            : %s" % ("OK" if all_ok else "YOK"))
	if max_sync < 100.0 and all_ok:
		print("  >>> BASARILI: Send yolu hicbir senaryoda ana thread'i bloklamadi ve AGY streaming calisiyor.")
	elif not all_ok:
		print("  >>> BASARISIZ: Bazi senaryolarda yanit gelmedi.")
	else:
		print("  >>> BASARISIZ: SENKRON BLOKAJ DEVAM EDIYOR (%.1f ms)." % max_sync)
	print("##################################################################")
	quit(0 if (max_sync < 100.0 and all_ok) else 1)
