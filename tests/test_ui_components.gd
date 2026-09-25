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
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

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
		var search_nodes: Array = [act_row]
		while not search_nodes.is_empty():
			var n = search_nodes.pop_back()
			if n is RichTextLabel and (n as RichTextLabel).selection_enabled and (n as CanvasItem).visible:
				act_lbl = n
				break
			for c in (n as Node).get_children():
				search_nodes.append(c)
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
	
	# Test 8: AISidebarTheme Token ve Factory Doğrulaması
	var user_style = AISidebarTheme.create_bubble_user_style()
	var asst_style = AISidebarTheme.create_bubble_assistant_style()
	var cmd_style = AISidebarTheme.create_bubble_command_style()
	var app_bg = AISidebarTheme.create_app_bg_style()
	var accent_btn = AISidebarTheme.create_accent_button_style(false, false)
	var ghost_btn = AISidebarTheme.create_ghost_button_style(false)
	if user_style is StyleBoxFlat and asst_style is StyleBoxFlat and cmd_style is StyleBoxFlat and app_bg is StyleBoxFlat and accent_btn is StyleBoxFlat and ghost_btn is StyleBoxFlat:
		passed += 1
	else:
		failed += 1
		errors.append("Test 8 (AISidebarTheme styles) failed.")

	# Test 9: MessageBubble Tema Entegrasyonu (User / Assistant / Command)
	var u_bubble = AISidebarMessageBubble.new("user", "Hello AI")
	u_bubble._ready()
	var u_panel = u_bubble.get_theme_stylebox("panel")
	var a_bubble = AISidebarMessageBubble.new("assistant", "Hello User")
	a_bubble._ready()
	var a_panel = a_bubble.get_theme_stylebox("panel")
	if u_panel != null and a_panel != null and u_bubble._role_label.get_theme_color("font_color") == AISidebarTheme.COLOR_ACCENT:
		passed += 1
	else:
		failed += 1
		errors.append("Test 9 (MessageBubble theme integration) failed.")
	u_bubble.queue_free()
	a_bubble.queue_free()

	# Test 10: ChatDock Gerçek Sahne Tema Uygulaması (ChatDockTheme.apply)
	var dock_scene = load("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
	if dock_scene:
		var dock = dock_scene.instantiate()
		dock._ready()
		var root_panel = dock.get_theme_stylebox("panel")
		var is_themed = root_panel is StyleBoxFlat and dock.title_label.get_theme_font_size("font_size") == AISidebarTheme.FONT_SIZE_HEADER and dock.send_btn.has_theme_stylebox_override("normal")
		if is_themed:
			passed += 1
		else:
			failed += 1
			errors.append("Test 10 (ChatDockTheme.apply) failed.")
		dock.queue_free()
	else:
		failed += 1
		errors.append("Test 10 (ChatDock scene load) failed.")
	
	# Test 11: Saf tool-call zarfı tespiti (ham JSON kullanıcıya gösterilmemeli)
	var envelope_plain = "{\n  \"tool_calls\": [\n    {\"name\": \"ask_user\", \"arguments\": {\"question\": \"GDScript mi?\"}}\n  ]\n}"
	var envelope_fenced = "```json\n{\"tool_calls\": [{\"name\": \"read_script\", \"arguments\": {}}]}\n```"
	if AISidebarMessageBubble.is_tool_call_envelope(envelope_plain) and AISidebarMessageBubble.is_tool_call_envelope(envelope_fenced):
		passed += 1
	else:
		failed += 1
		errors.append("Test 11 (tool-call envelope detection) failed.")

	# Test 12: Gerçek asistan metni zarf sayılmamalı (yanlış pozitif koruması)
	var real_text = "Hex grid sistemini oluşturdum.\n\n{\n  \"tool_calls\": [\n    {\"name\": \"create_or_update_script\", \"arguments\": {}}\n  ]\n}"
	var plain_prose = "res://player.gd dosyasını güncelledim ve dogrulama gecti."
	if not AISidebarMessageBubble.is_tool_call_envelope(real_text) and not AISidebarMessageBubble.is_tool_call_envelope(plain_prose):
		passed += 1
	else:
		failed += 1
		errors.append("Test 12 (assistant prose must stay visible) failed.")

	# Test 13: ActivityGroup aktifken açık kalabilir
	var live_grp = AISidebarActivityGroup.new(true)
	live_grp._ready()
	live_grp.add_activity("▶", "Reading project files", -1, "{\"path\":\"res://\"}")
	var stays_open = live_grp.is_expanded and live_grp._items_container.visible and live_grp.is_active
	if stays_open:
		passed += 1
	else:
		failed += 1
		errors.append("Test 13 (ActivityGroup stays expanded while active) failed.")

	# Test 14: complete_group() sonrası otomatik collapse
	live_grp.complete_group()
	var collapsed_ok = (not live_grp.is_expanded) and (not live_grp._items_container.visible) and (not live_grp.is_active)
	if collapsed_ok:
		passed += 1
	else:
		failed += 1
		errors.append("Test 14 (ActivityGroup auto-collapse on complete) failed.")

	# Test 15: Kullanıcı tamamlanmış grubu manuel tekrar açabilmeli
	live_grp._on_header_pressed()
	if live_grp.is_expanded and live_grp._items_container.visible:
		passed += 1
	else:
		failed += 1
		errors.append("Test 15 (ActivityGroup manual re-expand after collapse) failed.")
	live_grp.queue_free()

	return {"name": "UIComponentsTests", "passed": passed, "failed": failed, "errors": errors}
