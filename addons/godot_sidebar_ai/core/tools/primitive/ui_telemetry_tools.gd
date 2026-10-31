@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarUITelemetryTools

## AI-Native UI Yerleşim, Düzen ve Dokunmatik Telemetrisi Aracı (SRP).
## Godot 4.7 Control ağacını tarayarak Container vs Koordinat çakışmaları,
## dokunmatik hedef ergonomisi, Theme üretimi ve SubViewport önizleme sağlar.

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarUIThemeScaffold = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_theme_scaffold.gd")
const AISidebarUIAuditRules = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_audit_rules.gd")
const AISidebarUIAuditScenario = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_audit_scenario.gd")

## Telemetri sözleşmesi sürümü: inspect_ui_layout ve capture_ui_preview aynı bbox / hiyerarşi şemasını döner.
const SCHEMA_VERSION: String = "ui-telemetry/1"
const NESTING_LIMIT: int = 8
const MAX_FLAT_NODES: int = 300
const ALPHA_EPSILON: float = 0.01

## Kural -> öncelik. P0: kullanıcı etkileşimi bozuk, P1: yerleşim kırık, P2: bakım / ergonomi.
const PRIORITY: Dictionary = {
	"INTERACTIVE_INPUT_IGNORED": "P0", "INTERACTIVE_ZERO_ALPHA": "P0", "INTERACTIVE_ZERO_SIZE": "P0", "POTENTIAL_OVERLAY_BLOCKER": "P0",
	"CONTAINER_AUTHORITY_VIOLATION": "P1", "CONTAINER_CHILD_TOP_LEVEL": "P1", "CONTAINER_MANUAL_ANCHORS": "P1",
	"UI_CONTAINER_OVERFLOW": "P1", "OUTSIDE_PARENT_RECT": "P1", "OUTSIDE_VIEWPORT": "P1", "TEXT_LOW_CONTRAST": "P1", "TEXT_OVERLAPS_INTERACTIVE": "P1", "INTERACTIVE_OVERLAP": "P1", "TOUCH_TARGET_TOO_SMALL": "P1", "UI_TEXT_CLIPPED": "P1", "ZERO_SIZE_WITH_CHILDREN": "P1",
	"MISSING_SIZE_OR_EXPAND": "P2", "TOUCH_BUTTONS_TOO_CLOSE": "P2", "UI_NON_CONTAINER_CHILD_MISMATCH": "P2", "DEEP_NESTING": "P2", "ZERO_ALPHA_CONTENT": "P2"
}
## Container çocuğunun konumunu/boyutunu elle belirleyen sahne özellikleri (Container bunları ezer).
const AUTHORITY_PROPS: Array[String] = ["position", "anchors_preset", "anchor_left", "anchor_top", "anchor_right", "anchor_bottom", "offset_left", "offset_top", "offset_right", "offset_bottom"]

static var _registered_sidebar_dock: Control = null

static func register_sidebar_dock(dock: Control) -> void:
	_registered_sidebar_dock = dock

static func get_sidebar_dock() -> Control:
	return _registered_sidebar_dock if is_instance_valid(_registered_sidebar_dock) else null

static func get_schemas() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "inspect_ui_layout",
				"description": "Returns standardized layout telemetry (schema 'ui-telemetry/1') for a UI node or scene tree: per-node id, depth, index, layout_authority (container|anchors|manual), bbox {x,y,w,h,right,bottom,cx,cy} (viewport-global when in tree), min sizes, visibility, theme, A11y, semantic roles, plus prioritized (P0/P1/P2) layout warnings. Read-only.",
				"parameters": {
					"type": "object",
					"properties": {
						"root_path": {"type": "string", "description": "Root node path ('@sidebar', '@edited_scene', '/root/...', or empty)."},
						"format": {"type": "string", "enum": ["tree", "flat"], "description": "'tree' nested children (default) or 'flat' node list with parent_path (easier to diff/query)."},
						"max_depth": {"type": "integer", "description": "Max depth to scan (default: 4, max: 8)."},
						"include_invisible": {"type": "boolean", "description": "Include invisible nodes (default: false)."},
						"include_theme_details": {"type": "boolean", "description": "Include StyleBox details, font size and colors (default: false)."}
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "audit_ui_layout",
				"description": "Deterministic layout audit with P0/P1/P2 priorities. P0 (interaction broken): button ignoring mouse (mouse_filter IGNORE), fully transparent or zero-size clickable control. P1 (layout broken): Container authority violation (manual position/offset/anchors on a Container child; with scene_path this is read from the .tscn itself), top_level in Container, content clipped outside parent, control outside the viewport (OUTSIDE_VIEWPORT; scrolled/clipped content and world-space UI are exempt), text unreadable against its panel (TEXT_LOW_CONTRAST, WCAG ratio of the real font colour vs the nearest StyleBox/ColorRect/texture background: <3:1 is P1, below 4.5:1 for body text P2), visible text drawn over a button (TEXT_OVERLAPS_INTERACTIVE) or two enabled buttons overlapping (INTERACTIVE_OVERLAP), Container overflow, zero-size parent with children. P2: missing expand flags, deep nesting, transparent content, text hidden under a button. passed=false if any P0/P1. Read-only.",
				"parameters": {
					"type": "object",
					"properties": {
						"root_path": {"type": "string", "description": "Root node path to audit ('@edited_scene', '@sidebar', or empty)."},
						"scene_path": {"type": "string", "description": "Audit a saved .tscn directly (static Container-authority check + hierarchy rules); overrides root_path."},
						"max_depth": {"type": "integer", "description": "Max depth (default: 12)."},
						"include_invisible": {"type": "boolean", "description": "Audit invisible controls (default: false)."},
						"min_text_contrast": {"type": "number", "description": "Required WCAG contrast for body text (default: 4.5; large text >= 24 px needs 3.0)."},
						"states": {"type": "array", "items": {"type": "object"}, "description": "Hidden-panel scenario: audit each state in order. State = {name, show:[node refs], hide:[...], set:{node:{prop:value}}, call:[{node,method,args}], audit:[node refs]}. Each state is applied, layout settles, the audit runs, then the state is reverted. 'call' is disabled on the open editor scene."},
						"scenario_path": {"type": "string", "description": "JSON scenario file ({scene, viewport:[w,h], platform, states:[...]}); its states run like the states argument."},
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "audit_ui_touch",
				"description": "Audits pointer/touch ergonomics with P0/P1/P2 priorities for a platform profile (desktop: 28 px targets, 4 px spacing; mobile: 44 px, 8 px; default from project setting godot_ai_sidebar/ui_audit/platform, else mobile): buttons smaller than the target (P1), clickable controls closer than the spacing (P2), and a MOUSE_FILTER_STOP panel drawn ABOVE a button that overlaps it (P0, draw-order aware). Read-only.",
				"parameters": {
					"type": "object",
					"properties": {
						"root_path": {"type": "string", "description": "Root node path ('@edited_scene', '@sidebar', or empty)."},
						"platform": {"type": "string", "enum": ["desktop", "mobile"], "description": "Size profile: desktop (mouse, 28 px) or mobile (touch, 44 px). Default: project setting godot_ai_sidebar/ui_audit/platform, else mobile."},
						"min_touch_size": {"type": "number", "description": "Min target size in pixels; overrides the platform profile."},
						"min_spacing": {"type": "number", "description": "Min spacing between clickable buttons in pixels; overrides the platform profile."},
						"include_invisible": {"type": "boolean", "description": "Audit invisible controls (default: false)."},
						"states": {"type": "array", "items": {"type": "object"}, "description": "Hidden-panel scenario: audit each state in order. State = {name, show:[node refs], hide:[...], set:{node:{prop:value}}, call:[{node,method,args}], audit:[node refs]}. Each state is applied, layout settles, the audit runs, then the state is reverted. 'call' is disabled on the open editor scene."},
						"scenario_path": {"type": "string", "description": "JSON scenario file ({scene, viewport:[w,h], platform, states:[...]}); its states run like the states argument."}
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "scaffold_ui_theme",
				"description": "Generates a design-token driven Godot 4 Theme (.tres) + a '<theme>.tokens.json' sidecar. Tokens: colors (primary/secondary/background/surface/surface_hover/text/text_muted/accent/danger/success, auto on_primary), radius sm/md/lg, spacing xs..xl (from spacing_unit), font scale small/body/title/heading. Styles Button (all states), Panel(Container), LineEdit, ProgressBar, Label, RichTextLabel, CheckBox/OptionButton, box/grid/margin constants, separators; defines type variations PrimaryButton, DangerButton, GhostButton, Card, HeaderLarge, HeaderMedium, Caption, AccentLabel, DangerLabel, HealthBar, DangerBar, AccentBar (use theme_type_variation instead of per-node overrides). Returns a WCAG contrast report for the palette.",
				"parameters": {
					"type": "object",
					"properties": {
						"theme_path": {"type": "string", "description": "Target path (default: 'res://ui/theme.tres')."},
						"preset": {"type": "string", "enum": ["dark", "light", "parchment"], "description": "Base palette (default: 'dark'). Explicit colors override it."},
						"tokens": {"type": "object", "description": "Token overrides: {color:{primary:'#hex',...}, radius:{sm,md,lg}, spacing:{xs,sm,md,lg,xl}, font_size:{small,body,title,heading}, border_width}."},
						"token_map": {"type": "object", "description": "Optional mapping from standard token names to custom JSON keys (e.g. {'surface':'paper','text':'ink'})."},
						"tokens_path": {"type": "string", "description": "Custom path for the tokens JSON output (default: '<theme>.tokens.json')."},
						"spacing_unit": {"type": "integer", "description": "Base spacing unit in px; xs..xl = 1,2,3,4,6 x unit (default: 4)."},
						"write_tokens": {"type": "boolean", "description": "Write the tokens JSON sidecar (default: true)."},
						"success_color": {"type": "string", "description": "Success/health color in hex (default: preset)."},
						"primary_color": {"type": "string", "description": "Primary accent color in hex (default: '#4f46e5')."},
						"secondary_color": {"type": "string", "description": "Secondary accent color in hex (default: '#06b6d4')."},
						"background_color": {"type": "string", "description": "Background canvas color in hex (default: '#0f172a')."},
						"surface_color": {"type": "string", "description": "Surface container color in hex (default: '#1e293b')."},
						"surface_hover_color": {"type": "string", "description": "Surface hover color in hex (default: '#334155')."},
						"text_color": {"type": "string", "description": "Text primary color in hex (default: '#f8fafc')."},
						"text_muted_color": {"type": "string", "description": "Muted text color in hex (default: '#94a3b8')."},
						"accent_color": {"type": "string", "description": "Highlight accent color in hex (default: '#f59e0b')."},
						"danger_color": {"type": "string", "description": "Danger color in hex (default: '#ef4444')."},
						"corner_radius": {"type": "integer", "description": "Corner radius for rounded styleboxes (default: 8)."},
						"font_size_body": {"type": "integer", "description": "Default font size for body/buttons (default: 16)."},
						"font_size_title": {"type": "integer", "description": "Title font size (default: 22)."},
						"font_size_small": {"type": "integer", "description": "Small caption font size (default: 12)."}
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "capture_ui_preview",
				"description": "Renders an offscreen SubViewport preview of a UI scene across mobile portrait, mobile landscape, tablet, desktop resolutions and saves a PNG for visual analysis. Returns the same bbox telemetry ('ui-telemetry/1', viewport coordinates, flat list), the controls overflowing the viewport and a prioritized audit summary, so the image can be checked against numbers. draw_bounds outlines every control: green = Container-managed, blue = anchors, orange = manual, magenta = interactive.",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": {"type": "string", "description": "Path to UI scene (e.g. 'res://scenes/ui/hud.tscn'). Empty uses active scene root."},
						"include_telemetry": {"type": "boolean", "description": "Return bbox telemetry + audit (default: true)."},
						"draw_bounds": {"type": "boolean", "description": "Draw bounding-box outlines on the PNG (default: false)."},
						"root_path": {"type": "string", "description": "Node path if previewing an existing node."},
						"profile": {"type": "string", "enum": ["mobile_portrait", "mobile_landscape", "tablet", "desktop", "square", "custom"], "description": "Profile resolution (default: 'mobile_portrait')."},
						"width": {"type": "integer", "description": "Custom width in pixels (default: 720)."},
						"height": {"type": "integer", "description": "Custom height in pixels (default: 1280)."},
						"simulate_safe_area": {"type": "boolean", "description": "Simulate mobile notch and home indicator guides (default: true)."},
						"save_path": {"type": "string", "description": "Path to save preview PNG (default: 'user://ui_snapshots/preview_{profile}_{width}x{height}.png')."}
					}
				}
			}
		}
	]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"inspect_ui_layout": return _inspect_ui_layout(args)
		"audit_ui_layout": return _audit_ui_layout(args)
		"audit_ui_touch": return _audit_ui_touch(args)
		"scaffold_ui_theme": return _scaffold_ui_theme(args)
		"capture_ui_preview": return _capture_ui_preview(args)
		_: return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen UI telemetri aracı: " + tool_name)

# --- 1. INSPECT UI LAYOUT ---

static func _inspect_ui_layout(args: Dictionary) -> Dictionary:
	var target_override: Node = args.get("target_node") as Node
	var root_path: String = str(args.get("root_path", "")).strip_edges()
	var max_depth: int = clampi(int(args.get("max_depth", 4)), 1, 8)
	var include_invisible: bool = bool(args.get("include_invisible", false))
	var include_theme_details: bool = bool(args.get("include_theme_details", false))
	var target_node: Node = _resolve_target_node(root_path, target_override)
	if not target_node:
		var err_code: String = "EDITOR_SCENE_REQUIRED" if root_path.begins_with("@edited_scene") else "NODE_NOT_FOUND"
		return AISidebarToolResult.err(err_code, "UI kök düğümü bulunamadı: " + root_path)
	var warnings: Array[Dictionary] = []
	var stats: Dictionary = {"total_inspected": 0}
	var telemetry: Dictionary = _inspect_node_recursive(target_node, 0, max_depth, include_invisible, include_theme_details, warnings, stats)
	var by_priority: Dictionary = _prioritize(warnings)
	var result: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"coordinate_space": {"rect": "parent-local", "global_rect": "viewport-global", "bbox": "viewport-global when in tree, else parent-local"},
		"root_path": _get_safe_node_path(target_node),
		"target_identifier": root_path if not root_path.is_empty() else "@edited_scene",
		"total_nodes_inspected": int(stats["total_inspected"]),
		"warnings": warnings,
		"warning_count": warnings.size(),
		"by_priority": by_priority
	}
	if str(args.get("format", "tree")) == "flat":
		var flat: Array = []
		_flatten_telemetry(telemetry, flat, "")
		result["format"] = "flat"
		result["nodes"] = flat
	else:
		result["format"] = "tree"
		result["telemetry"] = telemetry
	return AISidebarToolResult.ok(result, "UI layout telemetrisi çıkarıldı (%d düğüm, %d uyarı)." % [int(stats["total_inspected"]), warnings.size()])

## Ağaç telemetrisini parent_path'li düz listeye çevirir (diff / sorgu için).
static func _flatten_telemetry(node: Dictionary, out: Array, parent_path: String) -> void:
	var item: Dictionary = node.duplicate()
	item.erase("children")
	item["parent_path"] = parent_path
	out.append(item)
	for ch: Dictionary in node.get("children", []):
		_flatten_telemetry(ch, out, str(node.get("path", "")))

## Standart sınır kutusu: x, y, w, h, right, bottom, cx, cy.
static func _bbox(r: Rect2) -> Dictionary:
	return {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "right": r.end.x, "bottom": r.end.y, "cx": r.position.x + r.size.x * 0.5, "cy": r.position.y + r.size.y * 0.5}

## Yerleşim otoritesi: kim bu düğümün konumunu belirliyor?
static func _layout_authority(ctrl: Control) -> String:
	if ctrl.get_parent() is Container and not ctrl.top_level: return "container"
	if ctrl.anchor_left != 0.0 or ctrl.anchor_top != 0.0 or ctrl.anchor_right != 0.0 or ctrl.anchor_bottom != 0.0: return "anchors"
	return "manual"

static func _is_interactive(ctrl: Control) -> bool:
	return ctrl is BaseButton or ctrl.has_signal("pressed") or ctrl.get_class().contains("Button") or ctrl.has_meta("touch_interactive")

## Kural öncelik etiketini ekler, P0 → P2 sıralar ve sayımı döner.
static func _prioritize(issues: Array[Dictionary]) -> Dictionary:
	var by: Dictionary = {"P0": 0, "P1": 0, "P2": 0}
	for iss: Dictionary in issues:
		var p: String = str(iss.get("priority", PRIORITY.get(str(iss.get("rule_id", "")), "P2")))
		iss["priority"] = p
		by[p] = int(by.get(p, 0)) + 1
	issues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["priority"]) < str(b["priority"]))
	return by

static func _issue(rule_id: String, severity: String, node: Node, message: String, fix: String, extra: Dictionary = {}) -> Dictionary:
	var iss: Dictionary = {"rule_id": rule_id, "severity": severity, "node_path": _get_safe_node_path(node), "node_class": node.get_class(), "message": message, "fix_action": fix}
	iss.merge(extra)
	return iss

static func _get_safe_node_path(node: Node) -> String:
	if not node: return ""
	if node.is_inside_tree(): return str(node.get_path())
	var parts: PackedStringArray = []
	var cur: Node = node
	while cur:
		parts.insert(0, str(cur.name))
		cur = cur.get_parent()
	return "/".join(parts)

static func _is_node_effectively_visible(node: Node) -> bool:
	if not node: return false
	if node is CanvasItem:
		var ci: CanvasItem = node as CanvasItem
		if ci.is_inside_tree(): return ci.is_visible_in_tree()
		var curr: Node = ci
		while curr:
			if curr is CanvasItem and not (curr as CanvasItem).visible: return false
			curr = curr.get_parent()
	return true

static func _get_edited_scene_root() -> Node:
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		if EditorInterface.has_method("get_edited_scene_root"):
			return EditorInterface.get_edited_scene_root()
	return null

static func _resolve_target_node(path_str: String, target_override: Node = null) -> Node:
	if target_override and is_instance_valid(target_override): return target_override
	var clean: String = path_str.strip_edges()
	if clean in ["@sidebar", "sidebar", "GodotAISidebar"] or clean.begins_with("@sidebar/"):
		var dock: Control = get_sidebar_dock()
		if not dock and Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_base_control"):
			var bc: Control = EditorInterface.get_base_control() as Control
			if bc: dock = bc.find_child("GodotAISidebar", true, false) as Control
		if not dock:
			var tree: SceneTree = Engine.get_main_loop() as SceneTree
			if tree and tree.root: dock = tree.root.find_child("GodotAISidebar", true, false) as Control
		if not dock: return null
		var sp: int = clean.find("/")
		if sp == -1: return dock
		var sub: String = clean.substr(sp + 1).strip_edges()
		return dock.get_node(NodePath(sub)) if dock.has_node(NodePath(sub)) else dock.find_child(sub, true, false)
	if clean in ["@edited_scene", "edited_scene", ""] or clean.begins_with("@edited_scene/"):
		var sc: Node = _get_edited_scene_root()
		if not sc and clean.is_empty():
			var tree: SceneTree = Engine.get_main_loop() as SceneTree
			if tree: sc = tree.current_scene if tree.current_scene else tree.root
		if not sc: return null
		var sp: int = clean.find("/")
		if sp == -1: return sc
		var sub: String = clean.substr(sp + 1).strip_edges()
		return sc.get_node(NodePath(sub)) if sc.has_node(NodePath(sub)) else sc.find_child(sub, true, false)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if clean.begins_with("/root/") and tree and tree.root:
		return tree.root.get_node(NodePath(clean)) if tree.root.has_node(NodePath(clean)) else tree.root.find_child(clean.replace("/root/", ""), true, false)
	var sc2: Node = _get_edited_scene_root()
	if sc2:
		if sc2.has_node(NodePath(clean)): return sc2.get_node(NodePath(clean))
		var f: Node = sc2.find_child(clean, true, false)
		if f: return f
	return null

static func _inspect_node_recursive(node: Node, cur_depth: int, max_depth: int, inc_inv: bool, inc_thm: bool, warnings: Array[Dictionary], stats: Dictionary) -> Dictionary:
	stats["total_inspected"] = int(stats.get("total_inspected", 0)) + 1
	var is_ctrl: bool = (node is Control)
	var ctrl: Control = node as Control
	var data: Dictionary = {"name": node.name, "path": _get_safe_node_path(node), "class": node.get_class(), "is_control": is_ctrl}
	data["id"] = str(node.get_meta("ui_id")) if node.has_meta("ui_id") else str(data["path"])
	var parent: Node = node.get_parent()
	if parent: data["parent_class"] = parent.get_class(); data["parent_name"] = parent.name
	if is_ctrl:
		var rect: Rect2 = ctrl.get_rect()
		data["rect"] = {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}
		data["bbox"] = _bbox(ctrl.get_global_rect() if ctrl.is_inside_tree() else rect)
		data["depth"] = cur_depth
		data["index"] = node.get_index()
		data["layout_authority"] = _layout_authority(ctrl)
		data["interactive"] = _is_interactive(ctrl)
		if not is_equal_approx(ctrl.modulate.a, 1.0): data["modulate_alpha"] = ctrl.modulate.a
		data["visible"] = ctrl.visible
		data["visible_in_tree"] = _is_node_effectively_visible(ctrl)
		if ctrl.is_inside_tree():
			var gr: Rect2 = ctrl.get_global_rect()
			data["global_rect"] = {"x": gr.position.x, "y": gr.position.y, "w": gr.size.x, "h": gr.size.y}
		data["custom_min_size"] = {"w": ctrl.custom_minimum_size.x, "h": ctrl.custom_minimum_size.y}
		var cm: Vector2 = ctrl.get_combined_minimum_size()
		data["combined_min_size"] = {"w": cm.x, "h": cm.y}
		data["size_flags_horizontal"] = ctrl.size_flags_horizontal
		data["size_flags_vertical"] = ctrl.size_flags_vertical
		data["clip_contents"] = ctrl.clip_contents
		data["mouse_filter"] = "PASS" if ctrl.mouse_filter == Control.MOUSE_FILTER_PASS else ("IGNORE" if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE else "STOP")
		data["focus_mode"] = "CLICK" if ctrl.focus_mode == Control.FOCUS_CLICK else ("ALL" if ctrl.focus_mode == Control.FOCUS_ALL else "NONE")
		data["has_focus"] = ctrl.has_focus() if ctrl.is_inside_tree() else false
		if not ctrl.theme_type_variation.is_empty(): data["theme_type_variation"] = str(ctrl.theme_type_variation)
		if inc_thm: _extract_theme_details(ctrl, data)
		var a11y: Dictionary = {}
		if "accessibility_name" in ctrl and not str(ctrl.accessibility_name).is_empty(): a11y["name"] = str(ctrl.accessibility_name)
		if "accessibility_description" in ctrl and not str(ctrl.accessibility_description).is_empty(): a11y["description"] = str(ctrl.accessibility_description)
		if not a11y.is_empty(): data["accessibility"] = a11y
		var meta: Dictionary = {}
		for k: String in ["ui_role", "ui_intent", "ui_id"]:
			if ctrl.has_meta(k): meta[k] = ctrl.get_meta(k)
		if not meta.is_empty(): data["semantic_meta"] = meta
		if ctrl is Label: _inspect_label(ctrl as Label, data, warnings)
		elif ctrl is Button: data["button_text"] = (ctrl as Button).text; data["button_flat"] = (ctrl as Button).flat
		_evaluate_layout_warnings(ctrl, warnings)
	if cur_depth < max_depth:
		var ch_list: Array = []
		for child: Node in node.get_children():
			if not (child is Control) and not (child is Node): continue
			if child is Control and not inc_inv and not _is_node_effectively_visible(child): continue
			ch_list.append(_inspect_node_recursive(child, cur_depth + 1, max_depth, inc_inv, inc_thm, warnings, stats))
		data["children"] = ch_list
	else: data["children_truncated"] = node.get_child_count() > 0
	return data

static func _extract_theme_details(ctrl: Control, data: Dictionary) -> void:
	if ctrl.has_theme_font_size("font_size"):
		var fs: int = ctrl.get_theme_font_size("font_size")
		if fs > 0: data["theme_font_size"] = fs
	if ctrl.has_theme_color("font_color"): data["theme_font_color"] = "#" + ctrl.get_theme_color("font_color").to_html()
	var sb: StyleBox = ctrl.get_theme_stylebox("panel") if ctrl.has_theme_stylebox("panel") else (ctrl.get_theme_stylebox("normal") if ctrl.has_theme_stylebox("normal") else null)
	if sb and sb is StyleBoxFlat:
		var sbf: StyleBoxFlat = sb as StyleBoxFlat
		data["theme_stylebox"] = {
			"class": "StyleBoxFlat", "bg_color": "#" + sbf.bg_color.to_html(),
			"border_width": {"left": sbf.border_width_left, "top": sbf.border_width_top, "right": sbf.border_width_right, "bottom": sbf.border_width_bottom},
			"corner_radius": {"tl": sbf.corner_radius_top_left, "tr": sbf.corner_radius_top_right, "bl": sbf.corner_radius_bottom_left, "br": sbf.corner_radius_bottom_right}
		}

static func _inspect_label(lbl: Label, data: Dictionary, warnings: Array[Dictionary]) -> void:
	data["text_length"] = lbl.text.length()
	data["overrun_behavior"] = lbl.text_overrun_behavior
	var is_clip: bool = bool(lbl.is_clipping_text()) if lbl.has_method("is_clipping_text") else false
	data["is_clipping_text"] = is_clip
	if lbl.is_inside_tree():
		var rw: float = lbl.get_combined_minimum_size().x
		var aw: float = lbl.size.x
		if is_clip or (lbl.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING and aw < rw and rw > 0):
			warnings.append({"rule_id": "UI_TEXT_CLIPPED", "node_path": _get_safe_node_path(lbl), "severity": "warning", "confidence": 0.95, "message": "Metin tahsis edilen alandan geniştir ve kırpılmaktadır."})

static func _evaluate_layout_warnings(ctrl: Control, warnings: Array[Dictionary]) -> void:
	if ctrl is Container and not (ctrl is ScrollContainer) and not (ctrl is TabContainer) and not (ctrl is SubViewportContainer):
		var cs: Vector2 = ctrl.size
		if ctrl is HBoxContainer and cs.x > 0:
			var tw: float = 0.0
			for c: Node in ctrl.get_children():
				if c is Control and (c as Control).visible: tw += (c as Control).get_combined_minimum_size().x
			if tw > cs.x:
				warnings.append({"rule_id": "UI_CONTAINER_OVERFLOW", "node_path": _get_safe_node_path(ctrl), "severity": "warning", "confidence": 0.85, "evidence": {"container_class": "HBoxContainer", "allocated_width": cs.x, "aggregate_children_min_width": tw, "overflow_amount": tw - cs.x}, "message": "HBoxContainer çocuklarının minimum genişliği (%d px) tahsis edilen genişliği (%d px) aşmaktadır." % [int(tw), int(cs.x)]})
		elif ctrl is VBoxContainer and cs.y > 0:
			var th: float = 0.0
			for c: Node in ctrl.get_children():
				if c is Control and (c as Control).visible: th += (c as Control).get_combined_minimum_size().y
			if th > cs.y:
				warnings.append({"rule_id": "UI_CONTAINER_OVERFLOW", "node_path": _get_safe_node_path(ctrl), "severity": "warning", "confidence": 0.85, "evidence": {"container_class": "VBoxContainer", "allocated_height": cs.y, "aggregate_children_min_height": th, "overflow_amount": th - cs.y}, "message": "VBoxContainer çocuklarının minimum yüksekliği (%d px) tahsis edilen yüksekliği (%d px) aşmaktadır." % [int(th), int(cs.y)]})
	if ctrl is Button and ctrl.get_child_count() > 0:
		for ch: Node in ctrl.get_children():
			if ch is Container:
				warnings.append({"rule_id": "UI_NON_CONTAINER_CHILD_MISMATCH", "node_path": _get_safe_node_path(ctrl), "severity": "warning", "confidence": 0.80, "evidence": {"parent_class": "Button", "parent_path": _get_safe_node_path(ctrl), "child_class": ch.get_class(), "child_path": _get_safe_node_path(ch)}, "message": "'%s' bir Container değildir; içindeki '%s' düzeni otomatik yönetilmez." % [ctrl.name, ch.name]})

# --- 2. AUDIT UI LAYOUT ---

static func _audit_ui_layout(args: Dictionary) -> Dictionary:
	var scene_path: String = str(args.get("scene_path", "")).strip_edges()
	var issues: Array[Dictionary] = []
	var target_node: Node = null
	var owned_instance: Node = null
	if not scene_path.is_empty():
		var packed: PackedScene = load(scene_path) as PackedScene if ResourceLoader.exists(scene_path) else null
		if not packed: return AISidebarToolResult.err("SCENE_NOT_FOUND", "UI sahnesi bulunamadı veya yüklenemedi: " + scene_path)
		_audit_scene_authority(packed.get_state(), issues)
		owned_instance = packed.instantiate()
		target_node = owned_instance
	else:
		target_node = _resolve_target_node(str(args.get("root_path", "")), args.get("target_node") as Node)
	if not target_node: return AISidebarToolResult.err("NODE_NOT_FOUND", "Hedef UI düğümü bulunamadı.")
	var stats: Dictionary = {"total_controls": 0, "containers": 0, "texts": [] as Array[Control], "interactive": [] as Array[Control], "min_text_contrast": float(args.get("min_text_contrast", AISidebarUIAuditRules.CONTRAST_NORMAL))}
	_audit_layout_recursive(target_node, 0, clampi(int(args.get("max_depth", 12)), 1, 16), bool(args.get("include_invisible", false)), issues, stats)
	AISidebarUIAuditRules.check_overlaps(stats["texts"], stats["interactive"], issues)
	var root_label: String = scene_path if owned_instance else _get_safe_node_path(target_node)
	if owned_instance: owned_instance.free()
	var by_priority: Dictionary = _prioritize(issues)
	var err_cnt: int = 0
	var wrn_cnt: int = 0
	for iss: Dictionary in issues:
		if str(iss.get("severity", "")) == "error": err_cnt += 1
		else: wrn_cnt += 1
	return AISidebarToolResult.ok({
		"schema_version": SCHEMA_VERSION, "root_path": root_label, "total_controls_audited": int(stats["total_controls"]),
		"container_count": int(stats["containers"]), "text_controls_checked": (stats["texts"] as Array).size(), "passed": (int(by_priority["P0"]) + int(by_priority["P1"]) == 0),
		"error_count": err_cnt, "warning_count": wrn_cnt, "by_priority": by_priority, "issues": issues
	}, "UI layout denetimi tamamlandı (%d kontrol; P0=%d P1=%d P2=%d)." % [int(stats["total_controls"]), int(by_priority["P0"]), int(by_priority["P1"]), int(by_priority["P2"])])

## .tscn'in kendisinden Container otorite ihlali: Container çocuğuna elle yazılmış position / offset / anchor.
## Çalışma zamanı konumuna bakılmaz (CenterContainer vb. yanlış pozitif vermez); yalnız kayıtlı özellikler.
static func _audit_scene_authority(state: SceneState, issues: Array[Dictionary]) -> void:
	var types: Dictionary = {}
	for i: int in state.get_node_count():
		types[str(state.get_node_path(i))] = _state_node_type(state, i, 0)
	for i: int in range(1, state.get_node_count()):
		var npath: String = str(state.get_node_path(i))
		var slash: int = npath.rfind("/")
		var parent_type: String = str(types.get(npath.substr(0, slash) if slash != -1 else ".", ""))
		var own_type: String = str(types.get(npath, ""))
		if parent_type.is_empty() or own_type.is_empty(): continue
		if not ClassDB.class_exists(parent_type) or not ClassDB.class_exists(own_type): continue
		if not ClassDB.is_parent_class(parent_type, "Container") or ClassDB.is_parent_class(parent_type, "SubViewportContainer"): continue
		if not ClassDB.is_parent_class(own_type, "Control"): continue
		var found: Array[String] = []
		var top_level: bool = false
		for j: int in state.get_node_property_count(i):
			var pname: String = str(state.get_node_property_name(i, j))
			if pname in AUTHORITY_PROPS: found.append(pname)
			elif pname == "layout_mode" and int(state.get_node_property_value(i, j)) != 2: found.append("layout_mode=%d" % int(state.get_node_property_value(i, j)))
			elif pname == "top_level" and bool(state.get_node_property_value(i, j)): top_level = true
		if found.is_empty() or top_level: continue
		issues.append({
			"rule_id": "CONTAINER_AUTHORITY_VIOLATION", "severity": "error", "node_path": npath.trim_prefix("./"), "node_class": own_type, "parent_class": parent_type,
			"evidence": {"saved_properties": found},
			"message": "'%s' bir %s çocuğu ama %s elle yazılmış; Container konum/boyutu kendisi belirler ve bunları ezer." % [npath.trim_prefix("./"), parent_type, ", ".join(found)],
			"fix_action": "Bu özellikleri sahneden sil; boyutu custom_minimum_size ve size_flags ile ver."
		})

static func _state_node_type(state: SceneState, idx: int, depth: int) -> String:
	var t: String = str(state.get_node_type(idx))
	if not t.is_empty() or depth > 4: return t
	var inst: PackedScene = state.get_node_instance(idx)
	return _state_node_type(inst.get_state(), 0, depth + 1) if inst else ""

static func _alpha_chain(ci: CanvasItem) -> float:
	var a: float = 1.0
	var cur: Node = ci
	while cur:
		if cur is CanvasItem: a *= (cur as CanvasItem).modulate.a
		cur = cur.get_parent()
	return a

static func _has_interactive_descendant(node: Node) -> bool:
	for ch: Node in node.get_children():
		if (ch is Control and _is_interactive(ch as Control)) or _has_interactive_descendant(ch): return true
	return false

static func _audit_layout_recursive(node: Node, cur_depth: int, max_depth: int, inc_inv: bool, issues: Array[Dictionary], stats: Dictionary) -> void:
	if not (node is Control):
		for ch: Node in node.get_children():
			if cur_depth < max_depth: _audit_layout_recursive(ch, cur_depth + 1, max_depth, inc_inv, issues, stats)
		return
	var ctrl: Control = node as Control
	if not inc_inv and not _is_node_effectively_visible(ctrl): return
	stats["total_controls"] = int(stats.get("total_controls", 0)) + 1
	if ctrl is Container: stats["containers"] = int(stats.get("containers", 0)) + 1
	var parent: Node = ctrl.get_parent()
	if parent is Container and not (parent is SubViewportContainer):
		if ctrl.top_level:
			issues.append(_issue("CONTAINER_CHILD_TOP_LEVEL", "error", ctrl, "'%s' düğümü top_level olarak ayarlanmıştır ve Container düzeninden kopmuştur." % ctrl.name, "top_level özelliğini kapatın.", {"parent_class": parent.get_class()}))
		if ctrl.anchors_preset != Control.PRESET_TOP_LEFT and ctrl.anchors_preset != 0:
			issues.append(_issue("CONTAINER_MANUAL_ANCHORS", "warning", ctrl, "'%s' düğümü Container içinde anchor preset (%d) kullanmaktadır." % [ctrl.name, ctrl.anchors_preset], "Reset anchors_preset to PRESET_TOP_LEFT.", {"parent_class": parent.get_class()}))
		if parent is BoxContainer and not (ctrl is Label or ctrl is Button or ctrl is TextureRect or ctrl is ColorRect or ctrl is Separator):
			if ctrl.size_flags_horizontal == 0 and ctrl.size_flags_vertical == 0 and ctrl.custom_minimum_size == Vector2.ZERO:
				issues.append(_issue("MISSING_SIZE_OR_EXPAND", "warning", ctrl, "'%s' kontrolü BoxContainer içinde hem min boyuta (0,0) sahip değil hem de genişleme bayrağı yok." % ctrl.name, "Set custom_minimum_size or enable SIZE_EXPAND_FILL.", {"parent_class": parent.get_class()}))
	if ctrl.is_inside_tree() and ctrl.visible and ctrl.size == Vector2.ZERO and ctrl.get_child_count() > 0 and not (ctrl is Container):
		issues.append(_issue("ZERO_SIZE_WITH_CHILDREN", "warning", ctrl, "'%s' kontrolünün boyutu (0,0) iken %d alt elemanı bulunmaktadır." % [ctrl.name, ctrl.get_child_count()], "Set custom_minimum_size or layout anchors."))
	_evaluate_layout_warnings(ctrl, issues)
	_audit_screen_rules(ctrl, cur_depth == 0, issues, stats)
	if _is_interactive(ctrl): _audit_interactive(ctrl, issues)
	elif ctrl.visible and ctrl.modulate.a <= ALPHA_EPSILON and (_alpha_chain(parent as CanvasItem) if parent is CanvasItem else 1.0) > ALPHA_EPSILON and not _has_interactive_descendant(ctrl):
		issues.append(_issue("ZERO_ALPHA_CONTENT", "warning", ctrl, "'%s' görünür ama tamamen saydam (modulate.a=0); kullanıcıya görünmez." % ctrl.name, "Intentional fade-in ise yok say; değilse modulate.a veya visible düzelt."))
	if cur_depth == NESTING_LIMIT + 1:
		issues.append(_issue("DEEP_NESTING", "warning", ctrl, "'%s' düğümü %d. düzeyde; iç içe geçme %d düzeyi aşıyor." % [ctrl.name, cur_depth, NESTING_LIMIT], "Ara Container'ları birleştir veya bölümü ayrı sahneye çıkar."))
	if ctrl.is_inside_tree() and parent is Control and not ctrl.top_level:
		var pc: Control = parent as Control
		if pc.clip_contents and not (pc is ScrollContainer) and pc.size.x > 0.0 and pc.size.y > 0.0 and ctrl.size.x > 0.0 and ctrl.size.y > 0.0:
			var pr: Rect2 = pc.get_global_rect().grow(1.0)
			var cr: Rect2 = ctrl.get_global_rect()
			if not pr.encloses(cr):
				issues.append(_issue("OUTSIDE_PARENT_RECT", "warning", ctrl, "'%s' içeriği, kırpan ebeveyni '%s' dışına taşıyor; görünmeyen kısım kesiliyor." % [ctrl.name, pc.name], "Ebeveyni büyüt, içeriği küçült veya ScrollContainer kullan.", {"evidence": {"child_bbox": _bbox(cr), "parent_bbox": _bbox(pc.get_global_rect())}}))
	if cur_depth < max_depth:
		for ch: Node in ctrl.get_children():
			_audit_layout_recursive(ch, cur_depth + 1, max_depth, inc_inv, issues, stats)

## Ekrana bakan kurallar (ui_audit_rules.gd): görünüm dışı, metin kontrastı; çakışma için metin / düğme listesi toplar.
static func _audit_screen_rules(ctrl: Control, is_root: bool, issues: Array[Dictionary], stats: Dictionary) -> void:
	if not ctrl.is_inside_tree() or not ctrl.is_visible_in_tree(): return
	AISidebarUIAuditRules.check_outside_viewport(ctrl, is_root, issues)
	AISidebarUIAuditRules.check_text_contrast(ctrl, float(stats.get("min_text_contrast", AISidebarUIAuditRules.CONTRAST_NORMAL)), issues)
	if stats.has("texts") and AISidebarUIAuditRules.is_text_control(ctrl) and not _is_interactive(ctrl):
		(stats["texts"] as Array).append(ctrl)
	if stats.has("interactive") and _is_interactive(ctrl):
		(stats["interactive"] as Array).append(ctrl)

## Etkileşimli düğümün gerçekten tıklanabilir olup olmadığı (P0 kuralları).
static func _audit_interactive(ctrl: Control, issues: Array[Dictionary]) -> void:
	if ctrl is BaseButton and (ctrl as BaseButton).disabled: return
	if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		issues.append(_issue("INTERACTIVE_INPUT_IGNORED", "error", ctrl, "'%s' etkileşimli ama mouse_filter=IGNORE; fare/dokunma olayı almaz." % ctrl.name, "mouse_filter değerini STOP yap."))
	if _alpha_chain(ctrl) <= ALPHA_EPSILON:
		issues.append(_issue("INTERACTIVE_ZERO_ALPHA", "error", ctrl, "'%s' tıklanabilir ama zincirdeki modulate.a ≈ 0; kullanıcı görmeden tıklar (hayalet düğme)." % ctrl.name, "modulate.a değerini düzelt veya visible=false yap."))
	var pc: Control = ctrl.get_parent() as Control
	if ctrl.is_inside_tree() and pc != null and pc.size.x > 0.0 and pc.size.y > 0.0 and (ctrl.size.x <= 0.0 or ctrl.size.y <= 0.0):
		issues.append(_issue("INTERACTIVE_ZERO_SIZE", "error", ctrl, "'%s' etkileşimli ama boyutu %dx%d; tıklanacak alanı yok (yerleşim tamamlandıktan sonra ölçülür)." % [ctrl.name, int(ctrl.size.x), int(ctrl.size.y)], "custom_minimum_size ver veya size_flags ile genişlet."))

# --- 3. AUDIT UI TOUCH ---

static func _audit_ui_touch(args: Dictionary) -> Dictionary:
	var target_node: Node = _resolve_target_node(str(args.get("root_path", "")), args.get("target_node") as Node)
	if not target_node: return AISidebarToolResult.err("NODE_NOT_FOUND", "Hedef UI düğümü bulunamadı.")
	var platform: String = AISidebarUIAuditRules.resolve_platform(args)
	if platform.is_empty(): return AISidebarToolResult.err("INVALID_ARGUMENT", "Bilinmeyen platform: '%s' (desktop | mobile)." % str(args.get("platform", "")))
	var limits: Dictionary = AISidebarUIAuditRules.touch_limits(args, platform)
	var min_size: float = float(limits["min_touch_size"])
	var min_spacing: float = float(limits["min_spacing"])
	var interactive: Array[Control] = []
	var containers: Array[Control] = []
	_collect_touch_candidates(target_node, bool(args.get("include_invisible", false)), interactive, containers)
	var issues: Array[Dictionary] = []
	for c: Control in interactive:
		var ew: float = maxf(c.size.x, c.custom_minimum_size.x)
		var eh: float = maxf(c.size.y, c.custom_minimum_size.y)
		if ew < min_size or eh < min_size:
			issues.append({"rule_id": "TOUCH_TARGET_TOO_SMALL", "severity": "error", "node_path": _get_safe_node_path(c), "node_class": c.get_class(), "message": "Dokunmatik buton '%s' boyutu (%.0fx%.0f px) asgari %.0fx%.0f px'in altındadır." % [c.name, ew, eh, min_size, min_size], "fix_action": "Increase custom_minimum_size."})
	for i: int in range(interactive.size()):
		var c1: Control = interactive[i]
		if not c1.is_inside_tree(): continue
		var r1: Rect2 = c1.get_global_rect()
		for j: int in range(i + 1, interactive.size()):
			var c2: Control = interactive[j]
			if not c2.is_inside_tree(): continue
			var dist: float = _rect_distance(r1, c2.get_global_rect())
			if dist >= 0.0 and dist < min_spacing:
				issues.append({"rule_id": "TOUCH_BUTTONS_TOO_CLOSE", "severity": "warning", "node_path": _get_safe_node_path(c1), "message": "Dokunmatik butonlar ('%s' ve '%s') birbirine çok yakındır (%.1f px < %.1f px)." % [c1.name, c2.name, dist, min_spacing]})
	for cont: Control in containers:
		if cont.mouse_filter == Control.MOUSE_FILTER_STOP and not (cont is ScrollContainer) and cont.is_inside_tree():
			var cr: Rect2 = cont.get_global_rect()
			for b: Control in interactive:
				if not b.is_inside_tree() or cont.is_ancestor_of(b) or b.is_ancestor_of(cont): continue
				if not _draws_above(cont, b): continue
				var br: Rect2 = b.get_global_rect()
				if cr.intersects(br):
					issues.append({"rule_id": "POTENTIAL_OVERLAY_BLOCKER", "severity": "error", "node_path": _get_safe_node_path(cont), "message": "Kapsayıcı/Panel '%s' (STOP filtresi) buton '%s' üzerinde çizilir ve ona biner; buton tıklanamaz." % [cont.name, b.name], "fix_action": "Paneli butonun altına al (sıra) veya mouse_filter=IGNORE yap."})
					break
	var by_priority: Dictionary = _prioritize(issues)
	var score: int = clampi(100 - (issues.size() * 15), 0, 100)
	return AISidebarToolResult.ok({"schema_version": SCHEMA_VERSION, "root_path": _get_safe_node_path(target_node), "platform": platform, "min_touch_size": min_size, "min_spacing": min_spacing, "interactive_controls_count": interactive.size(), "touch_score": score, "passed": (int(by_priority["P0"]) + int(by_priority["P1"]) == 0), "issue_count": issues.size(), "by_priority": by_priority, "issues": issues}, "Dokunmatik denetim tamamlandı: Skor %d/100 (%d sorun)." % [score, issues.size()])

## a, b'den SONRA çizilir mi (ağaç sırası + z_index)? Biri diğerinin atasıysa false.
static func _draws_above(a: Control, b: Control) -> bool:
	if a.z_index != b.z_index: return a.z_index > b.z_index
	var chain_a: Array[Node] = _ancestor_chain(a)
	var chain_b: Array[Node] = _ancestor_chain(b)
	var i: int = 0
	while i < chain_a.size() and i < chain_b.size() and chain_a[i] == chain_b[i]: i += 1
	if i >= chain_a.size() or i >= chain_b.size(): return false
	return chain_a[i].get_index() > chain_b[i].get_index()

static func _ancestor_chain(node: Node) -> Array[Node]:
	var chain: Array[Node] = []
	var cur: Node = node
	while cur:
		chain.push_front(cur)
		cur = cur.get_parent()
	return chain

static func _collect_touch_candidates(node: Node, inc_inv: bool, interactive: Array[Control], containers: Array[Control]) -> void:
	if not (node is Control):
		for ch: Node in node.get_children(): _collect_touch_candidates(ch, inc_inv, interactive, containers)
		return
	var ctrl: Control = node as Control
	if not inc_inv and not _is_node_effectively_visible(ctrl): return
	if _is_interactive(ctrl):
		interactive.append(ctrl)
	elif ctrl is Container or ctrl is Panel or ctrl is PanelContainer or ctrl is TextureRect or ctrl is ColorRect:
		containers.append(ctrl)
	for ch: Node in ctrl.get_children(): _collect_touch_candidates(ch, inc_inv, interactive, containers)

static func _rect_distance(r1: Rect2, r2: Rect2) -> float:
	if r1.intersects(r2): return 0.0
	var dx: float = maxf(0.0, maxf(r1.position.x - r2.end.x, r2.position.x - r1.end.x))
	var dy: float = maxf(0.0, maxf(r1.position.y - r2.end.y, r2.position.y - r1.end.y))
	return Vector2(dx, dy).length()

# --- 4. SCAFFOLD UI THEME ---

static func _scaffold_ui_theme(args: Dictionary) -> Dictionary:
	var raw_p: String = str(args.get("theme_path", "res://ui/theme.tres")).strip_edges()
	var pchk: Dictionary = AISidebarPathPolicy.is_safe_to_write(raw_p)
	if not pchk["safe"]: return AISidebarToolResult.err("PERMISSION_DENIED", str(pchk["reason"]))
	var tp: String = str(pchk["path"])
	var tokens: Dictionary = AISidebarUIThemeScaffold.resolve_tokens(args)
	var report: Dictionary = AISidebarUIThemeScaffold.contrast_report(tokens)
	var theme: Theme = AISidebarUIThemeScaffold.build_theme(tokens)
	var dp: String = tp.get_base_dir()
	if not DirAccess.dir_exists_absolute(dp): DirAccess.make_dir_recursive_absolute(dp)
	var err: Error = ResourceSaver.save(theme, tp)
	if err != OK: return AISidebarToolResult.err("SAVE_FAILED", "Theme kaydedilemedi (hata: %d): %s" % [err, tp])
	var tmap: Dictionary = args.get("token_map", {}) as Dictionary if args.get("token_map") is Dictionary else {}
	var tokens_json: Dictionary = AISidebarUIThemeScaffold.tokens_to_json(tokens, tmap)
	var tokens_path: String = ""
	if bool(args.get("write_tokens", true)):
		var cand: String = str(args.get("tokens_path", "")).strip_edges()
		if cand.is_empty(): cand = tp.get_basename() + ".tokens.json"
		var tchk: Dictionary = AISidebarPathPolicy.is_safe_to_write(cand)
		if tchk["safe"]:
			var tf: FileAccess = FileAccess.open(str(tchk["path"]), FileAccess.WRITE)
			if tf:
				tf.store_string(JSON.stringify(tokens_json, "  "))
				tf.close()
				tokens_path = str(tchk["path"])
	return AISidebarToolResult.ok({
		"theme_path": tp, "tokens_path": tokens_path, "preset": tokens["preset"], "default_font_size": int(tokens["font_size"]["body"]),
		"styled_classes": AISidebarUIThemeScaffold.styled_classes(), "type_variations": AISidebarUIThemeScaffold.VARIATIONS,
		"tokens": tokens_json, "contrast": report, "contrast_passed": report["passed"]
	}, "Theme şablonu oluşturuldu: %s (%d kontrast uyarısı)." % [tp, (report["warnings"] as Array).size()])

# --- 4b. SENARYO / GİZLİ PANELLER (audit_ui_layout / audit_ui_touch `states`, `scenario_path`) ---

## Durum listesini (ya da senaryo dosyasını) sırayla uygular; her durumda ilgili sync denetimi çalıştırır, durumu geri alır.
## Senaryo "scene" içeriyorsa o sahne ayrı bir SubViewport'ta örneklenir; yoksa root_path / düzenlenen sahne kullanılır
## (editörde açık sahnede "call" kapalıdır: geri alınamaz).
static func _audit_with_states(tool_name: String, args: Dictionary) -> Dictionary:
	var cfg: Dictionary = args.duplicate()
	var scenario_path: String = str(args.get("scenario_path", "")).strip_edges()
	if not scenario_path.is_empty():
		var loaded: Dictionary = AISidebarUIAuditScenario.load_scenario(scenario_path)
		if not bool(loaded["ok"]): return AISidebarToolResult.err("SCENARIO_NOT_FOUND", str(loaded["error"]))
		var sc: Dictionary = loaded["scenario"]
		for k: String in ["states", "platform", "scene", "viewport", "root_path", "min_touch_size", "min_spacing", "min_text_contrast"]:
			if sc.has(k) and not cfg.has(k): cfg[k] = sc[k]
	var states: Array[Dictionary] = AISidebarUIAuditScenario.normalize_states(cfg.get("states", []))
	if states.is_empty(): return AISidebarToolResult.err("INVALID_ARGUMENT", "states boş: en az bir durum ver ({name, show, hide, set, call, audit}).")
	var holder: Node = null
	var root: Node = null
	var allow_calls: bool = not Engine.is_editor_hint()
	var scene_ref: String = str(cfg.get("scene", "")).strip_edges()
	if not scene_ref.is_empty():
		var mounted: Dictionary = AISidebarUIAuditScenario.mount_scene(scene_ref, AISidebarUIAuditScenario.viewport_size(cfg.get("viewport")))
		if mounted.has("error"): return AISidebarToolResult.err("SCENE_NOT_FOUND", str(mounted["error"]))
		holder = mounted["holder"]
		root = mounted["root"]
		allow_calls = true
	else:
		root = _resolve_target_node(str(cfg.get("root_path", "")), cfg.get("target_node") as Node)
	if root == null: return AISidebarToolResult.err("NODE_NOT_FOUND", "Hedef UI düğümü bulunamadı.")
	var base: Dictionary = cfg.duplicate()
	for k: String in ["states", "scenario_path", "scene", "viewport", "root_path", "target_node"]: base.erase(k)
	var audit: Callable = func(node: Node) -> Dictionary:
		var a: Dictionary = base.duplicate()
		a["target_node"] = node
		return execute(tool_name, a)
	var result: Dictionary = await AISidebarUIAuditScenario.run(root, states, audit, allow_calls)
	if holder != null: holder.queue_free()
	var by_p: Dictionary = result["by_priority"]
	return AISidebarToolResult.ok({
		"schema_version": SCHEMA_VERSION, "tool": tool_name, "platform": AISidebarUIAuditRules.resolve_platform(cfg),
		"state_count": states.size(), "passed": bool(result["passed"]), "by_priority": by_p, "states": result["states"],
		"state_errors": result["state_errors"], "issues": result["issues"]
	}, "Senaryo denetimi: %d durum, P0=%d P1=%d P2=%d, %d durum hatası." % [states.size(), int(by_p["P0"]), int(by_p["P1"]), int(by_p["P2"]), (result["state_errors"] as Array).size()])

# --- 5. CAPTURE UI PREVIEW ---

static func _capture_ui_preview(args: Dictionary) -> Dictionary:
	var prep: Dictionary = _preview_begin(args)
	if prep.has("error"): return prep["error"]
	return _preview_finish(prep["ctx"], args, false)

## Container yerleşimi bir sonraki karede oturur; bu yol iki kare bekleyip çizer (ajan yolu bunu kullanır).
static func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name == "audit_ui_layout" or tool_name == "audit_ui_touch":
		if args.has("states") or args.has("scenario_path"): return await _audit_with_states(tool_name, args)
		return execute(tool_name, args)
	if tool_name != "capture_ui_preview": return execute(tool_name, args)
	var prep: Dictionary = _preview_begin(args)
	if prep.has("error"): return prep["error"]
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var settled: bool = false
	if tree and prep["ctx"]["attached_root"]:
		await tree.process_frame
		await tree.process_frame
		settled = true
	return _preview_finish(prep["ctx"], args, settled)

## Önizleme sahnesini kurar. Hata: {"error": sonuç}; başarı: {"ctx": {...}}.
static func _preview_begin(args: Dictionary) -> Dictionary:
	var sc_path: String = str(args.get("scene_path", "")).strip_edges()
	var prof: String = str(args.get("profile", "mobile_portrait")).to_lower()
	var vp_size: Vector2i = Vector2i(720, 1280)
	match prof:
		"mobile_portrait": vp_size = Vector2i(720, 1280)
		"mobile_landscape": vp_size = Vector2i(1280, 720)
		"tablet": vp_size = Vector2i(1024, 768)
		"desktop": vp_size = Vector2i(1920, 1080)
		"square": vp_size = Vector2i(1080, 1080)
		"custom": vp_size = Vector2i(maxi(int(args.get("width", 720)), 64), maxi(int(args.get("height", 1280)), 64))
	if int(vp_size.x) * int(vp_size.y) > (4096 * 4096):
		return {"error": AISidebarToolResult.err("PREVIEW_TOO_LARGE", "İstenen önizleme çözünürlüğü (%dx%d) azami piksel sınırını (4096x4096) aşmaktadır." % [vp_size.x, vp_size.y])}
	var spath: String = str(args.get("save_path", "")).strip_edges()
	if spath.is_empty(): spath = "user://ui_snapshots/preview_%s_%dx%d.png" % [prof, vp_size.x, vp_size.y]
	var pchk: Dictionary = AISidebarPathPolicy.is_safe_to_write(spath)
	if not pchk["safe"]: return {"error": AISidebarToolResult.err("PERMISSION_DENIED", str(pchk["reason"]))}
	var norm_p: String = str(pchk["path"])
	var ui_inst: Node = null
	var is_inst: bool = false
	if not sc_path.is_empty():
		if not ResourceLoader.exists(sc_path): return {"error": AISidebarToolResult.err("SCENE_NOT_FOUND", "UI sahnesi bulunamadı: " + sc_path)}
		var sc_res: PackedScene = load(sc_path) as PackedScene
		if not sc_res: return {"error": AISidebarToolResult.err("LOAD_FAILED", "UI sahnesi yüklenemedi: " + sc_path)}
		ui_inst = sc_res.instantiate(); is_inst = true
	else:
		ui_inst = _resolve_target_node(str(args.get("root_path", "")), args.get("target_node") as Node)
		if not ui_inst: return {"error": AISidebarToolResult.err("NODE_NOT_FOUND", "Önizleme yapılacak UI kök düğümü bulunamadı.")}
	var vp: SubViewport = SubViewport.new()
	vp.size = vp_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var attached_root: Node = null
	if tree and tree.root:
		attached_root = tree.root
		attached_root.add_child(vp)
	var render_node: Node = ui_inst if is_inst else ui_inst.duplicate()
	vp.add_child(render_node)
	if render_node is Control:
		var c: Control = render_node as Control
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return {"ctx": {"vp": vp, "render_node": render_node, "attached_root": attached_root, "vp_size": vp_size, "prof": prof, "norm_p": norm_p}}

## Yerleşim oturduktan sonra (async yolda iki kare beklenir) telemetriyi toplar, çizer ve kaydeder.
static func _preview_finish(ctx: Dictionary, args: Dictionary, layout_settled: bool) -> Dictionary:
	var vp: SubViewport = ctx["vp"]
	var render_node: Node = ctx["render_node"]
	var attached_root: Node = ctx["attached_root"]
	var vp_size: Vector2i = ctx["vp_size"]
	var prof: String = ctx["prof"]
	var norm_p: String = ctx["norm_p"]
	var telemetry: Dictionary = {}
	if bool(args.get("include_telemetry", true)):
		telemetry = _preview_telemetry(render_node, vp_size)
	if bool(args.get("draw_bounds", false)):
		_add_bounds_overlay(vp, render_node)
	if bool(args.get("simulate_safe_area", true)) and prof in ["mobile_portrait", "mobile_landscape"]:
		_add_safe_area_guides(vp, vp_size, prof)
	if RenderingServer.has_method("force_draw"):
		RenderingServer.force_draw(false)
	var tex: ViewportTexture = vp.get_texture()
	var img: Image = tex.get_image() if tex else null
	if not img or img.is_empty():
		vp.remove_child(render_node)
		render_node.free()
		if attached_root: attached_root.remove_child(vp)
		vp.free()
		return AISidebarToolResult.err("RENDER_FAILED", "Viewport görüntüsü render edilemedi (Headless veya renderer desteği olmayan ortam). UI önizlemesi için aktif bir grafik renderer gereklidir.")
	var dp: String = norm_p.get_base_dir()
	if not DirAccess.dir_exists_absolute(dp): DirAccess.make_dir_recursive_absolute(dp)
	var err: Error = img.save_png(norm_p)
	vp.remove_child(render_node)
	render_node.free()
	if attached_root:
		attached_root.remove_child(vp)
	vp.free()
	if err != OK: return AISidebarToolResult.err("SAVE_FAILED", "Ekran görüntüsü kaydedilemedi: " + norm_p)
	var b64: String = Marshalls.raw_to_base64(img.save_png_to_buffer())
	var out: Dictionary = {"preview_path": norm_p, "profile": prof, "width": vp_size.x, "height": vp_size.y, "aspect_ratio": "%.2f" % (float(vp_size.x) / float(vp_size.y)), "image_base64": b64}
	out["layout_settled"] = layout_settled
	if not telemetry.is_empty(): out["telemetry"] = telemetry
	return AISidebarToolResult.ok(out, "UI önizleme görüntüsü alındı (%s, %dx%d): %s" % [prof, vp_size.x, vp_size.y, norm_p])

## Önizlemenin sayısal karşılığı: görünüm alanına göre bbox listesi, taşanlar ve öncelikli denetim özeti.
static func _preview_telemetry(root: Node, vp_size: Vector2i) -> Dictionary:
	var nodes: Array[Dictionary] = []
	var overflow: Array[Dictionary] = []
	var vp_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(vp_size))
	_collect_preview_nodes(root, root, vp_rect, nodes, overflow)
	var issues: Array[Dictionary] = []
	_audit_layout_recursive(root, 0, 12, false, issues, {})
	var by_priority: Dictionary = _prioritize(issues)
	return {
		"schema_version": SCHEMA_VERSION, "coordinate_space": "viewport-global", "viewport": _bbox(vp_rect),
		"node_count": nodes.size(), "nodes_truncated": nodes.size() >= MAX_FLAT_NODES, "nodes": nodes,
		"overflow_viewport": overflow, "by_priority": by_priority, "passed": int(by_priority["P0"]) + int(by_priority["P1"]) == 0,
		"issues": issues.slice(0, 50)
	}

static func _collect_preview_nodes(node: Node, root: Node, vp_rect: Rect2, nodes: Array[Dictionary], overflow: Array[Dictionary]) -> void:
	if nodes.size() >= MAX_FLAT_NODES: return
	if node is Control:
		var ctrl: Control = node as Control
		if _is_node_effectively_visible(ctrl):
			var gr: Rect2 = ctrl.get_global_rect()
			var rel: String = "." if node == root else str(root.get_path_to(node))
			nodes.append({"path": rel, "class": ctrl.get_class(), "depth": _ancestor_chain(node).size() - _ancestor_chain(root).size(), "layout_authority": _layout_authority(ctrl), "interactive": _is_interactive(ctrl), "bbox": _bbox(gr)})
			if not vp_rect.grow(1.0).encloses(gr) and gr.size.x > 0.0 and gr.size.y > 0.0:
				overflow.append({"path": rel, "bbox": _bbox(gr), "overflow": {"left": maxf(0.0, vp_rect.position.x - gr.position.x), "top": maxf(0.0, vp_rect.position.y - gr.position.y), "right": maxf(0.0, gr.end.x - vp_rect.end.x), "bottom": maxf(0.0, gr.end.y - vp_rect.end.y)}})
	for ch: Node in node.get_children():
		_collect_preview_nodes(ch, root, vp_rect, nodes, overflow)

## Her kontrolün sınırını renkli çerçeveyle çizer: yeşil=Container, mavi=anchor, turuncu=elle, eflatun=etkileşimli.
static func _add_bounds_overlay(vp: SubViewport, root: Node) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	vp.add_child(layer)
	_add_bounds_for(root, layer)

static func _add_bounds_for(node: Node, layer: CanvasLayer) -> void:
	if node is Control and _is_node_effectively_visible(node):
		var ctrl: Control = node as Control
		var gr: Rect2 = ctrl.get_global_rect()
		if gr.size.x > 0.0 and gr.size.y > 0.0:
			var color: Color = Color(0.2, 0.85, 0.35)
			match _layout_authority(ctrl):
				"anchors": color = Color(0.25, 0.55, 1.0)
				"manual": color = Color(1.0, 0.6, 0.1)
			if _is_interactive(ctrl): color = Color(0.95, 0.2, 0.85)
			var box: StyleBoxFlat = StyleBoxFlat.new()
			box.draw_center = false
			box.set_border_width_all(1)
			box.border_color = color
			var p: Panel = Panel.new()
			p.add_theme_stylebox_override("panel", box)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.position = gr.position
			p.size = gr.size
			layer.add_child(p)
	for ch: Node in node.get_children():
		_add_bounds_for(ch, layer)

static func _add_safe_area_guides(vp: SubViewport, size: Vector2i, prof: String) -> void:
	var gl: CanvasLayer = CanvasLayer.new()
	vp.add_child(gl)
	var nh: float = 44.0 if prof == "mobile_portrait" else 0.0
	var hh: float = 34.0 if prof == "mobile_portrait" else 21.0
	if nh > 0.0:
		var top_notch: ColorRect = ColorRect.new()
		top_notch.color = Color(1.0, 0.2, 0.2, 0.25)
		top_notch.size = Vector2(float(size.x), nh)
		gl.add_child(top_notch)
	if hh > 0.0:
		var b_bar: ColorRect = ColorRect.new()
		b_bar.color = Color(0.2, 0.8, 1.0, 0.25)
		b_bar.position = Vector2(0.0, float(size.y) - hh)
		b_bar.size = Vector2(float(size.x), hh)
		gl.add_child(b_bar)
