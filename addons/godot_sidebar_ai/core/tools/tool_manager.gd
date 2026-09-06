@tool
extends RefCounted
class_name AISidebarToolManager

## Merkezi Araç Yöneticisi, Yetki Denetleyicisi ve Progressive Tool Routing Motoru (SRP).
## 37 aracın tamamını her LLM isteğinde göndermek yerine, kullanıcı isteğine göre
## dinamik olarak yalnızca ilgili araç alt kümesini modele sunar.

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")
const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarSceneTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/scene_tools.gd")
const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")
const AISidebarEditorTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/editor_tools.gd")
const AISidebarGameIntentTools = preload("res://addons/godot_sidebar_ai/core/tools/intent/game_intent_tools.gd")

## Tüm mevcut araç şemalarını döner (Full Schema Catalog)
static func get_all_schemas() -> Array:
	var schemas: Array = []
	
	# Progressive Discovery: search_tools aracı
	schemas.append({
		"type": "function",
		"function": {
			"name": "search_tools",
			"description": "Mevcut tüm Godot araçları arasında arama yapar ve sadece ilgili araçların listesini döner.",
			"parameters": {
				"type": "object",
				"properties": {
					"query": { "type": "string", "description": "Aranacak kelime (örn: 'scene', 'script', 'camera', 'character', 'enemy', 'hud')." }
				},
				"required": ["query"]
			}
		}
	})
	
	# Kullanıcıdan Netleştirme İsteme: ask_user aracı
	schemas.append({
		"type": "function",
		"function": {
			"name": "ask_user",
			"description": "Sonucu kökten değiştirecek ve aktif editör bağlamından çıkarılamayan kritik bir belirsizlik olduğunda kullanıcıya soru sorup netleştirme (clarification) ister (Örn: 'Sahne oluştur ve slime yap' dendiğinde 2D mi 3D mi olduğu belirsizse). Önemsiz detaylarda (hız, renk, boyut vb.) KESİNLİKLE soru sormayın, makul varsayımla devam edin.",
			"parameters": {
				"type": "object",
				"properties": {
					"question": {
						"type": "string",
						"description": "Kullanıcıya sorulacak açık, net ve kısa soru."
					},
					"options": {
						"type": "array",
						"items": { "type": "string" },
						"description": "Kullanıcının tek tıkla seçebileceği hızlı seçenekler (örn: ['2D', '3D']). İsteğe bağlıdır."
					}
				},
				"required": ["question"]
			}
		}
	})
	
	schemas.append_array(AISidebarSceneTools.get_schemas())
	schemas.append_array(AISidebarScriptTools.get_schemas())
	schemas.append_array(AISidebarEditorTools.get_schemas())
	schemas.append_array(AISidebarGameIntentTools.get_schemas())
	
	return schemas

## Kullanıcı isteği veya konuşma bağlamına göre yalnızca ilgili araç şemalarını filtreler
static func get_relevant_schemas(context_text: String, explicitly_unlocked: Array = []) -> Array:
	var all_schemas = get_all_schemas()
	var text = context_text.to_lower()
	
	var active_tool_names: Dictionary = {}
	
	# 1. Çekirdek Araçlar (Core Discovery, Clarification & Inspection - Daima Erişilebilir)
	var core_tools = ["search_tools", "ask_user", "analyze_project", "read_script"]
	for ct in core_tools:
		active_tool_names[ct] = true
		
	# 2. Kategori Anahtar Kelimeleri & Niyet Ayrımı
	var vision_keywords = [
		"viewport", "gör", "bak", "görüntü", "resim", "screenshot", "ekran", "vision",
		"görsel", "hiza", "align", "gözlem", "bakış", "incele"
	]
	var has_vision_intent = false
	for kw in vision_keywords:
		if kw in text:
			has_vision_intent = true
			break

	var runtime_keywords = [
		"runtime", "error", "hata", "bug", "crash", "play", "oyna", "çalıştır",
		"run", "test", "debug", "düzelt", "fix", "heal", "screenshot", "ekran",
		"stop", "durdur", "restart", "sıfırla", "log", "diagnostic", "check"
	]
	var has_runtime_intent = false
	for kw in runtime_keywords:
		if kw in text:
			has_runtime_intent = true
			break

	var script_keywords = [
		"script", "gdscript", "kod", "code", "fonksiyon", "method", "variable",
		"değişken", "class", "extends", "dosya", "file", "sil", "delete", "oluştur",
		"create", "yaz", "write", "düzenle", "edit", "güncelle", "update", "temizle",
		"validate", "doğrula", ".gd", "shader"
	]
	var has_script_intent = false
	for kw in script_keywords:
		if kw in text:
			has_script_intent = true
			break
			
	var scene_keywords = [
		"scene", "sahne", "node", "düğüm", "3d", "2d", "camera", "kamera",
		"hud", "ui", "arayüz", "level", "tscn", ".tscn", "mesh", "collision",
		"spawn", "rigid", "area", "light", "ışık", "spatial", "tree", "ağaç",
		"property", "özellik", "signal", "sinyal", "reparent", "select", "seç",
		"düşman sahnesi", "karakter sahnesi", "chest", "sandık"
	]
	var has_scene_intent = false
	for kw in scene_keywords:
		if kw in text:
			has_scene_intent = true
			break
			
	# 3. İlgili Kategorileri Aktif Et
	if has_vision_intent:
		var vision_tools = [
			"take_viewport_screenshot", "take_editor_screenshot", "take_runtime_screenshot",
			"get_active_scene_tree", "get_selected_nodes", "replace_file_content"
		]
		for vt in vision_tools:
			active_tool_names[vt] = true

	if has_runtime_intent:
		# Runtime / Debug odaklı dar araç seti (~10 araç)
		var runtime_tools = [
			"play_game", "stop_game", "restart_game", "get_runtime_errors",
			"take_runtime_screenshot", "take_viewport_screenshot", "create_or_update_script", "replace_file_content", "validate_script", "read_script"
		]
		for rt in runtime_tools:
			active_tool_names[rt] = true
			
	if has_script_intent:
		var script_tools = [
			"create_or_update_script", "replace_file_content", "validate_script", "write_files",
			"delete_file", "list_dir", "get_open_scripts", "read_script"
		]
		for st in script_tools:
			active_tool_names[st] = true
			
	if has_scene_intent:
		var scene_tools = [
			"create_scene", "save_scene", "add_node", "delete_node", "rename_node",
			"duplicate_node", "set_node_property", "connect_signal", "reparent_node",
			"select_node", "get_active_scene_tree", "get_selected_nodes", "write_files",
			"list_dir", "take_viewport_screenshot", "create_character_scene", "create_enemy_scene",
			"create_ui_hud", "create_interactable", "setup_camera_follow"
		]
		for sc in scene_tools:
			active_tool_names[sc] = true
			
	# 4. Hiçbir kategori eşleşmediyse varsayılan temel araç kümesini sun
	if not has_script_intent and not has_scene_intent and not has_runtime_intent and not has_vision_intent:
		var default_tools = [
			"create_or_update_script", "replace_file_content", "create_scene", "save_scene",
			"play_game", "get_runtime_errors", "take_viewport_screenshot", "write_files", "list_dir", "read_script"
		]
		for dt in default_tools:
			active_tool_names[dt] = true
			
	# 5. search_tools veya önceki adımlarda açılan özel araçlar (Progressive Unlocking)
	for ut in explicitly_unlocked:
		var ut_str = str(ut)
		if not ut_str.is_empty():
			active_tool_names[ut_str] = true
			
	# 6. Sıralı Şema Çıktısı Oluştur
	var filtered_schemas: Array = []
	for s in all_schemas:
		var fn_name = s.get("function", {}).get("name", "")
		if active_tool_names.has(fn_name):
			filtered_schemas.append(s)
			
	return filtered_schemas

static func execute_tool(tool_name: String, args: Dictionary, is_user_approved: bool = false) -> Dictionary:
	if tool_name == "search_tools":
		return _search_tools(args)
	elif tool_name == "ask_user":
		return AISidebarToolResult.ok({
			"question": args.get("question", ""),
			"options": args.get("options", []),
			"clarification": true
		}, "Clarification requested.")
		
	# 1. Verification-First: Doğrulama Onaydan Önce Çalışır (Pipeline Gate)
	# Hatalı kod tespit edilirse onay sorulmaz, diske yazılmaz, doğrudan AI modeline dönülür.
	var pre_val = _pre_verify_write_candidate(tool_name, args)
	if not pre_val.is_empty() and not pre_val.get("success", true):
		return pre_val
		
	# 2. Yetki Denetimi & Onay Politikası (Permission & Approval Policy)
	if not is_user_approved and AISidebarPermissionPolicy.requires_user_approval(tool_name, args):
		return AISidebarToolResult.err(
			"APPROVAL_REQUIRED",
			"Bu işlem (" + tool_name + ") kullanıcı onayı gerektirir.",
			true,
			{"requires_approval": true, "tool_name": tool_name, "args": args}
		)
		
	# 2. Sahne İlkel Araçları
	for s in AISidebarSceneTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarSceneTools.execute(tool_name, args)
			
	# 3. Script İlkel Araçları
	for s in AISidebarScriptTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarScriptTools.execute(tool_name, args)
			
	# 4. Editör İlkel Araçları
	for s in AISidebarEditorTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarEditorTools.execute(tool_name, args)
			
	# 5. Yüksek Seviyeli Intent Araçları
	for s in AISidebarGameIntentTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarGameIntentTools.execute(tool_name, args)
			
	return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen motor aracı: " + tool_name)

static func _search_tools(args: Dictionary) -> Dictionary:
	var query = str(args.get("query", "")).to_lower()
	var all = get_all_schemas()
	var matches: Array = []
	
	for tool_def in all:
		var fn = tool_def.get("function", {})
		var t_name = fn.get("name", "")
		var t_desc = fn.get("description", "")
		if query.is_empty() or query in t_name.to_lower() or query in t_desc.to_lower():
			matches.append({
				"name": t_name,
				"description": t_desc
			})
			
	return AISidebarToolResult.ok({
		"query": query,
		"count": matches.size(),
		"tools": matches
	})

## Diske yazmadan veya onay sormadan önce kod doğrulaması (Pipeline Gate)
static func _pre_verify_write_candidate(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"create_or_update_script":
			var raw_path = args.get("file_path", "")
			var content = args.get("content", "")
			var safe_check = AISidebarPathPolicy.is_safe_to_write(raw_path)
			if not safe_check["safe"]:
				return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
			var path = safe_check["path"]
			var val_res = AISidebarVerificationPipeline.validate_source(content, path)
			if not val_res.get("success", false):
				var err_obj = val_res.get("error", {})
				var err_code = err_obj.get("code", "VALIDATION_FAILED") if err_obj is Dictionary else "VALIDATION_FAILED"
				var err_msg = err_obj.get("message", "Doğrulama hatası") if err_obj is Dictionary else str(val_res.get("error", "Doğrulama hatası"))
				return AISidebarToolResult.err(err_code, "Dosya doğrulaması başarısız, diske yazılmadı: " + err_msg, false, val_res)
				
		"replace_file_content":
			var raw_path = args.get("file_path", "")
			var target_code = args.get("target_code", "")
			var replacement_code = args.get("replacement_code", "")
			if target_code.is_empty():
				return AISidebarToolResult.err("INVALID_ARGUMENT", "target_code parametresi boş olamaz.")
			var safe_check = AISidebarPathPolicy.is_safe_to_write(raw_path)
			if not safe_check["safe"]:
				return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
			var path = safe_check["path"]
			if not FileAccess.file_exists(path):
				return AISidebarToolResult.err("FILE_NOT_FOUND", "Değiştirilecek dosya bulunamadı: " + path)
			var file = FileAccess.open(path, FileAccess.READ)
			if not file:
				return AISidebarToolResult.err("READ_ERROR", "Dosya okunamadı: " + path)
			var old_content = file.get_as_text()
			file.close()
			var first_idx = old_content.find(target_code)
			if first_idx == -1:
				return AISidebarToolResult.err("TARGET_NOT_FOUND", "Hedef kod bloğu dosyada bulunamadı: " + path)
			var second_idx = old_content.find(target_code, first_idx + target_code.length())
			if second_idx != -1:
				var occurrences = 0
				var pos = 0
				while true:
					pos = old_content.find(target_code, pos)
					if pos == -1:
						break
					occurrences += 1
					pos += target_code.length()
				return AISidebarToolResult.err("MULTIPLE_TARGETS_FOUND", "Hedef kod dosyada birden fazla kez (" + str(occurrences) + " kez) bulundu: " + path)
			var new_content = old_content.substr(0, first_idx) + replacement_code + old_content.substr(first_idx + target_code.length())
			var val_res = AISidebarVerificationPipeline.validate_source(new_content, path)
			if not val_res.get("success", false):
				var err_obj = val_res.get("error", {})
				var err_code = err_obj.get("code", "VALIDATION_FAILED") if err_obj is Dictionary else "VALIDATION_FAILED"
				var err_msg = err_obj.get("message", "Doğrulama hatası") if err_obj is Dictionary else str(val_res.get("error", "Doğrulama hatası"))
				return AISidebarToolResult.err(err_code, "Dosya doğrulaması başarısız, diske yazılmadı: " + err_msg, false, val_res)

		"write_files":
			var files_arr = args.get("files", [])
			if not (files_arr is Array) or files_arr.is_empty():
				return AISidebarToolResult.err("INVALID_ARGUMENT", "'files' listesi boş veya geçersiz.")
			for f_item in files_arr:
				if f_item is Dictionary:
					var raw_p = f_item.get("file_path", "")
					var safe_chk = AISidebarPathPolicy.is_safe_to_write(raw_p)
					if not safe_chk["safe"]:
						return AISidebarToolResult.err("PERMISSION_DENIED", "Güvenlik engeli: " + safe_chk["reason"] + " (" + raw_p + ")")
			var val_res = AISidebarVerificationPipeline.validate_batch_files(files_arr)
			if not val_res.get("success", false):
				var err_obj = val_res.get("error", {})
				var err_code = err_obj.get("code", "BATCH_VALIDATION_FAILED") if err_obj is Dictionary else "BATCH_VALIDATION_FAILED"
				var err_msg = err_obj.get("message", "Doğrulama hatası") if err_obj is Dictionary else str(val_res.get("error", "Doğrulama hatası"))
				return AISidebarToolResult.err(err_code, "Toplu dosya yazımı doğrulanamadı: " + err_msg, false, val_res)

		"create_scene":
			var scene_path = args.get("scene_path", "")
			var tscn_content = args.get("tscn_content", "")
			if not tscn_content.strip_edges().is_empty():
				var safe_check = AISidebarPathPolicy.is_safe_to_write(scene_path)
				if not safe_check["safe"]:
					return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
				var val_res = AISidebarVerificationPipeline.validate_source(tscn_content, scene_path)
				if not val_res.get("success", false):
					var err_obj = val_res.get("error", {})
					var err_code = err_obj.get("code", "VALIDATION_FAILED") if err_obj is Dictionary else "VALIDATION_FAILED"
					var err_msg = err_obj.get("message", "Sahne doğrulama hatası") if err_obj is Dictionary else str(val_res.get("error", "Sahne doğrulama hatası"))
					return AISidebarToolResult.err(err_code, "Sahne doğrulaması başarısız, diske yazılmadı: " + err_msg, false, val_res)

		"delete_file":
			var raw_path = args.get("file_path", "")
			var safe_check = AISidebarPathPolicy.is_safe_to_delete(raw_path)
			if not safe_check["safe"]:
				return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])

	return {}
