@tool
extends RefCounted
class_name AISidebarPermissionPolicy

## Araç Yetki ve Güvenlik Seviyesi Yöneticisi & Denetleyicisi (SRP).

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

## Auto Approve Çalışma Modları (Cursor Benzeri)
enum AutoApproveMode {
	MANUAL = 0,     # Mevcut davranış: Onay gerektiren her işlem kullanıcıya sorulur.
	AUTO = 1,       # Güvenli/düşük riskli (READ_ONLY, WRITE) işlemler otomatik onaylanır; DESTRUCTIVE ve EXTERNAL_SENSITIVE onay ister.
	FULL_AUTO = 2   # Hiçbir tool için kullanıcı onayı istemez (Güvenlik filtreleri / PathPolicy yine de devrededir).
}

## Merkezi Tool Risk Sınıflandırması
enum RiskLevel {
	READ_ONLY = 0,          # Okuma, arama, gözlem, ekran görüntüsü (Sıfır risk)
	WRITE = 1,              # Dosya yazma, kod güncelleme, sahne/düğüm ekleme (Orta risk)
	DESTRUCTIVE = 2,        # Dosya veya düğüm silme, yıkıcı reset (Yüksek risk)
	EXTERNAL_SENSITIVE = 3  # Dış sisteme/ağa veri aktarma, hassas/dinamik yürütme (Kritik risk)
}

## Geriye dönük uyumluluk için PermissionLevel enum'ı korunur
enum PermissionLevel {
	READ_ONLY = 0,
	SAFE_MUTATION = 1,
	DESTRUCTIVE = 2,
	EXTERNAL_SENSITIVE = 3
}

## Merkezi Risk Kayıt Defteri (Central Risk Registry)
static var _tool_risk_registry: Dictionary = {}

static func get_risk_registry() -> Dictionary:
	if _tool_risk_registry.is_empty():
		_init_default_risks()
	return _tool_risk_registry

static func register_tool_risk(tool_name: String, risk: int) -> void:
	get_risk_registry()[tool_name] = risk

static func get_tool_risk(tool_name: String) -> int:
	var reg = get_risk_registry()
	if reg.has(tool_name):
		return reg[tool_name]
	return RiskLevel.WRITE

## Geriye dönük uyumluluk: get_tool_permission_level
static func get_tool_permission_level(tool_name: String) -> int:
	return get_tool_risk(tool_name)

static func parse_auto_approve_mode(val: Variant) -> AutoApproveMode:
	if val is int:
		match val:
			1: return AutoApproveMode.AUTO
			2: return AutoApproveMode.FULL_AUTO
			_: return AutoApproveMode.MANUAL
	var s = str(val).strip_edges().to_upper()
	match s:
		"AUTO": return AutoApproveMode.AUTO
		"FULL_AUTO", "FULLAUTO", "FULL": return AutoApproveMode.FULL_AUTO
		_: return AutoApproveMode.MANUAL

static func get_auto_approve_mode() -> AutoApproveMode:
	var cfg = AISidebarConfig.load_config()
	return parse_auto_approve_mode(cfg.get("auto_approve_mode", "MANUAL"))

static func set_auto_approve_mode(mode: AutoApproveMode) -> void:
	var cfg = AISidebarConfig.load_config()
	match mode:
		AutoApproveMode.AUTO:
			cfg["auto_approve_mode"] = "AUTO"
		AutoApproveMode.FULL_AUTO:
			cfg["auto_approve_mode"] = "FULL_AUTO"
		_:
			cfg["auto_approve_mode"] = "MANUAL"
	AISidebarConfig.save_config(cfg)

static func get_mode_name(mode: AutoApproveMode) -> String:
	match mode:
		AutoApproveMode.AUTO: return "AUTO"
		AutoApproveMode.FULL_AUTO: return "FULL_AUTO"
		_: return "MANUAL"

## Bu aracın çalıştırılması için kullanıcıdan açık onay alınması gerekir mi?
static func requires_user_approval(tool_name: String, args: Dictionary = {}, mode_override: int = -1) -> bool:
	var mode = mode_override if mode_override >= 0 else get_auto_approve_mode()
	var risk = get_tool_risk(tool_name)
	var cfg = AISidebarConfig.load_config()
	
	# 1. FULL_AUTO: Hiçbir tool için kullanıcı onayı istemez
	if mode == AutoApproveMode.FULL_AUTO:
		return false
		
	# 2. AUTO: Yalnızca DESTRUCTIVE ve EXTERNAL_SENSITIVE onay gerektirir
	if mode == AutoApproveMode.AUTO:
		if risk == RiskLevel.DESTRUCTIVE:
			var req_delete = cfg.get("require_delete_approval", true)
			if not req_delete and tool_name in ["delete_node", "delete_file"]:
				return false
			return true
		elif risk == RiskLevel.EXTERNAL_SENSITIVE:
			return true
		return false
		
	# 3. MANUAL: Mevcut onay davranışı
	if risk == RiskLevel.DESTRUCTIVE:
		var req_delete = cfg.get("require_delete_approval", true)
		if not req_delete and tool_name in ["delete_node", "delete_file"]:
			return false
		return true
		
	if risk == RiskLevel.EXTERNAL_SENSITIVE:
		return true
		
	# Eğer bir dosya sıfırdan yazılmıyor da mevcut bir dosya eziliyorsa veya cerrahi değiştiriliyorsa
	if tool_name in ["create_or_update_script", "replace_file_content"]:
		var path = args.get("file_path", "")
		if not path.is_empty() and FileAccess.file_exists(path):
			var req_overwrite = cfg.get("require_overwrite_approval", true)
			return req_overwrite
			
	if tool_name == "write_files":
		var files_arr = args.get("files", [])
		for f_item in files_arr:
			if f_item is Dictionary:
				var p = f_item.get("file_path", "")
				if not p.is_empty() and FileAccess.file_exists(p):
					var req_overwrite = cfg.get("require_overwrite_approval", true)
					return req_overwrite
					
	return false

static func _init_default_risks() -> void:
	# READ_ONLY: Read, search, analyze, project inspection, scene tree inspection, runtime log/error, vision
	var read_only_tools = [
		"get_scene_tree", "read_script", "get_project_files", "search_project_assets",
		"get_selected_nodes", "get_node_properties", "get_editor_errors", "get_runtime_errors",
		"search_tools", "ask_user", "validate_script", "take_editor_screenshot",
		"take_runtime_screenshot", "take_viewport_screenshot", "analyze_project",
		"list_dir", "get_open_scripts", "open_script"
	]
	for t in read_only_tools:
		_tool_risk_registry[t] = RiskLevel.READ_ONLY
		
	# WRITE: Create/update script, write_files, replace_file_content, scene mutations
	var write_tools = [
		"create_or_update_script", "replace_file_content", "write_files",
		"create_scene", "save_scene", "add_node", "instantiate_scene",
		"rename_node", "duplicate_node", "set_node_property", "connect_signal",
		"attach_script_to_node", "reparent_node", "select_node",
		"play_game", "stop_game", "restart_game",
		"create_character_scene", "create_enemy_scene", "create_ui_hud",
		"create_interactable", "setup_camera_follow"
	]
	for t in write_tools:
		_tool_risk_registry[t] = RiskLevel.WRITE
		
	# DESTRUCTIVE: Silme ve yıkıcı temizlik işlemleri
	var destructive_tools = [
		"delete_node", "delete_file"
	]
	for t in destructive_tools:
		_tool_risk_registry[t] = RiskLevel.DESTRUCTIVE
		
	# EXTERNAL_SENSITIVE: Dış sisteme/ağa veri aktarma veya hassas dinamik yürütme
	var sensitive_tools = [
		"eval_gdscript"
	]
	for t in sensitive_tools:
		_tool_risk_registry[t] = RiskLevel.EXTERNAL_SENSITIVE
