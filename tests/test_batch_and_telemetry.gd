@tool
extends RefCounted

const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")

class MockTelemetryProvider extends AISidebarAIProvider:
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
	
	var file1 = "res://tests/temp_player.gd"
	var file2 = "res://tests/temp_player.tscn"
	var invalid_file = "res://tests/temp_broken.gd"
	
	# Temizlik
	for p in [file1, file2, invalid_file]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
			
	# Test 1: write_files toplu yazım testi
	var batch_files = [
		{"file_path": file1, "content": "extends CharacterBody3D\nfunc _ready() -> void:\n\tpass\n"},
		{"file_path": file2, "content": "[gd_scene format=3]\n[node name=\"Player\" type=\"CharacterBody3D\"]\n"}
	]
	var res1 = AISidebarScriptTools.execute("write_files", {"files": batch_files})
	if res1.get("success", false) and FileAccess.file_exists(file1) and FileAccess.file_exists(file2):
		passed += 1
	else:
		failed += 1
		errors.append("write_files toplu yazım başarısız: " + str(res1))
		
	# Temizlik
	for p in [file1, file2]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
			
	# Test 2: İçinde 1 hatalı GDScript olan write_files hiçbir dosyayı yazmamalı (Atomik)
	var broken_batch = [
		{"file_path": file1, "content": "extends CharacterBody3D\nfunc _ready() -> void:\n\tpass\n"},
		{"file_path": invalid_file, "content": "extends Node\nfunc _ready( -> syntax_error:\n"}
	]
	var res2 = AISidebarScriptTools.execute("write_files", {"files": broken_batch})
	if not res2.get("success", false) and not FileAccess.file_exists(file1) and not FileAccess.file_exists(invalid_file):
		passed += 1
	else:
		failed += 1
		errors.append("Hatalı dosya içeren write_files atomikliği koruyamadı!")
		
	# Test 3: Multi-file ChangeSet unified diff kontrolü
	var cs = AISidebarChangeSet.new("res://player.gd", AISidebarChangeSet.ChangeType.MODIFY_FILE, "var speed = 8.0\n", "var speed = 5.0\n", "Player speed")
	cs.add_sub_change("res://Player.tscn", AISidebarChangeSet.ChangeType.MODIFY_FILE, "[node name=\"Camera3D\"]\n", "", "Player scene camera")
	var diff_txt = cs.get_unified_diff()
	if "--- a/res://player.gd" in diff_txt and "--- a/res://Player.tscn" in diff_txt and "+ var speed = 8.0" in diff_txt:
		passed += 1
	else:
		failed += 1
		errors.append("Çoklu dosya ChangeSet unified diff hatalı: " + diff_txt)
		
	# Test 4: Telemetri ölçümleri
	var mock_p = MockTelemetryProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock_p, ctx)
	
	mock_p.response_queue = [
		{
			"content": "",
			"thinking": "Dosyaları oluşturuyorum.",
			"tool_calls": [{"id": "call_1", "name": "write_files", "arguments": {"files": batch_files}}]
		},
		{
			"content": "Tüm dosyalar oluşturuldu.",
			"thinking": "Tamamlandı.",
			"tool_calls": []
		}
	]
	
	var reported_metrics_arr: Array = []
	runner.task_completed.connect(func(m):
		reported_metrics_arr.append(m)
	)
	
	runner.start_task("3D Player oluştur")
	
	var m = reported_metrics_arr[0] if reported_metrics_arr.size() > 0 else {}
	if m.get("llm_turns", 0) == 2 and m.get("file_ops", 0) >= 2 and m.has("elapsed_seconds"):
		passed += 1
	else:
		failed += 1
		errors.append("Telemetri ölçümleri eksik veya hatalı: " + str(m))
		
	# Temizlik
	for p in [file1, file2, invalid_file]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
			
	return {"name": "BatchAndTelemetryTests", "passed": passed, "failed": failed, "errors": errors}
