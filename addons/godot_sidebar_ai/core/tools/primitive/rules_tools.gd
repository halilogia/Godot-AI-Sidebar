@tool
extends RefCounted
class_name AISidebarRulesTools

## `add_rule`: kalıcı bir kuralı proje (`.agents/rules/AGENTS.md`) ya da global (`~/.agents/AGENTS.md`)
## kural dosyasına ekler. /learn bu aracı kullanır. Bütün gelecek oturumları etkilediği için risk
## sınıfı EXTERNAL_SENSITIVE'dir: Manuel ve Otomatik modda kullanıcı onayı ister. Köprüde açılmaz.

const AISidebarRulesRegistry = preload("res://addons/godot_sidebar_ai/core/skills/rules_registry.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

const TOOL_NAME := "add_rule"

static func get_schemas() -> Array:
	return [{
		"type": "function",
		"function": {
			"name": TOOL_NAME,
			"description": "Saves one permanent rule the user wants followed in every future task: a single short, testable sentence (not a procedure; procedures belong in a skill). scope=project writes the game project's .agents/rules/AGENTS.md (shared with other agents via git); scope=global writes the user's ~/.agents/AGENTS.md (all projects). Needs the user's approval.",
			"parameters": {
				"type": "object",
				"properties": {
					"rule": {"type": "string", "description": "The rule, one sentence, imperative (e.g. 'Store province data in data/*.json, never in scene files')."},
					"scope": {"type": "string", "enum": ["project", "global"], "description": "project (default) or global."},
				},
				"required": ["rule"],
			},
		},
	}]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != TOOL_NAME:
		return AISidebarToolResult.err("UNKNOWN_TOOL", "Unknown rules tool: " + tool_name)
	var scope := str(args.get("scope", AISidebarRulesRegistry.SCOPE_PROJECT))
	var res := AISidebarRulesRegistry.add_rule(str(args.get("rule", "")), scope)
	if res.get("ok", false) != true:
		return AISidebarToolResult.err("RULE_NOT_SAVED", str(res.get("error", "")))
	return AISidebarToolResult.ok({"path": str(res["path"]), "scope": scope}, "Rule saved to " + str(res["path"]))
