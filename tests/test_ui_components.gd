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
	
	# Test 1: MessageBubble Seçilebilirlik ve Mouse Filter
	var bubble = AISidebarMessageBubble.new("assistant", "Check res://player.gd for details.")
	bubble._ready()
	var formatted = bubble._format_text_with_links_and_code("Check res://player.gd for details.")
	var b_lbl = bubble._content_label
	var is_b_selectable = b_lbl.selection_enabled and b_lbl.context_menu_enabled and b_lbl.shortcut_keys_enabled and b_lbl.focus_mode == Control.FOCUS_CLICK
	if "[url=file:res://player.gd]" in formatted and is_b_selectable and bubble.mouse_filter == Control.MOUSE_FILTER_PASS:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (MessageBubble selectable) failed.")
	bubble.queue_free()
	
	# Test 2: ActivityGroup Seçilebilirlik
	var grp = AISidebarActivityGroup.new(true)
	grp._ready()
	grp.add_activity("✓", "Updated player.gd", 100, "details")
	var act_row = grp._items_container.get_child(0) if grp._items_container.get_child_count() > 0 else null
	var act_lbl: RichTextLabel = null
	if act_row:
		for c in act_row.get_children():
			if c is RichTextLabel:
				act_lbl = c
				break
	var is_act_selectable = act_lbl and act_lbl.selection_enabled and act_lbl.context_menu_enabled and act_lbl.shortcut_keys_enabled
	if grp._items.size() == 1 and grp.is_expanded and is_act_selectable:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (ActivityGroup item selectable) failed.")
	grp.complete_group()
	if not grp.is_active:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (ActivityGroup complete) failed.")
	grp.queue_free()
	
	# Test 3: ChangesCard Seçilebilirlik ve Diff/Undo
	var cs = AISidebarChangeSet.new("res://player.gd", AISidebarChangeSet.ChangeType.MODIFY_FILE, "var a = 1\n", "", "desc")
	var card = AISidebarChangesCard.new(cs)
	card._ready()
	var emitted_diff = [false]
	card.view_diff_requested.connect(func(c): emitted_diff[0] = true)
	card._on_diff_pressed()
	
	var is_card_selectable = card._header_lbl.selection_enabled and card._header_lbl.context_menu_enabled
	if emitted_diff[0] and is_card_selectable and card.mouse_filter == Control.MOUSE_FILTER_PASS:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (ChangesCard view_diff_requested and selectable) failed.")
	card.queue_free()
	
	# Test 4: ApprovalCard Seçilebilirlik
	var app_card = AISidebarApprovalCard.new("delete_node", {"node_path": "Enemy"}, cs)
	app_card._ready()
	var emitted_app = [false]
	app_card.action_approved.connect(func(): emitted_app[0] = true)
	app_card._on_approve()
	var is_app_selectable = app_card._desc_lbl is RichTextLabel and app_card._desc_lbl.selection_enabled and app_card._desc_lbl.context_menu_enabled
	if emitted_app[0] and app_card._approve_btn.disabled and is_app_selectable:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (ApprovalCard approval and selectable) failed.")
	app_card.queue_free()
	
	# Test 5: TelemetryCard Seçilebilirlik
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
	var is_t_selectable = t_card._details_lbl.selection_enabled and t_card._details_lbl.context_menu_enabled
	if "Completed in 2.5s" in t_card._header_btn.text and is_t_selectable:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (TelemetryCard rendering and selectable) failed: " + t_card._header_btn.text)
	t_card.queue_free()
	
	# Test 6: RuntimeCard Seçilebilirlik
	var r_card = AISidebarRuntimeCard.new()
	r_card._ready()
	r_card.add_status("✓", "No runtime errors")
	var r_row = r_card._status_list.get_child(0) if r_card._status_list.get_child_count() > 0 else null
	var r_lbl: RichTextLabel = null
	if r_row:
		for c in r_row.get_children():
			if c is RichTextLabel:
				r_lbl = c
				break
	var is_r_selectable = r_lbl and r_lbl.selection_enabled and r_lbl.context_menu_enabled
	if r_card._status_list.get_child_count() == 1 and is_r_selectable:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (RuntimeCard status and selectable) failed.")
	r_card.queue_free()
	
	# Test 7: ErrorCard Seçilebilirlik
	var e_card = AISidebarErrorCard.new("Network 502")
	e_card._ready()
	var retry_emitted = [false]
	e_card.retry_requested.connect(func(): retry_emitted[0] = true)
	e_card._on_retry_pressed()
	var is_e_selectable = e_card._msg_lbl is RichTextLabel and e_card._msg_lbl.selection_enabled and e_card._msg_lbl.context_menu_enabled
	if retry_emitted[0] and is_e_selectable:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (ErrorCard retry and selectable) failed.")
	e_card.queue_free()
	
	return {"name": "UIComponentsTests", "passed": passed, "failed": failed, "errors": errors}
