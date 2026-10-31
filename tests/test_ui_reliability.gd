@tool
extends RefCounted

## UI Güvenilirlik Katmanı: P0/P1/P2 denetim kuralları, telemetri standardı, tema belirteçleri ve bileşen şablonları.

const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarUITelemetryTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd")
const AISidebarUIComponentTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_component_tools.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")

const OUT_DIR: String = "user://ui_reliability_test"

static func run() -> Dictionary:
	var checks: Array = []
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	# --- Kayıt ve izin ---
	var names: Array[String] = []
	for s: Dictionary in AISidebarToolManager.get_all_schemas():
		names.append(str((s.get("function", {}) as Dictionary).get("name", "")))
	checks.append(["R0 scaffold_ui_component is registered and classified as WRITE", "scaffold_ui_component" in names and AISidebarPermissionPolicy.get_tool_risk("scaffold_ui_component") == AISidebarPermissionPolicy.RiskLevel.WRITE])

	# --- P0 kuralları ---
	var box := VBoxContainer.new()
	box.name = "Box"
	var ignored := Button.new()
	ignored.name = "IgnoredBtn"
	ignored.custom_minimum_size = Vector2(120, 48)
	ignored.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ghost := Button.new()
	ghost.name = "GhostBtn"
	ghost.custom_minimum_size = Vector2(120, 48)
	ghost.modulate.a = 0.0
	var off := Button.new()
	off.name = "DisabledBtn"
	off.custom_minimum_size = Vector2(120, 48)
	off.disabled = true
	off.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b: Button in [ignored, ghost, off]:
		box.add_child(b)
	var rep: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_layout", {"target_node": box})
	var rd: Dictionary = rep.get("data", {})
	var by_rule: Dictionary = {}
	for iss: Dictionary in rd.get("issues", []):
		by_rule[str(iss["rule_id"]) + "@" + str(iss["node_path"]).get_file()] = str(iss["priority"])
	checks.append(["R1 mouse_filter IGNORE button is P0, disabled one is not accused", by_rule.get("INTERACTIVE_INPUT_IGNORED@IgnoredBtn") == "P0" and not by_rule.has("INTERACTIVE_INPUT_IGNORED@DisabledBtn")])
	checks.append(["R2 zero-alpha clickable button is P0 ghost button", by_rule.get("INTERACTIVE_ZERO_ALPHA@GhostBtn") == "P0"])
	checks.append(["R3 audit reports by_priority, fails on P0 and sorts P0 first", int((rd.get("by_priority", {}) as Dictionary).get("P0", 0)) >= 2 and rd.get("passed") == false and str((rd["issues"] as Array)[0]["priority"]) == "P0" and rd.get("schema_version") == AISidebarUITelemetryTools.SCHEMA_VERSION])
	box.free()

	# --- P2: saydam içerik ve derin iç içe geçme ---
	var deep := Control.new()
	deep.name = "DeepRoot"
	var cur: Control = deep
	for i: int in 11:
		var n := Control.new()
		n.name = "L%d" % i
		cur.add_child(n)
		cur = n
	cur.modulate.a = 0.0
	var drep: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_layout", {"target_node": deep})
	var drules: Array[String] = []
	for iss: Dictionary in (drep["data"] as Dictionary)["issues"]:
		drules.append(str(iss["rule_id"]))
	checks.append(["R4 deep nesting and transparent content are P2 and do not fail the audit", "DEEP_NESTING" in drules and "ZERO_ALPHA_CONTENT" in drules and (drep["data"] as Dictionary)["passed"] == true])
	deep.free()

	# --- .tscn'den Container otorite ihlali (çalışma zamanı konumuna bakmadan) ---
	var tscn_path: String = OUT_DIR + "/authority.tscn"
	var tf: FileAccess = FileAccess.open(tscn_path, FileAccess.WRITE)
	tf.store_string("[gd_scene format=3]\n\n[node name=\"Root\" type=\"VBoxContainer\"]\n\n[node name=\"Bad\" type=\"Button\" parent=\".\"]\nposition = Vector2(50, 50)\ntext = \"x\"\n\n[node name=\"Good\" type=\"Button\" parent=\".\"]\nlayout_mode = 2\ncustom_minimum_size = Vector2(100, 48)\ntext = \"y\"\n\n[node name=\"Center\" type=\"CenterContainer\" parent=\".\"]\nlayout_mode = 2\n\n[node name=\"Inner\" type=\"Button\" parent=\"Center\"]\nlayout_mode = 2\ncustom_minimum_size = Vector2(100, 48)\n")
	tf.close()
	var srep: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_layout", {"scene_path": tscn_path})
	var sflagged: Array[String] = []
	for iss: Dictionary in (srep.get("data", {}) as Dictionary).get("issues", []):
		if iss["rule_id"] == "CONTAINER_AUTHORITY_VIOLATION":
			sflagged.append(str(iss["node_path"]) + ":" + str(iss["priority"]))
	checks.append(["R5 scene file: hand-set position on a Container child is P1; layout_mode=2 children and CenterContainer are clean", sflagged == ["Bad:P1"] and (srep["data"] as Dictionary)["passed"] == false])
	checks.append(["R5b missing scene_path returns SCENE_NOT_FOUND", AISidebarUITelemetryTools.execute("audit_ui_layout", {"scene_path": OUT_DIR + "/nope.tscn"}).get("error", {}).get("code", "") == "SCENE_NOT_FOUND"])
	DirAccess.remove_absolute(tscn_path)

	# --- Dokunma: çizim sırası ---
	if tree and tree.root:
		var overlay_hits: Array[int] = []
		for cover_first: bool in [false, true]:
			var root := Control.new()
			root.size = Vector2(400, 400)
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(100, 50)
			btn.size = Vector2(100, 50)
			var cover := Panel.new()
			cover.size = Vector2(300, 300)
			if cover_first:
				root.add_child(cover)
				root.add_child(btn)
			else:
				root.add_child(btn)
				root.add_child(cover)
			tree.root.add_child(root)
			var trep: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_touch", {"target_node": root})
			var hit: int = 0
			for iss: Dictionary in (trep["data"] as Dictionary)["issues"]:
				if iss["rule_id"] == "POTENTIAL_OVERLAY_BLOCKER" and iss["priority"] == "P0":
					hit += 1
			overlay_hits.append(hit)
			tree.root.remove_child(root)
			root.free()
		checks.append(["R6 STOP panel drawn above a button is P0; the same panel drawn below it is not", overlay_hits == [1, 0]])

	# --- Telemetri standardı ---
	var tele_root := PanelContainer.new()
	tele_root.name = "TeleRoot"
	tele_root.size = Vector2(300, 200)
	var tele_btn := Button.new()
	tele_btn.name = "TeleBtn"
	tele_root.add_child(tele_btn)
	var flat: Dictionary = AISidebarUITelemetryTools.execute("inspect_ui_layout", {"target_node": tele_root, "format": "flat", "include_invisible": true})
	var fd: Dictionary = flat.get("data", {})
	var fnodes: Array = fd.get("nodes", [])
	var fbtn: Dictionary = {}
	for n: Dictionary in fnodes:
		if n.get("name") == "TeleBtn":
			fbtn = n
	var bb: Dictionary = fbtn.get("bbox", {})
	checks.append(["T1 flat telemetry: schema, parent_path, full bbox keys, container authority, interactive flag", fd.get("schema_version") == "ui-telemetry/1" and fd.get("format") == "flat" and fnodes.size() == 2 and fbtn.get("parent_path") == "TeleRoot" and bb.has("cx") and bb.has("cy") and bb.has("right") and bb.has("bottom") and fbtn.get("layout_authority") == "container" and fbtn.get("interactive") == true and not fd.has("telemetry")])
	var tree_fmt: Dictionary = AISidebarUITelemetryTools.execute("inspect_ui_layout", {"target_node": tele_root, "include_invisible": true})
	checks.append(["T2 tree format stays the default and carries by_priority", (tree_fmt["data"] as Dictionary).has("telemetry") and (tree_fmt["data"] as Dictionary).has("by_priority")])
	# Önizleme telemetrisi: görünüm alanından taşan kontrol listelenir
	var wide := Control.new()
	wide.name = "Wide"
	wide.size = Vector2(300, 100)
	var wide_child := Panel.new()
	wide_child.size = Vector2(250, 50)
	wide_child.position = Vector2(0, 0)
	wide.add_child(wide_child)
	var ptele: Dictionary = AISidebarUITelemetryTools._preview_telemetry(wide, Vector2i(100, 100))
	var overflow: Array = ptele["overflow_viewport"]
	checks.append(["T3 preview telemetry lists controls overflowing the viewport (bbox + per-side overflow)", overflow.size() == 2 and ptele["schema_version"] == "ui-telemetry/1" and (ptele["nodes"] as Array).size() == 2 and is_equal_approx(float(overflow[0]["overflow"]["right"]), 200.0)])
	checks.append(["T4 capture_ui_preview is routed as an async tool (layout needs a frame to settle)", AISidebarToolManager.is_async_tool("capture_ui_preview")])
	wide.free()
	tele_root.free()

	# --- Tema belirteçleri ---
	var theme_path: String = OUT_DIR + "/tokens_theme.tres"
	var tres: Dictionary = AISidebarUITelemetryTools.execute("scaffold_ui_theme", {"theme_path": theme_path, "preset": "light", "spacing_unit": 8, "font_size_title": 30, "tokens": {"color": {"primary": "#0f766e"}, "radius": {"md": 12}}})
	var td: Dictionary = tres.get("data", {})
	var th: Theme = ResourceLoader.load(theme_path, "Theme", ResourceLoader.CACHE_MODE_IGNORE) as Theme if FileAccess.file_exists(theme_path) else null
	var json_ok: bool = false
	var tj_path: String = str(td.get("tokens_path", ""))
	if not tj_path.is_empty() and FileAccess.file_exists(tj_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(tj_path))
		json_ok = parsed is Dictionary and (parsed as Dictionary).get("schema") == "ui-tokens/1" and str(((parsed as Dictionary)["color"] as Dictionary)["primary"]) == "#0f766e"
	checks.append(["K1 theme: preset + token override, variations resolve to base types, tokens sidecar written", tres.get("success") == true and th != null and th.get_type_variation_base("PrimaryButton") == "Button" and th.get_type_variation_base("HealthBar") == "ProgressBar" and th.get_type_variation_base("Card") == "PanelContainer" and json_ok and td.get("preset") == "light"])
	checks.append(["K2 theme: title/spacing/radius tokens reach the Theme (HeaderMedium 30, VBox separation 16, Button radius 12)", th != null and th.get_font_size("font_size", "HeaderMedium") == 30 and th.get_constant("separation", "VBoxContainer") == 16 and (th.get_stylebox("normal", "Button") as StyleBoxFlat).corner_radius_top_left == 12])
	checks.append(["K3 theme: default palette passes the contrast report", td.get("contrast_passed") == true])
	var bad: Dictionary = AISidebarUITelemetryTools.execute("scaffold_ui_theme", {"theme_path": OUT_DIR + "/bad_theme.tres", "write_tokens": false, "text_color": "#888888", "surface_color": "#8a8a8a"})
	var bd: Dictionary = bad.get("data", {})
	checks.append(["K4 theme: low-contrast palette is reported, not silently accepted", bad.get("success") == true and bd.get("contrast_passed") == false and (bd["contrast"]["warnings"] as Array).size() >= 1 and str(bd.get("tokens_path", "x")) == ""])

	# --- Bileşen şablonları ---
	var invalid: Dictionary = AISidebarUIComponentTools.execute("scaffold_ui_component", {"component": "nope"})
	checks.append(["C0 unknown component is refused", invalid.get("error", {}).get("code", "") == "INVALID_COMPONENT"])
	var bad_tree := VBoxContainer.new()
	var bad_btn := Button.new()
	bad_btn.custom_minimum_size = Vector2(100, 48)
	bad_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bad_tree.add_child(bad_btn)
	checks.append(["C1 verify_component blocks a tree with a P0 finding", AISidebarUIComponentTools.verify_component(bad_tree)["passed"] == false])
	bad_tree.free()
	for comp: String in ["healthbar", "dialogue_box", "inventory_grid", "pause_menu"]:
		var sp: String = "%s/%s.tscn" % [OUT_DIR, comp]
		var args: Dictionary = {"component": comp, "scene_path": sp, "theme_path": theme_path, "columns": 4, "slot_count": 8}
		var res: Dictionary = AISidebarUIComponentTools.execute("scaffold_ui_component", args)
		var data: Dictionary = res.get("data") if res.get("success") == true else {}
		var packed: PackedScene = ResourceLoader.load(sp, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene if FileAccess.file_exists(sp) else null
		var inst: Node = packed.instantiate() if packed else null
		var again: Dictionary = AISidebarUIComponentTools.verify_component(inst) if inst else {"passed": false}
		checks.append(["C2 %s: saved, loads, script attached, passes its own audit, theme applied (%s)" % [comp, str(res.get("error", ""))], res.get("success") == true and inst != null and inst.get_script() != null and again["passed"] == true and data.get("theme_applied") == theme_path and FileAccess.file_exists(str(data.get("script_path", "")))])
		if inst == null or tree == null or tree.root == null:
			if inst: inst.free()
			continue
		tree.root.add_child(inst)
		match comp:
			"healthbar":
				inst.call("set_health", 20.0, 80.0)
				var bar: ProgressBar = inst.get_node("%Bar") as ProgressBar
				var lbl: Label = inst.get_node("%ValueLabel") as Label
				checks.append(["C3 healthbar: set_health drives value, label and low-health variation", is_equal_approx(bar.value, 20.0) and is_equal_approx(bar.max_value, 80.0) and lbl.text == "20 / 80" and bar.theme_type_variation == &"DangerBar"])
			"dialogue_box":
				inst.set("chars_per_second", 0.0)
				var done: Array[bool] = [false]
				inst.connect("line_finished", func() -> void: done[0] = true)
				inst.call("show_line", "Ayşe", "Merhaba")
				checks.append(["C4 dialogue_box: show_line sets speaker/text and finishes instantly without typewriter", done[0] and (inst.get_node("%SpeakerLabel") as Label).text == "Ayşe" and (inst.get_node("%TextLabel") as RichTextLabel).visible_characters == -1])
			"inventory_grid":
				var grid: GridContainer = inst.get_node("%Grid") as GridContainer
				var pressed: Array[int] = []
				inst.connect("slot_pressed", func(i: int) -> void: pressed.append(i))
				(grid.get_child(3) as Button).pressed.emit()
				inst.call("set_item", 1, null, 5)
				checks.append(["C5 inventory_grid: columns/slot_count honoured, slot press emits its index, 44px slots", grid.columns == 4 and grid.get_child_count() == 8 and pressed == [3] and (grid.get_child(0) as Button).custom_minimum_size.x >= 44.0])
			"pause_menu":
				var menu: Control = inst as Control
				var btns: Control = inst.get_node("%Buttons") as Control
				var actions: Array[String] = []
				inst.connect("action_selected", func(a: StringName) -> void: actions.append(str(a)))
				inst.call("open")
				var opened: bool = menu.visible and tree.paused
				(btns.get_child(0) as Button).pressed.emit()
				checks.append(["C6 pause_menu: open pauses, resume button closes + unpauses and reports its action", opened and not menu.visible and not tree.paused and actions == ["resume"] and btns.get_child_count() == 3 and menu.process_mode == Node.PROCESS_MODE_ALWAYS])
		tree.paused = false
		tree.root.remove_child(inst)
		inst.free()

	# Temizlik
	var dir: DirAccess = DirAccess.open(OUT_DIR)
	if dir:
		for f: String in dir.get_files():
			DirAccess.remove_absolute(OUT_DIR + "/" + f)
	DirAccess.remove_absolute(OUT_DIR)

	var passed: int = 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "UiReliabilityTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
