@tool
extends RefCounted
class_name AISidebarRuntimeObserver

## Çalışma Zamanı Gözlem ve Geri Bildirim Motoru (Runtime Observation & Feedback Loop) (SRP).
## Oyun çalıştırma, hata loglarını yakalama ve Viewport ekran görüntüsü alma yeteneklerini yönetir.

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")

static func capture_recent_errors() -> Array:
	var log_path = OS.get_user_data_dir().path_join("logs/godot.log")
	var errors: Array = []
	
	if FileAccess.file_exists(log_path):
		var f = FileAccess.open(log_path, FileAccess.READ)
		if f:
			var txt = f.get_as_text()
			f.close()
			var lines = txt.split("\n")
			for l in lines:
				if "ERROR" in l or "SCRIPT ERROR" in l or "CRASH" in l:
					errors.append(l)
					
	return errors.slice(-15)

## Viewport ekran görüntüsü alma
static func take_screenshot(target_save_path: String = "user://ai_viewport_snapshot.png") -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Ekran görüntüsü yalnızca editör GUI açıkken alınabilir.")
		
	var vp = null
	if EditorInterface.has_method("get_editor_main_screen"):
		var main_screen = EditorInterface.get_editor_main_screen()
		if main_screen and main_screen.get_viewport():
			vp = main_screen.get_viewport()
			
	if not vp and EditorInterface.has_method("get_base_control"):
		var base_ctrl = EditorInterface.get_base_control()
		if base_ctrl and base_ctrl.get_viewport():
			vp = base_ctrl.get_viewport()
			
	if not vp:
		return AISidebarToolResult.err("VIEWPORT_NOT_FOUND", "Aktif editör Viewport bulunamadı.")
		
	var tex = vp.get_texture()
	if not tex:
		return AISidebarToolResult.err("TEXTURE_EMPTY", "Viewport texture alınamadı.")
		
	var img = tex.get_image()
	if not img:
		return AISidebarToolResult.err("IMAGE_EMPTY", "Görüntü verisi çıkarılamadı.")
		
	var err = img.save_png(target_save_path)
	if err != OK:
		return AISidebarToolResult.err("SAVE_FAILED", "Ekran görüntüsü kaydedilemedi: " + str(err))
		
	var vision_input = AISidebarVisionInput.from_file(target_save_path)
	return AISidebarToolResult.ok({
		"file_path": target_save_path,
		"width": img.get_width(),
		"height": img.get_height(),
		"has_vision_data": vision_input != null
	}, "✓ Viewport ekran görüntüsü başarıyla alındı: " + target_save_path)
