@tool
extends Node

## Demo benchmark: editör `-- --ai-sidebar-bench=<mutlak klasör>` ile açılınca plugin.gd kurar
## (tools/demo_bench.ps1 başlatır). <klasör>/prompt.txt'teki istemi sidebar ajanına verir; onay modu
## yalnız bu çalıştırma için bellekte Tam Otomatik olur (config.json değişmez), ajan soru sorarsa ya da
## plan onayı beklerse devam ettirilir. Görev bitince ya da zaman aşımında Everything export'u
## (<klasör>/export.md + export.json) ve result.json yazılır, editör kapanır.

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")

const FLAG := "--ai-sidebar-bench="
const TIMEOUT_FLAG := "--ai-sidebar-bench-timeout="
const MODEL_FLAG := "--ai-sidebar-bench-model="
const SETTLE_SEC := 8.0
const POLL_SEC := 3.0
const AUTO_ANSWER := "Soru sorma; en makul varsayımla devam et ve işi bitir."

## Motorun hata günlüğü (editör + çalışan oyunun editöre ilettiği hatalar): başka iş parçacığından da
## gelebilir, kuyruğa alınır ve ana döngüde live.jsonl'a yazılır.
class _EngineErrors extends Logger:
	var items: Array[String] = []
	var _mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		# Doğrulamanın geçici derlemeleri (bellek içi kopya, batch aynası) beklenen gürültüdür; sonucu
		# araç sonucunda zaten görünür. Canlı günlüğü boğmasın, gerçek hatayı gizlemesin.
		if file.begins_with("gdscript://") or file.contains("ai_sidebar_verify"):
			return
		var msg := rationale if not rationale.is_empty() else code
		_mutex.lock()
		items.append("%s:%d %s (%s)" % [file, line, msg, function])
		_mutex.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass
	func take() -> Array[String]:
		_mutex.lock()
		var out := items.duplicate()
		items.clear()
		_mutex.unlock()
		return out

const LIVE_FILE := "live.jsonl"
const LIVE_TEXT_MAX := 600

var out_dir: String = ""
var dock: Control = null
var _engine_errors := _EngineErrors.new()
var _done: bool = false
var _started_msec: int = 0
var _timeout_sec: float = 1500.0
var _completion: Dictionary = {}
var _stages: Array[Dictionary] = []

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
	var prompt_text := FileAccess.get_file_as_string(out_dir.path_join("prompt.txt")).strip_edges()
	var prompts: Array[String] = []
	for part: String in prompt_text.split("\n=====\n"):
		if not part.strip_edges().is_empty():
			prompts.append(part.strip_edges())
	var prompt: String = prompts[0] if not prompts.is_empty() else ""
	await _wait(SETTLE_SEC)
	var runner: AISidebarAgentRunner = dock.get("agent_runner") if dock else null
	var tasks: Node = dock.get("tasks") if dock else null
	if prompt.is_empty() or runner == null or tasks == null:
		_finish("setup_failed", "prompt=%d runner=%s tasks=%s" % [prompt.length(), runner != null, tasks != null])
		return
	AISidebarPermissionPolicy.mode_override = AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO
	_force_model()
	runner.task_completed.connect(func(m: Dictionary) -> void: _completion = m, CONNECT_ONE_SHOT)
	_watch(runner)
	_started_msec = Time.get_ticks_msec()
	tasks.call("start_task_prompt", prompt)
	var stage := 0
	while not _done:
		await _wait(POLL_SEC)
		for e: String in _engine_errors.take():
			_live("engine_error", {"text": e})
		if not _completion.is_empty() and not runner.is_running():
			# Çok istemli test (-----: aynı sohbette sırayla): her istemin sonucu ayrı kaydedilir, sıradaki başlar.
			_stages.append({"stage": stage + 1, "elapsed_s": (Time.get_ticks_msec() - _started_msec) / 1000, "metrics": _completion.duplicate(true)})
			stage += 1
			if stage < prompts.size():
				_live("stage", {"text": "istem %d/%d" % [stage + 1, prompts.size()]})
				_completion = {}
				runner.task_completed.connect(func(m: Dictionary) -> void: _completion = m, CONNECT_ONE_SHOT)
				tasks.call("start_task_prompt", prompts[stage])
				continue
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

## -Model ile verilen model listede olmasa da seçili kalsın: model listesi çekilince editör seçimi ilk modele
## çevirebilir; ajan her istekte config'ten okuduğu için açılıştan sonra yeniden yazmak yeter.
func _force_model() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(MODEL_FLAG):
			var cfg := AISidebarConfig.load_config()
			cfg["selected_model"] = a.trim_prefix(MODEL_FLAG)
			AISidebarConfig.save_config(cfg)

## Canlı izleme: ajanın her olayı <klasör>/live.jsonl'a bir satır olarak anında yazılır (tools/demo_bench.ps1
## izleyicisi ve geliştirici okur). Dosya her satırda açılıp kapanır: dışarıdan okuyan kilitlenmez.
func _watch(runner: AISidebarAgentRunner) -> void:
	OS.add_logger(_engine_errors)
	runner.state_changed.connect(func(_s: int, d: String) -> void: _live("state", {"text": d}))
	runner.text_received.connect(func(role: String, t: String) -> void: _live("text", {"role": role, "text": t}))
	runner.thinking_received.connect(func(t: String) -> void: _live("thinking", {"text": t}))
	runner.tool_executing.connect(func(n: String, a: Dictionary) -> void: _live("tool", {"tool": n, "paths": _paths_of(a), "args": JSON.stringify(a)}))
	runner.tool_completed.connect(func(n: String, r: Dictionary) -> void:
		var msg := str(r.get("message", ""))
		var err_v: Variant = r.get("error", null)
		if err_v is Dictionary:
			var err: Dictionary = err_v
			msg = str(err.get("message", ""))
		_live("result", {"tool": n, "ok": r.get("success") == true, "text": msg}))
	runner.error_occurred.connect(func(m: String) -> void: _live("error", {"text": m}))
	runner.runtime_observation_received.connect(func(o: Variant) -> void: _live("runtime", {"text": str(o)}))

## Araç argümanındaki dosya yolları (args 600 karakterde kesilince batch'in içeriği görünmüyordu).
static func _paths_of(args: Dictionary) -> String:
	var out := PackedStringArray()
	var files_v: Variant = args.get("files", null)
	if files_v is Array:
		var files: Array = files_v
		for f: Variant in files:
			if f is Dictionary:
				var fd: Dictionary = f
				out.append(str(fd.get("file_path", "")))
	for key: String in ["file_path", "scene_path", "path", "node_path"]:
		if args.has(key):
			out.append(str(args[key]))
	return ", ".join(out)

func _live(kind: String, data: Dictionary) -> void:
	var entry := {"t": Time.get_time_string_from_system(), "kind": kind}
	for k: String in data.keys():
		entry[k] = str(data[k]).left(LIVE_TEXT_MAX)
	var path := out_dir.path_join(LIVE_FILE)
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(JSON.stringify(entry))
		f.close()

func _finish(status: String, detail: String) -> void:
	_done = true
	OS.remove_logger(_engine_errors)
	_live("finish", {"text": "%s %s" % [status, detail]})
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
	var result := {"status": status, "detail": detail, "elapsed_s": elapsed, "metrics": metrics}
	if _stages.size() > 1:
		result["stages"] = _stages
	_write("result.json", JSON.stringify(result, "  "))
	print("[ai-sidebar-bench] %s (%s) -> %s" % [status, detail, out_dir])
	get_tree().quit(0)

func _write(file: String, text: String) -> void:
	var f := FileAccess.open(out_dir.path_join(file), FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
