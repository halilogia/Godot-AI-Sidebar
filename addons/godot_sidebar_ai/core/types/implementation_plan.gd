@tool
extends RefCounted
class_name AISidebarImplementationPlan

## Kullanıcıya Gösterilen Uygulama Planı Veri Modeli (SRP).
##
## AMAC:
##   Modelin 'propose_plan' aracından gelen YAPILANDIRILMIS alanları normalize
##   edip, kullanıcıya gösterilebilir bir artifact'a dönüştürmek.
##
## GIZLI REASONING GÖSTERİLMEZ:
##   Plan yalnızca burada tanımlı açık alanlardan (goal, steps, verification...)
##   üretilir. Modelin düşünme metni (thinking) bu modele hiç girmez.
##
## RENDER AYRILIĞI:
##   Bu sınıf yalnızca VERİ ve metin üretir; Godot UI düğümü oluşturmaz.
##   Görselleştirme plan_card.gd sorumluluğundadır (SRP).

var goal: String = ""
var affected_files: Array = []
var steps: Array = []
var dependencies: Array = []
var verification: Array = []
var risks: Array = []
var tools: Array = []
var raw_args: Dictionary = {}

func _init(args: Dictionary = {}) -> void:
	raw_args = args.duplicate(true)
	goal = str(args.get("goal", "")).strip_edges()
	affected_files = _to_string_array(args.get("affected_files", []))
	steps = _to_string_array(args.get("steps", []))
	dependencies = _to_string_array(args.get("dependencies", []))
	verification = _to_string_array(args.get("verification", []))
	risks = _to_string_array(args.get("risks", []))
	tools = _to_string_array(args.get("tools", []))

## Plan kullanıcıya gösterilebilecek kadar anlamlı mı?
## Gevşek doğrulama: amaç + en az bir adım + en az bir doğrulama ölçütü.
## (Model eksik alan döndürürse UI'da boş bir plan kartı göstermemek için.)
func is_valid() -> bool:
	return not goal.is_empty() and steps.size() > 0 and verification.size() > 0

## Kullanıcıya gösterilecek plan metni (Markdown).
func to_markdown() -> String:
	var out: PackedStringArray = []
	out.append("## PLAN")
	out.append("")
	out.append("**Goal:** " + (goal if not goal.is_empty() else "(belirtilmedi)"))
	out.append("")

	if affected_files.size() > 0:
		out.append("**Affected files:**")
		for f in affected_files:
			out.append("- `" + str(f) + "`")
		out.append("")

	if steps.size() > 0:
		out.append("**Implementation steps:**")
		var idx: int = 1
		for s in steps:
			out.append(str(idx) + ". " + str(s))
			idx += 1
		out.append("")

	if dependencies.size() > 0:
		out.append("**Dependencies:**")
		for d in dependencies:
			out.append("- " + str(d))
		out.append("")

	if tools.size() > 0:
		out.append("**Tools:**")
		for t in tools:
			out.append("- `" + str(t) + "`")
		out.append("")

	if verification.size() > 0:
		out.append("**Verification:**")
		for v in verification:
			out.append("- " + str(v))
		out.append("")

	if risks.size() > 0:
		out.append("**Risks:**")
		for r in risks:
			out.append("- " + str(r))

	return "\n".join(out).strip_edges()

## Oturum kalıcılığı için düz sözlük gösterimi.
func to_dict() -> Dictionary:
	return {
		"goal": goal,
		"affected_files": affected_files.duplicate(),
		"steps": steps.duplicate(),
		"dependencies": dependencies.duplicate(),
		"verification": verification.duplicate(),
		"risks": risks.duplicate(),
		"tools": tools.duplicate()
	}

static func _to_string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var s: String = str(item).strip_edges()
			if not s.is_empty():
				result.append(s)
	elif value is String and not str(value).strip_edges().is_empty():
		result.append(str(value).strip_edges())
	return result
