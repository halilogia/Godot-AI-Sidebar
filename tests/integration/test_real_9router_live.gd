@tool
extends SceneTree

## Bağımsız Canlı 9Router Entegrasyon & Teşhis Aracı (Live Diagnostic Tool).
## Gerçek 9Router (http://127.0.0.1:20128/v1) ve gerçek LLM trafiğini test eder.
## API anahtarı kod içine yazılmaz; ortam değişkeni (GODOT_AI_TEST_API_KEY) veya .env dosyasından okunur.

const CONFIG_PATH = "res://addons/godot_sidebar_ai/config.json"
const ENV_PATH = "res://.env"

var base_url: String = "http://127.0.0.1:20128/v1"
var model_name: String = "ag/gemini-3.7-flash-low"
var api_key: String = ""

func _init() -> void:
	_load_credentials()
	print("==================================================")
	print("   GODOT AI CORE - GERÇEK 9ROUTER CANLI ENTEGRASYON TESTİ   ")
	print("==================================================")
	print("Hedef URL : %s" % base_url)
	print("Hedef Model: %s" % model_name)
	print("API Key   : %s" % ("[BULUNDU (Gizli)]" if not api_key.is_empty() else "[BULUNAMADI / Boş]"))
	print("==================================================\n")
	
	# TEST 1: Streaming (stream: true)
	_execute_single_test(1, true)
	OS.delay_msec(1000)
	
	# TEST 2: Non-Streaming (stream: false)
	_execute_single_test(2, false)
	
	print("\n==================================================")
	print("🎉 CANLI 9ROUTER ENTEGRASYON TESTLERİ TAMAMLANDI")
	print("==================================================")
	quit(0)

func _load_credentials() -> void:
	# 1. Ortam Değişkeni (Öncelikli)
	api_key = OS.get_environment("GODOT_AI_TEST_API_KEY").strip_edges()
	if not api_key.is_empty():
		return
		
	# 2. .env Dosyası
	if FileAccess.file_exists(ENV_PATH):
		var f = FileAccess.open(ENV_PATH, FileAccess.READ)
		if f:
			var txt = f.get_as_text()
			f.close()
			for line in txt.split("\n"):
				var l = line.strip_edges()
				if l.begins_with("GODOT_AI_TEST_API_KEY="):
					api_key = l.trim_prefix("GODOT_AI_TEST_API_KEY=").strip_edges().trim_prefix("\"").trim_suffix("\"")
					return
				elif l.begins_with("API_KEY="):
					api_key = l.trim_prefix("API_KEY=").strip_edges().trim_prefix("\"").trim_suffix("\"")
					return
					
	# 3. Addon Config (Varsa)
	if FileAccess.file_exists(CONFIG_PATH):
		var fc = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if fc:
			var j = JSON.parse_string(fc.get_as_text())
			fc.close()
			if j is Dictionary:
				api_key = str(j.get("api_key", "")).strip_edges()
				var cfg_url = str(j.get("base_url", "")).strip_edges()
				if not cfg_url.is_empty():
					base_url = cfg_url
				var cfg_mod = str(j.get("selected_model", "")).strip_edges()
				if not cfg_mod.is_empty() and cfg_mod != "all":
					model_name = cfg_mod

func _execute_single_test(stage_num: int, is_streaming: bool) -> void:
	var raw_response = PackedByteArray()
	var has_received_first_byte = false
	var seen_done_marker = false
	var chunk_count = 0
	var ttft_msec = 0
	var last_http_status = -1
	
	print("\n>>> BAŞLATILIYOR: TEST %d (stream=%s)" % [stage_num, str(is_streaming)])
	
	var url = base_url.trim_suffix("/") + "/chat/completions"
	var host = "127.0.0.1"
	var port = 20128
	var path = "/v1/chat/completions"
	
	if "://" in url:
		var no_proto = url.split("://")[1]
		var slash_idx = no_proto.find("/")
		if slash_idx != -1:
			path = no_proto.substr(slash_idx)
			var hp = no_proto.substr(0, slash_idx)
			if ":" in hp:
				var sp = hp.split(":")
				host = sp[0]
				port = sp[1].to_int()
			else:
				host = hp
				port = 80
				
	if host == "localhost":
		host = "127.0.0.1"
		
	var payload_dict = {
		"model": model_name,
		"messages": [
			{"role": "user", "content": "Reply with exactly: TEST_OK"}
		],
		"stream": is_streaming,
		"temperature": 0.0
	}
	var payload_str = JSON.stringify(payload_dict)
	
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Connection: close"
	]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)
		
	var client = HTTPClient.new()
	var req_start_msec = Time.get_ticks_msec()
	var connect_start_msec = Time.get_ticks_msec()
	
	var err = client.connect_to_host(host, port)
	if err != OK:
		print("❌ HATA: connect_to_host başarısız (err=%d)" % err)
		return
		
	var request_sent = false
	var is_active = true
	var exit_status = -1
	var total_dur = 0
	
	while is_active:
		client.poll()
		var status = client.get_status()
		
		match status:
			HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
				OS.delay_msec(2)
			HTTPClient.STATUS_CONNECTED:
				if not request_sent:
					request_sent = true
					var conn_dur = Time.get_ticks_msec() - connect_start_msec
					print("  [1] Bağlantı Kuruldu (Connect Time: %d ms)" % conn_dur)
					var req_err = client.request(HTTPClient.METHOD_POST, path, headers, payload_str)
					if req_err != OK:
						print("❌ HATA: request() başarısız (err=%d)" % req_err)
						is_active = false
				OS.delay_msec(2)
			HTTPClient.STATUS_REQUESTING:
				OS.delay_msec(5)
			HTTPClient.STATUS_BODY:
				if not has_received_first_byte and client.has_response():
					has_received_first_byte = true
					ttft_msec = Time.get_ticks_msec() - req_start_msec
					last_http_status = client.get_response_code()
					print("  [2] İlk Yanıt / TTFT: %d ms (HTTP %d)" % [ttft_msec, last_http_status])
					
				var chunk = client.read_response_body_chunk()
				if chunk.size() > 0:
					chunk_count += 1
					raw_response.append_array(chunk)
					var c_str = chunk.get_string_from_utf8()
					print("  [CHUNK #%d RAW (%d b)]: %s" % [chunk_count, chunk.size(), c_str.strip_edges()])
					if "[DONE]" in c_str or "\"finish_reason\":\"stop\"" in c_str or "\"finish_reason\": \"stop\"" in c_str:
						seen_done_marker = true
						total_dur = Time.get_ticks_msec() - req_start_msec
						exit_status = status
						print("  [3] Tamamlanma Belirteci Yakalandı! (Chunk #%d, Süre: %d ms)" % [chunk_count, total_dur])
						is_active = false
				OS.delay_msec(5)
			HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CONNECTION_ERROR:
				total_dur = Time.get_ticks_msec() - req_start_msec
				exit_status = status
				print("  [4] Soket Kapandı -> Status: %d (%s) (Toplam Süre: %d ms)" % [status, "STATUS_DISCONNECTED" if status == 0 else "STATUS_CONNECTION_ERROR", total_dur])
				is_active = false
			_:
				OS.delay_msec(5)
				
	client.close()
	
	# Sonuç Raporu
	var body_text = raw_response.get_string_from_utf8().strip_edges()
	var body_len = raw_response.size()
	
	print("\n--- SONUÇ RAPORU (Test %d: stream=%s) ---" % [stage_num, str(is_streaming)])
	print("• Toplanmış Bayt : %d bayt" % body_len)
	print("• Alınan Chunk   : %d adet" % chunk_count)
	print("• TTFT / İlk Byte: %d ms" % ttft_msec)
	print("• Toplam Süre    : %d ms" % total_dur)
	print("• HTTP Kod       : %d" % last_http_status)
	print("• Kapanış Statusü: %d" % exit_status)
	
	if is_streaming:
		print("• [DONE] Görüldü : %s" % str(seen_done_marker))
		# SSE parse et
		var parsed_content = ""
		for line in body_text.split("\n"):
			var l = line.strip_edges()
			if l.begins_with("data:"):
				var payload = l.trim_prefix("data:").strip_edges()
				if payload != "[DONE]" and not payload.is_empty():
					var pj = JSON.parse_string(payload)
					if pj is Dictionary and pj.has("choices") and pj["choices"].size() > 0:
						var d = pj["choices"][0].get("delta", {})
						parsed_content += str(d.get("content", ""))
		print("• Ayrıştırılan Metin: \"%s\"" % parsed_content.strip_edges())
		if "TEST_OK" in parsed_content or not parsed_content.is_empty():
			print("✅ TEST BAŞARILI (Streaming içerik başarıyla alındı)")
		else:
			print("⚠️ UYARI: Ayrıştırılan içerik boş veya beklenenden farklı.")
	else:
		var json_obj = JSON.parse_string(body_text)
		var content = ""
		if json_obj is Dictionary and json_obj.has("choices") and json_obj["choices"].size() > 0:
			content = json_obj["choices"][0].get("message", {}).get("content", "")
		print("• Ayrıştırılan Metin: \"%s\"" % content.strip_edges())
		if "TEST_OK" in content or not content.is_empty():
			print("✅ TEST BAŞARILI (Non-streaming JSON başarıyla alındı)")
		else:
			print("⚠️ UYARI: JSON içeriği boş veya beklenenden farklı.")
