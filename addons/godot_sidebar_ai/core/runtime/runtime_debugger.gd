@tool
extends RefCounted
class_name AISidebarRuntimeDebugger

## Çalışma Zamanı Hata Ayıklayıcı ve Oyun İzleyici (Runtime Debugger) (SRP).
## Oyunun çalışmasını kontrol eder, artımlı logları izler ve RuntimeObservation üretir.
## Epistemik durum makinesi: STARTING, NO_NEW_LOG_DATA, INCONCLUSIVE, ERROR_DETECTED, CRASHED, VERIFIED_CLEAN.

const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarSourceMapper = preload("res://addons/godot_sidebar_ai/core/runtime/source_mapper.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

signal runtime_state_changed(new_status: AISidebarRuntimeObservation.RuntimeStatus)
signal runtime_error_detected(observation: AISidebarRuntimeObservation)

# Süreçler ve araç çağrıları arasında paylaşılan kalıcı izleme durumu
static var _active_start_time_msec: int = 0
static var _active_start_log_offset: int = 0
static var _last_poll_offset: int = 0
static var _is_monitoring: bool = false
static var _last_observation: AISidebarRuntimeObservation = null

func _init() -> void:
	if _last_observation == null:
		_last_observation = AISidebarRuntimeObservation.new()

static func _get_log_path() -> String:
	return OS.get_user_data_dir().path_join("logs/godot.log")

static func _reset_log_pointer() -> void:
	var log_path = _get_log_path()
	var cur_len = 0
	if FileAccess.file_exists(log_path):
		var f = FileAccess.open(log_path, FileAccess.READ)
		if f:
			cur_len = f.get_length()
			f.close()
	_active_start_log_offset = cur_len
	_last_poll_offset = cur_len
	_active_start_time_msec = Time.get_ticks_msec()
	_is_monitoring = true

## Oyunu başlatır (F5 veya F6)
func play(current_scene_only: bool = false) -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Oyun başlatma editör gerektirir.")
		
	_reset_log_pointer()
	_last_observation = AISidebarRuntimeObservation.new()
	_last_observation.status = AISidebarRuntimeObservation.RuntimeStatus.STARTING
	_last_observation.is_process_alive = true
	_last_observation.elapsed_msec = 0
	
	if current_scene_only:
		EditorInterface.play_current_scene()
	else:
		EditorInterface.play_main_scene()
		
	runtime_state_changed.emit(_last_observation.status)
	return AISidebarToolResult.ok({
		"status": "STARTING",
		"status_name": "Başlatılıyor (STARTING)",
		"observation_verdict": _last_observation.get_observation_verdict(),
		"is_process_alive": true,
		"elapsed_msec": 0
	}, "✓ Oyun başlatıldı. Çalışma zamanı gözlemi aktif.")

## Oyunu durdurur
func stop() -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Oyun durdurma editör gerektirir.")
		
	EditorInterface.stop_playing_scene()
	_is_monitoring = false
	if _last_observation:
		_last_observation.status = AISidebarRuntimeObservation.RuntimeStatus.STOPPED
		_last_observation.is_process_alive = false
		runtime_state_changed.emit(_last_observation.status)
		
	return AISidebarToolResult.ok({
		"status": "STOPPED",
		"status_name": "Durduruldu (STOPPED)",
		"is_process_alive": false
	}, "✓ Oyun durduruldu.")

## Oyunu yeniden başlatır
func restart(current_scene_only: bool = false) -> Dictionary:
	stop()
	OS.delay_msec(200)
	return play(current_scene_only)

## Belirli bir checkpoint süresi ve log analizi ile epistemik gözlem yapar
func observe_runtime(checkpoint_duration_msec: int = 1500) -> AISidebarRuntimeObservation:
	var log_path = _get_log_path()
	var current_len = 0
	var f: FileAccess = null
	if FileAccess.file_exists(log_path):
		f = FileAccess.open(log_path, FileAccess.READ)
		if f:
			current_len = f.get_length()
			
	var is_alive = false
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("is_playing_scene"):
		is_alive = EditorInterface.is_playing_scene()
	else:
		is_alive = _is_monitoring
		
	var elapsed = 0
	if _active_start_time_msec > 0:
		elapsed = Time.get_ticks_msec() - _active_start_time_msec
		
	var new_bytes = maxi(0, current_len - _last_poll_offset)
	var all_text_since_start = ""
	
	if f:
		if current_len > _active_start_log_offset:
			f.seek(_active_start_log_offset)
			all_text_since_start = f.get_as_text()
		_last_poll_offset = current_len
		f.close()
		
	var obs: AISidebarRuntimeObservation
	if not all_text_since_start.is_empty():
		obs = AISidebarSourceMapper.parse_log_text(all_text_since_start)
	else:
		obs = AISidebarRuntimeObservation.new()
		
	obs.elapsed_msec = elapsed
	obs.new_log_bytes = new_bytes
	obs.is_process_alive = is_alive
	
	# Durum Kararı (Epistemic State Determination)
	if obs.errors.size() > 0:
		obs.status = AISidebarRuntimeObservation.RuntimeStatus.ERROR_DETECTED
		runtime_error_detected.emit(obs)
	elif not is_alive and _is_monitoring:
		obs.status = AISidebarRuntimeObservation.RuntimeStatus.CRASHED
		_is_monitoring = false
	elif is_alive:
		if elapsed < 300:
			obs.status = AISidebarRuntimeObservation.RuntimeStatus.STARTING
		elif new_bytes == 0 and elapsed < checkpoint_duration_msec:
			obs.status = AISidebarRuntimeObservation.RuntimeStatus.NO_NEW_LOG_DATA
		elif elapsed < checkpoint_duration_msec:
			obs.status = AISidebarRuntimeObservation.RuntimeStatus.INCONCLUSIVE
		else:
			obs.status = AISidebarRuntimeObservation.RuntimeStatus.VERIFIED_CLEAN
	else:
		obs.status = AISidebarRuntimeObservation.RuntimeStatus.STOPPED
		
	_last_observation = obs
	runtime_state_changed.emit(obs.status)
	return obs

## Güncel gözlem nesnesini döner
func get_current_observation(checkpoint_duration_msec: int = 1500) -> AISidebarRuntimeObservation:
	return observe_runtime(checkpoint_duration_msec)

## Editör ekran görüntüsü alma
static func take_editor_screenshot(save_path: String = "user://ai_editor_snapshot.png") -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Editör ekran görüntüsü için GUI gereklidir.")
		
	var vp = EditorInterface.get_base_control().get_viewport() if EditorInterface.has_method("get_base_control") else null
	if not vp:
		return AISidebarToolResult.err("VIEWPORT_NOT_FOUND", "Viewport bulunamadı.")
		
	var img = vp.get_texture().get_image()
	if not img:
		return AISidebarToolResult.err("IMAGE_EMPTY", "Görüntü verisi boş.")
		
	img.save_png(save_path)
	return AISidebarToolResult.ok({"path": save_path}, "✓ Editör ekran görüntüsü alındı: " + save_path)

## Çalışan oyunun ekran görüntüsü alma
static func take_runtime_screenshot(save_path: String = "user://ai_runtime_snapshot.png") -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Çalışan oyun ekran görüntüsü için GUI gereklidir.")
		
	var main_vp = null
	if EditorInterface.has_method("get_editor_main_screen"):
		var ms = EditorInterface.get_editor_main_screen()
		if ms:
			main_vp = ms.get_viewport()
			
	if not main_vp:
		return take_editor_screenshot(save_path)
		
	var img = main_vp.get_texture().get_image()
	if not img:
		return AISidebarToolResult.err("IMAGE_EMPTY", "Görüntü verisi boş.")
		
	img.save_png(save_path)
	return AISidebarToolResult.ok({"path": save_path}, "✓ Oyun ekran görüntüsü alındı: " + save_path)
