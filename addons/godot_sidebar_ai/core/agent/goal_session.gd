@tool
extends RefCounted
class_name AISidebarGoalSession

## /goal: kullanıcının verdiği hedefe ulaşana kadar ajanı tur tur çalıştıran oturumun durumu (SRP: saf
## mantık; arayüz ve ajan başlatma AISidebarGoalController'dadır).
##
## Akış: start(hedef) → ilk tur istemi. Ajan her turda report_goal aracıyla durumu bildirir
## (achieved + kanıt / in_progress + sıradaki adım / blocked + neden). Tur bitince on_round_finished
## kararı verir: hedef kanıtla tamamlandıysa ACHIEVED, engel bildirildiyse BLOCKED, tur sınırı
## dolduysa EXHAUSTED, kullanıcı durdurduysa ya da tur hatayla bittiyse STOPPED; aksi halde
## sıradaki tur istemi (continue_prompt) ile devam edilir.

enum State { INACTIVE, ACTIVE, ACHIEVED, BLOCKED, EXHAUSTED, STOPPED }

const TOOL_NAME := "report_goal"
const STATUS_ACHIEVED := "achieved"
const STATUS_IN_PROGRESS := "in_progress"
const STATUS_BLOCKED := "blocked"
const DEFAULT_MAX_ROUNDS := 10
const MAX_ROUNDS_LIMIT := 50

var state: State = State.INACTIVE
var objective: String = ""
var current_round: int = 0
var max_rounds: int = DEFAULT_MAX_ROUNDS
## Bu turdaki son report_goal çağrısı: {"status", "evidence", "next_step"} (yoksa boş).
var last_report: Dictionary = {}
## Önceki turların son raporu (bir sonraki tur istemine özet olarak girer).
var previous_report: Dictionary = {}

func start(p_objective: String, p_max_rounds: int = DEFAULT_MAX_ROUNDS) -> bool:
	var text := p_objective.strip_edges()
	if text.is_empty():
		return false
	objective = text
	max_rounds = clampi(p_max_rounds, 1, MAX_ROUNDS_LIMIT)
	current_round = 1
	last_report = {}
	previous_report = {}
	state = State.ACTIVE
	return true

func is_active() -> bool:
	return state == State.ACTIVE

func stop() -> void:
	if state == State.ACTIVE:
		state = State.STOPPED

## report_goal aracının argümanları (araç sonucu verisinden). Geçersiz durum yok sayılır.
func record_report(data: Dictionary) -> void:
	if state != State.ACTIVE:
		return
	var status := str(data.get("status", ""))
	if status not in [STATUS_ACHIEVED, STATUS_IN_PROGRESS, STATUS_BLOCKED]:
		return
	last_report = {
		"status": status,
		"evidence": str(data.get("evidence", "")).strip_edges(),
		"next_step": str(data.get("next_step", "")).strip_edges(),
	}

## Tur bitti. finished_ok: tur hatasız tamamlandı mı; user_stopped: kullanıcı durdurdu mu.
## Dönüş: "continue" ya da bitiş nedeni ("achieved", "blocked", "exhausted", "stopped").
func on_round_finished(finished_ok: bool, user_stopped: bool) -> String:
	if state != State.ACTIVE:
		return "stopped"
	if user_stopped:
		state = State.STOPPED
		return "stopped"
	var status := str(last_report.get("status", ""))
	# "Tamamlandı" yalnız tur hatasız bittiyse ve kanıt yazıldıysa kabul edilir; hatayla biten turdaki
	# "tamamlandı" beyanı bir sonraki turda doğrulanır.
	if status == STATUS_ACHIEVED and finished_ok and not str(last_report.get("evidence", "")).is_empty():
		state = State.ACHIEVED
		return "achieved"
	if status == STATUS_BLOCKED:
		state = State.BLOCKED
		return "blocked"
	if not finished_ok and last_report.is_empty():
		state = State.STOPPED
		return "stopped"
	if current_round >= max_rounds:
		state = State.EXHAUSTED
		return "exhausted"
	current_round += 1
	if not last_report.is_empty():
		previous_report = last_report
	last_report = {}
	return "continue"

## İlk tur: hedef ve çalışma sözleşmesi.
func first_prompt() -> String:
	return ("GOAL MODE. The user set this goal and wants you to keep working until it is fully met:\n\"%s\"\n\n" % objective) + _contract()

## Sonraki tur: aynı hedef, önceki turun durumu.
func continue_prompt() -> String:
	var summary := "(no report_goal call in the previous round)"
	if not previous_report.is_empty():
		summary = "status=%s; evidence: %s; next step: %s" % [str(previous_report.get("status", "")), str(previous_report.get("evidence", "")), str(previous_report.get("next_step", ""))]
	return ("GOAL MODE, round %d of %d. Goal:\n\"%s\"\nPrevious round: %s\n\nContinue from where you left off; do not redo finished work.\n\n" % [current_round, max_rounds, objective, summary]) + _contract()

func _contract() -> String:
	return "Rules for this round:\n" \
		+ "- Do the next concrete part of the work with your tools, then verify it (validate scripts, run the game, read runtime errors, take a screenshot when the result is visual).\n" \
		+ "- Before you end the round, call report_goal exactly once: status=achieved only when every part of the goal is met AND you verified it (put the evidence in 'evidence'); status=in_progress with the next concrete step otherwise; status=blocked when you need the user (missing information, a decision, or a failure you cannot fix), with the reason.\n" \
		+ "- Never claim achieved without evidence. If you are unsure, it is in_progress."
