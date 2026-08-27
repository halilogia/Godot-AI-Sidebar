@tool
extends Node
class_name AISidebarNetworkManager

## Düşük Gecikmeli HTTPClient Ağ Motoru ve Güvenli URL Normalizasyonu (SRP).
## Windows loopback (localhost -> 127.0.0.1) gecikmelerini önler, bağlantı durumlarını milisaniye bazında raporlar.

signal request_completed(endpoint_type: String, response_code: int, response_str: String)
signal response_chunk_received(endpoint_type: String, chunk_str: String)
signal request_failed(endpoint_type: String, error_message: String)

var _client: HTTPClient = null
var _current_endpoint: String = ""
var _is_request_active: bool = false
var _raw_response_body: PackedByteArray = PackedByteArray()
var _expected_content_length: int = -1
var _request_headers_sent: bool = false
var _first_byte_received: bool = false
var _req_start_msec: int = 0
var _last_logged_status: int = -999

var _method: int = HTTPClient.METHOD_POST
var _path: String = ""
var _headers: PackedStringArray = []
var _body: String = ""

static func get_ts() -> String:
	var dt = Time.get_time_dict_from_system()
	var ms = Time.get_ticks_msec() % 1000
	return "%02d:%02d:%02d.%03d" % [dt.hour, dt.minute, dt.second, ms]

func _ready() -> void:
	set_process(true)

func cancel_all() -> void:
	_is_request_active = false
	if _client:
		_client.close()
		_client = null

func get_request(url: String, headers: PackedStringArray) -> Error:
	return _start_httpclient_request("models", HTTPClient.METHOD_GET, url, headers, "")

func post_request(url: String, headers: PackedStringArray, body_json: String) -> Error:
	return _start_httpclient_request("chat", HTTPClient.METHOD_POST, url, headers, body_json)

func _start_httpclient_request(endpoint_type: String, method: int, url: String, headers: PackedStringArray, body: String) -> Error:
	cancel_all()
	
	_current_endpoint = endpoint_type
	_method = method
	_body = body
	_raw_response_body = PackedByteArray()
	_expected_content_length = -1
	_request_headers_sent = false
	_first_byte_received = false
	_req_start_msec = Time.get_ticks_msec()
	_last_logged_status = -999
	
	var final_headers = headers.duplicate()
	if not _has_header(final_headers, "Connection"):
		final_headers.append("Connection: close")
	_headers = final_headers
	
	var parsed_url = parse_url(url)
	_path = parsed_url["path"]
	
	print("[TIMING] %s | CONNECT_START | endpoint=%s host=%s port=%d path=%s" % [get_ts(), endpoint_type, parsed_url["host"], parsed_url["port"], _path])
	
	_client = HTTPClient.new()
	var err = _client.connect_to_host(parsed_url["host"], parsed_url["port"])
	if err != OK:
		print("[TIMING] %s | CONNECT_ERROR | err=%d" % [get_ts(), err])
		_client = null
		return err
		
	_is_request_active = true
	return OK

## Host adını güvenli şekilde normalize eder (localhost -> 127.0.0.1)
static func normalize_host(host: String) -> String:
	var clean = host.strip_edges().to_lower()
	if clean == "localhost" or clean == "localhost.localdomain":
		return "127.0.0.1"
	return host.strip_edges()

## URL çözümleme ve yapılandırma (Merkezi URL Parser)
static func parse_url(url: String) -> Dictionary:
	var clean = url.strip_edges()
	var is_ssl = clean.begins_with("https://")
	var default_port = 443 if is_ssl else 80
	
	clean = clean.trim_prefix("http://").trim_prefix("https://")
	var slash_idx = clean.find("/")
	var host_port = clean if slash_idx == -1 else clean.substr(0, slash_idx)
	var path = "/" if slash_idx == -1 else clean.substr(slash_idx)
	
	var host = host_port
	var port = default_port
	
	# IPv6 Literal Kontrolü (ör. [::1]:20128 veya [::1])
	if host_port.begins_with("["):
		var bracket_end = host_port.find("]")
		if bracket_end != -1:
			host = host_port.substr(0, bracket_end + 1)
			var rest = host_port.substr(bracket_end + 1)
			if rest.begins_with(":"):
				port = rest.substr(1).to_int()
	else:
		var colon_idx = host_port.find(":")
		if colon_idx != -1:
			host = host_port.substr(0, colon_idx)
			port = host_port.substr(colon_idx + 1).to_int()
			
	host = normalize_host(host)
	
	return {
		"host": host,
		"port": port,
		"path": path,
		"ssl": is_ssl
	}

func _parse_url(url: String) -> Dictionary:
	return parse_url(url)

func _has_header(headers: PackedStringArray, key: String) -> bool:
	var prefix = key.to_lower() + ":"
	for h in headers:
		if h.to_lower().begins_with(prefix):
			return true
	return false

func _status_to_name(status: int) -> String:
	match status:
		HTTPClient.STATUS_DISCONNECTED: return "STATUS_DISCONNECTED"
		HTTPClient.STATUS_RESOLVING: return "STATUS_RESOLVING"
		HTTPClient.STATUS_CANT_RESOLVE: return "STATUS_CANT_RESOLVE"
		HTTPClient.STATUS_CONNECTING: return "STATUS_CONNECTING"
		HTTPClient.STATUS_CANT_CONNECT: return "STATUS_CANT_CONNECT"
		HTTPClient.STATUS_CONNECTED: return "STATUS_CONNECTED"
		HTTPClient.STATUS_REQUESTING: return "STATUS_REQUESTING"
		HTTPClient.STATUS_BODY: return "STATUS_BODY"
		HTTPClient.STATUS_CONNECTION_ERROR: return "STATUS_CONNECTION_ERROR"
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR: return "STATUS_TLS_HANDSHAKE_ERROR"
		_: return "STATUS_" + str(status)

## Yanıt tamponunun geçerli ve tamamlanmış bir yanıt içerip içermediğini denetler.
## Bağlantı soketi kapandığında (Status 0 veya Status 8) erken başarısızlığı önler.
static func is_buffer_complete(raw_bytes: PackedByteArray, expected_len: int = -1) -> bool:
	if raw_bytes.is_empty():
		return false
		
	# 1. Content-Length sağlandıysa ve karşılandıysa
	if expected_len > 0 and raw_bytes.size() >= expected_len:
		return true
		
	var body_str = raw_bytes.get_string_from_utf8().strip_edges()
	if body_str.is_empty():
		return false
		
	# 2. SSE [DONE] kontrolü
	if body_str.ends_with("[DONE]") or "data: [DONE]" in body_str:
		return true
		
	# 3. Geçerli JSON kontrolü
	if body_str.begins_with("{") and body_str.ends_with("}"):
		var json = JSON.new()
		if json.parse(body_str) == OK and json.data is Dictionary:
			return true
	elif body_str.begins_with("[") and body_str.ends_with("]"):
		var json = JSON.new()
		if json.parse(body_str) == OK and json.data is Array:
			return true
			
	# 4. SSE Akışı tamamlanmış chunk kontrolü
	if body_str.begins_with("data:"):
		var lines = body_str.split("\n")
		var valid_sse_chunk_count = 0
		for line in lines:
			var l_clean = line.strip_edges()
			if l_clean.begins_with("data:"):
				var payload = l_clean.substr(5).strip_edges()
				if payload == "[DONE]":
					return true
				var p_json = JSON.new()
				if p_json.parse(payload) == OK and p_json.data is Dictionary:
					valid_sse_chunk_count += 1
		if valid_sse_chunk_count > 0:
			return true
			
	return false

func _process(delta: float) -> void:
	if not _is_request_active or _client == null:
		return
		
	var status = _client.get_status()
	if status != _last_logged_status:
		var elapsed = Time.get_ticks_msec() - _req_start_msec
		print("[TIMING] %s | CONNECT_STATUS | %s (+%dms)" % [get_ts(), _status_to_name(status), elapsed])
		_last_logged_status = status
		
	match status:
		HTTPClient.STATUS_DISCONNECTED:
			if is_buffer_complete(_raw_response_body, _expected_content_length):
				_finalize_success()
			else:
				_is_request_active = false
				print("[TIMING] %s | NETWORK_FAILED | Disconnected with incomplete/empty body (%d bytes)" % [get_ts(), _raw_response_body.size()])
				request_failed.emit(_current_endpoint, "Bağlantı kapandı (Sunucu yanıt vermedi veya eksik kaldı).")
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
			_client.poll()
		HTTPClient.STATUS_CONNECTED:
			if not _request_headers_sent:
				_request_headers_sent = true
				var conn_time = Time.get_ticks_msec() - _req_start_msec
				print("[TIMING] %s | CONNECT_ESTABLISHED | duration_to_connect=%dms" % [get_ts(), conn_time])
				print("[TIMING] %s | REQUEST_SENT | method=%d bytes=%d" % [get_ts(), _method, _body.length()])
				var req_err = _client.request(_method, _path, _headers, _body)
				if req_err != OK:
					_is_request_active = false
					print("[TIMING] %s | NETWORK_REQUEST_ERROR | err=%d" % [get_ts(), req_err])
					request_failed.emit(_current_endpoint, "İstek gönderilemedi (Hata: " + str(req_err) + ")")
			else:
				_client.poll()
		HTTPClient.STATUS_REQUESTING:
			_client.poll()
		HTTPClient.STATUS_BODY:
			_client.poll()
			if not _first_byte_received and _client.has_response():
				_first_byte_received = true
				var f_elapsed = Time.get_ticks_msec() - _req_start_msec
				var code = _client.get_response_code()
				print("[TIMING] %s | FIRST_RESPONSE | endpoint=%s code=%d t_first=%dms" % [get_ts(), _current_endpoint, code, f_elapsed])
				
			if _expected_content_length == -1 and _client.has_response():
				_expected_content_length = _client.get_response_body_length()
				
			var chunk = _client.read_response_body_chunk()
			if chunk.size() > 0:
				_raw_response_body.append_array(chunk)
				var chunk_str = chunk.get_string_from_utf8()
				if not chunk_str.is_empty():
					response_chunk_received.emit(_current_endpoint, chunk_str)
				
				# 1. Content-Length ile tamamlama
				if _expected_content_length > 0 and _raw_response_body.size() >= _expected_content_length:
					_finalize_success()
					return
					
				# 2. Erken JSON & SSE Doğrulama (Early Completion)
				if is_buffer_complete(_raw_response_body, _expected_content_length):
					_finalize_success()
					return
		HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			# Bağlantı soketi kapandı / sıfırlandı; ancak yanıt tamponu zaten tam/geçerli ise fatal hata sayma
			if status == HTTPClient.STATUS_CONNECTION_ERROR and is_buffer_complete(_raw_response_body, _expected_content_length):
				print("[TIMING] %s | CONNECTION_ERROR_RECOVERED | Valid response found in buffer (%d bytes), finalizing." % [get_ts(), _raw_response_body.size()])
				_finalize_success()
			else:
				_is_request_active = false
				print("[TIMING] %s | NETWORK_ERROR | status=%d bytes=%d" % [get_ts(), status, _raw_response_body.size()])
				request_failed.emit(_current_endpoint, "Ağ bağlantı hatası (Status: " + str(status) + ")")

func _finalize_success() -> void:
	var total_dur = Time.get_ticks_msec() - _req_start_msec
	var code = _client.get_response_code() if _client else 200
	var resp_str = _raw_response_body.get_string_from_utf8()
	var b_size = _raw_response_body.size()
	
	print("[TIMING] %s | REQUEST_COMPLETE | endpoint=%s code=%d bytes=%d total_duration=%dms" % [get_ts(), _current_endpoint, code, b_size, total_dur])
	
	if _client:
		_client.close()
	_is_request_active = false
	
	if code == 401:
		request_failed.emit(_current_endpoint, "Yetkilendirme Hatası (HTTP 401): Lütfen API Anahtarınızı kontrol edin.")
	elif code != 200 and code != 201:
		request_failed.emit(_current_endpoint, "HTTP " + str(code) + ": " + resp_str)
	else:
		request_completed.emit(_current_endpoint, code, resp_str)
