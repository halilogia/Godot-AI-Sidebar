@tool
extends RefCounted

## PlanChecklistTracker için DETERMINISTIK testler (plan step <-> tool eşleşmesi).
## Kapsar: dosya hedefi çıkarımı, validate anahtar kelimesi önceliği, running->completed/failed,
## izlenmeyen tool'un yok sayılması, finish (success/stop), snapshot kaydı, reset.

const AISidebarPlanChecklistTracker = preload("res://addons/godot_sidebar_ai/ui/presenters/plan_checklist_tracker.gd")
const AISidebarTaskChecklist = preload("res://addons/godot_sidebar_ai/ui/components/task_checklist.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")

static func _make(steps: Array) -> AISidebarPlanChecklistTracker:
	var cl = AISidebarTaskChecklist.new()
	cl.setup(steps, "Hedef")
	var tr = AISidebarPlanChecklistTracker.new()
	tr.checklist = cl
	return tr

static func _states(tr: AISidebarPlanChecklistTracker) -> Array:
	return tr.checklist.get_states()

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. file_targets: file_path + scene_path + files[] (path/file_path), küçük harf dosya adı
	var t1 = AISidebarPlanChecklistTracker.file_targets({
		"file_path": "res://src/Player.gd",
		"scene_path": "res://Main.tscn",
		"files": [{"file_path": "res://a/Enemy.gd"}, {"path": "res://b/HUD.tscn"}, "ignored"],
	})
	if t1 == ["player.gd", "main.tscn", "enemy.gd", "hud.tscn"]:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (file_targets) failed: " + str(t1))

	# 2. Dosya adıyla eşleşen pending adım running olur, sonra completed
	var tr2 = _make(["Create Player.gd", "Create Main.tscn"])
	tr2.on_tool_start("create_scene", {"scene_path": "res://Main.tscn"})
	var s2a = _states(tr2)
	tr2.on_tool_done("create_scene", true, "")
	var s2b = _states(tr2)
	if s2a == ["pending", "running"] and s2b == ["pending", "completed"]:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (match by file name) failed: %s -> %s" % [str(s2a), str(s2b)])

	# 3. validate_script: doğrulama anahtar kelimesi dosya adından önce gelir
	var tr3 = _make(["Update Player.gd", "Doğrulama çalıştır"])
	tr3.on_tool_start("validate_script", {"file_path": "res://Player.gd"})
	if _states(tr3) == ["pending", "running"]:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (verify keyword priority) failed: " + str(_states(tr3)))

	# 4. Başarısız tool -> failed + hata metni; argümanlar start'tan hatırlanır
	var tr4 = _make(["Update Player.gd"])
	tr4.on_tool_start("replace_file_content", {"file_path": "res://Player.gd"})
	tr4.on_tool_done("replace_file_content", false, "Parse error")
	var st4 = tr4.checklist.get_step(0)
	if str(st4.get("state", "")) == "failed" and "Parse error" in str(st4.get("error", "")):
		passed += 1
	else:
		failed += 1
		errors.append("T4 (failure) failed: " + str(st4))

	# 5. İzlenmeyen (read-only) tool ve ask_user checklist'e dokunmaz
	var tr5 = _make(["Read Player.gd"])
	tr5.on_tool_start("ask_user", {"file_path": "res://Player.gd"})
	tr5.on_tool_done("read_script", true, "")
	if _states(tr5) == ["pending"]:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (untracked tools ignored) failed: " + str(_states(tr5)))

	# 6. finish(false): running adım stop nedeniyle kapanır; bitmiş checklist yeniden eşleşmez
	var tr6 = _make(["Create Player.gd", "Create Main.tscn"])
	tr6.on_tool_start("create_or_update_script", {"file_path": "res://Player.gd"})
	tr6.finish(false, "Tool-call limit reached: 20/20")
	var idx6 = tr6.match_index("create_scene", {"scene_path": "res://Main.tscn"}, ["pending"])
	if tr6.checklist.is_finished and tr6.checklist.stop_reason.contains("limit") and idx6 == -1:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (finish with stop) failed: finished=%s idx=%d" % [str(tr6.checklist.is_finished), idx6])

	# 7. Snapshot: context varsa attach + her geçiş transcript'e yazılır
	var ctx = AISidebarAgentContext.new()
	ctx.begin_task("Sahne kur", "")
	var cl7 = AISidebarTaskChecklist.new()
	cl7.setup(["Create Main.tscn"], "Sahne kur")
	var tr7 = AISidebarPlanChecklistTracker.new()
	tr7.context = ctx
	tr7.attach(cl7)
	tr7.on_tool_start("create_scene", {"scene_path": "res://Main.tscn"})
	tr7.on_tool_done("create_scene", true, "")
	var snaps = 0
	for ev in ctx.get_transcript().get_current_task().get("events", []):
		if ev is Dictionary and str(ev.get("t", "")) == "checklist_snapshot":
			snaps += 1
	if snaps == 3:
		passed += 1
	else:
		failed += 1
		errors.append("T7 (snapshots) failed: %d" % snaps)

	# 8. reset: checklist bağı ve argüman hafızası temizlenir
	tr7.reset()
	if not tr7.has_checklist() and tr7.match_index("create_scene", {}, ["pending"]) == -1:
		passed += 1
	else:
		failed += 1
		errors.append("T8 (reset) failed.")

	for tr in [tr2, tr3, tr4, tr5, tr6]:
		tr.checklist.free()
	cl7.free()
	return {"name": "PlanChecklistTrackerTests", "passed": passed, "failed": failed, "errors": errors}
