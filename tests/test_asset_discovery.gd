@tool
extends RefCounted

const AISidebarEditorTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/editor_tools.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Search project assets for scene
	var scene_res = AISidebarEditorTools.execute("search_project_assets", {"query": "main", "asset_type": "scene"})
	if scene_res.get("success", false) and scene_res.get("data", {}).get("count", 0) >= 1:
		passed += 1
	else:
		failed += 1
		errors.append("search_project_assets scene araması başarısız: " + str(scene_res))
		
	# Test 2: Search project assets for script
	var script_res = AISidebarEditorTools.execute("search_project_assets", {"query": "player", "asset_type": "script"})
	if script_res.get("success", false) and script_res.get("data", {}).get("count", 0) >= 1:
		passed += 1
	else:
		failed += 1
		errors.append("search_project_assets script araması başarısız: " + str(script_res))
		
	# Test 3: Analyze project
	var anal_res = AISidebarEditorTools.execute("analyze_project", {})
	if anal_res.get("success", false) and anal_res.get("data", {}).has("scenes_count"):
		passed += 1
	else:
		failed += 1
		errors.append("analyze_project başarısız: " + str(anal_res))
		
	return {"name": "AssetDiscoveryTests", "passed": passed, "failed": failed, "errors": errors}
