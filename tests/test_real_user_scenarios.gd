@tool
extends RefCounted

const AISidebarGameIntentTools = preload("res://addons/godot_sidebar_ai/core/tools/intent/game_intent_tools.gd")
const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Senaryo A: "Yeni 2D/3D Karakter oluştur"
	var char_res = AISidebarGameIntentTools.execute("create_character_scene", {
		"dimension": "2d",
		"character_name": "PlayerAuto",
		"speed": 350.0
	})
	var scene_created = char_res.get("data", {}).get("scene_path", "")
	if char_res.get("success", false) and FileAccess.file_exists(scene_created):
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo A (create_character_scene) başarısız: " + str(char_res))
		
	# Senaryo B: "Karaktere zıplama ve script bağla"
	var verif_script = AISidebarVerificationPipeline.verify_script("res://tests/integration_project/scripts/player.gd")
	if verif_script.get("status") == AISidebarVerificationPipeline.VerificationStatus.PASSED:
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo B (verify_script) başarısız: " + str(verif_script))
		
	# Senaryo C: "Kameranın takip sistemini kur" (Headless kontrolü: GUI yokken EDITOR_REQUIRED güvenli dönüşü)
	var cam_res = AISidebarGameIntentTools.execute("setup_camera_follow", {
		"camera_path": "Camera2D",
		"target_node_path": "Player",
		"smoothing_enabled": true
	})
	if cam_res.get("success", false) or cam_res.get("error", {}).get("code", "") == "EDITOR_REQUIRED":
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo C (setup_camera_follow) beklenmeyen sonuç: " + str(cam_res))
		
	# Senaryo D: "Düşman devriye AI sahnesi oluştur"
	var enemy_res = AISidebarGameIntentTools.execute("create_enemy_scene", {
		"enemy_name": "EnemyAuto",
		"dimension": "2d"
	})
	var enemy_scene = enemy_res.get("data", {}).get("scene_path", "")
	if enemy_res.get("success", false) and FileAccess.file_exists(enemy_scene):
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo D (create_enemy_scene) başarısız: " + str(enemy_res))
		
	# Senaryo E: "UI HUD (Can barı ve Skor) oluştur"
	var hud_res = AISidebarGameIntentTools.execute("create_ui_hud", {
		"hud_name": "GameHUD"
	})
	var hud_scene = hud_res.get("data", {}).get("scene_path", "")
	if hud_res.get("success", false) and FileAccess.file_exists(hud_scene):
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo E (create_ui_hud) başarısız: " + str(hud_res))
		
	# Senaryo F: "Etkileşimli Alan (Interactable Trigger) oluştur"
	var inter_res = AISidebarGameIntentTools.execute("create_interactable", {
		"object_name": "InteractableChest",
		"prompt_text": "Sandığı Aç [E]"
	})
	var inter_scene = inter_res.get("data", {}).get("scene_path", "")
	if inter_res.get("success", false) and FileAccess.file_exists(inter_scene):
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo F (create_interactable) başarısız: " + str(inter_res))
		
	# Temizlik (Oluşturulan otomatik test sahnelerini sil)
	var to_clean = [
		scene_created,
		char_res.get("data", {}).get("script_path", ""),
		enemy_scene,
		enemy_res.get("data", {}).get("script_path", ""),
		hud_scene,
		inter_scene
	]
	for c in to_clean:
		if not c.is_empty() and FileAccess.file_exists(c):
			DirAccess.remove_absolute(c)
			
	return {"name": "RealUserScenariosTests", "passed": passed, "failed": failed, "errors": errors}
