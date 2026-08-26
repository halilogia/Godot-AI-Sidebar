@tool
extends RefCounted

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")

class MockFastProvider extends AISidebarAIProvider:
	var response_queue: Array = []
	
	func send_chat(messages: Array, tools_schema: Array) -> void:
		if response_queue.size() > 0:
			var r = response_queue.pop_front()
			response_received.emit(
				r.get("content", ""),
				r.get("thinking", ""),
				r.get("tool_calls", [])
			)

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: ChangeSet BBCode Diff ve Delta formatı
	var cs = AISidebarChangeSet.new("res://player.gd", AISidebarChangeSet.ChangeType.MODIFY_FILE, "var speed = 8.0\nvar jump = 10.0\n", "var speed = 5.0\n", "Player script update")
	cs.add_sub_change("res://Player.tscn", AISidebarChangeSet.ChangeType.CREATE_FILE, "[node name=\"Camera3D\"]\n", "", "Player scene")
	cs.add_sub_change("res://TestLevel.tscn", AISidebarChangeSet.ChangeType.CREATE_FILE, "[node name=\"Level\"]\n", "", "Level scene")
	
	var deltas = cs.get_file_deltas()
	var bbcode = cs.get_bbcode_diff()
	
	if deltas.size() == 3 and "player.gd" in bbcode and "Player.tscn" in bbcode and "TestLevel.tscn" in bbcode and "+ var speed = 8.0" in bbcode:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 Başarısız: ChangeSet BBCode diff formatı hatalı: " + bbcode)
		
	# Test 2: NetworkManager URL Parser Testi
	var nm = AISidebarNetworkManager.new()
	var p1 = nm._parse_url("http://localhost:20128/v1/chat/completions")
	var p2 = nm._parse_url("https://api.openai.com/v1/models")
	
	if p1["host"] == "localhost" and p1["port"] == 20128 and p1["path"] == "/v1/chat/completions" and p2["host"] == "api.openai.com" and p2["port"] == 443 and p2["ssl"] == true:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 Başarısız: NetworkManager URL parsing hatalı: " + str(p1) + " | " + str(p2))
		
	# Test 3: write_files sonrası changes_applied sinyali ve ChangeSet üretimi
	var mock_p = MockFastProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock_p, ctx)
	
	var f1 = "res://tests/temp_tf1.gd"
	var f2 = "res://tests/temp_tf2.gd"
	for p in [f1, f2]:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(p)
		
	var batch = [
		{"file_path": f1, "content": "extends Node\n"},
		{"file_path": f2, "content": "extends Node3D\n"}
	]
	
	mock_p.response_queue = [
		{
			"content": "",
			"thinking": "Yazıyorum.",
			"tool_calls": [{"id": "call_w", "name": "write_files", "arguments": {"files": batch}}]
		},
		{
			"content": "Bitti.",
			"thinking": "Tamamlandı.",
			"tool_calls": []
		}
	]
	
	var received_cs_arr: Array = []
	runner.changes_applied.connect(func(c): received_cs_arr.append(c))
	
	runner.start_task("Batch dosya yaz")
	
	if received_cs_arr.size() > 0 and FileAccess.file_exists(f1) and FileAccess.file_exists(f2):
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 Başarısız: changes_applied sinyali tetiklenmedi veya dosyalar yazılmadı!")
		
	# Test 4: Atomik Rollback (Undo) Testi
	if received_cs_arr.size() > 0:
		var applied_cs: AISidebarChangeSet = received_cs_arr[0]
		var undo_res = applied_cs.rollback()
		if undo_res.get("success", false) and not FileAccess.file_exists(f1) and not FileAccess.file_exists(f2):
			passed += 1
		else:
			failed += 1
			errors.append("Test 4 Başarısız: ChangeSet rollback dosyaları silemedi: " + str(undo_res))
	else:
		failed += 1
		errors.append("Test 4 Atlandı: applied_cs yok.")
		
	# Test 5: Telemetri Süre Ayrıştırması
	var mock_p2 = MockFastProvider.new()
	var ctx2 = AISidebarAgentContext.new()
	var runner2 = AISidebarAgentRunner.new(mock_p2, ctx2)
	
	mock_p2.response_queue = [
		{
			"content": "Doğrudan metin yanıtı.",
			"thinking": "",
			"tool_calls": []
		}
	]
	
	var reported_m_arr: Array = []
	runner2.task_completed.connect(func(m): reported_m_arr.append(m))
	runner2.start_task("Hızlı yanıt")
	
	var m = reported_m_arr[0] if reported_m_arr.size() > 0 else {}
	if m.has("elapsed_seconds") and m.has("llm_time_s") and m.has("tool_time_s") and m.has("waiting_time_s"):
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 Başarısız: Telemetri süre metrikleri eksik: " + str(m))
		
	return {"name": "ChangeSetAndNetworkTimingTests", "passed": passed, "failed": failed, "errors": errors}
