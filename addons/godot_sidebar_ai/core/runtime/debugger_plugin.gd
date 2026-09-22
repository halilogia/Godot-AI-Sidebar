@tool
extends EditorDebuggerPlugin
class_name AISidebarDebuggerPlugin

## Editör Hata Ayıklayıcı Eklentisi (Editor Debugger Plugin) (SRP).
## Godot'un resmi EditorDebuggerPlugin ve EditorDebuggerSession API'leri üzerinden
## çalışan oyun süreciyle çift yönlü semantik mesajlaşmayı (EngineDebugger) yönetir.

signal response_received(request_id: String, payload: Dictionary)

static var instance: AISidebarDebuggerPlugin = null

var _sessions: Dictionary = {}
var _pending_requests: Dictionary = {}
var _req_counter: int = 0

func _init() -> void:
	instance = self

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			instance = null

func _setup_session(session_id: int) -> void:
	var session = get_session(session_id)
	if session:
		_sessions[session_id] = session
		session.stopped.connect(func():
			_sessions.erase(session_id)
		)

func _has_capture(capture: String) -> bool:
	return capture == "godot_ai"

func _capture(message: String, data: Array, _session_id: int) -> bool:
	if message == "godot_ai:response":
		var req_id = str(data[0]) if data.size() > 0 else ""
		var payload = data[1] if data.size() > 1 and data[1] is Dictionary else {}
		if _pending_requests.has(req_id):
			_pending_requests[req_id]["completed"] = true
			_pending_requests[req_id]["payload"] = payload
		response_received.emit(req_id, payload)
		return true
	return false

## Aktif bir debuggable oyun oturumu olup olmadığını döndürür
func has_active_session() -> bool:
	for s_id in _sessions:
		var s: EditorDebuggerSession = _sessions[s_id]
		if s and s.is_active():
			return true
	return false

## İlk aktif oturumu döndürür
func get_active_session() -> EditorDebuggerSession:
	for s_id in _sessions:
		var s: EditorDebuggerSession = _sessions[s_id]
		if s and s.is_active():
			return s
	return null

## Çalışan oyuna zaman aşımlı sorgu gönderir
func query_sync(command: String, args: Array = [], timeout_msec: int = 2000) -> Dictionary:
	var session = get_active_session()
	if not session:
		return {"success": false, "error": "NO_ACTIVE_SESSION", "message": "Aktif bir oyun oturumu bulunamadı."}
		
	_req_counter += 1
	var req_id = "req_" + str(Time.get_ticks_msec()) + "_" + str(_req_counter)
	var req_entry = {
		"completed": false,
		"payload": {}
	}
	_pending_requests[req_id] = req_entry
	
	var data_to_send = [req_id]
	data_to_send.append_array(args)
	session.send_message("godot_ai:" + command, data_to_send)
	
	var start_time = Time.get_ticks_msec()
	while not req_entry["completed"]:
		if Time.get_ticks_msec() - start_time > timeout_msec:
			_pending_requests.erase(req_id)
			return {"success": false, "error": "TIMEOUT", "message": "Çalışma zamanı sorgusu zaman aşımına uğradı (%d ms)." % timeout_msec}
		OS.delay_msec(10)
		
	var res = req_entry["payload"]
	_pending_requests.erase(req_id)
	return res
