@tool
extends RefCounted
class_name AISidebarCompletionPolicy

## Completion Integrity Gate (SRP, pure/deterministik).
## Model final text yazdı diye task otomatik SUCCESS olmaz; runtime kanıtı gerekir.
##
## Girdi (runner'dan):
##   limit_hit: bool, steps_summary: String,
##   unrecovered: Dictionary (key -> {"tool": String, "deferred": bool}),
##   plan_approved: bool, mutations_done: bool, write_problems: String (derlenmeyen / yazılmamış dosyalar)
## Çıktı: {"verdict": "success"|"incomplete"|"failed", "reason": String}

## "Nereye bakacağını yanlış seçme" hataları: çalışan oyunda olmayan bir düğüme tıklamak / bakmak ya da editör
## görünümü açık değilken görüntü almak işin eksik olduğunu göstermez; tamamlanma kapısını bloklamaz (araç
## sonucunu model zaten görür). Yazma, okuma ve doğrulama hataları için sıkılık aynen sürer.
const PROBE_TOOLS := ["send_input", "inspect_runtime_node", "inspect_runtime_tree", "take_viewport_screenshot", "take_runtime_screenshot"]
const PROBE_MISS_CODES := ["NODE_NOT_FOUND", "NOT_CLICKABLE", "OFF_SCREEN", "BEHIND_CAMERA", "NO_CAMERA", "VIEWPORT_NOT_VISIBLE"]

static func is_probe_miss(tool_name: String, res: Dictionary) -> bool:
	if not tool_name in PROBE_TOOLS:
		return false
	var err_v: Variant = res.get("error", null)
	if not (err_v is Dictionary):
		return false
	var err: Dictionary = err_v
	return str(err.get("code", "")) in PROBE_MISS_CODES

const WRITE_TOOLS := ["create_or_update_script", "replace_file_content", "write_files", "create_scene"]

## Başarılı bir yazma, aynı dosyaya ait ÖNCEKİ başarısız YAZMALARI çözülmüş sayar (reddedilen replace_file_content'in
## ardından dosya create_scene / create_or_update_script ile yazıldıysa iş düzelmiştir). Okuma vb. başarısızlıkları
## yalnız aynı araçla düzelir (bilinçli sıkılık: test F). Sonda her zaman aynı-anahtar kaydı da silinir.
static func clear_resolved(unrecovered: Dictionary, fkey: String, tool_name: String, args: Dictionary) -> void:
	unrecovered.erase(fkey)
	if not tool_name in WRITE_TOOLS:
		return
	var written: Array[String] = []
	for k: String in ["file_path", "scene_path"]:
		var v := str(args.get(k, "")).strip_edges()
		if not v.is_empty():
			written.append(v)
	var files_v: Variant = args.get("files", null)
	if files_v is Array:
		var files: Array = files_v
		for f: Variant in files:
			if f is Dictionary:
				var fd: Dictionary = f
				written.append(str(fd.get("file_path", "")).strip_edges())
	if written.is_empty():
		return
	for key: Variant in unrecovered.keys():
		var parts := str(key).split("|", true, 1)
		if parts.size() < 2 or not parts[0] in WRITE_TOOLS:
			continue
		for target: String in parts[1].split(","):
			if not target.is_empty() and target in written:
				unrecovered.erase(key)
				break

static func evaluate(s: Dictionary) -> Dictionary:
	if bool(s.get("limit_hit", false)):
		return {"verdict": "failed", "reason": "Step limit reached (" + str(s.get("steps_summary", "")) + ") before task completion."}
	var write_problems := str(s.get("write_problems", ""))
	if not write_problems.is_empty():
		return {"verdict": "incomplete", "reason": "Unresolved file errors: " + write_problems}
	var unrec: Variant = s.get("unrecovered", {})
	if unrec is Dictionary and not (unrec as Dictionary).is_empty():
		var failed_names: Array = []
		var deferred_names: Array = []
		for k: Variant in (unrec as Dictionary).keys():
			var entry: Variant = (unrec as Dictionary)[k]
			var tname: String = str(entry.get("tool", k)) if entry is Dictionary else str(k)
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
