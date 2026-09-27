@tool
extends RefCounted

## Yerleşik skill'lerde `backtick` içinde geçen araç adları gerçekten var olmalı: sidebar araç
## şemalarında ya da köprünün kendi aracı (sync_project). Skill ile araç seti kayınca ajan olmayan
## aracı arayıp adım harcıyordu (benchmark: sync_project / get_project_files).

const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const SKILLS_DIR := "res://addons/godot_sidebar_ai/skills"
## Araç adına benzeyen ama araç olmayan tanımlayıcılar (argüman adları, alanlar, Godot API'si).
const NOT_TOOLS := [
	"changed_files", "expected_scene_path", "file_path", "scene_path", "scene_file", "is_inconclusive",
	"class_name", "get_node", "ext_resource", "sub_resource", "node_path",
]

static func run() -> Dictionary:
	var known: Dictionary = {"sync_project": true}
	for schema: Dictionary in AISidebarToolManager.get_all_schemas():
		var fn: Dictionary = schema.get("function", {})
		known[str(fn.get("name", ""))] = true
	var re := RegEx.new()
	re.compile("`([a-z][a-z0-9]*(?:_[a-z0-9]+)+)`")
	var unknown: Array = []
	for dir_name: String in DirAccess.get_directories_at(SKILLS_DIR):
		var path := SKILLS_DIR.path_join(dir_name).path_join("SKILL.md")
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		for m: RegExMatch in re.search_all(text):
			var ident := m.get_string(1)
			if not known.has(ident) and not NOT_TOOLS.has(ident):
				var entry := dir_name + ": " + ident
				if not unknown.has(entry):
					unknown.append(entry)
	if unknown.is_empty():
		return {"name": "SkillToolNameTests", "passed": 1, "failed": 0, "errors": []}
	return {"name": "SkillToolNameTests", "passed": 0, "failed": 1, "errors": ["Skill'lerde bilinmeyen araç adı: " + str(unknown)]}
