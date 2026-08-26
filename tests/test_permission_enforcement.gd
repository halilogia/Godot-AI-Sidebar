@tool
extends RefCounted

const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Destructive tool blocked without user approval
	var unapproved_res = AISidebarToolManager.execute_tool("delete_node", {"node_path": "Player"}, false)
	if not unapproved_res.get("success", false) and unapproved_res.get("error", {}).get("code", "") == "APPROVAL_REQUIRED":
		passed += 1
	else:
		failed += 1
		errors.append("Yıkıcı işlem onaysız engellenmedi: " + str(unapproved_res))
		
	# Test 2: Safe/Read-only tool allowed without approval
	var read_res = AISidebarToolManager.execute_tool("search_tools", {"query": "scene"}, false)
	if read_res.get("success", false):
		passed += 1
	else:
		failed += 1
		errors.append("Salt-okunur araç çalıştırılamadı: " + str(read_res))
		
	# Test 3: PermissionPolicy classification check
	if AISidebarPermissionPolicy.requires_user_approval("delete_node"):
		passed += 1
	else:
		failed += 1
		errors.append("delete_node onay gerektiriyor olarak işaretlenmedi.")
		
	return {"name": "PermissionEnforcementTests", "passed": passed, "failed": failed, "errors": errors}
