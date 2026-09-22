@tool
extends SceneTree

## FAZ B - STREAMING TTFT COLD/WARM AYRIM PROBU
##
## SORU: Kullanicinin gercek config'iyle (provider_type=openai_compatible,
##       base_url=127.0.0.1:20128, stream=true) ILK istek ~18s suruyor.
##       Bu COLD-START mi, yoksa STREAMING'e ozgu bir yavaslama mi?
##
## YONTEM: Ayni process icinde ardisik N istek atar ve her birinin
##         TTFT (ilk bayt) + toplam suresini + chunk sayisini raporlar.
##         Ilk istek COLD, sonrakiler WARM kabul edilir.
##         En sonda ayni modelle NON-STREAMING bir istek atip karsilastirir.
##
## ONEMLI: Bu prob GERCEK ag trafigi uretir. API anahtari ASLA ekrana basilmaz.

const CONFIG_PATH := "res://addons/godot_sidebar_ai/config.json"
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")

var _base_url := "http://127.0.0.1:20128/v1"
var _host := "127.0.0.1"
var _port := 20128
var _path := "/v1/chat/completions"
var _api_key := ""
var _model := "a"
var _system_prompt := ""
var _tools: Array = []
var _user_msg := ""

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  FAZ B - STREAMING TTFT COLD/WARM PROBU                          #")
	print("##################################################################")
	_load_config()
	_build_payload()

	print("  base_url      : %s" % _base_url)
	print("  model         : %s" % _model)
	print("  api_key       : %s" % ("[SET]" if not _api_key.is_empty() else "[EMPTY]"))
	print("  system_prompt : %d karakter" % _system_prompt.length())
	print("  tools         : %d sema / %d karakter" % [_tools.size(), JSON.stringify(_tools).length()])
	print("  user_msg      : %d karakter" % _user_msg.length())
	print("")

	# 4 ardisik STREAMING istek (turn1 = COLD)
	var turn_ttfts: Array = []
	for i in range(4):
		var tag := "turn%d-STREAM-COLD" % (i + 1) if i == 0 else "turn%d-STREAM-WARM" % (i + 1)
		var r: Dictionary = _run_request(true, tag)
		if r.get("ttft", -1) > 0:
			turn_ttfts.append(r["ttft"])
		OS.delay_msec(400)

	# 1 NON-STREAMING istek (karsilastirma)
	OS.delay_msec(400)
	var rn: Dictionary = _run_request(false, "turn5-NONSTREAM")

	print("")
	print("##################################################################")
	print("#  OZET                                                          #")
	print("##################################################################")
	if turn_ttfts.size() > 0:
		var cold: int = turn_ttfts[0]
		var warm_total := 0
		for k in range(1, turn_ttfts.size()):
			warm_total += int(turn_ttfts[k])
		var warm_avg := 0
		if turn_ttfts.size() > 1:
			warm_avg = warm_total / (turn_ttfts.size() - 1)
		print("  turn1 (COLD) STREAM TTFT : %d ms" % cold)
		print("  turn2+ (WARM) STREAM TTFT ortalamasi : %d ms  (n=%d)" % [warm_avg, turn_ttfts.size() - 1])
		print("  NON-STREAM TTFT          : %d ms" % int(rn.get("ttft", -1)))
		print("")
		if cold > 3 * maxi(warm_avg, 1):
			print("  >>> SONUC: Bu bir COLD-START problemi. Ilk istek %d ms," % cold)
			print("      sonrakiler ~%d ms. Sicak istekler kabul edilebilir." % warm_avg)
		else:
			print("  >>> SONUC: Cold/warm farki yok; yavaslik KALICI.")
	print("##################################################################")
	quit(0)

# ---------------------------------------------------------------- config

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		print("  !! config.json bulunamadi, varsayilanlar kullanilacak")
		return
	var f = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not f:
		return
	var j = JSON.parse_string(f.get_as_text())
	f.close()
	if not (j is Dictionary):
		return
	var cfg: Dictionary = j
	_api_key = str(cfg.get("api_key", "")).strip_edges()
	_model = str(cfg.get("selected_model", "a")).strip_edges()
	_system_prompt = str(cfg.get("system_prompt", ""))
	var url := str(cfg.get("base_url", _base_url)).strip_edges()
	if not url.is_empty():
		_base_url = url
	_parse_url()

func _parse_url() -> void:
	var u := _base_url.trim_suffix("/")
	var no_proto := u
	if "://" in u:
		no_proto = u.split("://")[1]
	var slash := no_proto.find("/")
	_path = "/v1/chat/completions"
	if slash != -1:
		_path = no_proto.substr(slash)
		if not _path.ends_with("/chat/completions"):
			_path = _path.trim_suffix("/") + "/chat/completions"
		no_proto = no_proto.substr(0, slash)
	_host = no_proto
	if ":" in no_proto:
		var sp := no_proto.split(":")
		_host = sp[0]
		_port = sp[1].to_int()
	if _host == "localhost":
		_host = "127.0.0.1"

func _build_payload() -> void:
	_tools = AISidebarToolManager.get_relevant_schemas(
		" dusman sistemi kur ve slime ekle sahne olustur script yaz", [])
	_user_msg = "Dusman sistemi kur ve oyuncuya saldiran 3 tane slime ekle. Kisa cevap ver."

# ---------------------------------------------------------------- request

func _run_request(stream: bool, tag: String) -> Dictionary:
	var messages: Array = []
	if not _system_prompt.is_empty():
		messages.append({"role": "system", "content": _system_prompt})
	messages.append({"role": "user", "content": _user_msg})

	var body: Dictionary = {
		"model": _model,
		"messages": messages,
		"temperature": 0.2,
		"stream": stream
	}
	if _tools.size() > 0:
		body["tools"] = _tools
		body["tool_choice"] = "auto"
	var body_str := JSON.stringify(body)

	var headers: PackedStringArray = ["Content-Type: application/json", "Connection: close"]
	if not _api_key.is_empty():
		headers.append("Authorization: Bearer " + _api_key)

	var client := HTTPClient.new()
	var t_req := Time.get_ticks_msec()
	var t_conn := t_req
	var err := client.connect_to_host(_host, _port)
	if err != OK:
		print("  [%s] !! connect_to_host hata err=%d" % [tag, err])
		return {"ttft": -1}

	var got_first := false
	var ttft := -1
	var total := -1
	var chunks := 0
	var first_chunk_bytes := 0
	var collected := ""
	var sent := false
	var active := true
	var guard := 0

	while active:
		guard += 1
		if guard > 200000:
			print("  [%s] !! watchdog: istek cok uzun" % tag)
			break
		client.poll()
		var st := client.get_status()
		match st:
			HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
				OS.delay_msec(2)
			HTTPClient.STATUS_CONNECTED:
				if not sent:
					sent = true
					var conn_ms := Time.get_ticks_msec() - t_conn
					var re := client.request(HTTPClient.METHOD_POST, _path, headers, body_str)
					if re != OK:
						print("  [%s] !! request hata err=%d" % [tag, re])
						active = false
					else:
						print("  [%s] connect=%dms body=%d bytes ... bekleniyor" % [tag, conn_ms, body_str.length()])
				OS.delay_msec(2)
			HTTPClient.STATUS_REQUESTING:
				OS.delay_msec(5)
			HTTPClient.STATUS_BODY:
				if not got_first and client.has_response():
					got_first = true
					ttft = Time.get_ticks_msec() - t_req
				var chunk := client.read_response_body_chunk()
				if chunk.size() > 0:
					chunks += 1
					if first_chunk_bytes == 0:
						first_chunk_bytes = chunk.size()
					collected += chunk.get_string_from_utf8()
					if stream:
						if "[DONE]" in collected or "\"finish_reason\":\"stop\"" in collected:
							total = Time.get_ticks_msec() - t_req
							active = false
					else:
						if "\"finish_reason\"" in collected:
							total = Time.get_ticks_msec() - t_req
							active = false
				OS.delay_msec(5)
			HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CONNECTION_ERROR:
				total = Time.get_ticks_msec() - t_req
				active = false
			_:
				OS.delay_msec(5)
	client.close()

	if total < 0:
		total = Time.get_ticks_msec() - t_req

	print("  [%s] TTFT=%dms total=%dms chunks=%d first_chunk=%dB body=%dB"
		% [tag, ttft, total, chunks, first_chunk_bytes, collected.length()])
	if stream and chunks <= 2:
		print("      ^^ DIKKAT: sadece %d chunk -> upstream GERCEK stream ETMIYOR olabilir" % chunks)
	return {"ttft": ttft, "total": total, "chunks": chunks}
