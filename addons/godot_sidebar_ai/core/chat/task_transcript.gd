@tool
extends RefCounted
class_name AISidebarTaskTranscript

## Görev Bazlı Tam Transcript Deposu (Task Transcript Store) (SRP).
## `agent_context.messages` çalışma belleğidir ve `_auto_compact_if_needed()` ile
## özetlenerek budanır; bu depo ise ASLA compact edilmez ve Everything Export ile
## gelecekteki Copy Task için deterministik task sınırlarını korur.
##
## Bir task: user prompt -> clarification -> plan -> approval -> tool calls ->
## verification -> completion/failure/cancellation zincirini kapsar.

const MAX_STORED_CHARS: int = 4000
const MAX_EVENTS_PER_TASK: int = 500
## Everything Export boyut sınırları (makul, deterministik, flag'li truncation).
const MAX_TEXT_CHARS: int = 4000
const MAX_ARGS_CHARS: int = 8000
const MAX_PAYLOAD_CHARS: int = 8000

var tasks: Array = []
var orphan_events: Array = []
var _running_idx: int = -1
var _task_seq: int = 0
## Son başlayan agent step'i (runner her step'te mark_step çağırır).
## Tüm event'ler mutlak step numarası taşır (benchmark/post-mortem için).
var _step_mark: int = 0

func mark_step(n: int) -> void:
	_step_mark = maxi(0, n)

static func now_ts() -> String:
	return Time.get_datetime_string_from_system()

## Credential sızıntısını engelle (activity_group.gd ile aynı desenler).
static func redact_secrets(raw: String) -> String:
	if raw == null or raw.is_empty():
		return raw if raw != null else ""
	var out = raw
	var patterns = [
		"(?i)(\"?(api[_-]?key|bearer|authorization|secret|password|passwd|access[_-]?token|refresh[_-]?token|client[_-]?secret)\"?\\s*[:=]\\s*\")(.*?)(\")",
		"(?i)(Bearer\\s+)[A-Za-z0-9\\-._~+/=]{6,}",
		"(?i)(\"?(token)\"?\\s*[:=]\\s*\")(.*?)(\")",
		"(?i)\\b((password|passwd|pwd|api[_-]?key|client[_-]?secret|access[_-]?token|refresh[_-]?token)\\s*=\\s*)([^\\s\"',;]+)",
	]
	for p in patterns:
		var re = RegEx.new()
		if re.compile(p) != OK:
			continue
		if p.contains("Bearer\\s") or p.contains("\\b("):
			out = re.sub(out, "$1[REDACTED]", true)
		else:
			out = re.sub(out, "$1[REDACTED]$4", true)
	return out

static func truncate_text(s: String, max_len: int = MAX_STORED_CHARS) -> String:
	if s == null:
		return ""
	if s.length() > max_len:
		return s.left(max_len) + "... [truncated]"
	return s

static func summarize_error(raw: String, max_len: int = 180) -> String:
	if raw == null:
		return ""
	var s = str(raw).strip_edges().replace("\n", " ").replace("\r", " ")
	while s.contains("  "):
		s = s.replace("  ", " ")
	if s.length() > max_len:
		s = s.left(max_len).strip_edges() + "..."
	return s

## Kısaltma durumunu açıkça bildiren varyant: {"text": ..., "truncated": bool}.
## Export kaydında veri kaybı gizlenmez; JSON transcript bayrağı taşır.
static func truncate_flagged(s: String, max_len: int = MAX_STORED_CHARS) -> Dictionary:
	if s == null:
		return {"text": "", "truncated": false}
	if s.length() > max_len:
		return {"text": s.left(max_len) + "... [truncated]", "truncated": true}
	return {"text": s, "truncated": false}

func clear() -> void:
	tasks.clear()
	orphan_events.clear()
	_running_idx = -1
	_task_seq = 0
	_step_mark = 0

func has_running_task() -> bool:
	return _running_idx >= 0 and _running_idx < tasks.size() and str(tasks[_running_idx].get("status", "")) == "running"

func task_count() -> int:
	return tasks.size()

func get_tasks() -> Array:
	return tasks.duplicate(true)

## ID ile canlı task kopyası (per-task Copy çözümlemesi; bulunamazsa boş).
func get_task_by_id(task_id: String) -> Dictionary:
	if task_id.strip_edges().is_empty():
		return {}
	for t in tasks:
		if t is Dictionary and str((t as Dictionary).get("id", "")) == task_id:
			return (t as Dictionary).duplicate(true)
	return {}

## Aktif task yoksa son biten task (Copy Current Task kaynağı).
func get_current_task() -> Dictionary:
	if has_running_task():
		return (tasks[_running_idx] as Dictionary).duplicate(true)
	if tasks.size() > 0:
		return (tasks[tasks.size() - 1] as Dictionary).duplicate(true)
	return {}

## Durmuş taskı aynı id ile yeniden açar (devam et; yeni task_id YOK).
func reopen_task(task_id: String) -> bool:
	if task_id.strip_edges().is_empty():
		return false
	if has_running_task():
		return str(tasks[_running_idx].get("id", "")) == task_id
	for i in range(tasks.size()):
		if str(tasks[i].get("id", "")) == task_id:
			tasks[i]["status"] = "running"
			tasks[i]["ended_at"] = ""
			tasks[i]["stop_reason"] = ""
			(tasks[i]["events"] as Array).append({"t": "task_resumed", "ts": now_ts(), "step": _step_mark, "data": {}})
			_running_idx = i
			return true
	return false

## Gerçek tool başarı hükmü: outer wrapper `success=true` olsa bile data/status/error
## içindeki açık başarısızlığı yakalar (or. validate_script: outer ok + data.success=false).
## Dönüş: {"success": bool, "error": String}
static func effective_tool_outcome(result: Dictionary) -> Dictionary:
	if result == null or result.is_empty():
		return {"success": false, "error": "Empty result."}
	if not bool(result.get("success", false)):
		var e0 = _extract_error_text(result)
		if e0.is_empty():
			e0 = str(result.get("message", "Tool failed.")).strip_edges()
		return {"success": false, "error": summarize_error(e0)}
	var scopes: Array = [result]
	if result.get("data") is Dictionary:
		scopes.append(result["data"])
	for scope in scopes:
		if not (scope is Dictionary):
			continue
		var sd: Dictionary = scope
		if sd.has("success") and not bool(sd.get("success", true)):
			var ed = _extract_error_text(sd)
			if ed.is_empty():
				ed = str(result.get("message", "Tool failed.")).strip_edges()
			return {"success": false, "error": summarize_error(ed)}
		if _is_failed_status(sd.get("status", 0)):
			var es = _extract_error_text(sd)
			if es.is_empty():
				es = str(result.get("message", "Verification failed.")).strip_edges()
			return {"success": false, "error": summarize_error(es)}
		if sd.has("error"):
			var ee = _extract_error_text(sd)
			if not ee.is_empty():
				return {"success": false, "error": summarize_error(ee)}
	return {"success": true, "error": ""}

static func _is_failed_status(st: Variant) -> bool:
	if st is int:
		return st == 1
	if st is String:
		return (st as String).strip_edges().to_lower() in ["failed", "error"]
	return false

static func _extract_error_text(scope: Dictionary) -> String:
	if not scope.has("error"):
		return ""
	var e = scope.get("error")
	if e is Dictionary:
		var m = str((e as Dictionary).get("message", "")).strip_edges()
		if not m.is_empty():
			return m
		return str((e as Dictionary).get("code", "")).strip_edges()
	if e is String:
		return (e as String).strip_edges()
	return ""

## Yeni task başlatır; yarım kalmış önceki task varsa "cancelled" kapatır.
func begin_task(prompt: String, display_prompt: String = "") -> String:
	if has_running_task():
		end_task("cancelled", "New task started before previous task finished.")
	_task_seq += 1
	var shown = display_prompt if not display_prompt.is_empty() else prompt
	var task = {
		"id": "task_%d_%d" % [_task_seq, Time.get_ticks_msec()],
		"seq": _task_seq,
		"prompt": truncate_text(prompt),
		"display_prompt": truncate_text(shown),
		"started_at": now_ts(),
		"ended_at": "",
		"status": "running",
		"stop_reason": "",
		"metrics": {},
		"events": [
			{"t": "task_started", "ts": now_ts(), "data": {"prompt": truncate_text(shown, 500)}}
		],
	}
	tasks.append(task)
	_running_idx = tasks.size() - 1
	return str(task["id"])

func end_task(status: String, stop_reason: String = "", metrics: Dictionary = {}) -> void:
	if not has_running_task():
		return
	var task: Dictionary = tasks[_running_idx]
	task["status"] = status
	task["ended_at"] = now_ts()
	task["stop_reason"] = stop_reason.strip_edges()
	task["metrics"] = metrics.duplicate(true)
	(task["events"] as Array).append({
		"t": "task_ended", "ts": now_ts(),
		"data": {"status": status, "stop_reason": stop_reason.strip_edges()}
	})
	_running_idx = -1

## Aktif taska olay ekler; aktif task yoksa session-düzeyi orphan listesine düşer.
func record(event_type: String, data: Dictionary = {}) -> void:
	var entry = {"t": event_type, "ts": now_ts(), "step": _step_mark, "data": data}
	if has_running_task():
		var evs: Array = tasks[_running_idx]["events"]
		if evs.size() >= MAX_EVENTS_PER_TASK + 2:
			return
		evs.append(entry)
	else:
		orphan_events.append(entry)

func to_data() -> Array:
	return tasks.duplicate(true)

func load_data(arr: Array) -> void:
	tasks.clear()
	_running_idx = -1
	if arr == null:
		return
	for t in arr:
		if t is Dictionary:
			var copy: Dictionary = (t as Dictionary).duplicate(true)
			if str(copy.get("status", "")) == "running":
				copy["status"] = "cancelled"
				copy["stop_reason"] = "Session reloaded while task was running."
				copy["ended_at"] = now_ts()
			tasks.append(copy)
			_task_seq = maxi(_task_seq, int(copy.get("seq", 0)))
