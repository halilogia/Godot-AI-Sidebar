@tool
extends RefCounted
class_name AISidebarSkillTools

## `activate_skill`: açık bir skill'in talimatlarını (katman 2) ya da skill klasöründeki bir ek
## dosyayı (katman 3) yükler. Açık skill yoksa araç hiç sunulmaz; ad parametresi açık skill
## adlarıyla sınırlıdır (enum). Salt okunur.

const AISidebarSkillRegistry = preload("res://addons/godot_sidebar_ai/core/skills/skill_registry.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

const TOOL_NAME := "activate_skill"

static func get_schemas() -> Array:
	var skills := AISidebarSkillRegistry.enabled_skills()
	if skills.is_empty():
		return []
	var names: Array[String] = []
	for s: Dictionary in skills:
		names.append(str(s["name"]))
	return [{
		"type": "function",
		"function": {
			"name": TOOL_NAME,
			"description": "Loads the full instructions of a skill listed under SKILLS. Call it when the task matches the skill's description, before doing the work. With `file`, loads one bundled file of that skill instead.",
			"parameters": {
				"type": "object",
				"properties": {
					"name": {"type": "string", "enum": names, "description": "Skill name."},
					"file": {"type": "string", "description": "Optional: a bundled file path relative to the skill folder (from the skill's file list)."},
				},
				"required": ["name"],
			},
		},
	}]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != TOOL_NAME:
		return AISidebarToolResult.err("UNKNOWN_TOOL", "Unknown skill tool: " + tool_name)
	var name := str(args.get("name", ""))
	var skill := AISidebarSkillRegistry.find(name, AISidebarSkillRegistry.enabled_skills())
	if skill.is_empty():
		return AISidebarToolResult.err("SKILL_NOT_FOUND", "No enabled skill named '%s'." % name)
	var file := str(args.get("file", "")).strip_edges()
	if not file.is_empty():
		var res := AISidebarSkillRegistry.read_resource(skill, file)
		if res.get("ok", false) != true:
			return AISidebarToolResult.err("SKILL_FILE_ERROR", str(res.get("error", "")))
		return AISidebarToolResult.ok({"skill": name, "file": file, "content": str(res["content"])}, "Skill file loaded: %s/%s" % [name, file])
	return AISidebarToolResult.ok({"skill": name, "content": AISidebarSkillRegistry.activation_content(skill)}, "Skill loaded: " + name)
