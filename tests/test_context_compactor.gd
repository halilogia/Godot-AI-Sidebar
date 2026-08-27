@tool
extends RefCounted

const AISidebarContextCompactor = preload("res://addons/godot_sidebar_ai/core/agent/context_compactor.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: analyze_project compaction
	var analyze_raw = JSON.stringify({
		"status": "ok",
		"result": {
			"project_name": "MyGame3D",
			"main_scene": "res://scenes/Main.tscn",
			"total_files": 120,
			"scenes_count": 15,
			"scripts_count": 30
		}
	})
	var comp1 = AISidebarContextCompactor.compact_tool_content("analyze_project", analyze_raw)
	var json1 = JSON.parse_string(comp1)
	if json1 and json1.get("is_compacted") == true and "MyGame3D" in json1.get("summary", ""):
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (analyze_project compaction) failed: " + comp1)
		
	# Test 2: get_project_files compaction (50 files to 1 line summary)
	var file_list: Array = []
	for i in range(50):
		file_list.append("res://scripts/file_%d.gd" % i)
	var files_raw = JSON.stringify({
		"status": "ok",
		"result": {
			"path": "res://",
			"count": 50,
			"files": file_list
		}
	})
	var comp2 = AISidebarContextCompactor.compact_tool_content("get_project_files", files_raw)
	var json2 = JSON.parse_string(comp2)
	if json2 and json2.get("is_compacted") == true and "50 dosya" in json2.get("summary", "") and "file_0.gd" in json2.get("summary", ""):
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (get_project_files compaction) failed: " + comp2)
		
	# Test 3: get_scene_tree compaction
	var scene_raw = JSON.stringify({
		"status": "ok",
		"result": {
			"root_name": "Level1",
			"node_type": "Node3D",
			"node_count": 42
		}
	})
	var comp3 = AISidebarContextCompactor.compact_tool_content("get_scene_tree", scene_raw)
	var json3 = JSON.parse_string(comp3)
	if json3 and json3.get("is_compacted") == true and "Level1" in json3.get("summary", "") and "42 düğüm" in json3.get("summary", ""):
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (get_scene_tree compaction) failed: " + comp3)
		
	# Test 4: read_script compaction
	var script_raw = JSON.stringify({
		"status": "ok",
		"result": {
			"file_path": "res://player.gd",
			"line_count": 180,
			"content": "extends CharacterBody3D\n" + "var x = 1\n".repeat(179)
		}
	})
	var comp4 = AISidebarContextCompactor.compact_tool_content("read_script", script_raw)
	var json4 = JSON.parse_string(comp4)
	if json4 and json4.get("is_compacted") == true and "res://player.gd" in json4.get("summary", "") and "180 satır" in json4.get("summary", ""):
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (read_script compaction) failed: " + comp4)
		
	# Test 5: get_runtime_errors compaction
	var err_raw = JSON.stringify({
		"status": "ok",
		"result": {
			"error_count": 3,
			"errors": [{"file": "res://enemy.gd", "line": 45, "message": "Null instance access"}]
		}
	})
	var comp5 = AISidebarContextCompactor.compact_tool_content("get_runtime_errors", err_raw)
	var json5 = JSON.parse_string(comp5)
	if json5 and json5.get("is_compacted") == true and "3 adet" in json5.get("summary", "") and "res://enemy.gd" in json5.get("summary", ""):
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (get_runtime_errors compaction) failed: " + comp5)
		
	# Test 6: compact_messages (Old tools compacted, recent 2 tools untouched)
	var raw_msgs = [
		{"role": "user", "content": "Karakter yap"},
		{"role": "assistant", "tool_calls": [{"id": "call_1", "name": "analyze_project"}]},
		{"role": "tool", "tool_call_id": "call_1", "name": "analyze_project", "content": analyze_raw},
		{"role": "assistant", "tool_calls": [{"id": "call_2", "name": "get_project_files"}]},
		{"role": "tool", "tool_call_id": "call_2", "name": "get_project_files", "content": files_raw},
		{"role": "assistant", "tool_calls": [{"id": "call_3", "name": "read_script"}]},
		{"role": "tool", "tool_call_id": "call_3", "name": "read_script", "content": script_raw},
		{"role": "assistant", "tool_calls": [{"id": "call_4", "name": "get_scene_tree"}]},
		{"role": "tool", "tool_call_id": "call_4", "name": "get_scene_tree", "content": scene_raw}
	]
	
	var compacted_res = AISidebarContextCompactor.compact_messages(raw_msgs, 2)
	
	# call_1 (analyze_project) and call_2 (get_project_files) must be compacted
	var tool_msg_0 = compacted_res[2]["content"]
	var tool_msg_1 = compacted_res[4]["content"]
	var is_t0_compacted = "is_compacted" in tool_msg_0
	var is_t1_compacted = "is_compacted" in tool_msg_1
	
	# call_3 (read_script) and call_4 (get_scene_tree) are the last 2 tools, must NOT be compacted
	var tool_msg_2 = compacted_res[6]["content"]
	var tool_msg_3 = compacted_res[8]["content"]
	var is_t2_raw = tool_msg_2 == script_raw
	var is_t3_raw = tool_msg_3 == scene_raw
	
	if is_t0_compacted and is_t1_compacted and is_t2_raw and is_t3_raw:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (compact_messages keeps recent 2 tools full) failed.")
		
	# Test 7: AgentContext get_messages_for_api applies compaction
	var ctx = AISidebarAgentContext.new()
	ctx.add_user_message("Proje analizi")
	ctx.add_assistant_tool_call_message("", [{"id": "c1", "name": "analyze_project", "arguments": {}}])
	ctx.add_tool_result_message("c1", "analyze_project", {"status": "ok", "result": {"project_name": "TestGame", "total_files": 90}})
	ctx.add_assistant_tool_call_message("", [{"id": "c2", "name": "get_project_files", "arguments": {}}])
	ctx.add_tool_result_message("c2", "get_project_files", {"status": "ok", "result": {"path": "res://", "count": 20, "files": ["a.gd", "b.gd"]}})
	ctx.add_assistant_tool_call_message("", [{"id": "c3", "name": "read_script", "arguments": {}}])
	ctx.add_tool_result_message("c3", "read_script", {"status": "ok", "result": {"file_path": "res://a.gd", "line_count": 10}})
	
	var api_msgs = ctx.get_messages_for_api(1) # Sadece son 1 tool'u full tut
	# Grounding mesajı (1) + ctx mesajları (7) = 8 mesaj
	if api_msgs.size() == 8 and "is_compacted" in api_msgs[3]["content"] and "is_compacted" in api_msgs[5]["content"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (AgentContext get_messages_for_api) failed: size=" + str(api_msgs.size()))
		
	return {"name": "ContextCompactorTests", "passed": passed, "failed": failed, "errors": errors}
