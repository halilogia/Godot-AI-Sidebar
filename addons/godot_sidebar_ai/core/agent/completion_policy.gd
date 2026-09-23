@tool
extends RefCounted
class_name AISidebarCompletionPolicy

## Completion Integrity Gate (SRP, pure/deterministik).
## Model final text yazdı diye task otomatik SUCCESS olmaz; runtime kanıtı gerekir.
##
## Girdi (runner'dan):
##   limit_hit: bool, steps_summary: String,
##   unrecovered: Dictionary (key -> {"tool": String, "deferred": bool}),
##   plan_approved: bool, mutations_done: bool
## Çıktı: {"verdict": "success"|"incomplete"|"failed", "reason": String}

static func evaluate(s: Dictionary) -> Dictionary:
	if bool(s.get("limit_hit", false)):
		return {"verdict": "failed", "reason": "Step limit reached (" + str(s.get("steps_summary", "")) + ") before task completion."}
	var unrec = s.get("unrecovered", {})
	if unrec is Dictionary and not (unrec as Dictionary).is_empty():
		var failed_names: Array = []
		var deferred_names: Array = []
		for k in (unrec as Dictionary).keys():
			var entry = (unrec as Dictionary)[k]
			var tname = str(entry.get("tool", k)) if entry is Dictionary else str(k)
			if entry is Dictionary and bool(entry.get("deferred", false)):
				if not tname in deferred_names:
					deferred_names.append(tname)
			elif not tname in failed_names:
				failed_names.append(tname)
		var parts: PackedStringArray = []
		if not failed_names.is_empty():
			parts.append("failed tool(s) without recovery: " + ", ".join(failed_names))
		if not deferred_names.is_empty():
			parts.append("deferred tool(s) never executed: " + ", ".join(deferred_names))
		return {"verdict": "incomplete", "reason": "Unresolved work (" + "; ".join(parts) + ")."}
	if bool(s.get("plan_approved", false)) and not bool(s.get("mutations_done", false)):
		return {"verdict": "incomplete", "reason": "Approved plan was not executed (no mutations)."}
	return {"verdict": "success", "reason": "Task completed."}
