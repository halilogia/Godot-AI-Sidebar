@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarUITelemetryTools

## AI-Native UI Yerleşim ve Düzen Telemetrisi Aracı (SRP).
## Tamamen salt-okunurdur (read-only). Godot 4.7 Control ve Container ağacını tarayarak
## geometri, minimum boyutlar, A11y, tema varyasyonları ve kanıta dayalı layout uyarıları üretir.

static func get_schemas() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "inspect_ui_layout",
				"description": "Belirtilen UI düğümünün veya sahne ağacının hiyerarşik yerleşim telemetrisini (geometri, bounding box, minimum boyutlar, görünürlük, kırpılma, tema varyasyonu, A11y ve semantik roller) ve kanıta dayalı layout uyarılarını döner. Tamamen salt okunurdur (read-only).",
				"parameters": {
					"type": "object",
					"properties": {
						"root_path": {
							"type": "string",
							"description": "Taranacak kök düğüm yolu (örn: '/root/GodotAISidebar' veya sahne içindeki bir Control yolu). Boş bırakılırsa aktif sahne veya editör kökü taranır."
						},
						"max_depth": {
							"type": "integer",
							"description": "Taranacak maksimum hiyerarşi derinliği (varsayılan: 4, maksimum: 8)."
						},
						"include_invisible": {
							"type": "boolean",
							"description": "Görünmez (visible == false) düğümlerin dahil edilip edilmeyeceği (varsayılan: false)."
						},
						"include_theme_details": {
							"type": "boolean",
							"description": "Detaylı StyleBox, font ve renk bilgilerinin dahil edilip edilmeyeceği (varsayılan: false)."
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
		return AISidebarToolResult.err(
			"NODE_NOT_FOUND",
			"Belirtilen UI kök düğümü bulunamadı veya açık bir sahne yok: '" + root_path + "'"
		)
		
	var warnings: Array[Dictionary] = []
	var stats = {"total_inspected": 0}
	var telemetry = _inspect_node_recursive(target_node, 0, max_depth, include_invisible, include_theme_details, warnings, stats)
	
	return AISidebarToolResult.ok({
		"root_path": _get_safe_node_path(target_node),
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

static func _resolve_target_node(path_str: String, target_override: Node = null) -> Node:
	if target_override:
		return target_override
		
	# 1. Aktif editör sahnesi
	if Engine.is_editor_hint():
		var ei = _get_editor_interface()
		if ei and ei.has_method("get_edited_scene_root"):
			var sc_root = ei.get_edited_scene_root()
			if sc_root:
				if path_str.is_empty():
					return sc_root
				if sc_root.has_node(NodePath(path_str)):
					return sc_root.get_node(NodePath(path_str))
				var found = sc_root.find_child(path_str, true, false)
				if found:
					return found

	# 2. SceneTree aktif sahnesi veya kökü
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		if tree.current_scene:
			if path_str.is_empty():
				return tree.current_scene
			if tree.current_scene.has_node(NodePath(path_str)):
				return tree.current_scene.get_node(NodePath(path_str))
			var found = tree.current_scene.find_child(path_str, true, false)
			if found:
				return found
				
		if tree.root:
			if path_str.is_empty():
				return tree.root
			if tree.root.has_node(NodePath(path_str)):
				return tree.root.get_node(NodePath(path_str))
			var found = tree.root.find_child(path_str, true, false)
			if found:
				return found
				
	return null

static func _get_editor_interface() -> Object:
	if ClassDB.class_exists("EditorInterface"):
		return Engine.get_singleton("EditorInterface")
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
		
		if ctrl.is_inside_tree():
			var g_rect = ctrl.get_global_rect()
			data["global_rect"] = {"x": g_rect.position.x, "y": g_rect.position.y, "w": g_rect.size.x, "h": g_rect.size.y}
			data["visible_in_tree"] = ctrl.is_visible_in_tree()
		else:
			data["visible_in_tree"] = ctrl.visible
			
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
		
		# 4. Tema Varyasyonu (ThemeTypeVariation)
		if not ctrl.theme_type_variation.is_empty():
			data["theme_type_variation"] = str(ctrl.theme_type_variation)
			
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
		
	# Çocukları Tara
	if current_depth < max_depth:
		var children_list: Array = []
		for child in node.get_children():
			if not (child is Control) and not (child is Node):
				continue
			if child is Control and not include_invisible and not (child as Control).visible:
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
	var parent = ctrl.get_parent()
	
	# Kural 1: Container Overflow (ScrollContainer ve TabContainer hariç)
	if parent is Container and not (parent is ScrollContainer) and not (parent is TabContainer):
		var p_size = (parent as Container).size
		var child_min = ctrl.get_combined_minimum_size()
		if p_size.x > 0 and child_min.x > p_size.x:
			warnings.append({
				"rule_id": "UI_CONTAINER_OVERFLOW",
				"node_path": _get_safe_node_path(ctrl),
				"severity": "warning",
				"confidence": 0.85,
				"evidence": {
					"parent_class": parent.get_class(),
					"parent_width": p_size.x,
					"child_min_width": child_min.x
				},
				"message": "Bileşenin minimum genişliği parent Container boyutunu aşmaktadır."
			})
			
	# Kural 2: Container Olmayan Kontrol İçine Container Ekleme (Örn: Button.add_child(VBoxContainer))
	if ctrl is Button and ctrl.get_child_count() > 0:
		for child in ctrl.get_children():
			if child is Container:
				warnings.append({
					"rule_id": "UI_NON_CONTAINER_CHILD_MISMATCH",
					"node_path": _get_safe_node_path(ctrl),
					"severity": "warning",
					"confidence": 0.90,
					"evidence": {
						"parent_class": "Button",
						"child_class": child.get_class(),
						"child_path": _get_safe_node_path(child)
					},
					"message": "Button bir Container değildir; içerisine eklenen Container çocukları otomatik boyutlandıramaz."
				})
