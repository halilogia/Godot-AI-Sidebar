@tool
extends RefCounted

const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Schemas loaded
	var schemas = AISidebarToolManager.get_all_schemas()
	if schemas.size() >= 10:
		passed += 1
	else:
		failed += 1
		errors.append("Expected >= 10 tools, got: " + str(schemas.size()))
		
	# Test 2: Progressive Discovery search_tools
	var search_res = AISidebarToolManager.execute_tool("search_tools", {"query": "scene"})
	if search_res.get("success", false) and search_res.get("data", {}).get("count", 0) > 0:
		passed += 1
	else:
		failed += 1
		errors.append("search_tools failed: " + str(search_res))

	# Test 3: çok kelimeli sorgu kelimelere bölünür, adı eşleşen araç önce gelir (eskiden 0 sonuç).
	var multi = AISidebarToolManager.execute_tool("search_tools", {"query": "list project files"})
	var names: Array = (multi.get("data", {}).get("tools", []) as Array).map(func(t): return t["name"])
	if names.size() > 0 and names[0] == "get_project_files":
		passed += 1
	else:
		failed += 1
		errors.append("search_tools multi-word failed: " + str(names.slice(0, 5)))

	return {"name": "ToolManagerTests", "passed": passed, "failed": failed, "errors": errors}
