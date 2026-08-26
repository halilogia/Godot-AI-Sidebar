@tool
extends RefCounted
class_name AISidebarToolManager

## Merkezi Araç Yöneticisi ve Progressive Discovery Motoru (SRP).

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarSceneTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/scene_tools.gd")
const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")
const AISidebarEditorTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/editor_tools.gd")
const AISidebarGameIntentTools = preload("res://addons/godot_sidebar_ai/core/tools/intent/game_intent_tools.gd")

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
					"query": { "type": "string", "description": "Aranacak kelime (örn: 'scene', 'script', 'camera', 'character')." }
				},
				"required": ["query"]
			}
		}
	})
	
	schemas.append_array(AISidebarSceneTools.get_schemas())
	schemas.append_array(AISidebarScriptTools.get_schemas())
	schemas.append_array(AISidebarEditorTools.get_schemas())
	schemas.append_array(AISidebarGameIntentTools.get_schemas())
	
	return schemas

static func execute_tool(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name == "search_tools":
		return _search_tools(args)
		
	# 1. Sahne İlkel Araçları
	for s in AISidebarSceneTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarSceneTools.execute(tool_name, args)
			
	# 2. Script İlkel Araçları
	for s in AISidebarScriptTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarScriptTools.execute(tool_name, args)
			
	# 3. Editör İlkel Araçları
	for s in AISidebarEditorTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarEditorTools.execute(tool_name, args)
			
	# 4. Yüksek Seviyeli Intent Araçları
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
