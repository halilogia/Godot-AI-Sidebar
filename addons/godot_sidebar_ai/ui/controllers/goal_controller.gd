@tool
extends Node
class_name AISidebarGoalController

## /goal akışı (SRP): hedef oturumunu (AISidebarGoalSession) arayüze ve görev hattına bağlar. /goal komutunu
## ve şeritteki Durdur'u karşılar, report_goal sonuçlarını dinler, her tur bitince devam turunu başlatır
## ya da sonucu (tamamlandı / engellendi / tur sınırı / durduruldu) sohbete yazar. Görev başlatma
## TaskController'ın hattından geçer (start_prompt), böylece bahsetmeler, transcript ve kuyruk aynıdır.

const AISidebarGoalSession = preload("res://addons/godot_sidebar_ai/core/agent/goal_session.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarGoalBanner = preload("res://addons/godot_sidebar_ai/ui/components/goal_banner.gd")

var session: AISidebarGoalSession = AISidebarGoalSession.new()
var banner: AISidebarGoalBanner = null
var context: AISidebarAgentContext = null
## func(prompt: String, display: String) — TaskController.start_task_prompt.
var start_prompt: Callable = func(_p: String, _d: String) -> void: pass
## func(text: String) — sohbete asistan mesajı ekler.
var post_message: Callable = func(_t: String) -> void: pass
## func() -> bool — ajan şu an çalışıyor mu.
var is_busy: Callable = func() -> bool: return false
## func() — çalışan turu kullanıcı adına durdurur.
var stop_run: Callable = func() -> void: pass

func _init() -> void:
	name = "GoalController"

func is_active() -> bool:
	return session.is_active()

## /goal komutu (SlashCommandManager "goal" eylemi). Sohbete yazılacak yanıtı döndürür; boşsa bir tur başladı.
func handle_command(result: Dictionary) -> String:
	var cmd := str(result.get("goal_command", "status"))
	if cmd == "stop":
		if not session.is_active():
			return AISidebarI18n.get_text("goal_none")
		stop()
		return ""
	if cmd == "status":
		if not session.is_active():
			return AISidebarI18n.get_text("goal_none")
		return AISidebarI18n.get_text("goal_status_active", {"objective": session.objective, "round": session.current_round, "max": session.max_rounds})
	if session.is_active():
		return AISidebarI18n.get_text("goal_already_active", {"objective": session.objective})
	if is_busy.call() == true:
		return AISidebarI18n.get_text("goal_busy")
	var max_rounds: float = AISidebarConfig.load_config().get("goal_max_rounds", AISidebarGoalSession.DEFAULT_MAX_ROUNDS)
	if not session.start(str(result.get("objective", "")), roundi(max_rounds)):
		return AISidebarI18n.get_text("goal_usage")
	_refresh_banner()
	start_prompt.call(session.first_prompt(), str(result.get("display_prompt", "/goal " + session.objective)))
	return ""

## Yeni sohbet / temizle: hedef sessizce biter (mesaj yazılmaz, çalışan tur zaten durdurulmuştur).
func reset() -> void:
	session = AISidebarGoalSession.new()
	_refresh_banner()

## Şeritteki Durdur ya da /goal stop: hedef biter, çalışan tur durdurulur.
func stop() -> void:
	if not session.is_active():
		return
	session.stop()
	_finish("stopped")
	if is_busy.call() == true:
		stop_run.call()

## AgentRunner.tool_completed: report_goal sonucunu oturuma yazar.
func on_tool_completed(tool_name: String, result: Dictionary) -> void:
	if tool_name != AISidebarGoalSession.TOOL_NAME or not session.is_active():
		return
	if result.get("success", false) == true and result.get("data", null) is Dictionary:
		var data: Dictionary = result["data"]
		session.record_report(data)

## Görev bitti (TaskController). Hedef sürüyorsa bir sonraki turu başlatır ve true döner (kuyruk
## dağıtılmaz); hedef yoksa ya da bittiyse false.
func on_round_end(finished_ok: bool, user_stopped: bool) -> bool:
	if not session.is_active():
		return false
	var report := session.last_report.duplicate()
	var finished_round := session.current_round
	var decision := session.on_round_finished(finished_ok, user_stopped)
	_record("goal_round_finished", {
		"round": finished_round,
		"max_rounds": session.max_rounds,
		"status": str(report.get("status", "none")),
		"detail": str(report.get("evidence", "")) + (" | " + str(report.get("next_step", "")) if not str(report.get("next_step", "")).is_empty() else ""),
	})
	if decision == "continue":
		_refresh_banner()
		var t := get_tree()
		if t:
			t.create_timer(0.05).timeout.connect(_start_next_round)
		else:
			_start_next_round()
		return true
	_finish(decision, report)
	return false

func _start_next_round() -> void:
	if not session.is_active() or is_busy.call() == true:
		return
	start_prompt.call(session.continue_prompt(), AISidebarI18n.get_text("goal_round_display", {"round": session.current_round, "max": session.max_rounds}))

func _finish(outcome: String, report: Dictionary = {}) -> void:
	_record("goal_finished", {"outcome": outcome, "round": session.current_round, "objective": session.objective})
	var evidence := str(report.get("evidence", ""))
	var next_step := str(report.get("next_step", ""))
	match outcome:
		"achieved":
			post_message.call(AISidebarI18n.get_text("goal_achieved", {"rounds": session.current_round, "evidence": evidence}))
		"blocked":
			post_message.call(AISidebarI18n.get_text("goal_blocked", {"reason": next_step if not next_step.is_empty() else evidence}))
		"exhausted":
			post_message.call(AISidebarI18n.get_text("goal_exhausted", {"max": session.max_rounds, "next": next_step}))
		_:
			post_message.call(AISidebarI18n.get_text("goal_stopped"))
	_refresh_banner()

func _refresh_banner() -> void:
	if banner == null:
		return
	if session.is_active():
		banner.show_goal(session.objective, session.current_round, session.max_rounds)
	else:
		banner.show_goal("", 0, 0)

func _record(kind: String, data: Dictionary) -> void:
	if context:
		context.get_transcript().record(kind, data)
