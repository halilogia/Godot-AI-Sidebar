@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarUITelemetryTools

## AI-Native UI Yerleşim ve Düzen Telemetrisi Aracı (SRP).
## Tamamen salt-okunurdur (read-only). Godot 4.7 Control ve Container ağacını tarayarak
## geometri, minimum boyutlar, A11y, tema özellikleri ve kanıta dayalı layout uyarıları üretir.

static var _registered_sidebar_dock: Control = null

static func register_sidebar_dock(dock: Control) -> void:
	_registered_sidebar_dock = dock

static func get_sidebar_dock() -> Control:
	if is_instance_valid(_registered_sidebar_dock):
		return _registered_sidebar_dock
	return null

static func get_schemas() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "inspect_ui_layout",
				"description": "Belirtilen UI düğümünün veya sahne ağacının hiyerarşik yerleşim telemetrisini (geometri, bounding box, minimum boyutlar, görünürlük, kırpılma, tema, A11y ve semantik roller) ve kanıta dayalı layout uyarılarını döner. Tamamen salt okunurdur (read-only).",
				"parameters": {
					"type": "object",
					"properties": {
						"root_path": {
							"type": "string",
							"description": "Taranacak kök düğüm yolu (örn: '@sidebar', '@sidebar/HistoryPanel', '@edited_scene', '/root/...', veya sahne içi düğüm adı). Boş veya '@edited_scene' ise açık oyun sahnesi kökü taranır; '@sidebar' ise eklentinin kendi arayüzü taranır."
						},
						"max_depth": {
							"type": "integer",
							"description": "Taranacak maksimum hiyerarşi derinliği (varsayılan: 4, maksimum: 8)."
						},
						"include_invisible": {
							"type": "boolean",
							"description": "Görünmez (is_visible_in_tree == false) düğümlerin dahil edilip edilmeyeceği (varsayılan: false)."
						},
						"include_theme_details": {
							"type": "boolean",
							"description": "Detaylı StyleBox (arka plan, border, radius), font boyutu ve renk bilgilerinin dahil edilip edilmeyeceği (varsayılan: false)."
						}
					}
				}
			}
		}
	]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name == "inspect_ui_layout":
		return _inspect_ui_layout(args)
	return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen UI telemetri aracı: " + tool_name)

static func _inspect_ui_layout(args: Dictionary) -> Dictionary:
	var target_override = args.get("target_node") as Node
	var root_path = str(args.get("root_path", "")).strip_edges()
	var max_depth = clampi(int(args.get("max_depth", 4)), 1, 8)
	var include_invisible = bool(args.get("include_invisible", false))
	var include_theme_details = bool(args.get("include_theme_details", false))
	
	var target_node = _resolve_target_node(root_path, target_override)
	if not target_node:
		var err_msg = "Belirtilen UI kök düğümü bulunamadı veya açık bir sahne/dock yok: '" + root_path + "'"
		var err_code = "NODE_NOT_FOUND"
		if root_path == "@edited_scene" or root_path.begins_with("@edited_scene/"):
			err_code = "EDITOR_SCENE_REQUIRED"
			err_msg = "Editörde açık bir sahne kökü bulunamadı (@edited_scene). Lütfen önce bir sahne açın."
		elif root_path == "@sidebar" or root_path.begins_with("@sidebar/"):
			err_code = "SIDEBAR_NOT_INITIALIZED"
			err_msg = "Aktif bir Godot AI Sidebar dock örneği bulunamadı (@sidebar)."
		return AISidebarToolResult.err(err_code, err_msg)
		
	var warnings: Array[Dictionary] = []
	var stats = {"total_inspected": 0}
	var telemetry = _inspect_node_recursive(target_node, 0, max_depth, include_invisible, include_theme_details, warnings, stats)
	
	return AISidebarToolResult.ok({
		"root_path": _get_safe_node_path(target_node),
		"target_identifier": root_path if not root_path.is_empty() else "@edited_scene",
		"total_nodes_inspected": stats["total_inspected"],
		"telemetry": telemetry,
		"warnings": warnings,
		"warning_count": warnings.size()
	}, "UI layout telemetrisi başarıyla çıkarıldı (%d düğüm, %d uyarı)." % [stats["total_inspected"], warnings.size()])

static func _get_safe_node_path(node: Node) -> String:
	if not node:
		return ""
	if node.is_inside_tree():
		return str(node.get_path())
	return str(node.name)

static func _is_node_effectively_visible(node: Node) -> bool:
	if not node:
		return false
	if node is CanvasItem:
		var ci = node as CanvasItem
		if ci.is_inside_tree():
			return ci.is_visible_in_tree()
		var curr: Node = ci
		while curr:
			if curr is CanvasItem and not (curr as CanvasItem).visible:
				return false
			curr = curr.get_parent()
		return true
	return true

static func _get_edited_scene_root() -> Node:
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		if EditorInterface.has_method("get_edited_scene_root"):
			return EditorInterface.get_edited_scene_root()
	return null

static func _resolve_target_node(path_str: String, target_override: Node = null) -> Node:
	if target_override and is_instance_valid(target_override):
		return target_override
		
	var clean_path = path_str.strip_edges()
	
	# 1. Semantik Hedef: Godot AI Sidebar Dock (@sidebar)
	var is_sidebar_target = (
		clean_path == "@sidebar" or 
		clean_path == "sidebar" or 
		clean_path == "GodotAISidebar" or 
		clean_path.begins_with("@sidebar/") or 
		clean_path.begins_with("sidebar/") or
		clean_path.begins_with("GodotAISidebar/")
	)
	if is_sidebar_target:
		var dock = get_sidebar_dock()
		if not dock and Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
			if EditorInterface.has_method("get_base_control"):
				var base_ctrl = EditorInterface.get_base_control()
				if base_ctrl:
					dock = base_ctrl.find_child("GodotAISidebar", true, false)
		if not dock:
			var tree = Engine.get_main_loop() as SceneTree
			if tree and tree.root:
				dock = tree.root.find_child("GodotAISidebar", true, false)
		if not dock:
			return null
			
		var slash_pos = clean_path.find("/")
		if slash_pos == -1:
			return dock
		var subpath = clean_path.substr(slash_pos + 1).strip_edges()
		if subpath.is_empty():
			return dock
		if dock.has_node(NodePath(subpath)):
			return dock.get_node(NodePath(subpath))
		var sub_found = dock.find_child(subpath, true, false)
		return sub_found

	# 2. Semantik Hedef: Kullanıcının Açık Oyun Sahnesi (@edited_scene veya boş string)
	var is_edited_target = (
		clean_path == "@edited_scene" or 
		clean_path == "edited_scene" or 
		clean_path.is_empty() or 
		clean_path.begins_with("@edited_scene/") or
		clean_path.begins_with("edited_scene/")
	)
	if is_edited_target:
		var sc_root = _get_edited_scene_root()
		if not sc_root and clean_path.is_empty():
			var tree = Engine.get_main_loop() as SceneTree
			if tree:
				if tree.current_scene:
					sc_root = tree.current_scene
				elif tree.root:
					sc_root = tree.root
		if not sc_root:
			return null
			
		var slash_pos = clean_path.find("/")
		if slash_pos == -1:
			return sc_root
		var subpath = clean_path.substr(slash_pos + 1).strip_edges()
		if subpath.is_empty():
			return sc_root
		if sc_root.has_node(NodePath(subpath)):
			return sc_root.get_node(NodePath(subpath))
		var sub_found = sc_root.find_child(subpath, true, false)
		return sub_found

	# 3. Mutlak SceneTree Yolu (/root/...)
	if clean_path.begins_with("/root/"):
		var tree = Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			if tree.root.has_node(NodePath(clean_path)):
				return tree.root.get_node(NodePath(clean_path))
			return tree.root.find_child(clean_path.replace("/root/", ""), true, false)

	# 4. Göreceli Düğüm Yolu veya Adı (Önce Edited Scene, sonra Sidebar, sonra SceneTree)
	var sc = _get_edited_scene_root()
	if sc:
		if sc.has_node(NodePath(clean_path)):
			return sc.get_node(NodePath(clean_path))
		var found = sc.find_child(clean_path, true, false)
		if found:
			return found
			
	var sb = get_sidebar_dock()
	if sb:
		if sb.has_node(NodePath(clean_path)):
			return sb.get_node(NodePath(clean_path))
		var found = sb.find_child(clean_path, true, false)
		if found:
			return found

	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		if tree.current_scene:
			if tree.current_scene.has_node(NodePath(clean_path)):
				return tree.current_scene.get_node(NodePath(clean_path))
			var found = tree.current_scene.find_child(clean_path, true, false)
			if found:
				return found
		if tree.root:
			if tree.root.has_node(NodePath(clean_path)):
				return tree.root.get_node(NodePath(clean_path))
			var found = tree.root.find_child(clean_path, true, false)
			if found:
				return found

	return null

static func _inspect_node_recursive(
	node: Node,
	current_depth: int,
	max_depth: int,
	include_invisible: bool,
	include_theme_details: bool,
	warnings: Array[Dictionary],
	stats: Dictionary
) -> Dictionary:
	stats["total_inspected"] = stats.get("total_inspected", 0) + 1
	
	var is_ctrl = (node is Control)
	var ctrl = node as Control
	
	var data: Dictionary = {
		"name": node.name,
		"path": _get_safe_node_path(node),
		"class": node.get_class(),
		"is_control": is_ctrl
	}
	
	var parent = node.get_parent()
	if parent:
		data["parent_class"] = parent.get_class()
		data["parent_name"] = parent.name
	
	if is_ctrl:
		# 1. Geometri & Koordinatlar
		var rect = ctrl.get_rect()
		data["rect"] = {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}
		
		var is_vis_in_tree = _is_node_effectively_visible(ctrl)
		data["visible"] = ctrl.visible
		data["visible_in_tree"] = is_vis_in_tree
		
		if ctrl.is_inside_tree():
			var g_rect = ctrl.get_global_rect()
			data["global_rect"] = {"x": g_rect.position.x, "y": g_rect.position.y, "w": g_rect.size.x, "h": g_rect.size.y}
			
		data["custom_min_size"] = {"w": ctrl.custom_minimum_size.x, "h": ctrl.custom_minimum_size.y}
		var comb_min = ctrl.get_combined_minimum_size()
		data["combined_min_size"] = {"w": comb_min.x, "h": comb_min.y}
		
		# 2. Yerleşim Politikası & Size Flags
		data["size_flags_horizontal"] = ctrl.size_flags_horizontal
		data["size_flags_vertical"] = ctrl.size_flags_vertical
		data["stretch_ratio"] = ctrl.size_flags_stretch_ratio
		data["clip_contents"] = ctrl.clip_contents
		
		# 3. Etkileşim & Odak
		var mf = "STOP"
		match ctrl.mouse_filter:
			Control.MOUSE_FILTER_PASS: mf = "PASS"
			Control.MOUSE_FILTER_IGNORE: mf = "IGNORE"
		data["mouse_filter"] = mf
		
		var fm = "NONE"
		match ctrl.focus_mode:
			Control.FOCUS_CLICK: fm = "CLICK"
			Control.FOCUS_ALL: fm = "ALL"
		data["focus_mode"] = fm
		data["has_focus"] = ctrl.has_focus() if ctrl.is_inside_tree() else false
		
		# 4. Tema ve Stil Detayları
		if not ctrl.theme_type_variation.is_empty():
			data["theme_type_variation"] = str(ctrl.theme_type_variation)
			
		if include_theme_details:
			_extract_theme_details(ctrl, data)
			
		# 5. Erişilebilirlik (Godot 4.7 A11y Özellikleri)
		var a11y: Dictionary = {}
		if "accessibility_name" in ctrl and not str(ctrl.accessibility_name).is_empty():
			a11y["name"] = str(ctrl.accessibility_name)
		if "accessibility_description" in ctrl and not str(ctrl.accessibility_description).is_empty():
			a11y["description"] = str(ctrl.accessibility_description)
		if "accessibility_live" in ctrl and int(ctrl.accessibility_live) != 0:
			a11y["live"] = int(ctrl.accessibility_live)
		if not a11y.is_empty():
			data["accessibility"] = a11y
			
		# 6. Semantik Metadata
		var meta: Dictionary = {}
		for k in ["ui_role", "ui_intent", "ui_id"]:
			if ctrl.has_meta(k):
				meta[k] = ctrl.get_meta(k)
		if not meta.is_empty():
			data["semantic_meta"] = meta
			
		# 7. Label ve Metin Detayları
		if ctrl is Label:
			_inspect_label(ctrl as Label, data, warnings)
		elif ctrl is Button:
			data["button_text"] = (ctrl as Button).text
			data["button_flat"] = (ctrl as Button).flat
			
		# 8. Kanıta Dayalı Heuristik Uyarılar
		_evaluate_layout_warnings(ctrl, warnings)
		
	# Çocukları Tara (include_invisible false ise _is_node_effectively_visible filtresi uygulanır)
	if current_depth < max_depth:
		var children_list: Array = []
		for child in node.get_children():
			if not (child is Control) and not (child is Node):
				continue
			if child is Control and not include_invisible:
				if not _is_node_effectively_visible(child):
					continue
			var child_data = _inspect_node_recursive(
				child,
				current_depth + 1,
				max_depth,
				include_invisible,
				include_theme_details,
				warnings,
				stats
			)
			children_list.append(child_data)
		data["children"] = children_list
	else:
		data["children_truncated"] = node.get_child_count() > 0
		
	return data

static func _extract_theme_details(ctrl: Control, data: Dictionary) -> void:
	if ctrl.has_theme_font_size("font_size"):
		var fs = ctrl.get_theme_font_size("font_size")
		if fs > 0:
			data["theme_font_size"] = fs
			
	if ctrl.has_theme_color("font_color"):
		data["theme_font_color"] = "#" + ctrl.get_theme_color("font_color").to_html()
		
	var sb: StyleBox = null
	if ctrl.has_theme_stylebox("panel"):
		sb = ctrl.get_theme_stylebox("panel")
	elif ctrl.has_theme_stylebox("normal"):
		sb = ctrl.get_theme_stylebox("normal")
		
	if sb:
		var sb_data = {"class": sb.get_class()}
		if sb is StyleBoxFlat:
			var sbf = sb as StyleBoxFlat
			sb_data["bg_color"] = "#" + sbf.bg_color.to_html()
			sb_data["border_width"] = {
				"left": sbf.border_width_left,
				"top": sbf.border_width_top,
				"right": sbf.border_width_right,
				"bottom": sbf.border_width_bottom
			}
			sb_data["corner_radius"] = {
				"tl": sbf.corner_radius_top_left,
				"tr": sbf.corner_radius_top_right,
				"bl": sbf.corner_radius_bottom_left,
				"br": sbf.corner_radius_bottom_right
			}
			if sbf.shadow_size > 0:
				sb_data["shadow_size"] = sbf.shadow_size
		data["theme_stylebox"] = sb_data

static func _inspect_label(lbl: Label, data: Dictionary, warnings: Array[Dictionary]) -> void:
	data["text_length"] = lbl.text.length()
	data["overrun_behavior"] = lbl.text_overrun_behavior
	
	var is_clipping = false
	if lbl.has_method("is_clipping_text"):
		is_clipping = lbl.is_clipping_text()
	data["is_clipping_text"] = is_clipping
	
	if lbl.is_inside_tree():
		var req_width = lbl.get_combined_minimum_size().x
		var alloc_width = lbl.size.x
		if is_clipping or (lbl.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING and alloc_width < req_width and req_width > 0):
			warnings.append({
				"rule_id": "UI_TEXT_CLIPPED",
				"node_path": _get_safe_node_path(lbl),
				"severity": "warning",
				"confidence": 0.95,
				"evidence": {
					"allocated_width": alloc_width,
					"required_width": req_width,
					"clipping": is_clipping,
					"overrun_behavior": lbl.text_overrun_behavior
				},
				"message": "Metin tahsis edilen alandan daha geniştir ve kırpılmaktadır."
			})

static func _evaluate_layout_warnings(ctrl: Control, warnings: Array[Dictionary]) -> void:
	# Kural 1: Container Overflow (HBox, VBox aggregate toplam kontrolü ve diğer non-scroll container'lar)
	if ctrl is Container and not (ctrl is ScrollContainer) and not (ctrl is TabContainer) and not (ctrl is SubViewportContainer):
		var c_size = ctrl.size
		if ctrl is HBoxContainer and c_size.x > 0:
			var total_min_w: float = 0.0
			for c in ctrl.get_children():
				if c is Control and (c as Control).visible:
					total_min_w += (c as Control).get_combined_minimum_size().x
			if total_min_w > c_size.x:
				warnings.append({
					"rule_id": "UI_CONTAINER_OVERFLOW",
					"node_path": _get_safe_node_path(ctrl),
					"severity": "warning",
					"confidence": 0.85,
					"evidence": {
						"container_class": "HBoxContainer",
						"allocated_width": c_size.x,
						"aggregate_children_min_width": total_min_w,
						"overflow_amount": total_min_w - c_size.x
					},
					"message": "HBoxContainer çocuklarının toplam minimum genişliği (%d px) tahsis edilen genişliği (%d px) aşmaktadır." % [int(total_min_w), int(c_size.x)]
				})
		elif ctrl is VBoxContainer and c_size.y > 0:
			var total_min_h: float = 0.0
			for c in ctrl.get_children():
				if c is Control and (c as Control).visible:
					total_min_h += (c as Control).get_combined_minimum_size().y
			if total_min_h > c_size.y:
				warnings.append({
					"rule_id": "UI_CONTAINER_OVERFLOW",
					"node_path": _get_safe_node_path(ctrl),
					"severity": "warning",
					"confidence": 0.85,
					"evidence": {
						"container_class": "VBoxContainer",
						"allocated_height": c_size.y,
						"aggregate_children_min_height": total_min_h,
						"overflow_amount": total_min_h - c_size.y
					},
					"message": "VBoxContainer çocuklarının toplam minimum yüksekliği (%d px) tahsis edilen yüksekliği (%d px) aşmaktadır." % [int(total_min_h), int(c_size.y)]
				})
		elif not (ctrl is BoxContainer) and c_size.x > 0:
			for c in ctrl.get_children():
				if c is Control and (c as Control).visible:
					var c_min = (c as Control).get_combined_minimum_size()
					if c_min.x > c_size.x:
						warnings.append({
							"rule_id": "UI_CONTAINER_OVERFLOW",
							"node_path": _get_safe_node_path(c),
							"severity": "warning",
							"confidence": 0.80,
							"evidence": {
								"container_class": ctrl.get_class(),
								"allocated_width": c_size.x,
								"child_min_width": c_min.x,
								"overflow_amount": c_min.x - c_size.x
							},
							"message": "Çocuğun minimum genişliği (%d px) parent %s alanını (%d px) aşmaktadır." % [int(c_min.x), ctrl.get_class(), int(c_size.x)]
						})
			
	# Kural 2: Container Olmayan Kontrol İçine Container Ekleme (Örn: Button.add_child(VBoxContainer))
	if ctrl is Button and ctrl.get_child_count() > 0:
		for child in ctrl.get_children():
			if child is Container:
				warnings.append({
					"rule_id": "UI_NON_CONTAINER_CHILD_MISMATCH",
					"node_path": _get_safe_node_path(ctrl),
					"severity": "warning",
					"confidence": 0.80,
					"evidence": {
						"parent_class": "Button",
						"parent_path": _get_safe_node_path(ctrl),
						"child_class": child.get_class(),
						"child_path": _get_safe_node_path(child)
					},
					"message": "'%s' bir Container değildir; içerisindeki '%s' çocuğunun boyutu ve yerleşimi ebeveyn tarafından otomatik yönetilmeyecektir." % [ctrl.name, child.name]
				})
