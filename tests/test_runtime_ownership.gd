@tool
extends RefCounted

## Runtime sahipliği (bulgu #14): AgentRunner.stop() oyunu yalnızca bu runner başlattıysa durdurur.
## Kullanıcının F5 ile açtığı ya da başka runner'ın başlattığı oyun kapanmaz. Sahiplik runner
## örneğindedir; yalnızca BAŞARILI play_game / restart_game verir, başarılı stop_game alır.
## Editördeki gerçek kapanma headless'ta görülemez; durdurma çağrısı sahte debugger ile sayılır.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarRuntimeDebugger = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_debugger.gd")

class ManualProvider extends AISidebarAIProvider:
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		pass
	func respond(text: String, tool_calls: Array = []) -> void:
		response_received.emit(text, "", tool_calls)

## Editöre dokunmadan durdurma çağrılarını sayar.
class CountingDebugger extends AISidebarRuntimeDebugger:
	var stops: int = 0
	func stop() -> Dictionary:
		stops += 1
		return {"success": true}

static func _runner() -> Dictionary:
	var p = ManualProvider.new()
	var r = AISidebarAgentRunner.new(p, AISidebarAgentContext.new())
	r.enable_planning_gate = false
	var dbg = CountingDebugger.new()
	r.runtime_debugger = dbg
	return {"runner": r, "provider": p, "dbg": dbg}

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Oyunu başlatmamış runner'ın Stop'u oyunu durdurmaz (kullanıcının F5'i kapanmaz)
	var s1 = _runner()
	s1["runner"].start_task("Metin görevi")
	s1["runner"].stop()
	var t1 = s1["dbg"].stops == 0
	if t1:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (stop without ownership) failed: stops=%d" % s1["dbg"].stops)

	# 2. Başarısız play_game sahiplik vermez (headless'ta araç EDITOR_REQUIRED döner)
	var s2 = _runner()
	s2["runner"].start_task("Oyunu çalıştır")
	s2["provider"].respond("", [{"id": "g1", "name": "play_game", "arguments": {}}])
	var not_owned = not s2["runner"]._owns_runtime
	if s2["runner"].is_running():
		s2["runner"].stop()
	if not_owned and s2["dbg"].stops == 0:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (failed play_game) failed: owned=%s stops=%d" % [str(not not_owned), s2["dbg"].stops])

	# 3. Başarılı play / restart sahiplik verir, Stop durdurur ve sahipliği bırakır;
	# başarılı stop_game sahipliği alır. A'nın sahipliği B'nin Stop'unu etkilemez.
	var a = _runner()
	var b = _runner()
	a["runner"].start_task("A")
	b["runner"].start_task("B")
	a["runner"]._note_runtime_ownership("play_game", {"success": true})
	b["runner"].stop()
	var b_isolated = b["dbg"].stops == 0 and a["runner"]._owns_runtime
	a["runner"].stop()
	var a_stopped = a["dbg"].stops == 1 and not a["runner"]._owns_runtime
	var c = _runner()
	c["runner"]._note_runtime_ownership("restart_game", {"success": true})
	var restart_owns = c["runner"]._owns_runtime
	c["runner"]._note_runtime_ownership("stop_game", {"success": false})
	var failed_stop_keeps = c["runner"]._owns_runtime
	c["runner"]._note_runtime_ownership("stop_game", {"success": true})
	var stop_game_releases = not c["runner"]._owns_runtime
	if b_isolated and a_stopped and restart_owns and failed_stop_keeps and stop_game_releases:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (ownership transitions) failed: b_iso=%s a_stop=%s restart=%s keep=%s release=%s" % [str(b_isolated), str(a_stopped), str(restart_owns), str(failed_stop_keeps), str(stop_game_releases)])

	# 4. Yeni task eski task'ın oyununu sahiplenmez; resume (aynı task) sahipliği korur
	var s4 = _runner()
	var r4 = s4["runner"]
	r4._note_runtime_ownership("play_game", {"success": true})
	r4.start_task("Yeni görev")
	var reset_on_start = not r4._owns_runtime
	r4._note_runtime_ownership("play_game", {"success": true})
	r4.current_state = AISidebarAgentRunner.AgentState.IDLE
	var cp = {"resumable": true, "task_id": "", "current_step": 1, "max_steps": 20}
	r4.context.get_transcript().begin_task("Devam", "")
	cp["task_id"] = str(r4.context.get_transcript().get_current_task().get("id", ""))
	r4.context.get_transcript().end_task("paused", "", {})
	var resumed = r4.resume_task(cp, "devam et")
	var kept_on_resume = resumed and r4._owns_runtime
	r4.stop()
	if reset_on_start and kept_on_resume and s4["dbg"].stops == 1:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (start resets, resume keeps) failed: reset=%s resumed=%s kept=%s stops=%d" % [str(reset_on_start), str(resumed), str(kept_on_resume), s4["dbg"].stops])

	return {"name": "RuntimeOwnershipTests", "passed": passed, "failed": failed, "errors": errors}
