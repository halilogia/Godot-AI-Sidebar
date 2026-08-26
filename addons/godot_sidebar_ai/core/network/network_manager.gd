@tool
extends Node
class_name AISidebarNetworkManager

## Saf Ağ ve HTTP İstek Yöneticisi (Infrastructure Katmanı) (SRP).
## UI'dan tamamen bağımsızdır; HTTPRequest düğümlerini kendi içinde yönetir.

signal request_completed(endpoint_type: String, response_code: int, response_str: String)
signal request_failed(endpoint_type: String, error_message: String)

var _models_http: HTTPRequest
var _chat_http: HTTPRequest

func _init() -> void:
	_models_http = HTTPRequest.new()
	_models_http.name = "AISidebarModelsHTTP"
	_models_http.timeout = 30.0
	_models_http.body_size_limit = -1
	_models_http.request_completed.connect(_on_models_completed)
	add_child(_models_http)
	
	_chat_http = HTTPRequest.new()
	_chat_http.name = "AISidebarChatHTTP"
	_chat_http.timeout = 180.0
	_chat_http.body_size_limit = -1
	_chat_http.request_completed.connect(_on_chat_completed)
	add_child(_chat_http)

func cancel_all() -> void:
	if _models_http:
		_models_http.cancel_request()
	if _chat_http:
		_chat_http.cancel_request()

func get_request(url: String, headers: PackedStringArray) -> Error:
	if not _models_http:
		return ERR_UNCONFIGURED
	_models_http.cancel_request()
	return _models_http.request(url, headers, HTTPClient.METHOD_GET)

func post_request(url: String, headers: PackedStringArray, body_json: String) -> Error:
	if not _chat_http:
		return ERR_UNCONFIGURED
	_chat_http.cancel_request()
	return _chat_http.request(url, headers, HTTPClient.METHOD_POST, body_json)

func _on_models_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 0:
		return
	if response_code != 200 and response_code != 201:
		request_failed.emit("models", "HTTP " + str(response_code) + ": " + body.get_string_from_utf8())
	else:
		request_completed.emit("models", response_code, body.get_string_from_utf8())

func _on_chat_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 0:
		return
	if response_code == 401:
		request_failed.emit("chat", "Yetkilendirme Hatası (HTTP 401): Lütfen API Anahtarınızı kontrol edin.")
	elif response_code != 200 and response_code != 201:
		request_failed.emit("chat", "HTTP " + str(response_code) + ": " + body.get_string_from_utf8())
	else:
		request_completed.emit("chat", response_code, body.get_string_from_utf8())
