@tool
extends RefCounted

## Görev telemetrisi (SRP): sayaçlar, süre dağılımı (ms), dosya kümeleri ve task sonu metrik
## sözlüğü. Karar vermez, sinyal yaymaz; AgentRunner olayları buraya kaydeder. Her runner'ın
## kendi örneği vardır (paylaşılan / statik durum yok).

const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")

# Zaman damgaları (Time.get_ticks_msec)
var task_start_time_msec: int = 0
var llm_step_start_time: int = 0
var waiting_start_time: int = 0

var llm_turns_count: int = 0
var tool_calls_count: int = 0
var file_ops_count: int = 0
var editor_ops_count: int = 0
var runtime_ops_count: int = 0
var verification_checkpoints_count: int = 0
## Performance Telemetry: read/search/write ayrımı, fail/retry/limit, dosya kümeleri.
var read_ops_count: int = 0
var search_ops_count: int = 0
var write_ops_count: int = 0
var failed_tool_count: int = 0
var retry_count: int = 0
var limit_hit: bool = false
var files_read: Dictionary = {}
var files_written: Dictionary = {}
var tool_time_by_name: Dictionary = {}

var llm_time_msec: int = 0
var tool_time_msec: int = 0
var file_time_msec: int = 0
var editor_time_msec: int = 0
var runtime_time_msec: int = 0
var verification_time_msec: int = 0
var waiting_time_msec: int = 0
## Research overhead paydası: read + search araçlarında harcanan süre.
var research_time_msec: int = 0

## Yeni task: sayaçlar, süreler ve dosya kümeleri sıfırlanır, task saati başlar.
## LLM / bekleme başlangıç damgaları sıfırlanmaz (her tur / bekleme kendi damgasını yazar).
func reset() -> void:
	task_start_time_msec = Time.get_ticks_msec()
	llm_turns_count = 0
	tool_calls_count = 0
	file_ops_count = 0
	editor_ops_count = 0
	runtime_ops_count = 0
	verification_checkpoints_count = 0
	read_ops_count = 0
	search_ops_count = 0
	write_ops_count = 0
	failed_tool_count = 0
	retry_count = 0
	limit_hit = false
	files_read.clear()
	files_written.clear()
	tool_time_by_name.clear()

	llm_time_msec = 0
	tool_time_msec = 0
	file_time_msec = 0
	editor_time_msec = 0
	runtime_time_msec = 0
	verification_time_msec = 0
	waiting_time_msec = 0
	research_time_msec = 0

func get_elapsed_s() -> float:
	if task_start_time_msec <= 0:
		return 0.0
	return snappedf((Time.get_ticks_msec() - task_start_time_msec) / 1000.0, 0.1)

## LLM isteği gönderildi.
func begin_llm_step() -> void:
	llm_step_start_time = Time.get_ticks_msec()

## LLM yanıtı geldi: istekten bu yana geçen süre LLM süresine eklenir.
func end_llm_step() -> void:
	if llm_step_start_time > 0:
		var delta_req = Time.get_ticks_msec() - llm_step_start_time
		llm_time_msec += delta_req
		llm_step_start_time = 0

## Kullanıcı kararı (onay / soru / plan) beklenmeye başlandı.
func begin_waiting() -> void:
	waiting_start_time = Time.get_ticks_msec()

## Kullanıcı karar verdi: bekleme süresi eklenir.
func end_waiting() -> void:
	if waiting_start_time > 0:
		waiting_time_msec += (Time.get_ticks_msec() - waiting_start_time)
		waiting_start_time = 0

func note_retry() -> void:
	retry_count += 1

func classify_op(fn_name: String, args: Dictionary) -> void:
	match fn_name:
		"create_or_update_script", "replace_file_content", "delete_file", "create_scene", "save_scene":
			file_ops_count += 1
		"write_files":
			var files_arr = args.get("files", [])
			file_ops_count += maxi(1, files_arr.size())
		"add_node", "delete_node", "rename_node", "duplicate_node", "set_node_property", "connect_signal", "reparent_node", "select_node":
			editor_ops_count += 1
		"play_game", "stop_game", "restart_game", "get_runtime_errors", "take_runtime_screenshot":
			runtime_ops_count += 1

func record_category_time(fn_name: String, duration_msec: int) -> void:
	match fn_name:
		"create_or_update_script", "replace_file_content", "delete_file", "create_scene", "save_scene", "write_files":
			file_time_msec += duration_msec
		"add_node", "delete_node", "rename_node", "duplicate_node", "set_node_property", "connect_signal", "reparent_node", "select_node":
			editor_time_msec += duration_msec
		"play_game", "stop_game", "restart_game", "get_runtime_errors", "take_runtime_screenshot":
			runtime_time_msec += duration_msec

## Tool türü sınıflandırması (pure/static; Research Budget da bunu kullanacak).
## "read" | "search" | "write" | "verify" | "runtime" | "editor" | "other"
static func classify_tool_kind(tool_name: String) -> String:
	match tool_name:
		"read_script", "read_file", "get_project_files", "list_files", "analyze_project":
			return "read"
		"search_tools":
			return "search"
		"create_or_update_script", "replace_file_content", "write_files", "create_scene", "save_scene", "delete_file":
			return "write"
		"validate_script":
			return "verify"
		"play_game", "stop_game", "restart_game", "get_runtime_errors", "take_runtime_screenshot":
			return "runtime"
		"add_node", "delete_node", "rename_node", "duplicate_node", "set_node_property", "connect_signal", "reparent_node", "select_node":
			return "editor"
		_:
			if tool_name.begins_with("search"):
				return "search"
			if tool_name.begins_with("read") or tool_name.begins_with("get_"):
				return "read"
			return "other"

## Her GERÇEK tool icrası için tek kayıt noktası (normal + onaylı yol).
## Başarı hükmü transcript helper ile (outer ok + payload fail yakalanır).
func record_tool(fn_name: String, args: Dictionary, duration_msec: int, result: Dictionary) -> void:
	var kind = classify_tool_kind(fn_name)
	match kind:
		"read":
			read_ops_count += 1
			research_time_msec += duration_msec
		"search":
			search_ops_count += 1
			research_time_msec += duration_msec
		"write":
			write_ops_count += 1
	tool_time_by_name[fn_name] = int(tool_time_by_name.get(fn_name, 0)) + duration_msec
	for f in file_targets(args):
		if kind == "write":
			files_written[f] = true
		else:
			files_read[f] = true
	var outcome = AISidebarTaskTranscript.effective_tool_outcome(result)
	if not bool(outcome.get("success", false)):
		failed_tool_count += 1

static func file_targets(args: Dictionary) -> Array:
	var out: Array = []
	if args == null:
		return out
	for k in ["file_path", "scene_path"]:
		var v = str(args.get(k, "")).strip_edges()
		if not v.is_empty():
			out.append(v)
	var files = args.get("files", [])
	if files is Array:
		for f in files:
			if f is Dictionary:
				var fp = str((f as Dictionary).get("file_path", (f as Dictionary).get("path", ""))).strip_edges()
				if not fp.is_empty():
					out.append(fp)
	return out

## Test edilebilir metrik yardımcıları (pure hesap, sinyal yok).
func tool_time_by_tool_seconds() -> Dictionary:
	var out: Dictionary = {}
	for k in tool_time_by_name.keys():
		out[k] = snappedf(int(tool_time_by_name[k]) / 1000.0, 0.1)
	return out

## Research overhead = keşif (read+search) süresi / toplam task süresi.
func research_overhead_ratio(total_elapsed_sec: float) -> float:
	if total_elapsed_sec <= 0.0:
		return 0.0
	return snappedf((research_time_msec / 1000.0) / total_elapsed_sec, 0.01)

## Task sonu metrik sözlüğü. Anahtar sırası export / telemetri kartı için sabittir.
func build_metrics(success: bool, completion: Dictionary, used_steps: int, max_steps: int, tools_sent: int, total_tools: int, total_elapsed_sec: float) -> Dictionary:
	return {
		"success": success,
		"completion": str(completion.get("verdict", "success")),
		"completion_reason": str(completion.get("reason", "")),
		"elapsed_seconds": snappedf(total_elapsed_sec, 0.1),
		"used_steps": used_steps,
		"max_steps": max_steps,
		"steps_summary": str(used_steps) + " / " + str(max_steps),
		"tools_sent": tools_sent,
		"total_tools": total_tools,
		"tools_ratio": str(tools_sent) + " / " + str(total_tools),
		"llm_turns": llm_turns_count,
		"tool_calls": tool_calls_count,
		"file_ops": file_ops_count,
		"editor_ops": editor_ops_count,
		"runtime_ops": runtime_ops_count,
		"verification_checkpoints": verification_checkpoints_count,
		# Performance Telemetry: read/search/write ayrımı, fail/retry/limit, dosyalar.
		"read_ops": read_ops_count,
		"search_ops": search_ops_count,
		"write_ops": write_ops_count,
		"failed_tools": failed_tool_count,
		"retry_count": retry_count,
		"limit_hit": limit_hit,
		"files_read_count": files_read.size(),
		"files_written_count": files_written.size(),
		"files_read": files_read.keys(),
		"files_written": files_written.keys(),
		"tool_time_by_tool_s": tool_time_by_tool_seconds(),
		# Detaylı Süre Dağılımı (Saniye)
		"llm_time_s": snappedf(llm_time_msec / 1000.0, 0.1),
		"tool_time_s": snappedf(tool_time_msec / 1000.0, 0.1),
		"file_time_s": snappedf(file_time_msec / 1000.0, 0.1),
		"editor_time_s": snappedf(editor_time_msec / 1000.0, 0.1),
		"runtime_time_s": snappedf(runtime_time_msec / 1000.0, 0.1),
		"verification_time_s": snappedf(verification_time_msec / 1000.0, 0.1),
		"waiting_time_s": snappedf(waiting_time_msec / 1000.0, 0.1),
		"research_time_s": snappedf(research_time_msec / 1000.0, 0.1),
		"research_overhead_ratio": research_overhead_ratio(total_elapsed_sec)
	}
