@tool
extends RefCounted
class_name AISidebarCustomizationBudget

## Özelleştirmelerin modele her turda eklediği yük (Ayarlar → Özelleştirmeler, Antigravity'nin
## "Token Usage" görünümü gibi): kurallar, skill kataloğu, araç tanımları. Token sayısı yaklaşıktır
## (karakter / 4); araçlar için tam katalog verilir, her turda bunun ilgili alt kümesi gider (üst sınır).

const AISidebarRulesRegistry = preload("res://addons/godot_sidebar_ai/core/skills/rules_registry.gd")
const AISidebarSkillRegistry = preload("res://addons/godot_sidebar_ai/core/skills/skill_registry.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")

const CHARS_PER_TOKEN := 4.0

static func estimate_tokens(chars: int) -> int:
	return ceili(chars / CHARS_PER_TOKEN)

## {rules: {chars, tokens, files, truncated}, skills: {chars, tokens, count}, tools: {chars, tokens, count}, total_tokens}
static func measure() -> Dictionary:
	var files := AISidebarRulesRegistry.discover()
	var rules_text := AISidebarRulesRegistry.prompt_text(files)
	var raw_rule_chars := 0
	for f: Dictionary in files:
		var c: int = f.get("chars", 0)
		raw_rule_chars += c
	var skills := AISidebarSkillRegistry.enabled_skills()
	var catalog := AISidebarSkillRegistry.catalog_prompt(skills)
	var schemas := AISidebarToolManager.get_all_schemas()
	var tools_json := JSON.stringify(schemas)
	var out := {
		"rules": {"chars": rules_text.length(), "tokens": estimate_tokens(rules_text.length()), "files": files.size(), "truncated": raw_rule_chars > AISidebarRulesRegistry.MAX_TOTAL_CHARS},
		"skills": {"chars": catalog.length(), "tokens": estimate_tokens(catalog.length()), "count": skills.size()},
		"tools": {"chars": tools_json.length(), "tokens": estimate_tokens(tools_json.length()), "count": schemas.size()},
	}
	out["total_tokens"] = estimate_tokens(rules_text.length()) + estimate_tokens(catalog.length()) + estimate_tokens(tools_json.length())
	return out
