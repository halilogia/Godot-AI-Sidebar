@tool
extends RefCounted
class_name AISidebarTaskCheckpoint

## Pause / Resume Checkpoint Modeli (SRP).
## TaskTranscript'ten türetilir; ayrı database YOKTUR, ChatSession içinde saklanır.
## "devam et" aynı task_id ile, S kaldığı noktadan devam eder (tahmin yok, kanıt var).

const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")

const VERSION: int = 1

const RESUME_COMMANDS = ["devam et", "devam", "continue", "sürdür", "surdur", "resume", "go on"]

## Tüm mesaj buysa continuation'dır (alt cümle sayılmaz).
static func is_resume_command(text: String) -> bool:
	if text == null:
		return false
	return text.strip_edges().to_lower() in RESUME_COMMANDS

## Limit/stagnation/iyileşme-tükenmesi terminaldir; resume anlamsız olur.
static func is_terminal_failure(stop_reason: String) -> bool:
	if stop_reason == null or stop_reason.strip_edges().is_empty():
		return false
	var s = stop_reason.to_lower()
	return "limit" in s or "tekrarlad" in s or "iyileştirme limiti" in s or "stagnation" in s

## Bitmiş transcript task + canlı runner bilgisinden checkpoint kurar.
## live: {"current_step": int, "max_steps": int, "elapsed_s": float}
static func build(task: Dictionary, live: Dictionary, active_scene_path: String = "") -> Dictionary:
	if task == null or task.is_empty():
		return {}
	var status = str(task.get("status", "unknown"))
	var stop_reason = str(task.get("stop_reason", "")).strip_edges()
	var completed_tools: Array = []
	var last_success = {}
	var last_failed = {}
	var deferred_tools: Array = []
	var runtime_summary = ""
	var evs = task.get("events", [])
	if evs is Array:
		for e in evs:
			if not (e is Dictionary):
				continue
			var t = str(e.get("t", ""))
			var d = e.get("data", {})
			if not (d is Dictionary):
				continue
			if t == "tool_completed" or t == "tool_result":
				var tname = str(d.get("tool", ""))
				if tname.is_empty() or tname == "ask_user" or tname == "propose_plan":
					continue
				if bool(d.get("success", false)):
					if not tname in completed_tools:
						completed_tools.append(tname)
					last_success = {"tool": tname, "title": str(d.get("title", d.get("message", ""))).left(200)}
				else:
					var ecode = str(d.get("error_code", ""))
					if ecode.begins_with("DEFERRED"):
						if not tname in deferred_tools:
							deferred_tools.append(tname)
					else:
						last_failed = {"tool": tname, "error": str(d.get("error", d.get("message", ""))).left(300), "code": ecode}
			elif t == "runtime_observation":
				var summ = str(d.get("summary", "")).strip_edges()
				if not summ.is_empty():
					runtime_summary = summ.left(500)
	var resumable = status in ["cancelled", "failed"] and not is_terminal_failure(stop_reason)
	# Hata mesajı yok ama failed ise yine de resume'a izin ver (recoverable varsayımı).
	if status == "cancelled":
		resumable = true
	return {
		"version": VERSION,
		"task_id": str(task.get("id", "")),
		"original_prompt": str(task.get("display_prompt", task.get("prompt", ""))).left(500),
		"current_step": int(live.get("current_step", 0)),
		"max_steps": int(live.get("max_steps", 20)),
		"elapsed_s": float(live.get("elapsed_s", 0.0)),
		"status": status,
		"stop_reason": stop_reason,
		"resumable": resumable,
		"completed_tools": completed_tools,
		"last_success_tool": last_success,
		"last_failed_tool": last_failed,
		"deferred_tools": deferred_tools,
		"runtime_summary": runtime_summary,
		"active_scene_path": active_scene_path.strip_edges().left(200),
		"updated_at": AISidebarTaskTranscript.now_ts(),
	}

## Resume bağlamı: model geçmişi tahmin etmez, kanıtı okur.
static func build_resume_message(cp: Dictionary) -> String:
	if cp == null or cp.is_empty():
		return ""
	var lines: PackedStringArray = []
	lines.append("DEVAM — Task resumed at S%d/%d (task %s, yeni task_id açma)." % [int(cp.get("current_step", 0)), int(cp.get("max_steps", 20)), str(cp.get("task_id", ""))])
	lines.append("Orijinal görev: " + str(cp.get("original_prompt", "")).left(300))
	var done = cp.get("completed_tools", [])
	if done is Array and not done.is_empty():
		lines.append("Tamamlanan araçlar (gereksiz yere tekrar ÇALIŞTIRMA): " + ", ".join(done).left(300))
	var lf = cp.get("last_failed_tool", {})
	if lf is Dictionary and not str(lf.get("tool", "")).is_empty():
		lines.append("Son başarısız adım (YENİDEN DENE): " + str(lf.get("tool", "")) + " — " + str(lf.get("error", "")).left(300))
	var df = cp.get("deferred_tools", [])
	if df is Array and not df.is_empty():
		lines.append("Ertelenmiş araçlar (duruma göre çalıştır): " + ", ".join(df).left(300))
	if not str(cp.get("stop_reason", "")).is_empty():
		lines.append("Durma nedeni: " + str(cp.get("stop_reason", "")).left(300))
	if not str(cp.get("runtime_summary", "")).is_empty():
		lines.append("Runtime özeti: " + str(cp.get("runtime_summary", "")).left(300))
	lines.append("Kaldığın yerden devam et; ne yaptığımızı anlamak için project scan yapma.")
	return "\n".join(lines)
