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
const AISidebarUITelemetryTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd")
const AISidebarPlanningPolicy = preload("res://addons/godot_sidebar_ai/core/agent/planning_policy.gd")
const AISidebarSkillTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/skill_tools.gd")
const AISidebarOutputTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/output_tools.gd")
const AISidebarRuntimeInputTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/runtime_input_tools.gd")
const AISidebarRulesTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/rules_tools.gd")
const AISidebarGoalTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/goal_tools.gd")
const AISidebarApiTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/api_tools.gd")
const AISidebarProjectSettingsTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/project_settings_tools.gd")
const AISidebarBlenderTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/blender_tools.gd")

## Tüm mevcut araç şemalarını döner (Full Schema Catalog)
static func get_all_schemas() -> Array:
	var schemas: Array = []
	
	# Progressive Discovery: search_tools aracı
	schemas.append({
		"type": "function",
		"function": {
			"name": "search_tools",
			"description": "Searches all available Godot tools and returns only the matching ones.",
			"parameters": {
				"type": "object",
				"properties": {
					"query": { "type": "string", "description": "Word to search for (e.g. 'scene', 'script', 'camera', 'character', 'enemy', 'hud')." }
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
			"description": "Last resort. Asks the user only when two readings of the request lead to incompatible, costly work and neither the request nor the editor context gives any hint. If the user named what they want (e.g. 'UI', 'map'), do not ask: pick the reading closest to their words, start with the smallest working version, state your assumption in one sentence and proceed. NEVER ask about scope or minor details (speed, color, size, ...).",
			"parameters": {
				"type": "object",
				"properties": {
					"question": {
						"type": "string",
						"description": "A clear, short question for the user."
					},
					"options": {
						"type": "array",
						"items": { "type": "string" },
						"description": "Quick options the user can pick with one click (e.g. ['2D', '3D']). Optional."
					}
				},
				"required": ["question"]
			}
		}
	})

	# Uygulama Planı Sunumu: propose_plan aracı
	schemas.append({
		"type": "function",
		"function": {
			"name": "propose_plan",
			"description": "For a medium or large build request, presents an actionable implementation plan BEFORE WRITING ANY CODE and asks for approval. No changing tool (file write/delete, scene or node change) can run until the plan is approved. The plan must be concrete: vague steps like 'build the system and test it' are NOT enough; it needs real file paths, ordered actionable steps and concrete verification criteria.",
			"parameters": {
				"type": "object",
				"properties": {
					"goal": { "type": "string", "description": "The plan's goal in one sentence (e.g. 'Add a pause menu')." },
					"affected_files": { "type": "array", "items": { "type": "string" }, "description": "Real file paths that will be affected (e.g. 'res://ui/pause_menu.gd')." },
					"steps": { "type": "array", "items": { "type": "string" }, "description": "Ordered, actionable steps (e.g. 'Toggle the pause menu with the pause action and set get_tree().paused')." },
					"dependencies": { "type": "array", "items": { "type": "string" }, "description": "Prerequisites / dependencies (optional)." },
					"verification": { "type": "array", "items": { "type": "string" }, "description": "How the plan will be verified (e.g. 'Check the generated node hierarchy', 'Run the project and check there are no errors')." },
					"risks": { "type": "array", "items": { "type": "string" }, "description": "Known risks (optional)." },
					"tools": { "type": "array", "items": { "type": "string" }, "description": "Tools that will be used (optional)." }
				},
				"required": ["goal", "steps", "verification"]
			}
		}
	})

	schemas.append_array(AISidebarSceneTools.get_schemas())
	schemas.append_array(AISidebarScriptTools.get_schemas())
	schemas.append_array(AISidebarEditorTools.get_schemas())
	schemas.append_array(AISidebarGameIntentTools.get_schemas())
	schemas.append_array(AISidebarUITelemetryTools.get_schemas())
	schemas.append_array(AISidebarRuntimeInputTools.get_schemas())
	schemas.append_array(AISidebarOutputTools.get_schemas())
	schemas.append_array(AISidebarRulesTools.get_schemas())
	schemas.append_array(AISidebarGoalTools.get_schemas())
	schemas.append_array(AISidebarApiTools.get_schemas())
	schemas.append_array(AISidebarProjectSettingsTools.get_schemas())
	# Skill'ler: açık skill yoksa activate_skill hiç sunulmaz.
	schemas.append_array(AISidebarSkillTools.get_schemas())
	# Blender köprüsü: Ayarlar → Blender kapalıysa blender_tools / blender_call hiç sunulmaz.
	schemas.append_array(AISidebarBlenderTools.get_schemas())

	return schemas

## Kullanıcı isteği veya konuşma bağlamına göre yalnızca ilgili araç şemalarını filtreler.
## read_only_only = true ise (planlama fazı) yalnızca mutation ÜRETMEYEN araçlar sunulur.
static func get_relevant_schemas(context_text: String, explicitly_unlocked: Array = [], read_only_only: bool = false) -> Array:
	var all_schemas = get_all_schemas()
	var text = context_text.to_lower()
	
	var active_tool_names: Dictionary = {}
	
	# 1. Çekirdek Araçlar (Core Discovery, Clarification, Planning & Inspection - Daima Erişilebilir)
	var core_tools = ["search_tools", "ask_user", "analyze_project", "read_script", "activate_skill"]
	for ct in core_tools:
		active_tool_names[ct] = true
	# Plan aracı yalnız plan istenince (/plan ya da plan modu = read_only_only) sunulur; normal istekte
	# model büyük bir işi kendiliğinden plana çevirmesin.
	if read_only_only:
		active_tool_names["propose_plan"] = true
		
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
		"runtime", "error", "hata", "bug", "crash", "play", "oyna", "çalıştır", "calistir",
		"başlat", "baslat", "start", "run", "test", "debug", "düzelt", "fix", "heal", "screenshot", "ekran",
		"stop", "durdur", "restart", "sıfırla", "log", "diagnostic", "check",
		"canlı", "canli", "remote", "canlı düğüm", "canlı sahne", "inspect_runtime"
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
			"get_active_scene_tree", "get_selected_nodes", "replace_file_content", "inspect_ui_layout"
		]
		for vt in vision_tools:
			active_tool_names[vt] = true

	if has_runtime_intent:
		# Runtime / Debug odaklı dar araç seti (~12 araç)
		var runtime_tools = [
			"play_game", "stop_game", "restart_game", "get_runtime_errors",
			"inspect_runtime_tree", "inspect_runtime_node", "send_input", "wait_for_runtime",
			"take_runtime_screenshot", "take_viewport_screenshot", "create_or_update_script", "replace_file_content", "validate_script", "read_script"
		]
		for rt in runtime_tools:
			active_tool_names[rt] = true
			
	if has_script_intent:
		var script_tools = [
			"create_or_update_script", "replace_file_content", "validate_script", "validate_project", "write_files", "get_godot_class_info",
			"delete_file", "list_dir", "get_open_scripts", "read_script", "file_info", "find_files", "search_code", AISidebarProjectSettingsTools.TOOL_NAME
		]
		for st in script_tools:
			active_tool_names[st] = true
			
	if has_scene_intent:
		var scene_tools = [
			"create_scene", "save_scene", "add_node", "delete_node", "rename_node",
			"duplicate_node", "set_node_property", "connect_signal", "reparent_node",
			"select_node", "get_active_scene_tree", "get_selected_nodes", "write_files",
			"list_dir", "take_viewport_screenshot", "inspect_ui_layout", "create_character_scene", "create_enemy_scene",
			"create_ui_hud", "create_interactable", "setup_camera_follow", AISidebarProjectSettingsTools.TOOL_NAME
		]
		for sc in scene_tools:
			active_tool_names[sc] = true

	var ui_keywords = [
		"ui", "layout", "telemetri", "telemetry", "inspect_ui", "inspect layout", "arayüz", "buton", "button",
		"panel", "label", "container", "theme", "tasarım", "design", "overflow", "font", "sidebar"
	]
	for kw in ui_keywords:
		if kw in text:
			active_tool_names["inspect_ui_layout"] = true
			active_tool_names["take_viewport_screenshot"] = true
			break
			
	# Kalıcı kural kaydetme (/learn ve "bunu hep hatırla" istekleri).
	for kw: String in ["add_rule", "/learn", "learn", "remember", "hatırla", "kural", "rule"]:
		if kw in text:
			active_tool_names["add_rule"] = true
			break

	# Proje ayarları: ana sahne, input action, autoload (hangi kategori eşleşirse eşleşsin).
	for kw: String in ["input", "autoload", "main scene", "ana sahne", "project setting", "proje ayar", "project.godot", "tuş", "kontrol"]:
		if kw in text:
			active_tool_names[AISidebarProjectSettingsTools.TOOL_NAME] = true
			break

	# Output (terminal) günlüğü: çıktı / konsol / günlük / print / hata okuma konuşulunca (araç listesini şişirmez).
	for kw: String in ["output", "çıktı", "cikti", "konsol", "console", "terminal", "log ", "logu", "günlük", "print(", "debug", "hata ayıkla", "autoload", "yükleme hata", "import hata", "eklenti hata"]:
		if kw in text:
			active_tool_names["get_output"] = true
			break

	# Sinyal izleme: sinyal / olay konuşulunca ve oyun çalıştırılıp davranış doğrulanacaksa.
	if ("signal" in text or "sinyal" in text) and (has_runtime_intent or "trace" in text or "izle" in text):
		active_tool_names["trace_runtime_signals"] = true

	# Performans ölçümü: performans / FPS / takılma / sızıntı konuşulunca (her istekte araç listesini şişirmez).
	for kw: String in ["performance", "performans", "fps", "lag", "stutter", "takıl", "yavaş", "slow", "leak", "sızıntı", "optimi", "profil", "memory", "bellek"]:
		if kw in text:
			active_tool_names["get_runtime_performance"] = true
			break

	# Çalışan oyunda durum enjeksiyonu: kazan / kaybet / oyun sonu gibi kilit durumları doğrudan denemek.
	for kw: String in ["game over", "oyun sonu", "kazan", "kaybet", "win screen", "zafer", "victory", "inject", "enjekte", "skoru", "canı 0", "set_runtime"]:
		if kw in text:
			active_tool_names["set_runtime_property"] = true
			break

	# Fizik teşhisi: çarpışma / tetikleyici / layer-mask konuşulunca.
	for kw: String in ["collision", "çarpış", "carpis", "layer", "mask", "trigger", "tetik", "body_entered", "area2d", "area3d", "fizik", "physics", "içinden geç", "geçiyor", "clip through"]:
		if kw in text:
			active_tool_names["diagnose_physics"] = true
			break

	# Arayüz denetimi: kontrast / taşma / üst üste binme / okunabilirlik konuşulunca.
	for kw: String in ["kontrast", "contrast", "overlap", "üst üste", "okunab", "readab", "clipped", "taşan", "overflow", "ui audit", "arayüz denet"]:
		if kw in text:
			active_tool_names["audit_runtime_ui"] = true
			break

	# Blender: 3B model / prop / karakter konuşulunca (köprü kapalıysa şema zaten yok).
	for kw: String in ["blender", "glb", "gltf", "3d model", "3d asset", "3d varl", "3b model", "3d prop", "low-poly", "low poly", "lowpoly", "3d karakter", "3d character"]:
		if kw in text:
			active_tool_names[AISidebarBlenderTools.LIST_TOOL] = true
			active_tool_names[AISidebarBlenderTools.CALL_TOOL] = true
			break

	# Hedef modu (/goal): tur istemi aracın adını içerir.
	if AISidebarGoalTools.TOOL_NAME in text:
		active_tool_names[AISidebarGoalTools.TOOL_NAME] = true

	# 4. Hiçbir kategori eşleşmediyse varsayılan temel araç kümesini sun
	if not has_script_intent and not has_scene_intent and not has_runtime_intent and not has_vision_intent:
		var default_tools = [
			"create_or_update_script", "replace_file_content", "create_scene", "save_scene",
			"play_game", "get_runtime_errors", "take_viewport_screenshot", "write_files", "list_dir", "read_script",
			"file_info", "search_code", AISidebarProjectSettingsTools.TOOL_NAME
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
			# Planlama fazı: yalnızca mutation üretmeyen araçlar sunulur.
			if read_only_only and AISidebarPlanningPolicy.is_mutation_blocked(fn_name):
				continue
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
	elif tool_name == "propose_plan":
		# Araç hiçbir mutasyon yapmaz; plan verisini olduğu gibi döner.
		# AgentRunner bu çağrıyı intercept ederek kullanıcı onayına sunar.
		return AISidebarToolResult.ok({
			"goal": args.get("goal", ""),
			"affected_files": args.get("affected_files", []),
			"steps": args.get("steps", []),
			"dependencies": args.get("dependencies", []),
			"verification": args.get("verification", []),
			"risks": args.get("risks", []),
			"tools": args.get("tools", []),
			"plan": true
		}, "Implementation plan proposed.")
		
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
			
	# 5. UI Telemetri Araçları
	for s in AISidebarUITelemetryTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarUITelemetryTools.execute(tool_name, args)
			
	if tool_name == AISidebarSkillTools.TOOL_NAME:
		return AISidebarSkillTools.execute(tool_name, args)
	if tool_name == AISidebarRulesTools.TOOL_NAME:
		return AISidebarRulesTools.execute(tool_name, args)
	if tool_name == AISidebarGoalTools.TOOL_NAME:
		return AISidebarGoalTools.execute(tool_name, args)
	if tool_name == AISidebarApiTools.TOOL_NAME:
		return AISidebarApiTools.execute(tool_name, args)
	if tool_name == AISidebarProjectSettingsTools.TOOL_NAME:
		return AISidebarProjectSettingsTools.execute(tool_name, args)

	# 6. Yüksek Seviyeli Intent Araçları
	for s in AISidebarGameIntentTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarGameIntentTools.execute(tool_name, args)
			
	return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen motor aracı: " + tool_name)

static func is_async_tool(tool_name: String) -> bool:
	return tool_name in [AISidebarRuntimeInputTools.TOOL_NAME, AISidebarRuntimeInputTools.WAIT_TOOL, AISidebarRuntimeInputTools.PERF_TOOL, AISidebarRuntimeInputTools.TRACE_TOOL, AISidebarRuntimeInputTools.UI_AUDIT_TOOL, AISidebarRuntimeInputTools.PHYSICS_TOOL, AISidebarRuntimeInputTools.SET_PROP_TOOL, AISidebarOutputTools.TOOL_NAME] or AISidebarBlenderTools.is_blender_tool(tool_name) or AISidebarEditorTools.is_async_tool(tool_name)

static func execute_tool_async(tool_name: String, args: Dictionary, is_user_approved: bool = false) -> Dictionary:
	if not is_async_tool(tool_name):
		return execute_tool(tool_name, args, is_user_approved)
		
	# 1. Yetki Denetimi & Onay Politikası
	if not is_user_approved and AISidebarPermissionPolicy.requires_user_approval(tool_name, args):
		return AISidebarToolResult.err(
			"APPROVAL_REQUIRED",
			"Bu işlem (" + tool_name + ") kullanıcı onayı gerektirir.",
			true,
			{"requires_approval": true, "tool_name": tool_name, "args": args}
		)
		
	if tool_name == AISidebarRuntimeInputTools.TOOL_NAME:
		return await AISidebarRuntimeInputTools.execute_async(args)
	if tool_name == AISidebarRuntimeInputTools.WAIT_TOOL:
		return await AISidebarRuntimeInputTools.execute_wait_async(args)
	if tool_name == AISidebarRuntimeInputTools.PERF_TOOL:
		return await AISidebarRuntimeInputTools.execute_perf_async(args)
	if tool_name == AISidebarRuntimeInputTools.SET_PROP_TOOL:
		return await AISidebarRuntimeInputTools.execute_set_prop_async(args)
	if tool_name == AISidebarRuntimeInputTools.PHYSICS_TOOL:
		return await AISidebarRuntimeInputTools.execute_physics_async(args)
	if tool_name == AISidebarRuntimeInputTools.UI_AUDIT_TOOL:
		return await AISidebarRuntimeInputTools.execute_ui_audit_async()
	if tool_name == AISidebarRuntimeInputTools.TRACE_TOOL:
		return await AISidebarRuntimeInputTools.execute_trace_async(args)
	if tool_name == AISidebarOutputTools.TOOL_NAME:
		return await AISidebarOutputTools.execute_async(args)
	if AISidebarBlenderTools.is_blender_tool(tool_name):
		return await AISidebarBlenderTools.execute_async(tool_name, args)
	return await AISidebarEditorTools.execute_async(tool_name, args)

static func _search_tools(args: Dictionary) -> Dictionary:
	var query: String = str(args.get("query", "")).to_lower()
	# Çok kelimeli sorgu kelimelere bölünür ("sync validate script" → 3 kelime); en çok kelimesi
	# eşleşen araç önce gelir. Ad içindeki eşleşme açıklamadakinden ağırdır.
	var words := query.replace("_", " ").split(" ", false)
	var scored: Array[Dictionary] = []

	for tool_def: Dictionary in get_all_schemas():
		var fn: Dictionary = tool_def.get("function", {})
		var t_name: String = str(fn.get("name", ""))
		var t_desc: String = str(fn.get("description", ""))
		# Plan aracı aramayla açılmaz: yalnız plan modunda sunulur (Build modunda onaya düşürürdü).
		if t_name == "propose_plan":
			continue
		var name_l := t_name.to_lower().replace("_", " ")
		var desc_l := t_desc.to_lower()
		var score := 0
		for w: String in words:
			if w in name_l:
				score += 3
			elif w in desc_l:
				score += 1
		if words.is_empty() or score > 0:
			scored.append({"score": score, "name": t_name, "description": t_desc})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	var matches: Array = []
	for s: Dictionary in scored:
		matches.append({"name": s["name"], "description": s["description"]})

	var out := {"query": query, "count": matches.size(), "tools": matches}
	# Skill'ler köprü ajanlarının sync_project adımını da anlatır; sidebar ajanı her görevde onu arıyordu.
	if query.contains("sync"):
		out["note"] = "sync_project exists only for external (MCP bridge) agents. Here the write tools sync the editor themselves: no sync step is needed."
	return AISidebarToolResult.ok(out)

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
			# Yalnız sözdizimi hatası engeller; derlenmeyen kod yazılır ve araç sonucunda raporlanır.
			if AISidebarVerificationPipeline.blocks_write(val_res):
				return AISidebarScriptTools._reject_write(str(path), AISidebarVerificationPipeline.error_message(val_res), val_res, str(content))

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
				return AISidebarScriptTools.missing_file_error(str(path))
			var file = FileAccess.open(path, FileAccess.READ)
			if not file:
				return AISidebarToolResult.err("READ_ERROR", "Dosya okunamadı: " + path)
			var old_content = file.get_as_text()
			file.close()
			var first_idx = old_content.find(target_code)
			if first_idx == -1:
				return AISidebarScriptTools.target_not_found_error(str(path), str(old_content), str(target_code))
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
			# Yalnız sözdizimi hatası engeller; derlenmeyen kod yazılır ve araç sonucunda raporlanır.
			if AISidebarVerificationPipeline.blocks_write(val_res):
				return AISidebarScriptTools._reject_write(str(path), AISidebarVerificationPipeline.error_message(val_res), val_res, str(new_content))

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
			# Doğrulama dosya dosya araçta yapılır (sağlam dosyalar yazılır, bozuklar raporlanır).

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
