@tool
extends RefCounted

## Onaylı planın checklist'ini tool olaylarıyla ilerletir (SRP: eşleştirme + durum).
## Plan step'i <-> tool execution eşleşmesi deterministiktir (dosya adı / doğrulama anahtar kelimesi).
## Checklist bileşenini oluşturmak ve stream'e eklemek ChatDock'un işidir; bu sınıf yalnızca günceller.

const AISidebarTaskChecklist = preload("res://addons/godot_sidebar_ai/ui/components/task_checklist.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")

const MUTATING_TOOLS = ["create_or_update_script", "replace_file_content", "write_files", "create_scene", "save_scene", "delete_file", "delete_node", "add_node"]
const VERIFYING_TOOLS = ["validate_script", "play_game", "get_runtime_errors"]
const VERIFY_KEYWORDS = ["valid", "test", "verif", "doğrul", "kontrol", "check"]

var checklist: AISidebarTaskChecklist = null
## Snapshot'ların yazılacağı AgentContext (null ise snapshot atlanır).
var context: AISidebarAgentContext = null
## Son görülen tool argümanları (tool_completed argüman taşımadığı için).
var _last_tool_args: Dictionary = {}

func has_checklist() -> bool:
	return checklist != null and is_instance_valid(checklist)

## Yeni onaylı plan checklist'i bağla ve ilk snapshot'ı yaz.
func attach(p_checklist: AISidebarTaskChecklist) -> void:
	checklist = p_checklist
	record_snapshot()

## Yeni task / stream temizliği: checklist bağını ve argüman hafızasını bırak.
func reset() -> void:
	checklist = null
	_last_tool_args.clear()

func clear_tool_args() -> void:
	_last_tool_args.clear()

func on_tool_start(tool_name: String, args: Dictionary) -> void:
	_last_tool_args[tool_name] = args.duplicate(true)
	if tool_name == "ask_user" or tool_name == "propose_plan":
		return
	var idx = match_index(tool_name, args, ["pending"])
	if idx < 0:
		return
	checklist.set_step_state(idx, AISidebarTaskChecklist.STATE_RUNNING)
	record_snapshot()

func on_tool_done(tool_name: String, success: bool, error_summary: String) -> void:
	if tool_name == "ask_user" or tool_name == "propose_plan":
		return
	if not (tool_name in MUTATING_TOOLS or tool_name in VERIFYING_TOOLS):
		return
	var args = _last_tool_args.get(tool_name, {})
	if not (args is Dictionary):
		args = {}
	var idx = match_index(tool_name, args, ["running", "pending"])
	if idx < 0:
		return
	if success:
		checklist.set_step_state(idx, AISidebarTaskChecklist.STATE_COMPLETED, "", tool_name)
	else:
		checklist.set_step_state(idx, AISidebarTaskChecklist.STATE_FAILED, error_summary, tool_name)
	record_snapshot()

func finish(success: bool, stop_reason: String) -> void:
	if not has_checklist():
		return
	if checklist.is_finished:
		return
	if success:
		checklist.set_finished_success()
	else:
		var ridx = checklist.get_states().find("running")
		checklist.finish_with_stop(ridx, stop_reason)
	record_snapshot()

func record_snapshot() -> void:
	if context == null or not has_checklist():
		return
	context.get_transcript().record("checklist_snapshot", {
		"goal": checklist.goal.left(200),
		"steps": checklist.to_snapshot(),
		"finished": checklist.is_finished,
		"stop_reason": checklist.stop_reason.left(200),
	})

## Tool argümanlarındaki hedef dosya adları (küçük harf, yalnızca dosya adı).
static func file_targets(args: Dictionary) -> Array:
	var out: Array = []
	for k in ["file_path", "scene_path"]:
		var v = str(args.get(k, "")).strip_edges()
		if not v.is_empty():
			out.append(v.get_file().to_lower())
	var files = args.get("files", [])
	if files is Array:
		for f in files:
			if f is Dictionary:
				var fp = str((f as Dictionary).get("file_path", (f as Dictionary).get("path", ""))).strip_edges()
				if not fp.is_empty():
					out.append(fp.get_file().to_lower())
	return out

## İlk geçiş: validate_script için doğrulama anahtar kelimesi; ikinci geçiş: dosya adı.
func match_index(tool_name: String, args: Dictionary, only_states: Array) -> int:
	if not has_checklist() or checklist.is_finished:
		return -1
	var targets = file_targets(args)
	for pass_idx in range(2):
		for i in range(checklist.step_count()):
			var st = checklist.get_step(i)
			if not str(st.get("state", "")) in only_states:
				continue
			var title_l = str(st.get("title", "")).to_lower()
			if tool_name == "validate_script" and pass_idx == 0:
				for kw in VERIFY_KEYWORDS:
					if kw in title_l:
						return i
				continue
			if pass_idx == 1:
				for t in targets:
					if not (t as String).is_empty() and (t as String) in title_l:
						return i
	return -1
