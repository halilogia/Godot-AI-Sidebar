@tool
extends SceneTree

## MODEL ALIAS DOGRULAMA PROBU (HTTP STATUS KODLU)
##
## ORTAYA CIKAN KRITIK BULGU:
##   Entegre probda model alias "a" ile istek:
##       REQUEST_COMPLETE code=403 bytes=196 total_duration=14288ms
##       err = "OpenCode's free tier can only be used from within OpenCode"
##
##   Yani 14.3 saniye, BASARILI bir yanit degil; 9Router'in upstream'den
##   iki deneme sonrasi dondugu bir 403 HATASI.
##
## KENDI ONCEKI PROBUMUN HATASI (durustluk notu):
##   streaming_ttft_probe.gd HTTP status kodunu KONTROL ETMIYORDU.
##   Orada raporlanan "TTFT=594/351/318/306 ms" degerleri de ayni 196 baytlik
##   403 govdesiydi. Yani "streaming hizli" sonucu YANLISTI; basarili bir
##   tamamlanma hic olmadi.
##
## BU PROB:
##   HTTP status kodunu ve ilk chunk icerigini acikca raporlar, boylece
##   "hizli" ile "hatali-hizli" karistirilmaz. Birden fazla model alias'ini
##   dener ve hangisinin GERCEKTEN calistigini sayisal olarak gosterir.

const CONFIG_PATH := "res://addons/godot_sidebar_ai/config.json"

# Test edilecek alias'lar: kullanicinin cached_models listesinden secildi
const CANDIDATES: Array[String] = [
	"a",
	"all",
	"ag/gemini-3.8-flash-low",
	"gemini/gemini-3.8-flash",
	"gh/gemini-3-flash-preview"
]

var _host := "127.0.0.1"
var _port := 20128
var _path := "/v1/chat/completions"
var _api_key := ""

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  MODEL ALIAS DOGRULAMA PROBU (HTTP STATUS KODLU)                 #")
	print("##################################################################")
	_load_key()
	print("  api_key : %s" % ("[SET]" if not _api_key.is_empty() else "[EMPTY]"))
	print("  NOT: 403 donen istekler BASARISIZ sayilir; hizli olsa bile.")
	print("")

	var results: Array[Dictionary] = []
	for model in CANDIDATES:
		var r := _probe_model(model)
		results.append(r)
		OS.delay_msec(500)

	print("")
	print("##################################################################")
	print("#  OZET TABLO                                                    #")
	print("##################################################################")
	print("  %-26s %8s %8s %10s  %s" % ["MODEL", "STATUS", "TTFT", "TOTAL", "SONUC"])
	print("  " + "-".repeat(74))
	for r in results:
		var verdict := "OK"
		var st: int = int(r.get("status", -1))
		if st == 403:
			verdict = "403 FREETIER HATASI"
		elif st != 200:
			verdict = "HATA"
		if st == 200 and int(r.get("bytes", 0)) < 40:
			verdict = "SUPHELI (govde cok kucuk)"
		print("  %-26s %8d %7dms %9dms  %s" % [
			r.get("model", "?"), st, int(r.get("ttft", -1)), int(r.get("total", -1)), verdict])

	print("")
	print("  YORUM:")
	print("   - 403 donen modeller KULLANILAMAZ; gecikme tamamen hata kaynakli.")
	print("   - 200 donen ve makul sureli modeller gercek kullanim icin uygundur.")
	print("   - Kullanicinin secili modeli 'a' ise ve 403 aliyorsa, asil sorun")
	print("     'yavaslik' degil, YANLIS MODEL ALIAS'i olabilir.")
	print("##################################################################")
	quit(0)

# ---------------------------------------------------------------- helpers

func _load_key() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var f = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not f:
		return
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	if j is Dictionary:
		_api_key = str(j.get("api_key", "")).strip_edges()

func _probe_model(model: String) -> Dictionary:
	var body := JSON.stringify({
		"model": model,
		"messages": [{"role": "user", "content": "Say OK"}],
		"stream": true,
		"temperature": 0.0
	})
	var headers: PackedStringArray = ["Content-Type: application/json", "Connection: close"]
	if not _api_key.is_empty():
		headers.append("Authorization: Bearer " + _api_key)

	var client := HTTPClient.new()
	var t_req := Time.get_ticks_msec()
	if client.connect_to_host(_host, _port) != OK:
		print("  [%s] !! baglanti hatasi" % model)
		return {"model": model, "status": -1, "ttft": -1, "total": -1}

	var ttft := -1
	var total := -1
	var status := -1
	var body_txt := ""
	var sent := false
	var active := true
	var guard := 0

	while active:
		guard += 1
		if guard > 400000:
			break
		client.poll()
		match client.get_status():
			HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
				OS.delay_msec(2)
			HTTPClient.STATUS_CONNECTED:
				if not sent:
					sent = true
					if client.request(HTTPClient.METHOD_POST, _path, headers, body) != OK:
						active = false
				OS.delay_msec(2)
			HTTPClient.STATUS_REQUESTING:
				OS.delay_msec(5)
			HTTPClient.STATUS_BODY:
				if ttft < 0 and client.has_response():
					ttft = Time.get_ticks_msec() - t_req
					status = client.get_response_code()
				var chunk := client.read_response_body_chunk()
				if chunk.size() > 0:
					body_txt += chunk.get_string_from_utf8()
					# Yuksek hata kodlarinda govde kisa olur; hemen bitir
					if status >= 400 and body_txt.length() > 40:
						total = Time.get_ticks_msec() - t_req
						active = false
					elif "[DONE]" in body_txt or "\"finish_reason\":\"stop\"" in body_txt:
						total = Time.get_ticks_msec() - t_req
						active = false
				OS.delay_msec(5)
			HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CONNECTION_ERROR:
				if ttft < 0:
					ttft = Time.get_ticks_msec() - t_req
					status = client.get_response_code()
				total = Time.get_ticks_msec() - t_req
				active = false
			_:
				OS.delay_msec(5)
	client.close()

	if total < 0:
		total = Time.get_ticks_msec() - t_req
	if ttft < 0:
		ttft = total
	if status < 0:
		status = client.get_response_code()

	var snippet := body_txt.strip_edges().left(110).replace("\n", " ")
	print("  [%s] status=%d ttft=%dms total=%dms bytes=%d" % [model, status, ttft, total, body_txt.length()])
	print("      govde: %s" % snippet)
	return {"model": model, "status": status, "ttft": ttft, "total": total, "bytes": body_txt.length()}
