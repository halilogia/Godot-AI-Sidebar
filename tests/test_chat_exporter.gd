@tool
extends RefCounted

const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var history = [
		{"role": "user", "content": "Create player script"},
		{"role": "assistant", "content": "Done! Player script created at res://player.gd."}
	]
	
	# Test 1: Markdown export format
	var md = AISidebarChatExporter.export_to_markdown(history)
	if "### 👤 User" in md and "### 🤖 Godot AI" in md and "Create player script" in md:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (Markdown export format) failed.")
		
	# Test 2: File save
	var save_res = AISidebarChatExporter.save_to_file(md)
	if save_res.get("success", false) and FileAccess.file_exists(save_res.get("path", "")):
		passed += 1
		# Clean up exported test file
		DirAccess.remove_absolute(save_res.get("path", ""))
	else:
		failed += 1
		errors.append("Test 2 (File save) failed: " + str(save_res))
		
	return {"name": "ChatExporterTests", "passed": passed, "failed": failed, "errors": errors}
