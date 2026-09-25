@tool
extends RefCounted

## Kullanıcıdan karar isteyen kartların sunumu (SRP): netleştirme sorusu, tool onayı,
## uygulama planı (onay → checklist), uygulanan değişiklikler, diff görüntüleme ve undo.
## Kararlar AgentRunner'a iletilir ve transcript'e yazılır.

const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarApprovalCard = preload("res://addons/godot_sidebar_ai/ui/components/approval_card.gd")
const AISidebarChangesCard = preload("res://addons/godot_sidebar_ai/ui/components/changes_card.gd")
const AISidebarClarificationCard = preload("res://addons/godot_sidebar_ai/ui/components/clarification_card.gd")
const AISidebarPlanCard = preload("res://addons/godot_sidebar_ai/ui/components/plan_card.gd")
const AISidebarTaskChecklist = preload("res://addons/godot_sidebar_ai/ui/components/task_checklist.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarChangeSetDialog = preload("res://addons/godot_sidebar_ai/ui/dialogs/change_set_dialog.gd")
const AISidebarAgentStreamPresenter = preload("res://addons/godot_sidebar_ai/ui/presenters/agent_stream_presenter.gd")
const AISidebarAgentActivityPresenter = preload("res://addons/godot_sidebar_ai/ui/presenters/agent_activity_presenter.gd")
const AISidebarPlanChecklistTracker = preload("res://addons/godot_sidebar_ai/ui/presenters/plan_checklist_tracker.gd")

## func(comp: Control) — bileşeni message stream'e ekler.
var add_component: Callable = func(_c): pass
## func(meta) — kartlardaki bağlantı tıklamaları.
var on_meta_clicked: Callable = func(_m): pass
## func() — kullanıcı en alttaysa akışı aşağı kaydırır.
var scroll_if_following: Callable = func(): pass
## func() — dock metin/ikon/buton durumlarını yeniler.
var refresh_ui: Callable = func(): pass
var stream: AISidebarAgentStreamPresenter = null
var activity: AISidebarAgentActivityPresenter = null
var checklist_tracker: AISidebarPlanChecklistTracker = null
## Transcript kaynağı olan AgentContext (headless testlerde null olabilir).
var context = null
## Kararların iletildiği AgentRunner (headless testlerde null olabilir).
var runner = null
var change_set_dialog: AISidebarChangeSetDialog = null

var approval_card: AISidebarApprovalCard = null
var plan_card: AISidebarPlanCard = null
var pending_change_set: AISidebarChangeSet = null
var last_applied_change_set: AISidebarChangeSet = null
var pending_tool_name: String = ""
var pending_tool_args: Dictionary = {}

## Yeni task: bekleyen onay kartı bırakılır.
func begin_task() -> void:
	approval_card = null

## Akış temizlendi: canlı kart referansları bırakılır.
func reset() -> void:
	approval_card = null
	plan_card = null

func on_clarification_requested(question: String, options: Array, clarification_id: String) -> void:
	stream.detach_bubble()
	activity.clear_running()
	if activity.group:
		activity.group.add_activity("✓", "Asked clarification", 50, "question: " + question.left(500))
		activity.close_group()
	stream.set_action_summary("Question: " + question.left(120))
	if context:
		context.get_transcript().record("clarification_requested", {"question": question.left(500), "options": options.duplicate(), "id": clarification_id})

	var card = AISidebarClarificationCard.new(question, options)
	card.response_submitted.connect(func(ans: String):
		var grp = activity.ensure_group()
		grp.add_activity("✓", "User selected: " + AISidebarActivityGroup.summarize_error(ans, 120), 50, "answer: " + str(ans).left(500))
		if context:
			context.get_transcript().record("clarification_answered", {"answer": str(ans).left(500)})
			context.get_transcript().record("activity", {"icon": "✓", "title": ("User selected: " + ans).left(200)})
		if runner:
			runner.submit_clarification_response(ans)
	)
	add_component.call(card)
	scroll_if_following.call()
	refresh_ui.call()

func on_approval_requested(tool_name: String, args: Dictionary, cs: AISidebarChangeSet) -> void:
	# Duplicate approval request deduping: Aynı bekleyen işlem için ikinci kart oluşturma
	if approval_card != null and is_instance_valid(approval_card) and not approval_card.is_resolved:
		if pending_tool_name == tool_name and pending_tool_args == args:
			return
			
	pending_tool_name = tool_name
	pending_tool_args = args
	pending_change_set = cs
	
	approval_card = AISidebarApprovalCard.new(tool_name, args, cs)
	approval_card.action_approved.connect(_on_approve_pressed)
	approval_card.action_rejected.connect(_on_reject_pressed)
	approval_card.view_diff_requested.connect(_on_view_diff_pressed)
	add_component.call(approval_card)
	if context:
		context.get_transcript().record("approval_requested", {"tool": tool_name})
	# NOT: change_set_dialog otomatik AÇILMAZ; yalnızca kullanıcı karttaki [View Diff] butonuna basarsa açılır.

func _on_approve_pressed() -> void:
	if approval_card and is_instance_valid(approval_card):
		approval_card.mark_approved()
	if pending_change_set:
		last_applied_change_set = pending_change_set
	if context:
		context.get_transcript().record("approval_granted", {"tool": pending_tool_name})
	if runner:
		runner.approve_pending_action()

func _on_reject_pressed() -> void:
	if approval_card and is_instance_valid(approval_card):
		approval_card.mark_rejected()
	if context:
		context.get_transcript().record("approval_rejected", {"tool": pending_tool_name})
	if runner:
		runner.reject_pending_action()

## Ajandan uygulama planı geldi. Execution HENÜZ başlamadı;
## kullanıcı onayı bekleniyor.
func on_plan_proposed(plan) -> void:
	stream.detach_bubble()
	activity.close_group()

	if not guard_plan_card_integrity(plan):
		return

	if context:
		var p_steps = 0
		var p_files = 0
		var p_goal = ""
		if plan.get("steps") is Array:
			p_steps = (plan.get("steps") as Array).size()
		if plan.get("affected_files") is Array:
			p_files = (plan.get("affected_files") as Array).size()
		if plan.get("goal") != null:
			p_goal = str(plan.get("goal"))
		elif plan.get("title") != null:
			p_goal = str(plan.get("title"))
		context.get_transcript().record("plan_proposed", {"steps": p_steps, "files": p_files, "goal": p_goal.left(300)})
	stream.set_action_summary("Plan proposed — onay bekleniyor")
	plan_card = AISidebarPlanCard.new(plan)
	plan_card.plan_applied.connect(_on_plan_applied)
	plan_card.plan_cancelled.connect(_on_plan_cancelled)
	add_component.call(plan_card)
	scroll_if_following.call()

## Plan verisi kullanıcıya gösterilebilecek kadar anlamlı mı?
## (Eksik plan için boş kart göstermemek adına basit bir bütünlük kontrolü.)
func guard_plan_card_integrity(plan) -> bool:
	if plan == null or not plan.has_method("is_valid"):
		return false
	return plan.is_valid()

func _on_plan_applied() -> void:
	if plan_card and is_instance_valid(plan_card):
		plan_card.mark_applied()
	if context:
		context.get_transcript().record("plan_approved", {})
		context.get_transcript().record("activity", {"icon": "✓", "title": "Plan approved by user"})
	if plan_card and is_instance_valid(plan_card) and plan_card.plan:
		var checklist = AISidebarTaskChecklist.new()
		checklist.setup(plan_card.plan.steps, plan_card.plan.goal)
		checklist.meta_clicked.connect(on_meta_clicked)
		checklist_tracker.checklist = checklist
		add_component.call(checklist)
		checklist_tracker.attach(checklist)
	if runner:
		runner.approve_plan()

func _on_plan_cancelled() -> void:
	if plan_card and is_instance_valid(plan_card):
		plan_card.mark_cancelled()
	if context:
		context.get_transcript().record("plan_rejected", {"reason": "User cancelled the plan."})
		context.get_transcript().record("activity", {"icon": "✕", "title": "Plan rejected by user"})
	if runner:
		runner.reject_plan()

func _on_view_diff_pressed(cs: AISidebarChangeSet = null) -> void:
	var cs_to_show = cs if cs else (pending_change_set if pending_change_set else last_applied_change_set)
	if change_set_dialog:
		change_set_dialog.show_change_set(pending_tool_name, pending_tool_args, cs_to_show)

func on_changes_applied(cs: AISidebarChangeSet) -> void:
	last_applied_change_set = cs
	if not cs:
		return
	var card = AISidebarChangesCard.new(cs)
	card.view_diff_requested.connect(func(c): _on_view_diff_pressed(c))
	card.undo_requested.connect(func(c): _on_undo_pressed(c))
	card.meta_clicked.connect(on_meta_clicked)
	add_component.call(card)

func _on_undo_pressed(cs: AISidebarChangeSet) -> void:
	if cs:
		var res = cs.rollback()
		var grp = activity.ensure_group()
		if res.get("success", false):
			grp.add_activity("✓", "Undo successful: changes reverted", 50)
		else:
			grp.add_activity("✕", "Undo failed: " + res.get("error", "Error"), 50)
