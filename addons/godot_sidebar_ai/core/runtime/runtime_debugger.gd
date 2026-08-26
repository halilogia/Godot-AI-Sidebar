@tool
extends RefCounted
class_name AISidebarRuntimeDebugger

## Çalışma Zamanı Hata Ayıklayıcı ve Oyun İzleyici (Runtime Debugger) (SRP).
## Oyunun çalışmasını kontrol eder, artımlı logları izler ve RuntimeObservation üretir.

const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarSourceMapper = preload("res://addons/godot_sidebar_ai/core/runtime/source_mapper.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

signal runtime_state_changed(new_status: AISidebarRuntimeObservation.RuntimeStatus)
signal runtime_error_detected(observation: AISidebarRuntimeObservation)

var _last_log_offset: int = 0
var _is_monitoring: bool = false
var _current_observation: AISidebarRuntimeObservation = null

func _init() -> void:
	_current_observation = AISidebarRuntimeObservation.new()
	_reset_log_pointer()

func _reset_log_pointer() -> void:
	var log_path = _get_log_path()
	if FileAccess.file_exists(log_path):
		var f = FileAccess.open(log_path, FileAccess.READ)
		if f:
			_last_log_offset = f.get_length()
			f.close()

func _get_log_path() -> String:
	return OS.get_user_data_dir().path_join("logs/godot.log")

## Oyunu başlatır (F5 veya F6)
func play(current_scene_only: bool = false) -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Oyun başlatma editör gerektirir.")
		
	_reset_log_pointer()
	_current_observation = AISidebarRuntimeObservation.new()
	_current_observation.status = AISidebarRuntimeObservation.RuntimeStatus.RUNNING
	_is_monitoring = true
	
	if current_scene_only:
		EditorInterface.play_current_scene()
	else:
		EditorInterface.play_main_scene()
		
	runtime_state_changed.emit(_current_observation.status)
	return AISidebarToolResult.ok({"status": "RUNNING"}, "✓ Oyun başlatıldı ve çalışma zamanı izleniyor.")

## Oyunu durdurur
func stop() -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Oyun durdurma editör gerektirir.")
		
	EditorInterface.stop_playing_scene()
	_is_monitoring = false
	if _current_observation:
		_current_observation.status = AISidebarRuntimeObservation.RuntimeStatus.STOPPED
		runtime_state_changed.emit(_current_observation.status)
		
	return AISidebarToolResult.ok({"status": "STOPPED"}, "✓ Oyun durduruldu.")

## Oyunu yeniden başlatır
func restart(current_scene_only: bool = false) -> Dictionary:
	stop()
	OS.delay_msec(200)
	return play(current_scene_only)

## Artımlı logları tarar ve yeni hataları yakalar (Throttled Polling)
func poll_incremental_logs() -> AISidebarRuntimeObservation:
	var log_path = _get_log_path()
	if not FileAccess.file_exists(log_path):
		return _current_observation
		
	var f = FileAccess.open(log_path, FileAccess.READ)
	if not f:
		return _current_observation
		
	var len = f.get_length()
	if len > _last_log_offset:
		f.seek(_last_log_offset)
		var new_text = f.get_as_text()
		_last_log_offset = len
		f.close()
		
		var delta_obs = AISidebarSourceMapper.parse_log_text(new_text)
		if delta_obs.has_errors():
			_current_observation = delta_obs
			runtime_error_detected.emit(delta_obs)
			return delta_obs
	else:
		f.close()
		
	return _current_observation

## Güncel gözlem nesnesini döner
func get_current_observation() -> AISidebarRuntimeObservation:
	return poll_incremental_logs()

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
		
	# Aktif oyun penceresini yakala
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
