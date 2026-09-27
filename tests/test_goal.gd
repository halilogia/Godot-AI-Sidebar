@tool
extends RefCounted

## /goal hedef modu: oturum kararları, report_goal aracı, araç sunumu, slash ayrıştırma, risk sınıfı,
## hedef denetleyicisinin tur akışı ve şerit.

const AISidebarGoalSession = preload("res://addons/godot_sidebar_ai/core/agent/goal_session.gd")
const AISidebarGoalTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/goal_tools.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarGoalController = preload("res://addons/godot_sidebar_ai/ui/controllers/goal_controller.gd")
const AISidebarGoalBanner = preload("res://addons/godot_sidebar_ai/ui/components/goal_banner.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

static func _schema_names(schemas: Array) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in schemas:
		var fn: Dictionary = s["function"]
		out.append(str(fn["name"]))
	return out

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	# T1 Oturum kararları.
	var s := AISidebarGoalSession.new()
	var empty_rejected := not s.start("   ", 5)
	var started := s.start("Oyuncu zıplasın", 3)
	var prompt_ok := s.first_prompt().contains("Oyuncu zıplasın") and s.first_prompt().contains(AISidebarGoalSession.TOOL_NAME)
	s.record_report({"status": "achieved", "evidence": ""})
	var no_evidence_continues := s.on_round_finished(true, false) == "continue" and s.current_round == 2
	s.record_report({"status": "in_progress", "evidence": "script valid", "next_step": "add animation"})
	var cont := s.on_round_finished(true, false) == "continue" and s.continue_prompt().contains("add animation") and s.continue_prompt().contains("round 3 of 3")
	var exhausted := s.on_round_finished(true, false) == "exhausted" and s.state == AISidebarGoalSession.State.EXHAUSTED
	var a := AISidebarGoalSession.new()
	a.start("x", 5)
	a.record_report({"status": "achieved", "evidence": "played the game, no runtime errors"})
	var achieved := a.on_round_finished(true, false) == "achieved" and not a.is_active()
	# Hatayla biten turdaki "tamamlandı" beyanı kabul edilmez; bir sonraki tur doğrular.
	var af := AISidebarGoalSession.new()
	af.start("x", 5)
	af.record_report({"status": "achieved", "evidence": "played the game"})
	achieved = achieved and af.on_round_finished(false, false) == "continue" and af.is_active()
	var b := AISidebarGoalSession.new()
	b.start("x", 5)
	b.record_report({"status": "blocked", "evidence": "", "next_step": "which sprite?"})
	var blocked := b.on_round_finished(true, false) == "blocked"
	var u := AISidebarGoalSession.new()
	u.start("x", 5)
	var user_stop := u.on_round_finished(false, true) == "stopped"
	var f := AISidebarGoalSession.new()
	f.start("x", 5)
	var failed_no_report := f.on_round_finished(false, false) == "stopped"
	var g := AISidebarGoalSession.new()
	g.start("x", 5)
	g.record_report({"status": "bogus"})
	var bogus_ignored := g.last_report.is_empty()
	var clamp := AISidebarGoalSession.new()
	clamp.start("x", 999)
	var clamped := clamp.max_rounds == AISidebarGoalSession.MAX_ROUNDS_LIMIT
	if empty_rejected and started and prompt_ok and no_evidence_continues and cont and exhausted and achieved and blocked and user_stop and failed_no_report and bogus_ignored and clamped:
		passed += 1
	else:
		failed += 1
		errors.append("T1 goal session: empty=%s start=%s prompt=%s noev=%s cont=%s exh=%s ach=%s blk=%s user=%s fail=%s bogus=%s clamp=%s" % [empty_rejected, started, prompt_ok, no_evidence_continues, cont, exhausted, achieved, blocked, user_stop, failed_no_report, bogus_ignored, clamped])

	# T2 report_goal aracı: geçersiz durum ve kanıtsız achieved reddedilir, geçerli rapor geri verilir.
	var bad := AISidebarGoalTools.execute("report_goal", {"status": "done"})
	var no_ev := AISidebarGoalTools.execute("report_goal", {"status": "achieved", "evidence": " "})
	var ok := AISidebarGoalTools.execute("report_goal", {"status": "in_progress", "evidence": "a", "next_step": "b"})
	var ok_data: Dictionary = ok.get("data", {})
	if bad.get("success", true) == false and no_ev.get("success", true) == false and ok.get("success", false) == true and str(ok_data.get("next_step", "")) == "b":
		passed += 1
	else:
		failed += 1
		errors.append("T2 report_goal: bad=%s no_ev=%s ok=%s" % [str(bad), str(no_ev), str(ok)])

	# T3 Araç yalnız hedef istemi onu andığında sunulur; salt okunur.
	var with_goal := _schema_names(AISidebarToolManager.get_relevant_schemas(AISidebarGoalSession.new().first_prompt() + " report_goal"))
	var plain := _schema_names(AISidebarToolManager.get_relevant_schemas("oyuncuya zıplama ekle"))
	var risk_ok := AISidebarPermissionPolicy.get_tool_risk("report_goal") == AISidebarPermissionPolicy.RiskLevel.READ_ONLY
	var exec := AISidebarToolManager.execute_tool("report_goal", {"status": "blocked", "evidence": "", "next_step": "need input"})
	if with_goal.has("report_goal") and not plain.has("report_goal") and risk_ok and exec.get("success", false) == true:
		passed += 1
	else:
		failed += 1
		errors.append("T3 tool offering: goal=%s plain=%s risk=%s exec=%s" % [with_goal.has("report_goal"), plain.has("report_goal"), risk_ok, str(exec)])

	# T4 /goal ayrıştırma.
	var r_start := AISidebarSlashCommandManager.execute_command("goal", "düşman devriye gezsin")
	var r_status := AISidebarSlashCommandManager.execute_command("goal", "")
	var r_stop := AISidebarSlashCommandManager.execute_command("goal", "stop")
	if str(r_start.get("goal_command", "")) == "start" and str(r_start.get("objective", "")) == "düşman devriye gezsin" and str(r_status.get("goal_command", "")) == "status" and str(r_stop.get("goal_command", "")) == "stop" and str(r_start.get("action", "")) == "goal":
		passed += 1
	else:
		failed += 1
		errors.append("T4 slash: start=%s status=%s stop=%s" % [str(r_start), str(r_status), str(r_stop)])

	# T5 Denetleyici: başlatma, rapor, devam turu, sonuç mesajı ve şerit (ağaç dışı: devam turu hemen).
	var ctl := AISidebarGoalController.new()
	var banner := AISidebarGoalBanner.new()
	ctl.banner = banner
	var prompts: Array[String] = []
	var messages: Array[String] = []
	ctl.start_prompt = func(p: String, _d: String) -> void: prompts.append(p)
	ctl.post_message = func(t: String) -> void: messages.append(t)
	var reply := ctl.handle_command({"goal_command": "start", "objective": "Envanter çalışsın"})
	var first_started := reply.is_empty() and prompts.size() == 1 and banner.visible and banner.get_goal_text().contains("Envanter")
	var dup := ctl.handle_command({"goal_command": "start", "objective": "başka"})
	var dup_refused := not dup.is_empty() and prompts.size() == 1
	ctl.on_tool_completed("report_goal", {"success": true, "data": {"status": "in_progress", "evidence": "grid ok", "next_step": "drag & drop"}})
	var continued := ctl.on_round_end(true, false) and prompts.size() == 2 and prompts[1].contains("drag & drop")
	ctl.on_tool_completed("report_goal", {"success": true, "data": {"status": "achieved", "evidence": "item moved in game"}})
	var ended := not ctl.on_round_end(true, false) and messages.size() == 1 and messages[0].contains("item moved in game") and not banner.visible
	var status_none := ctl.handle_command({"goal_command": "status"}) == AISidebarI18n.get_text("goal_none")
	ctl.handle_command({"goal_command": "start", "objective": "y"})
	ctl.stop()
	var stopped := messages.size() == 2 and messages[1] == AISidebarI18n.get_text("goal_stopped") and not ctl.is_active()
	ctl.free()
	banner.free()
	if first_started and dup_refused and continued and ended and status_none and stopped:
		passed += 1
	else:
		failed += 1
		errors.append("T5 controller: start=%s dup=%s cont=%s end=%s none=%s stop=%s msgs=%s" % [first_started, dup_refused, continued, ended, status_none, stopped, str(messages)])

	return {"name": "GoalTests", "passed": passed, "failed": failed, "errors": errors}
