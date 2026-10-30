@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarUITelemetryTools

## AI-Native UI Yerleşim, Düzen ve Dokunmatik Telemetrisi Aracı (SRP).
## Godot 4.7 Control ağacını tarayarak Container vs Koordinat çakışmaları,
## dokunmatik hedef ergonomisi, Theme üretimi ve SubViewport önizleme sağlar.

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
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
				"description": "Returns layout telemetry for a UI node or scene tree (geometry, bounding boxes, min sizes, visibility, theme, A11y, semantic roles) with layout warnings. Read-only.",
				"parameters": {
					"type": "object",
					"properties": {
						"root_path": {"type": "string", "description": "Root node path ('@sidebar', '@edited_scene', '/root/...', or empty)."},
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
				"description": "Audits Control & Container hierarchy for layout antipatterns: Container vs Coordinate conflict (manual position/anchors inside Container), zero-size controls, missing expand flags, and deep nesting. Read-only.",
				"parameters": {
					"type": "object",
					"properties": {
						"root_path": {"type": "string", "description": "Root node path to audit ('@edited_scene', '@sidebar', or empty)."},
						"max_depth": {"type": "integer", "description": "Max depth (default: 8)."},
						"include_invisible": {"type": "boolean", "description": "Audit invisible controls (default: false)."}
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "audit_ui_touch",
				"description": "Audits mobile touch ergonomics: buttons smaller than 44x44px, clickable controls closer than 8px, and overlay containers blocking input with MOUSE_FILTER_STOP. Read-only.",
				"parameters": {
					"type": "object",
					"properties": {
						"root_path": {"type": "string", "description": "Root node path ('@edited_scene', '@sidebar', or empty)."},
						"min_touch_size": {"type": "number", "description": "Min touch target size in pixels (default: 44.0)."},
						"min_spacing": {"type": "number", "description": "Min spacing between clickable buttons in pixels (default: 8.0)."},
						"include_invisible": {"type": "boolean", "description": "Audit invisible controls (default: false)."}
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "scaffold_ui_theme",
				"description": "Generates a cohesive Godot 4 Theme (.tres) resource with StyleBoxFlat tokens for Button (states), Panel, LineEdit, ProgressBar, Label and typography for mobile/desktop UI.",
				"parameters": {
					"type": "object",
					"properties": {
						"theme_path": {"type": "string", "description": "Target path (default: 'res://ui/theme.tres')."},
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
				"description": "Renders an offscreen SubViewport preview of a UI scene across mobile portrait, mobile landscape, tablet, desktop resolutions and saves preview PNG for visual analysis. Read-only.",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": {"type": "string", "description": "Path to UI scene (e.g. 'res://scenes/ui/hud.tscn'). Empty uses active scene root."},
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
	return AISidebarToolResult.ok({
		"root_path": _get_safe_node_path(target_node),
		"target_identifier": root_path if not root_path.is_empty() else "@edited_scene",
		"total_nodes_inspected": int(stats["total_inspected"]),
		"telemetry": telemetry,
		"warnings": warnings,
		"warning_count": warnings.size()
	}, "UI layout telemetrisi çıkarıldı (%d düğüm, %d uyarı)." % [int(stats["total_inspected"]), warnings.size()])

static func _get_safe_node_path(node: Node) -> String:
	if not node: return ""
	return str(node.get_path()) if node.is_inside_tree() else str(node.name)

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
	var parent: Node = node.get_parent()
	if parent: data["parent_class"] = parent.get_class(); data["parent_name"] = parent.name
	if is_ctrl:
		var rect: Rect2 = ctrl.get_rect()
		data["rect"] = {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}
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
	var target_node: Node = _resolve_target_node(str(args.get("root_path", "")), args.get("target_node") as Node)
	if not target_node: return AISidebarToolResult.err("NODE_NOT_FOUND", "Hedef UI düğümü bulunamadı.")
	var issues: Array[Dictionary] = []
	var stats: Dictionary = {"total_controls": 0, "containers": 0}
	_audit_layout_recursive(target_node, 0, clampi(int(args.get("max_depth", 8)), 1, 16), bool(args.get("include_invisible", false)), issues, stats)
	var err_cnt: int = 0
	var wrn_cnt: int = 0
	for iss: Dictionary in issues:
		if str(iss.get("severity", "")) == "error": err_cnt += 1
		else: wrn_cnt += 1
	return AISidebarToolResult.ok({
		"root_path": _get_safe_node_path(target_node), "total_controls_audited": int(stats["total_controls"]),
		"container_count": int(stats["containers"]), "passed": (err_cnt == 0),
		"error_count": err_cnt, "warning_count": wrn_cnt, "issues": issues
	}, "UI layout denetimi tamamlandı (%d kontrol, %d hata, %d uyarı)." % [int(stats["total_controls"]), err_cnt, wrn_cnt])

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
			issues.append({"rule_id": "CONTAINER_CHILD_TOP_LEVEL", "severity": "error", "node_path": _get_safe_node_path(ctrl), "node_class": ctrl.get_class(), "parent_class": parent.get_class(), "message": "'%s' düğümü top_level olarak ayarlanmıştır ve Container düzeninden kopmuştur." % ctrl.name, "fix_action": "top_level özelliğini kapatın."})
		if ctrl.get_index() == 0 and not (parent is MarginContainer) and ctrl.position != Vector2.ZERO:
			issues.append({"rule_id": "CONTAINER_MANUAL_POSITION", "severity": "error", "node_path": _get_safe_node_path(ctrl), "node_class": ctrl.get_class(), "parent_class": parent.get_class(), "message": "'%s' düğümü Container'ın ilk elemanıdır ancak konumu (0,0) değildir. Container çocukları otomatik konumlandırılır; elle koordinat vermek düzeni bozar." % ctrl.name, "fix_action": "Container içindeki elemanlara elle position vermeyin; hizalama için size_flags veya MarginContainer kullanın."})
		if ctrl.anchors_preset != Control.PRESET_TOP_LEFT and ctrl.anchors_preset != 0:
			issues.append({"rule_id": "CONTAINER_MANUAL_ANCHORS", "severity": "warning", "node_path": _get_safe_node_path(ctrl), "node_class": ctrl.get_class(), "parent_class": parent.get_class(), "message": "'%s' düğümü Container içinde anchor preset (%d) kullanmaktadır." % [ctrl.name, ctrl.anchors_preset], "fix_action": "Reset anchors_preset to PRESET_TOP_LEFT."})
		if parent is BoxContainer and not (ctrl is Label or ctrl is Button or ctrl is TextureRect or ctrl is ColorRect or ctrl is Separator):
			if ctrl.size_flags_horizontal == 0 and ctrl.size_flags_vertical == 0 and ctrl.custom_minimum_size == Vector2.ZERO:
				issues.append({"rule_id": "MISSING_SIZE_OR_EXPAND", "severity": "warning", "node_path": _get_safe_node_path(ctrl), "node_class": ctrl.get_class(), "parent_class": parent.get_class(), "message": "'%s' kontrolü BoxContainer içinde hem min boyuta (0,0) sahip değil hem de genişleme bayrağı yok." % ctrl.name, "fix_action": "Set custom_minimum_size or enable SIZE_EXPAND_FILL."})
	if ctrl.visible and ctrl.size == Vector2.ZERO and ctrl.get_child_count() > 0 and not (ctrl is Container):
		issues.append({"rule_id": "ZERO_SIZE_WITH_CHILDREN", "severity": "warning", "node_path": _get_safe_node_path(ctrl), "node_class": ctrl.get_class(), "message": "'%s' kontrolünün boyutu (0,0) iken %d alt elemanı bulunmaktadır." % [ctrl.name, ctrl.get_child_count()], "fix_action": "Set custom_minimum_size or layout anchors."})
	if cur_depth < max_depth:
		for ch: Node in ctrl.get_children():
			_audit_layout_recursive(ch, cur_depth + 1, max_depth, inc_inv, issues, stats)

# --- 3. AUDIT UI TOUCH ---

static func _audit_ui_touch(args: Dictionary) -> Dictionary:
	var target_node: Node = _resolve_target_node(str(args.get("root_path", "")), args.get("target_node") as Node)
	if not target_node: return AISidebarToolResult.err("NODE_NOT_FOUND", "Hedef UI düğümü bulunamadı.")
	var min_size: float = float(args.get("min_touch_size", 44.0))
	var min_spacing: float = float(args.get("min_spacing", 8.0))
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
			if not c2.is_inside_tree() or c1.get_parent() != c2.get_parent(): continue
			var dist: float = _rect_distance(r1, c2.get_global_rect())
			if dist >= 0.0 and dist < min_spacing:
				issues.append({"rule_id": "TOUCH_BUTTONS_TOO_CLOSE", "severity": "warning", "node_path": _get_safe_node_path(c1), "message": "Dokunmatik butonlar ('%s' ve '%s') birbirine çok yakındır (%.1f px < %.1f px)." % [c1.name, c2.name, dist, min_spacing]})
	for cont: Control in containers:
		if cont.mouse_filter == Control.MOUSE_FILTER_STOP and not (cont is ScrollContainer) and cont.is_inside_tree():
			var cr: Rect2 = cont.get_global_rect()
			for b: Control in interactive:
				if not b.is_inside_tree() or cont.is_ancestor_of(b) or b.is_ancestor_of(cont): continue
				var br: Rect2 = b.get_global_rect()
				if cr.intersects(br) and (cont.get_index() > b.get_index() or cont.z_index > b.z_index):
					issues.append({"rule_id": "OVERLAY_INPUT_BLOCKER", "severity": "warning", "node_path": _get_safe_node_path(cont), "message": "Kapsayıcı/Panel '%s' (STOP filtresi) buton '%s' üzerine biniyor ve tıklamaları bloke edebilir." % [cont.name, b.name]})
					break
	var score: int = clampi(100 - (issues.size() * 15), 0, 100)
	return AISidebarToolResult.ok({"root_path": _get_safe_node_path(target_node), "interactive_controls_count": interactive.size(), "touch_score": score, "passed": (issues.size() == 0), "issue_count": issues.size(), "issues": issues}, "Dokunmatik denetim tamamlandı: Skor %d/100 (%d sorun)." % [score, issues.size()])

static func _collect_touch_candidates(node: Node, inc_inv: bool, interactive: Array[Control], containers: Array[Control]) -> void:
	if not (node is Control):
		for ch: Node in node.get_children(): _collect_touch_candidates(ch, inc_inv, interactive, containers)
		return
	var ctrl: Control = node as Control
	if not inc_inv and not _is_node_effectively_visible(ctrl): return
	if ctrl is BaseButton or ctrl.has_signal("pressed") or ctrl.get_class().contains("Button") or ctrl.has_meta("touch_interactive"):
		interactive.append(ctrl)
	elif ctrl is Container or ctrl is Panel or ctrl is PanelContainer or ctrl is TextureRect or ctrl is ColorRect:
		containers.append(ctrl)
	for ch: Node in ctrl.get_children(): _collect_touch_candidates(ch, inc_inv, interactive, containers)

static func _rect_distance(r1: Rect2, r2: Rect2) -> float:
	var l: bool = r2.end.x < r1.position.x; var r: bool = r1.end.x < r2.position.x
	var b: bool = r2.end.y < r1.position.y; var t: bool = r1.end.y < r2.position.y
	if t and l: return r1.position.distance_to(Vector2(r2.end.x, r2.position.y))
	if l and b: return Vector2(r1.position.x, r1.end.y).distance_to(r2.end)
	if b and r: return r1.end.distance_to(Vector2(r2.position.x, r2.end.y))
	if r and t: return Vector2(r1.end.x, r1.position.y).distance_to(r2.position)
	if l: return r1.position.x - r2.end.x
	if r: return r2.position.x - r1.end.x
	if b: return r2.position.y - r1.end.y
	if t: return r1.position.y - r2.end.y
	return 0.0

# --- 4. SCAFFOLD UI THEME ---

static func _scaffold_ui_theme(args: Dictionary) -> Dictionary:
	var raw_p: String = str(args.get("theme_path", "res://ui/theme.tres")).strip_edges()
	var pchk: Dictionary = AISidebarPathPolicy.is_safe_to_write(raw_p)
	if not pchk["safe"]: return AISidebarToolResult.err("PERMISSION_DENIED", str(pchk["reason"]))
	var tp: String = str(pchk["path"])
	var pri: Color = Color.from_string(str(args.get("primary_color", "#4f46e5")), Color(0.31, 0.27, 0.90))
	var bg: Color = Color.from_string(str(args.get("background_color", "#0f172a")), Color(0.06, 0.09, 0.16))
	var surf: Color = Color.from_string(str(args.get("surface_color", "#1e293b")), Color(0.12, 0.16, 0.23))
	var surf_h: Color = Color.from_string(str(args.get("surface_hover_color", "#334155")), Color(0.20, 0.25, 0.33))
	var txt: Color = Color.from_string(str(args.get("text_color", "#f8fafc")), Color(0.97, 0.98, 0.99))
	var txt_m: Color = Color.from_string(str(args.get("text_muted_color", "#94a3b8")), Color(0.58, 0.64, 0.72))
	var rad: int = clampi(int(args.get("corner_radius", 8)), 0, 32)
	var fs_body: int = clampi(int(args.get("font_size_body", 16)), 8, 72)
	var theme: Theme = Theme.new()
	theme.default_font_size = fs_body
	var make_flat: Callable = func(bg_c: Color, b_c: Color, bw: int, r: int, mh: int = 14, mv: int = 10) -> StyleBoxFlat:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = bg_c
		if bw > 0: sb.set_border_width_all(bw); sb.border_color = b_c
		if r > 0: sb.set_corner_radius_all(r)
		sb.content_margin_left = float(mh); sb.content_margin_right = float(mh); sb.content_margin_top = float(mv); sb.content_margin_bottom = float(mv)
		return sb
	theme.set_stylebox("normal", "Button", make_flat.call(surf, pri * Color(1, 1, 1, 0.4), 1, rad))
	theme.set_stylebox("hover", "Button", make_flat.call(surf_h, pri, 1, rad))
	theme.set_stylebox("pressed", "Button", make_flat.call(pri, Color.WHITE, 2, rad))
	theme.set_stylebox("focus", "Button", make_flat.call(surf, pri, 2, rad))
	theme.set_stylebox("disabled", "Button", make_flat.call(bg * Color(1, 1, 1, 0.6), txt_m * Color(1, 1, 1, 0.2), 1, rad))
	theme.set_color("font_color", "Button", txt)
	theme.set_color("font_disabled_color", "Button", txt_m)
	theme.set_font_size("font_size", "Button", fs_body)
	var pnl: StyleBoxFlat = make_flat.call(surf, surf_h, 1, rad, 12, 12)
	pnl.shadow_size = 4; pnl.shadow_color = Color(0, 0, 0, 0.35)
	theme.set_stylebox("panel", "Panel", pnl)
	theme.set_stylebox("panel", "PanelContainer", pnl)
	theme.set_stylebox("normal", "LineEdit", make_flat.call(bg, surf_h, 1, rad, 10, 8))
	theme.set_stylebox("focus", "LineEdit", make_flat.call(bg, pri, 2, rad, 10, 8))
	theme.set_color("font_color", "LineEdit", txt)
	theme.set_stylebox("background", "ProgressBar", make_flat.call(bg, Color.TRANSPARENT, 0, clampi(rad / 2, 2, 8), 0, 0))
	theme.set_stylebox("fill", "ProgressBar", make_flat.call(pri, Color.TRANSPARENT, 0, clampi(rad / 2, 2, 8), 0, 0))
	theme.set_color("font_color", "Label", txt)
	theme.set_font_size("font_size", "Label", fs_body)
	var dp: String = tp.get_base_dir()
	if not DirAccess.dir_exists_absolute(dp): DirAccess.make_dir_recursive_absolute(dp)
	var err: Error = ResourceSaver.save(theme, tp)
	if err != OK: return AISidebarToolResult.err("SAVE_FAILED", "Theme kaydedilemedi (hata: %d): %s" % [err, tp])
	return AISidebarToolResult.ok({"theme_path": tp, "default_font_size": fs_body, "styled_classes": ["Button", "Panel", "PanelContainer", "LineEdit", "ProgressBar", "Label"]}, "Theme şablonu oluşturuldu: " + tp)

# --- 5. CAPTURE UI PREVIEW ---

static func _capture_ui_preview(args: Dictionary) -> Dictionary:
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
	var spath: String = str(args.get("save_path", "")).strip_edges()
	if spath.is_empty(): spath = "user://ui_snapshots/preview_%s_%dx%d.png" % [prof, vp_size.x, vp_size.y]
	var pchk: Dictionary = AISidebarPathPolicy.is_safe_to_write(spath)
	if not pchk["safe"]: return AISidebarToolResult.err("PERMISSION_DENIED", str(pchk["reason"]))
	var norm_p: String = str(pchk["path"])
	var ui_inst: Node = null
	var is_inst: bool = false
	if not sc_path.is_empty():
		if not ResourceLoader.exists(sc_path): return AISidebarToolResult.err("SCENE_NOT_FOUND", "UI sahnesi bulunamadı: " + sc_path)
		var sc_res: PackedScene = load(sc_path) as PackedScene
		if not sc_res: return AISidebarToolResult.err("LOAD_FAILED", "UI sahnesi yüklenemedi: " + sc_path)
		ui_inst = sc_res.instantiate(); is_inst = true
	else:
		ui_inst = _resolve_target_node(str(args.get("root_path", "")), args.get("target_node") as Node)
		if not ui_inst: return AISidebarToolResult.err("NODE_NOT_FOUND", "Önizleme yapılacak UI kök düğümü bulunamadı.")
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
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.size = Vector2(vp_size)
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
	return AISidebarToolResult.ok({"preview_path": norm_p, "profile": prof, "width": vp_size.x, "height": vp_size.y, "aspect_ratio": "%.2f" % (float(vp_size.x) / float(vp_size.y)), "image_base64": b64}, "UI önizleme görüntüsü alındı (%s, %dx%d): %s" % [prof, vp_size.x, vp_size.y, norm_p])

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
