@tool
extends RefCounted

## audit_ui_layout / audit_ui_touch'ın ekrana bakan kuralları: platform profili, görünüm dışı, metin kontrastı,
## etkileşimli kontrolle çakışma. Her kural için bilinçli kusurlu bir arayüz yakalanmalı, temiz olanı alarm vermemeli.

const AISidebarUITelemetryTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd")
const AISidebarUIAuditRules = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_audit_rules.gd")
const AISidebarUIAuditScenario = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_audit_scenario.gd")
const AISidebarUIComponentTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_component_tools.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

const PAPER := Color("#e8dcc0")
const INK := Color("#3b2a1a")
const FADED_INK := Color("#cbbd9f")
const MID_INK := Color("#7d6e52")

static var _tree: SceneTree

static func run() -> Dictionary:
	_tree = Engine.get_main_loop() as SceneTree
	var checks: Array = []
	_platform_checks(checks)
	_viewport_checks(checks)
	_contrast_checks(checks)
	_overlap_checks(checks)
	_scenario_checks(checks)
	_config_and_cli_checks(checks)
	_theme_and_component_checks(checks)
	var passed: int = 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "UiAuditRulesTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}

# --- yardımcılar ---

## 800x600 bilinen boyutlu görünüm; kök Control onu doldurur.
static func _stage() -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 600)
	_tree.root.add_child(vp)
	var root := Control.new()
	root.name = "Stage"
	root.size = Vector2(800, 600)
	vp.add_child(root)
	return [vp, root]

static func _drop(stage: Array) -> void:
	var vp: SubViewport = stage[0]
	_tree.root.remove_child(vp)
	vp.free()

static func _btn(parent: Node, name: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.name = name
	parent.add_child(b)
	b.position = pos
	b.size = size
	return b

static func _label(parent: Node, name: String, text: String, color: Color, pos: Vector2 = Vector2.ZERO, size: Vector2 = Vector2(200, 24), font_px: int = 16) -> Label:
	var l := Label.new()
	l.name = name
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_px)
	parent.add_child(l)
	l.position = pos
	l.size = size
	return l

static func _paper_panel(parent: Node, name: String, pos: Vector2, size: Vector2, sb: StyleBox = null) -> Panel:
	var p := Panel.new()
	p.name = name
	if sb == null:
		var f := StyleBoxFlat.new()
		f.bg_color = PAPER
		sb = f
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	p.position = pos
	p.size = size
	return p

static func _sort(c: Container) -> void:
	c.notification(Container.NOTIFICATION_SORT_CHILDREN)

static func _layout(root: Node) -> Dictionary:
	return AISidebarUITelemetryTools.execute("audit_ui_layout", {"target_node": root}).get("data", {})

## rule_id@düğüm adı -> öncelik.
static func _hits(data: Dictionary, rule: String) -> Dictionary:
	var out: Dictionary = {}
	for iss: Dictionary in data.get("issues", []):
		if str(iss.get("rule_id", "")) == rule:
			out[str(iss.get("node_path", "")).get_file()] = str(iss.get("priority", ""))
	return out

# --- 1. platform profili ---

static func _platform_checks(checks: Array) -> void:
	var stage := _stage()
	var root: Control = stage[1]
	_btn(root, "Normal1", Vector2(10, 10), Vector2(120, 32))
	_btn(root, "Normal2", Vector2(10, 60), Vector2(120, 32))
	_btn(root, "Normal3", Vector2(10, 110), Vector2(32, 32))
	_btn(root, "Normal4", Vector2(60, 110), Vector2(32, 32))
	_btn(root, "Tiny", Vector2(10, 160), Vector2(16, 16))
	var desk: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_touch", {"target_node": root, "platform": "desktop"}).get("data", {})
	var mob: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_touch", {"target_node": root, "platform": "mobile"}).get("data", {})
	var small_desk := _hits(desk, "TOUCH_TARGET_TOO_SMALL")
	var small_mob := _hits(mob, "TOUCH_TARGET_TOO_SMALL")
	checks.append(["P1a desktop profile (28 px): only the 16 px button is too small, normal 32 px buttons are clean", small_desk.keys() == ["Tiny"] and desk.get("platform") == "desktop" and is_equal_approx(float(desk.get("min_touch_size", 0)), 28.0)])
	checks.append(["P1b mobile profile (44 px) keeps the phone rule: all five buttons are too small", small_mob.size() == 5 and mob.get("platform") == "mobile"])
	ProjectSettings.set_setting(AISidebarUIAuditRules.PLATFORM_SETTING, "desktop")
	var proj: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_touch", {"target_node": root}).get("data", {})
	ProjectSettings.clear(AISidebarUIAuditRules.PLATFORM_SETTING)
	var dflt: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_touch", {"target_node": root}).get("data", {})
	checks.append(["P1c project setting sets the default platform; without it the default stays mobile", proj.get("platform") == "desktop" and dflt.get("platform") == "mobile"])
	var over: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_touch", {"target_node": root, "platform": "desktop", "min_touch_size": 40.0}).get("data", {})
	var bad: Dictionary = AISidebarUITelemetryTools.execute("audit_ui_touch", {"target_node": root, "platform": "watch"})
	checks.append(["P1d explicit min_touch_size overrides the profile; unknown platform is INVALID_ARGUMENT", _hits(over, "TOUCH_TARGET_TOO_SMALL").size() == 5 and (bad.get("error", {}) as Dictionary).get("code", "") == "INVALID_ARGUMENT"])
	_drop(stage)

# --- 2. görünüm dışı ---

static func _viewport_checks(checks: Array) -> void:
	var stage := _stage()
	var root: Control = stage[1]
	_btn(root, "HalfOut", Vector2(760, 100), Vector2(100, 40))
	_btn(root, "FarOut", Vector2(900, 10), Vector2(80, 30))
	var parked := Panel.new()
	parked.name = "ParkedPanel"
	root.add_child(parked)
	parked.position = Vector2(820, 300)
	parked.size = Vector2(200, 100)
	_btn(parked, "ChildOfParked", Vector2(10, 10), Vector2(80, 30))
	_btn(root, "Inside", Vector2(10, 10), Vector2(80, 30))
	var d := _layout(root)
	var out := _hits(d, "OUTSIDE_VIEWPORT")
	checks.append(["V1 a button half off-screen and one fully off-screen are P1 OUTSIDE_VIEWPORT; audit fails", out.get("HalfOut") == "P1" and out.get("FarOut") == "P1" and d.get("passed") == false])
	checks.append(["V2 off-screen panel is reported once, its child is not repeated; on-screen button is clean", out.has("ParkedPanel") and not out.has("ChildOfParked") and not out.has("Inside")])
	_drop(stage)

	# Temiz: Container yerleşimi, CenterContainer, kaydırılan uzun içerik.
	var clean := _stage()
	var croot: Control = clean[1]
	var box := VBoxContainer.new()
	croot.add_child(box)
	box.position = Vector2(10, 10)
	box.size = Vector2(300, 200)
	for i: int in 3:
		var b := Button.new()
		b.text = "Item %d" % i
		box.add_child(b)
	_sort(box)
	var center := CenterContainer.new()
	croot.add_child(center)
	center.position = Vector2(400, 0)
	center.size = Vector2(400, 300)
	var cb := Button.new()
	cb.text = "Center"
	center.add_child(cb)
	_sort(center)
	var scroll := ScrollContainer.new()
	croot.add_child(scroll)
	scroll.position = Vector2(10, 320)
	scroll.size = Vector2(300, 260)
	var tall := VBoxContainer.new()
	tall.custom_minimum_size = Vector2(280, 2000)
	scroll.add_child(tall)
	var deep := Button.new()
	deep.custom_minimum_size = Vector2(100, 1900)
	tall.add_child(deep)
	_sort(scroll)
	_sort(tall)
	var cd := _layout(croot)
	checks.append(["V3 Container / CenterContainer / scrolled content raise no OUTSIDE_VIEWPORT", _hits(cd, "OUTSIDE_VIEWPORT").is_empty() and (tall.get_global_rect().end.y > 600.0)])
	_drop(clean)

# --- 3. metin kontrastı ---

static func _contrast_checks(checks: Array) -> void:
	var stage := _stage()
	var root: Control = stage[1]
	var paper := _paper_panel(root, "Paper", Vector2(0, 0), Vector2(400, 300))
	_label(paper, "FadedInk", "Soluk mürekkep", FADED_INK, Vector2(10, 10))
	_label(paper, "MidInk", "Orta mürekkep", MID_INK, Vector2(10, 50))
	_label(paper, "SepiaInk", "Koyu sepya", INK, Vector2(10, 90))
	_label(paper, "BigMidInk", "Başlık", MID_INK, Vector2(10, 130), Vector2(300, 40), 28)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(PAPER)
	var tex_sb := StyleBoxTexture.new()
	tex_sb.texture = ImageTexture.create_from_image(img)
	var textured := _paper_panel(root, "TexturedPaper", Vector2(400, 0), Vector2(400, 300), tex_sb)
	_label(textured, "FadedOnTexture", "Doku üstünde soluk yazı", FADED_INK, Vector2(10, 10))
	_label(root, "NoBackground", "Arka planı bilinmeyen yazı", FADED_INK, Vector2(10, 400))
	var faded_btn := _btn(root, "DisabledFaded", Vector2(10, 450), Vector2(120, 32))
	faded_btn.text = "Kapalı"
	faded_btn.disabled = true
	var d := _layout(root)
	var low := _hits(d, "TEXT_LOW_CONTRAST")
	checks.append(["K1 faded ink on a paper StyleBoxFlat is P1 TEXT_LOW_CONTRAST", low.get("FadedInk") == "P1"])
	checks.append(["K2 mid ink (~3.7:1) is P2 for body text; the same colour at 28 px passes (3:1 large text)", low.get("MidInk") == "P2" and not low.has("BigMidInk")])
	checks.append(["K3 faded ink on a paper texture (StyleBoxTexture) is measured from the texture colour", low.get("FadedOnTexture") == "P1"])
	checks.append(["K4 dark sepia on paper, text with no known background and a disabled button are not accused", not low.has("SepiaInk") and not low.has("NoBackground") and not low.has("DisabledFaded")])
	var ev: Dictionary = {}
	for iss: Dictionary in d.get("issues", []):
		if iss.get("rule_id") == "TEXT_LOW_CONTRAST" and str(iss.get("node_path", "")).ends_with("FadedInk"):
			ev = iss.get("evidence", {})
	checks.append(["K5 evidence carries ratio, required ratio and both colours", float(ev.get("ratio", 0.0)) > 1.0 and float(ev.get("ratio", 9.0)) < 3.0 and ev.get("background") == PAPER.to_html(false).insert(0, "#")])
	_drop(stage)

# --- 4. etkileşimli kontrolle çakışma ---

static func _overlap_checks(checks: Array) -> void:
	var stage := _stage()
	var root: Control = stage[1]
	var recruit := _btn(root, "Recruit", Vector2(100, 100), Vector2(120, 32))
	recruit.text = "Topla"
	_label(root, "GrownText", "Büyüyen panelin uzun açıklama metni düğmenin üstüne biniyor", INK, Vector2(60, 104), Vector2(500, 24))
	_label(root, "UnderText", "Altta kalan metin", INK, Vector2(300, 204), Vector2(300, 24))
	root.move_child(root.get_node("UnderText"), 0)
	_btn(root, "Covering", Vector2(290, 200), Vector2(120, 32))
	_btn(root, "StackA", Vector2(100, 300), Vector2(120, 32))
	_btn(root, "StackB", Vector2(150, 310), Vector2(120, 32))
	var off := _btn(root, "StackOff", Vector2(150, 300), Vector2(60, 32))
	off.disabled = true
	_btn(root, "Lonely", Vector2(600, 500), Vector2(120, 32))
	var d := _layout(root)
	var txt := _hits(d, "TEXT_OVERLAPS_INTERACTIVE")
	var btn := _hits(d, "INTERACTIVE_OVERLAP")
	checks.append(["O1 text drawn over a neighbour button is P1 TEXT_OVERLAPS_INTERACTIVE", txt.get("GrownText") == "P1"])
	checks.append(["O2 text hidden under a button drawn after it is P2", txt.get("UnderText") == "P2"])
	checks.append(["O3 two enabled buttons overlapping is P1 INTERACTIVE_OVERLAP; disabled one is ignored", btn.get("StackA") == "P1" and btn.size() == 1])
	_drop(stage)

	var clean := _stage()
	var croot: Control = clean[1]
	var row := HBoxContainer.new()
	croot.add_child(row)
	row.position = Vector2(10, 10)
	row.size = Vector2(500, 32)
	var info := Label.new()
	info.text = "Asker: 1200"
	row.add_child(info)
	var go := Button.new()
	go.text = "Gönder"
	row.add_child(go)
	_sort(row)
	var own := _btn(croot, "WithOwnLabel", Vector2(10, 100), Vector2(160, 40))
	var inner := Label.new()
	inner.text = "Düğmenin kendi etiketi"
	own.add_child(inner)
	inner.size = Vector2(150, 30)
	var cd := _layout(croot)
	checks.append(["O4 label next to a button in an HBox and a button's own child label raise no overlap", _hits(cd, "TEXT_OVERLAPS_INTERACTIVE").is_empty() and _hits(cd, "INTERACTIVE_OVERLAP").is_empty()])
	_drop(clean)

# --- 5. gizli paneller / senaryo ---

static func _scenario_checks(checks: Array) -> void:
	var stage := _stage()
	var root: Control = stage[1]
	var hidden_panel := Panel.new()
	hidden_panel.name = "TechPanel"
	hidden_panel.visible = false
	hidden_panel.position = Vector2(20, 20)
	hidden_panel.size = Vector2(300, 200)
	root.add_child(hidden_panel)
	var off_btn := _btn(hidden_panel, "OffScreenInHidden", Vector2(950, 20), Vector2(80, 32))
	off_btn.text = "Kaymış"

	var default_audit := _layout(root)
	checks.append(["S1 hidden panel is ignored by default audit when visible=false", _hits(default_audit, "OUTSIDE_VIEWPORT").is_empty()])

	var applied: Dictionary = AISidebarUIAuditScenario.apply_state(root, {"name": "tech_open", "show": ["TechPanel"], "set": {"TechPanel": {"self_modulate": "Color(0.9, 0.9, 0.9, 1.0)"}}}, false)
	var shown_audit := _layout(root)
	var found_while_shown: bool = _hits(shown_audit, "OUTSIDE_VIEWPORT").get("OffScreenInHidden") == "P1" and hidden_panel.visible == true
	AISidebarUIAuditScenario.revert(applied["undo"])
	var reverted_clean: bool = hidden_panel.visible == false and hidden_panel.self_modulate.is_equal_approx(Color.WHITE)
	checks.append(["S2 scenario apply_state reveals hidden panel for audit and revert restores exact state", found_while_shown and reverted_clean and (applied["errors"] as Array).is_empty()])

	var blocked: Dictionary = AISidebarUIAuditScenario.apply_state(root, {"call": [{"node": "TechPanel", "method": "queue_free"}]}, true)
	checks.append(["S3 scenario blocks destructive method calls like queue_free", not (blocked["errors"] as Array).is_empty() and is_instance_valid(hidden_panel)])
	_drop(stage)

# --- 6. user:// config ve headless CLI ---

static func _config_and_cli_checks(checks: Array) -> void:
	checks.append(["C1 AISidebarConfig writes to user://godot_sidebar_ai/config.json and not res://addons/", AISidebarConfig.CONFIG_PATH.begins_with("user://") and FileAccess.file_exists("res://tools/ui_audit.ps1") and FileAccess.file_exists("res://tools/ui_audit.gd")])

# --- 7. tema belirteç eşleme ve oyun bileşen şablonları ---

static func _theme_and_component_checks(checks: Array) -> void:
	var out_dir: String = "user://ui_audit_rules_test"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var tp: String = out_dir + "/pafta_theme.tres"
	var tj: String = out_dir + "/pafta_tokens.json"
	var tres: Dictionary = AISidebarUITelemetryTools.execute("scaffold_ui_theme", {
		"theme_path": tp,
		"tokens_path": tj,
		"preset": "parchment",
		"token_map": {"surface": "paper", "text": "ink", "primary": "seal"}
	})
	var tdata: Dictionary = tres.get("data", {})
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(tj)) if FileAccess.file_exists(tj) else null
	var colors_dict: Dictionary = (parsed as Dictionary).get("colors", {}) if parsed is Dictionary else {}
	checks.append(["T1 scaffold_ui_theme parchment preset + token_map writes mapped JSON keys (paper, ink, seal)", tres.get("success") == true and tdata.get("contrast_passed") == true and colors_dict.has("paper") and colors_dict.has("ink") and colors_dict.has("seal")])

	var all_ok: bool = true
	for comp: String in ["framed_panel", "resource_strip", "list_row", "event_popup"]:
		var sp: String = "%s/%s.tscn" % [out_dir, comp]
		var res: Dictionary = AISidebarUIComponentTools.execute("scaffold_ui_component", {"component": comp, "scene_path": sp, "theme_path": tp})
		if res.get("success") != true or not FileAccess.file_exists(sp):
			all_ok = false
	checks.append(["T2 game UI templates (framed_panel, resource_strip, list_row, event_popup) build, pass self-audit and save", all_ok])

	var d: DirAccess = DirAccess.open(out_dir)
	if d:
		for f: String in d.get_files():
			DirAccess.remove_absolute(out_dir + "/" + f)
	DirAccess.remove_absolute(out_dir)
