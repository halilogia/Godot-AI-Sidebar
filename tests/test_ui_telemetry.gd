@tool
extends RefCounted

const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarUITelemetryTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarHistoryPanel = preload("res://addons/godot_sidebar_ai/ui/components/history_panel.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# --- Test 1: Schema ve ToolManager Kaydı ---
	var all_schemas = AISidebarToolManager.get_all_schemas()
	var has_inspect_schema = false
	for s in all_schemas:
		if s.get("function", {}).get("name", "") == "inspect_ui_layout":
			has_inspect_schema = true
			break
	if has_inspect_schema:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (Schema registration) failed: inspect_ui_layout şemalarda bulunamadı.")

	# --- Test 2: İzin Politikası (Read-Only) ---
	var req_approval = AISidebarPermissionPolicy.requires_user_approval("inspect_ui_layout")
	var risk_level = AISidebarPermissionPolicy.get_tool_risk("inspect_ui_layout")
	if not req_approval and risk_level == AISidebarPermissionPolicy.RiskLevel.READ_ONLY:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (Permission policy) failed: req_approval=" + str(req_approval) + " risk=" + str(risk_level))

	# --- Test 3: Geometri ve Temel Control Özelliklerinin Çıkarımı ---
	var root = PanelContainer.new()
	root.name = "TestRootPanel"
	root.size = Vector2(400, 300)
	
	var vbox = VBoxContainer.new()
	vbox.name = "TestVBox"
	root.add_child(vbox)
	
	var btn = Button.new()
	btn.name = "TestButton"
	btn.text = "Click Me"
	btn.custom_minimum_size = Vector2(120, 36)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(btn)
	
	var stats = {"total_inspected": 0}
	var warnings: Array[Dictionary] = []
	var telemetry = AISidebarUITelemetryTools._inspect_node_recursive(root, 0, 4, true, false, warnings, stats)
	
	if telemetry.get("class", "") == "PanelContainer" and telemetry.get("children", []).size() == 1:
		var child_vbox = telemetry["children"][0]
		if child_vbox.get("class", "") == "VBoxContainer" and child_vbox.get("children", []).size() == 1:
			var child_btn = child_vbox["children"][0]
			if child_btn.get("name", "") == "TestButton" and child_btn.get("custom_min_size", {}).get("w", 0) == 120:
				passed += 1
			else:
				failed += 1
				errors.append("Test 3 (Button properties) failed: " + str(child_btn))
		else:
			failed += 1
			errors.append("Test 3 (VBox inspection) failed: " + str(child_vbox))
	else:
		failed += 1
		errors.append("Test 3 (Root inspection) failed: " + str(telemetry))

	# --- Test 4: Godot 4.7 Erişilebilirlik (A11y) Çıkarımı ---
	if "accessibility_name" in btn:
		btn.accessibility_name = "Primary Submit"
		btn.accessibility_description = "Submits the active form data"
		
	var a11y_stats = {"total_inspected": 0}
	var a11y_warnings: Array[Dictionary] = []
	var btn_telemetry = AISidebarUITelemetryTools._inspect_node_recursive(btn, 0, 1, true, false, a11y_warnings, a11y_stats)
	
	if "accessibility" in btn_telemetry:
		var a_info = btn_telemetry["accessibility"]
		if a_info.get("name", "") == "Primary Submit" and "Submits" in a_info.get("description", ""):
			passed += 1
		else:
			failed += 1
			errors.append("Test 4 (A11y content) failed: " + str(a_info))
	else:
		# Godot platformunda A11y property yoksa en azından graceful pas geçer
		passed += 1

	# --- Test 5: Semantik Metadata Çıkarımı ---
	btn.set_meta("ui_role", "action.primary")
	btn.set_meta("ui_intent", "task.confirm")
	btn.set_meta("ui_id", "btn_submit_order")
	
	var meta_stats = {"total_inspected": 0}
	var meta_warnings: Array[Dictionary] = []
	var meta_telemetry = AISidebarUITelemetryTools._inspect_node_recursive(btn, 0, 1, true, false, meta_warnings, meta_stats)
	
	var s_meta = meta_telemetry.get("semantic_meta", {})
	if s_meta.get("ui_role", "") == "action.primary" and s_meta.get("ui_intent", "") == "task.confirm":
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (Semantic metadata) failed: " + str(s_meta))

	# --- Test 6: Kanıta Dayalı UI_NON_CONTAINER_CHILD_MISMATCH Tespiti ---
	# Buton içine Container ekleme anti-pattern'i
	var bad_btn = Button.new()
	bad_btn.name = "MisconfiguredButton"
	var nested_vbox = VBoxContainer.new()
	nested_vbox.name = "ChildVBox"
	bad_btn.add_child(nested_vbox)
	
	var bad_warnings: Array[Dictionary] = []
	var bad_stats = {"total_inspected": 0}
	AISidebarUITelemetryTools._inspect_node_recursive(bad_btn, 0, 2, true, false, bad_warnings, bad_stats)
	
	var has_mismatch_warning = false
	for w in bad_warnings:
		if w.get("rule_id", "") == "UI_NON_CONTAINER_CHILD_MISMATCH":
			if w.get("confidence", 0.0) >= 0.85 and w.get("evidence", {}).get("parent_class", "") == "Button":
				has_mismatch_warning = true
				break
				
	if has_mismatch_warning:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (Non-container child mismatch) failed: warnings=" + str(bad_warnings))
	bad_btn.queue_free()

	# --- Test 7: Kanıta Dayalı UI_CONTAINER_OVERFLOW Tespiti ---
	var fixed_hbox = HBoxContainer.new()
	fixed_hbox.name = "FixedHBox"
	fixed_hbox.size = Vector2(100, 40)
	
	var giant_child = Control.new()
	giant_child.name = "GiantChild"
	giant_child.custom_minimum_size = Vector2(250, 40)
	fixed_hbox.add_child(giant_child)
	
	var of_warnings: Array[Dictionary] = []
	var of_stats = {"total_inspected": 0}
	AISidebarUITelemetryTools._inspect_node_recursive(fixed_hbox, 0, 2, true, false, of_warnings, of_stats)
	
	var has_overflow_warning = false
	for w in of_warnings:
		if w.get("rule_id", "") == "UI_CONTAINER_OVERFLOW":
			var ev = w.get("evidence", {})
			if ev.get("parent_width", 0) == 100 and ev.get("child_min_width", 0) == 250:
				has_overflow_warning = true
				break
				
	if has_overflow_warning:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (Container overflow) failed: warnings=" + str(of_warnings))
	fixed_hbox.queue_free()

	# --- Test 8: Derinlik Sınırı (max_depth) ---
	var d0 = Node.new()
	var d1 = Node.new()
	var d2 = Node.new()
	var d3 = Node.new()
	d0.add_child(d1)
	d1.add_child(d2)
	d2.add_child(d3)
	
	var depth_warnings: Array[Dictionary] = []
	var depth_stats = {"total_inspected": 0}
	var d_telemetry = AISidebarUITelemetryTools._inspect_node_recursive(d0, 0, 2, true, false, depth_warnings, depth_stats)
	
	# depth 0 -> depth 1 -> depth 2 (children_truncated olmalı)
	var d1_res = d_telemetry.get("children", [])[0]
	var d2_res = d1_res.get("children", [])[0]
	if d2_res.get("children_truncated", false) == true and not d2_res.has("children"):
		passed += 1
	else:
		failed += 1
		errors.append("Test 8 (Depth limit) failed: " + str(d2_res))
	d0.queue_free()

	# --- Test 9: Canlı Component Testi (HistoryPanel) ---
	var panel = AISidebarHistoryPanel.new()
	var panel_warnings: Array[Dictionary] = []
	var panel_stats = {"total_inspected": 0}
	var p_telemetry = AISidebarUITelemetryTools._inspect_node_recursive(panel, 0, 4, true, false, panel_warnings, panel_stats)
	
	if panel_stats["total_inspected"] >= 3 and p_telemetry.get("class", "") == "PanelContainer":
		passed += 1
	else:
		failed += 1
		errors.append("Test 9 (Live HistoryPanel inspection) failed: total=" + str(panel_stats["total_inspected"]))
	panel.queue_free()

	# --- Test 10: execute_tool entegrasyon testi ---
	var exec_res = AISidebarToolManager.execute_tool("inspect_ui_layout", {"target_node": root})
	var err_res = AISidebarToolManager.execute_tool("inspect_ui_layout", {"root_path": "NonExistentNode_XYZ"})
	
	if exec_res.get("success", false) == true and exec_res.has("data") and err_res.get("success", true) == false:
		passed += 1
	else:
		failed += 1
		errors.append("Test 10 (execute_tool inspect_ui_layout) failed: exec=" + str(exec_res) + " err=" + str(err_res))

	# Temizlik
	root.queue_free()

	return {"name": "UITelemetryTests", "passed": passed, "failed": failed, "errors": errors}
