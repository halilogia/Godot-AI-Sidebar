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

var tasks: Array = []
var orphan_events: Array = []
var _running_idx: int = -1
var _task_seq: int = 0

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
	]
	for p in patterns:
		var re = RegEx.new()
		if re.compile(p) != OK:
			continue
		if p.contains("Bearer\\s"):
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

func clear() -> void:
	tasks.clear()
	orphan_events.clear()
	_running_idx = -1
	_task_seq = 0

func has_running_task() -> bool:
	return _running_idx >= 0 and _running_idx < tasks.size() and str(tasks[_running_idx].get("status", "")) == "running"

func task_count() -> int:
	return tasks.size()

func get_tasks() -> Array:
	return tasks.duplicate(true)

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
	var entry = {"t": event_type, "ts": now_ts(), "data": data}
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
