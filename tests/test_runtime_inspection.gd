@tool
extends RefCounted

const AISidebarRuntimeBridge = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_bridge.gd")
const AISidebarDebuggerPlugin = preload("res://addons/godot_sidebar_ai/core/runtime/debugger_plugin.gd")
const AISidebarEditorTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/editor_tools.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# Setup mock scene hierarchy
	var root = Node2D.new()
	root.name = "World"
	
	var player = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(100.5, 200.75)
	root.add_child(player)
	
	var col = CollisionShape2D.new()
	col.name = "CollisionShape2D"
	player.add_child(col)
	
	var camera = Camera2D.new()
	camera.name = "MainCamera"
	root.add_child(camera)

	# Test 1: Hiyerarşik Ağaç Serileştirme (Tree Serialization)
	var tree_data = AISidebarRuntimeBridge.serialize_tree(root, 3)
	if tree_data.get("name") == "World" and tree_data.get("type") == "Node2D" and tree_data.get("children", []).size() == 2:
		var p_node = tree_data["children"][0]
		if p_node.get("name") == "Player" and p_node.get("children", []).size() == 1:
			passed += 1
		else:
			failed += 1
			errors.append("Çocuk düğüm hiyerarşisi hatalı: " + str(p_node))
	else:
		failed += 1
		errors.append("Kök hiyerarşi serileştirme hatası: " + str(tree_data))

	# Test 2: Derinlik Limiti Kontrolü (Max Depth)
	var shallow_tree = AISidebarRuntimeBridge.serialize_tree(root, 1)
	var shallow_player = shallow_tree.get("children", [])[0]
	if not shallow_player.has("children"):
		passed += 1
	else:
		failed += 1
		errors.append("Maksimum derinlik limiti uygulanmadı: " + str(shallow_player))

	# Test 3: Güvenli Düğüm Whitelist Özellikleri (Node Property Serialization)
	var node_data = AISidebarRuntimeBridge.serialize_node(player)
	if node_data.get("name") == "Player" and node_data.get("type") == "CharacterBody2D":
		var pos = node_data.get("position", {})
		if pos.get("x") == 100.5 and pos.get("y") == 200.75 and node_data.has("visible") and node_data.has("process_mode"):
			passed += 1
		else:
			failed += 1
			errors.append("Düğüm pozisyon/özellik whitelist serileştirmesi hatalı: " + str(node_data))
	else:
		failed += 1
		errors.append("Düğüm temel veri serileştirme hatası: " + str(node_data))

	# Mock düğümleri temizle
	root.free()

	# Test 4: Oyun Çalışmıyorken Fail-Fast Hata Dönüşü (inspect_runtime_tree)
	var tree_res = AISidebarEditorTools.execute("inspect_runtime_tree", {})
	if not tree_res.get("success", true) and tree_res.get("error", {}).get("code") == "GAME_NOT_RUNNING":
		passed += 1
	else:
		failed += 1
		errors.append("Oyun kapalıyken beklenen GAME_NOT_RUNNING hatası alınamadı: " + str(tree_res))

	# Test 5: Oyun Çalışmıyorken Fail-Fast Hata Dönüşü (inspect_runtime_node)
	var node_res = AISidebarEditorTools.execute("inspect_runtime_node", {"node_path": "root/Player"})
	if not node_res.get("success", true) and node_res.get("error", {}).get("code") == "GAME_NOT_RUNNING":
		passed += 1
	else:
		failed += 1
		errors.append("Oyun kapalıyken beklenen GAME_NOT_RUNNING hatası alınamadı: " + str(node_res))

	# Test 6: Eksik Parametre Denetimi (MISSING_ARGUMENT)
	var miss_res = AISidebarEditorTools.execute("inspect_runtime_node", {})
	if not miss_res.get("success", true) and miss_res.get("error", {}).get("code") == "MISSING_ARGUMENT":
		passed += 1
	else:
		failed += 1
		errors.append("Eksik node_path argümanı yakalanamadı: " + str(miss_res))

	# Test 7: Debugger Plugin Sınıf Tanımı ve Eklenti Entegrasyonu
	if ClassDB.class_exists("EditorDebuggerPlugin"):
		if ClassDB.can_instantiate("EditorDebuggerPlugin"):
			var dbg = AISidebarDebuggerPlugin.new()
			if dbg._has_capture("godot_ai") and not dbg._has_capture("other_channel"):
				var captured_payload: Array = []
				dbg.response_received.connect(func(_req_id: String, payload: Dictionary):
					captured_payload.append(payload)
				)
				var handled = dbg._capture("godot_ai:response", ["test_req", {"success": true, "tree": {"name": "Simulated"}}], 0)
				if handled and captured_payload.size() == 1 and captured_payload[0].get("success") == true:
					passed += 1
				else:
					failed += 1
					errors.append("Debugger capture yanıt dağıtımı başarısız: " + str(captured_payload))
			else:
				failed += 1
				errors.append("Debugger _has_capture kontrolü hatalı.")
		else:
			# Headless modda EditorDebuggerPlugin doğrudan instantiate edilemez, script sınıf varlığı doğrulanır
			if AISidebarDebuggerPlugin != null:
				passed += 1
			else:
				failed += 1
				errors.append("AISidebarDebuggerPlugin scripti yüklenemedi.")
	else:
		failed += 1
		errors.append("Godot ClassDB içinde EditorDebuggerPlugin bulunamadı.")

	# Test 8: ToolManager Şema Kayıtları
	var all_schemas = AISidebarToolManager.get_all_schemas()
	var has_tree_tool = false
	var has_node_tool = false
	for s in all_schemas:
		var fn = s.get("function", {}).get("name", "")
		if fn == "inspect_runtime_tree": has_tree_tool = true
		if fn == "inspect_runtime_node": has_node_tool = true
		
	if has_tree_tool and has_node_tool:
		passed += 1
	else:
		failed += 1
		errors.append("ToolManager içinde inspect_runtime_tree veya inspect_runtime_node bulunamadı.")

	# Test 9: Path Resolution Normalizasyonu (resolve_node_path)
	var test_root = Node.new()
	test_root.name = "root"
	var child_main = Node.new()
	child_main.name = "Main"
	test_root.add_child(child_main)
	var child_player = Node.new()
	child_player.name = "Player"
	child_main.add_child(child_player)

	var p1 = AISidebarRuntimeBridge.resolve_node_path(test_root, "")
	var p2 = AISidebarRuntimeBridge.resolve_node_path(test_root, "/root")
	var p3 = AISidebarRuntimeBridge.resolve_node_path(test_root, "Main/Player")
	var p4 = AISidebarRuntimeBridge.resolve_node_path(test_root, "/root/Main/Player")
	var p5 = AISidebarRuntimeBridge.resolve_node_path(test_root, "root/Main/Player")
	var p6 = AISidebarRuntimeBridge.resolve_node_path(test_root, "NonExistent")

	if p1 == test_root and p2 == test_root and p3 == child_player and p4 == child_player and p5 == child_player and p6 == null:
		passed += 1
	else:
		failed += 1
		errors.append("resolve_node_path normalizasyonu başarısız.")
	test_root.free()

	# Test 10: PermissionPolicy READ_ONLY Sınıflandırması
	var const_policy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
	var tree_risk = const_policy.get_tool_risk("inspect_runtime_tree")
	var node_risk = const_policy.get_tool_risk("inspect_runtime_node")
	if tree_risk == const_policy.RiskLevel.READ_ONLY and node_risk == const_policy.RiskLevel.READ_ONLY:
		passed += 1
	else:
		failed += 1
		errors.append("inspect_runtime araçları READ_ONLY olarak kaydedilmemiş: tree=" + str(tree_risk) + " node=" + str(node_risk))

	# Test 11: Intent Routing ve Anahtar Kelime Keşfi
	var routed_schemas = AISidebarToolManager.get_relevant_schemas("Oyundaki canlı düğümlere ve sahne ağacına bak")
	var routed_has_tree = false
	var routed_has_node = false
	for s in routed_schemas:
		var fn = s.get("function", {}).get("name", "")
		if fn == "inspect_runtime_tree": routed_has_tree = true
		if fn == "inspect_runtime_node": routed_has_node = true

	if routed_has_tree and routed_has_node:
		passed += 1
	else:
		failed += 1
		errors.append("Canlı düğüm intent routing inspect_runtime araçlarını dahil etmedi: tree=" + str(routed_has_tree) + " node=" + str(routed_has_node))

	# Test 12: Asenkron Araç Ayrımı (is_async_tool)
	if AISidebarToolManager.is_async_tool("inspect_runtime_tree") and AISidebarToolManager.is_async_tool("inspect_runtime_node") and not AISidebarToolManager.is_async_tool("search_tools"):
		passed += 1
	else:
		failed += 1
		errors.append("is_async_tool ayrımı beklenen araçları tespit edemedi.")

	return {"name": "RuntimeInspectionTests", "passed": passed, "failed": failed, "errors": errors}
