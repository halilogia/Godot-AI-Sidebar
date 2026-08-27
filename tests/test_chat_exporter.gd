@tool
extends RefCounted

const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: User message export (Text and Multimodal)
	var user_history = [
		{"role": "user", "content": "Create player script"},
		{"role": "user", "content": [
			{"type": "text", "text": "Check viewport"},
			{"type": "image_url", "image_url": {"url": "data:image/png;base64,123"}}
		]}
	]
	var md1 = AISidebarChatExporter.export_to_markdown(user_history)
	if "## 👤 User" in md1 and "Create player script" in md1 and "Attached 1 Viewport Image" in md1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (export_user_message) failed: " + md1)
		
	# Test 2: Assistant message with reasoning & tool calls
	var assistant_history = [
		{
			"role": "assistant",
			"reasoning_content": "Planning to read player.gd first.",
			"tool_calls": [
				{
					"id": "call_001",
					"function": {
						"name": "read_script",
						"arguments": "{\"file_path\": \"res://player.gd\"}"
					}
				}
			],
			"content": "I am analyzing the player script."
		}
	]
	var md2 = AISidebarChatExporter.export_to_markdown(assistant_history)
	if "## 🤖 Godot AI" in md2 and "Planning to read player.gd first." in md2 and "Tool Executed: `read_script`" in md2 and "res://player.gd" in md2:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (export_assistant_message & tool_call) failed: " + md2)
		
	# Test 3: Tool Result export (Success & File target)
	var tool_history = [
		{
			"role": "tool",
			"name": "create_or_update_script",
			"tool_call_id": "call_001",
			"content": "{\"success\": true, \"data\": {\"file_path\": \"res://player.gd\", \"action\": \"created\"}, \"message\": \"Script created successfully.\"}"
		}
	]
	var md3 = AISidebarChatExporter.export_to_markdown(tool_history)
	if "### ⚙️ Tool Result: `create_or_update_script`" in md3 and "✅ **Status:** Success" in md3 and "res://player.gd" in md3:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (export_tool_result) failed: " + md3)
		
	# Test 4: Runtime Error observation in tool result
	var error_tool_history = [
		{
			"role": "tool",
			"name": "get_runtime_errors",
			"tool_call_id": "call_002",
			"content": "{\"success\": false, \"data\": {\"errors\": [{\"file\": \"res://player.gd\", \"line\": 42, \"message\": \"Variable not found\"}]}, \"message\": \"Errors found in runtime\"}"
		}
	]
	var md4 = AISidebarChatExporter.export_to_markdown(error_tool_history)
	if "Runtime Diagnostic Errors:" in md4 and "res://player.gd:42" in md4 and "Variable not found" in md4:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (export_runtime_error) failed: " + md4)
		
	# Test 5: Session Telemetry & Metadata export
	var meta = {
		"model": "ag/gemini-3.7-flash-low",
		"elapsed_s": 2.4,
		"telemetry": {
			"total_elapsed_s": 2.4,
			"llm_time_s": 1.5,
			"tool_time_s": 0.9,
			"tool_calls_count": 3
		}
	}
	var md5 = AISidebarChatExporter.export_to_markdown(user_history, meta)
	if "ag/gemini-3.7-flash-low" in md5 and "## 📊 Session Telemetry" in md5 and "Total Elapsed S" in md5:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (export_telemetry) failed: " + md5)
		
	# Test 6: Null-Safety with corrupted/empty entries
	var corrupted_history = [
		null,
		{},
		{"role": null, "content": null},
		{"role": "assistant", "tool_calls": null, "content": null},
		{"role": "tool", "name": null, "content": null}
	]
	var md6 = AISidebarChatExporter.export_to_markdown(corrupted_history)
	if md6.length() > 0 and "# 🤖 Godot AI Chat Export" in md6:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (export_null_safe) failed: " + md6)
		
	# Test 7: JSON Export format
	var json_export = AISidebarChatExporter.export_to_json(user_history, meta)
	var parsed = JSON.parse_string(json_export)
	if parsed is Dictionary and parsed.get("export_version", "") == "2.0" and parsed.get("messages", []).size() == 2:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (export_to_json) failed: " + str(parsed))
		
	# Test 8: Save to file
	var save_res = AISidebarChatExporter.save_to_file(md1, "md")
	if save_res.get("success", false) and FileAccess.file_exists(save_res.get("path", "")):
		passed += 1
		DirAccess.remove_absolute(save_res.get("path", ""))
	else:
		failed += 1
		errors.append("Test 8 (save_to_file) failed: " + str(save_res))
		
	return {"name": "ChatExporterTests", "passed": passed, "failed": failed, "errors": errors}
