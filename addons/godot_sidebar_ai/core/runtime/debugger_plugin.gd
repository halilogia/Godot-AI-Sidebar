@tool
extends EditorDebuggerPlugin
class_name AISidebarDebuggerPlugin

## Editör Hata Ayıklayıcı Eklentisi (Editor Debugger Plugin) (SRP).
## Godot'un resmi EditorDebuggerPlugin ve EditorDebuggerSession API'leri üzerinden
## çalışan oyun süreciyle çift yönlü semantik mesajlaşmayı (EngineDebugger) yönetir.

signal response_received(request_id: String, payload: Dictionary)

static var instance: AISidebarDebuggerPlugin = null
## Ajanın başlattığı oyunda betik hatası oyunu hata ayıklayıcıda DURDURMASIN (Godot'nun "hata molalarını
## yoksay" ayarı oyuna gönderilir; hata yine günlüğe düşer). Aksi halde oyun ilk hatada donar: inspect
## çalışır ama send_input / wait_for_runtime gibi bekleyen araçlar zaman aşımına düşer (benchmark: RPG,
## tower defense, kart oyunu). Kullanıcının kendi başlattığı oyunlar etkilenmez (play_game açar, stop_game kapatır).
static var ignore_error_breaks: bool = false

var _sessions: Dictionary = {}
var _pending_requests: Dictionary = {}
var _req_counter: int = 0

func _init() -> void:
	instance = self

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			instance = null

## Oturum kaydı kalıcıdır: editör aynı oturumu sonraki çalıştırmalarda yeniden kullanır ve
## _setup_session'ı tekrar çağırmaz. `stopped`'da silmek ikinci çalıştırmadan itibaren runtime
## araçlarını (ekran görüntüsü, canlı ağaç) öldürüyordu; canlılık her erişimde is_active() ile sınanır.
func _setup_session(session_id: int) -> void:
	var session: EditorDebuggerSession = get_session(session_id)
	if session:
		_sessions[session_id] = session
		session.started.connect(func() -> void: apply_run_options(session))

## Oyun bağlanınca (ve bağlantının oturması için bir saniye sonra yine) çalıştırma seçeneklerini gönderir.
func apply_run_options(session: EditorDebuggerSession) -> void:
	if not ignore_error_breaks:
		return
	session.send_message("set_ignore_error_breaks", [true])
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.create_timer(1.0).timeout.connect(func() -> void:
			if ignore_error_breaks and is_instance_valid(session) and session.is_active():
				session.send_message("set_ignore_error_breaks", [true]))

## Capture eşleşmesi (prefix-toleranslı): editör tam mesaj da geçse önek de geçse yakalar.
static func matches_capture(capture: String) -> bool:
	var c = str(capture).strip_edges()
	return c == "godot_ai" or c.begins_with("godot_ai:")

func _has_capture(capture: String) -> bool:
	return matches_capture(capture)

## Response yönlendirme (pure; bekleyen istek sözlüğü üzerinde çalışır).
static func route_response(pending: Dictionary, message: String, data: Array) -> Dictionary:
	if str(message).strip_edges() != "godot_ai:response":
		return {"handled": false, "req_id": "", "payload": {}}
	var req_id = str(data[0]) if data.size() > 0 else ""
	var payload = data[1] if data.size() > 1 and data[1] is Dictionary else {}
	if pending.has(req_id):
		(pending[req_id] as Dictionary)["completed"] = true
		(pending[req_id] as Dictionary)["payload"] = payload
	return {"handled": true, "req_id": req_id, "payload": payload}

func _capture(message: String, data: Array, _session_id: int) -> bool:
	var routed = route_response(_pending_requests, message, data)
	if bool(routed.get("handled", false)):
		response_received.emit(str(routed.get("req_id", "")), routed.get("payload", {}))
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

## Çalışan oyuna event-loop uyumlu, ana akışı kilitlemeyen zaman aşımlı asenkron sorgu gönderir
func query_async(command: String, args: Array = [], timeout_sec: float = 3.0) -> Dictionary:
	var session: EditorDebuggerSession = get_active_session()
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
	print("[TIMING] %d | DBG_QUERY_SEND | cmd=%s req=%s" % [Time.get_ticks_msec(), command, req_id])
	session.send_message("godot_ai:" + command, data_to_send)

	var tree = Engine.get_main_loop() as SceneTree
	var timer = tree.create_timer(timeout_sec) if tree else null

	# Ana iş parçacığını dondurmadan, event-loop'un soket paketlerini işlemesine izin vererek bekle
	while not req_entry["completed"]:
		if timer and timer.time_left <= 0.0:
			break
		if tree:
			await tree.process_frame
		else:
			break

	if not req_entry["completed"]:
		_pending_requests.erase(req_id)
		print("[TIMING] %d | DBG_QUERY_TIMEOUT | cmd=%s req=%s" % [Time.get_ticks_msec(), command, req_id])
		if session.is_breaked():
			return paused_result()
		return timeout_result(timeout_sec)

	var res = req_entry["payload"]
	_pending_requests.erase(req_id)
	print("[TIMING] %d | DBG_QUERY_RESPONSE | cmd=%s req=%s" % [Time.get_ticks_msec(), command, req_id])
	return res

## Oyun hata ayıklayıcıda durmuş (betik hatası ya da kesme noktası): zaman aşımı yerine gerçek neden.
static func paused_result() -> Dictionary:
	return {"success": false, "error": "GAME_PAUSED_IN_DEBUGGER", "message": "The game is paused in the Godot debugger (a script error or breakpoint stopped it), so it cannot answer. The error is in the editor's Debugger tab. Fix the script and call restart_game."}

static func timeout_result(timeout_sec: float) -> Dictionary:
	return {"success": false, "error": "RUNTIME_QUERY_TIMEOUT", "message": "Çalışma zamanı sorgusu zaman aşımına uğradı (%.1f sn)." % timeout_sec}

## Ping-öncelikli sorgu: bridge canlılığını önce kanıtlar, sonra gerçek sorguyu gönderir.
## Session yok -> DEBUGGER_NOT_CONNECTED; ping yanıtsız -> BRIDGE_NOT_READY.
func query_with_ready_check(command: String, args: Array = [], ping_timeout_sec: float = 1.0, query_timeout_sec: float = 3.0) -> Dictionary:
	var session = get_active_session()
	if not session:
		return {"success": false, "error": "DEBUGGER_NOT_CONNECTED", "message": "Aktif bir oyun oturumu bulunamadı."}
	var ping = await query_async("ping", [], ping_timeout_sec)
	var branch = ready_check_result(ping)
	if not bool(branch.get("proceed", false)):
		return branch["result"]
	return await query_async(command, args, query_timeout_sec)

## Ping -> devam kararı (pure; session gerektirmez).
static func ready_check_result(ping: Dictionary) -> Dictionary:
	if ping is Dictionary and bool(ping.get("success", false)):
		return {"proceed": true, "result": {}}
	return {"proceed": false, "result": {"success": false, "error": "BRIDGE_NOT_READY", "message": "Runtime bridge hazır değil (ping yanıtsız). Oyun yeni başladıysa bir saniye sonra tekrar deneyin."}}
