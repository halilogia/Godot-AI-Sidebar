@tool
extends Node

## Demo benchmark: editör `-- --ai-sidebar-bench=<mutlak klasör>` ile açılınca plugin.gd kurar
## (tools/demo_bench.ps1 başlatır). <klasör>/prompt.txt'teki istemi sidebar ajanına verir; onay modu
## yalnız bu çalıştırma için bellekte Tam Otomatik olur (config.json değişmez), ajan soru sorarsa ya da
## plan onayı beklerse devam ettirilir. Görev bitince ya da zaman aşımında Everything export'u
## (<klasör>/export.md + export.json) ve result.json yazılır, editör kapanır.

const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")

const FLAG := "--ai-sidebar-bench="
const TIMEOUT_FLAG := "--ai-sidebar-bench-timeout="
const SETTLE_SEC := 8.0
const POLL_SEC := 3.0
const AUTO_ANSWER := "Soru sorma; en makul varsayımla devam et ve işi bitir."

var out_dir: String = ""
var dock: Control = null
var _done: bool = false
var _started_msec: int = 0
var _timeout_sec: float = 1500.0
var _completion: Dictionary = {}

static func requested_out_dir() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(FLAG):
			return a.trim_prefix(FLAG)
	return ""

func _ready() -> void:
	name = "AISidebarDemoBench"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(TIMEOUT_FLAG):
			_timeout_sec = float(a.trim_prefix(TIMEOUT_FLAG))
	_run.call_deferred()

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _run() -> void:
	var prompt := FileAccess.get_file_as_string(out_dir.path_join("prompt.txt")).strip_edges()
	await _wait(SETTLE_SEC)
	var runner: AISidebarAgentRunner = dock.get("agent_runner") if dock else null
	var tasks: Node = dock.get("tasks") if dock else null
	if prompt.is_empty() or runner == null or tasks == null:
		_finish("setup_failed", "prompt=%d runner=%s tasks=%s" % [prompt.length(), runner != null, tasks != null])
		return
	AISidebarPermissionPolicy.mode_override = AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO
	runner.task_completed.connect(func(m: Dictionary) -> void: _completion = m, CONNECT_ONE_SHOT)
	_started_msec = Time.get_ticks_msec()
	tasks.call("start_task_prompt", prompt)
	while not _done:
		await _wait(POLL_SEC)
		if not _completion.is_empty() and not runner.is_running():
			_finish("completed", str(_completion.get("completion", "")))
			return
		match runner.current_state:
			AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION:
				runner.submit_clarification_response(AUTO_ANSWER)
			AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL:
				runner.approve_plan()
			AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL:
				runner.approve_pending_action()
		if (Time.get_ticks_msec() - _started_msec) / 1000.0 > _timeout_sec:
			runner.stop()
			await _wait(1.0)
			_finish("timeout", "%d s" % int(_timeout_sec))
			return

func _finish(status: String, detail: String) -> void:
	_done = true
	AISidebarPermissionPolicy.mode_override = -1
	var context: RefCounted = dock.get("agent_context") if dock else null
	if context:
		var transcript: Object = context.call("get_transcript")
		var tasks_data: Array = transcript.call("to_data")
		var msgs: Array = context.get("messages")
		var meta := {"exported_at": Time.get_datetime_string_from_system(), "bench_status": status}
		_write("export.md", AISidebarChatExporter.export_transcript_to_markdown(tasks_data, msgs, meta))
		_write("export.json", AISidebarChatExporter.export_transcript_to_json(tasks_data, msgs, meta))
	var elapsed := 0 if _started_msec == 0 else (Time.get_ticks_msec() - _started_msec) / 1000
	var metrics: Dictionary = _completion.duplicate(true)
	_write("result.json", JSON.stringify({"status": status, "detail": detail, "elapsed_s": elapsed, "metrics": metrics}, "  "))
	print("[ai-sidebar-bench] %s (%s) -> %s" % [status, detail, out_dir])
	get_tree().quit(0)

func _write(file: String, text: String) -> void:
	var f := FileAccess.open(out_dir.path_join(file), FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
