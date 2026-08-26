@tool
extends RefCounted

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarChangesCard = preload("res://addons/godot_sidebar_ai/ui/components/changes_card.gd")
const AISidebarApprovalCard = preload("res://addons/godot_sidebar_ai/ui/components/approval_card.gd")
const AISidebarRuntimeCard = preload("res://addons/godot_sidebar_ai/ui/components/runtime_card.gd")
const AISidebarTelemetryCard = preload("res://addons/godot_sidebar_ai/ui/components/telemetry_card.gd")
const AISidebarErrorCard = preload("res://addons/godot_sidebar_ai/ui/components/error_card.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: MessageBubble
	var bubble = AISidebarMessageBubble.new("assistant", "Check res://player.gd for details.")
	var formatted = bubble._format_text_with_links_and_code("Check res://player.gd for details.")
	if "[url=file:res://player.gd]" in formatted:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (MessageBubble link formatting) failed: " + formatted)
	bubble.queue_free()
	
	# Test 2: ActivityGroup
	var grp = AISidebarActivityGroup.new(true)
	grp._ready()
	grp.add_activity("✓", "Updated player.gd", 100, "details")
	if grp._items.size() == 1 and grp.is_expanded:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (ActivityGroup item adding) failed.")
	grp.complete_group()
	if not grp.is_active:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (ActivityGroup complete) failed.")
	grp.queue_free()
	
	# Test 3: ChangesCard
	var cs = AISidebarChangeSet.new("res://player.gd", AISidebarChangeSet.ChangeType.MODIFY_FILE, "var a = 1\n", "", "desc")
	var card = AISidebarChangesCard.new(cs)
	card._ready()
	var emitted_diff = [false]
	card.view_diff_requested.connect(func(c): emitted_diff[0] = true)
	card._on_diff_pressed()
	if emitted_diff[0]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (ChangesCard view_diff_requested) failed.")
	card.queue_free()
	
	# Test 4: ApprovalCard
	var app_card = AISidebarApprovalCard.new("delete_node", {"node_path": "Enemy"}, cs)
	app_card._ready()
	var emitted_app = [false]
	app_card.action_approved.connect(func(): emitted_app[0] = true)
	app_card._on_approve()
	if emitted_app[0] and app_card._approve_btn.disabled:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (ApprovalCard approval) failed.")
	app_card.queue_free()
	
	# Test 5: TelemetryCard
	var t_card = AISidebarTelemetryCard.new({
		"success": true,
		"elapsed_seconds": 2.5,
		"llm_turns": 2,
		"tool_calls": 1,
		"file_ops": 1,
		"llm_time_s": 2.4,
		"tool_time_s": 0.1,
		"file_time_s": 0.1,
		"waiting_time_s": 0.0
	})
	t_card._ready()
	if "Completed in 2.5s" in t_card._header_btn.text:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (TelemetryCard rendering) failed: " + t_card._header_btn.text)
	t_card.queue_free()
	
	# Test 6: RuntimeCard
	var r_card = AISidebarRuntimeCard.new()
	r_card._ready()
	r_card.add_status("✓", "No runtime errors")
	if r_card._status_list.get_child_count() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (RuntimeCard status) failed.")
	r_card.queue_free()
	
	# Test 7: ErrorCard
	var e_card = AISidebarErrorCard.new("Network 502")
	e_card._ready()
	var retry_emitted = [false]
	e_card.retry_requested.connect(func(): retry_emitted[0] = true)
	e_card._on_retry_pressed()
	if retry_emitted[0]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (ErrorCard retry) failed.")
	e_card.queue_free()
	
	return {"name": "UIComponentsTests", "passed": passed, "failed": failed, "errors": errors}
