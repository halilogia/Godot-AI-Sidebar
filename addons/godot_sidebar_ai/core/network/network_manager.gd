@tool
extends Node
class_name AISidebarNetworkManager

## Düşük Gecikmeli HTTPClient Ağ Motoru (Low-Latency HTTPClient Transport) (SRP).
## Keep-Alive ve Chunked transfer askıda kalmalarını önler, JSON/[DONE] tamamlandığında milisaniyeler içinde döner.

signal request_completed(endpoint_type: String, response_code: int, response_str: String)
signal request_failed(endpoint_type: String, error_message: String)

var _client: HTTPClient = null
var _current_endpoint: String = ""
var _is_request_active: bool = false
var _raw_response_body: PackedByteArray = PackedByteArray()
var _expected_content_length: int = -1
var _request_headers_sent: bool = false

var _method: int = HTTPClient.METHOD_POST
var _path: String = ""
var _headers: PackedStringArray = []
var _body: String = ""

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
	
	var final_headers = headers.duplicate()
	if not _has_header(final_headers, "Connection"):
		final_headers.append("Connection: close")
	_headers = final_headers
	
	var parsed_url = _parse_url(url)
	_path = parsed_url["path"]
	
	_client = HTTPClient.new()
	var err = _client.connect_to_host(parsed_url["host"], parsed_url["port"])
	if err != OK:
		_client = null
		return err
		
	_is_request_active = true
	return OK

func _parse_url(url: String) -> Dictionary:
	var clean = url.strip_edges()
	var is_ssl = clean.begins_with("https://")
	var default_port = 443 if is_ssl else 80
	
	clean = clean.trim_prefix("http://").trim_prefix("https://")
	var slash_idx = clean.find("/")
	var host_port = clean if slash_idx == -1 else clean.substr(0, slash_idx)
	var path = "/" if slash_idx == -1 else clean.substr(slash_idx)
	
	var host = host_port
	var port = default_port
	var colon_idx = host_port.find(":")
	if colon_idx != -1:
		host = host_port.substr(0, colon_idx)
		port = host_port.substr(colon_idx + 1).to_int()
		
	return {
		"host": host,
		"port": port,
		"path": path,
		"ssl": is_ssl
	}

func _has_header(headers: PackedStringArray, key: String) -> bool:
	var prefix = key.to_lower() + ":"
	for h in headers:
		if h.to_lower().begins_with(prefix):
			return true
	return false

func _process(delta: float) -> void:
	if not _is_request_active or _client == null:
		return
		
	var status = _client.get_status()
	match status:
		HTTPClient.STATUS_DISCONNECTED:
			# Soket kapandıysa ve gövde geldiyse başarıyla tamamla
			if _raw_response_body.size() > 0:
				_finalize_success()
			else:
				_is_request_active = false
				request_failed.emit(_current_endpoint, "Bağlantı kapandı (Sunucu yanıt vermedi).")
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING:
			_client.poll()
		HTTPClient.STATUS_CONNECTED:
			if not _request_headers_sent:
				_request_headers_sent = true
				var req_err = _client.request(_method, _path, _headers, _body)
				if req_err != OK:
					_is_request_active = false
					request_failed.emit(_current_endpoint, "İstek gönderilemedi (Hata: " + str(req_err) + ")")
			else:
				_client.poll()
		HTTPClient.STATUS_REQUESTING:
			_client.poll()
		HTTPClient.STATUS_BODY:
			_client.poll()
			if _expected_content_length == -1 and _client.has_response():
				_expected_content_length = _client.get_response_body_length()
				
			var chunk = _client.read_response_body_chunk()
			if chunk.size() > 0:
				_raw_response_body.append_array(chunk)
				
				# Erken Tamamlanma Tespiti (Early Completion)
				if _expected_content_length > 0 and _raw_response_body.size() >= _expected_content_length:
					_finalize_success()
					return
					
				var body_str = _raw_response_body.get_string_from_utf8().strip_edges()
				if body_str.ends_with("[DONE]") or (body_str.begins_with("{") and body_str.ends_with("}")):
					_finalize_success()
					return
		HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_is_request_active = false
			request_failed.emit(_current_endpoint, "Ağ bağlantı hatası (Status: " + str(status) + ")")

func _finalize_success() -> void:
	var code = _client.get_response_code() if _client else 200
	var resp_str = _raw_response_body.get_string_from_utf8()
	if _client:
		_client.close()
	_is_request_active = false
	
	if code == 401:
		request_failed.emit(_current_endpoint, "Yetkilendirme Hatası (HTTP 401): Lütfen API Anahtarınızı kontrol edin.")
	elif code != 200 and code != 201:
		request_failed.emit(_current_endpoint, "HTTP " + str(code) + ": " + resp_str)
	else:
		request_completed.emit(_current_endpoint, code, resp_str)
