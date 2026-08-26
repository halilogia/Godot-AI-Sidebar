@tool
extends RefCounted

const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarChangesCard = preload("res://addons/godot_sidebar_ai/ui/components/changes_card.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var test_path = "res://tests/temp_test_del.gd"
	var protected_path = "res://project.godot"
	
	# Test 1: delete_file korumalı dosya engelleme (Protected Path)
	var prot_res = AISidebarScriptTools.execute("delete_file", {"file_path": protected_path})
	if not prot_res.get("success", false) and prot_res.get("error", {}).get("code") == "PERMISSION_DENIED":
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (delete_file protected path) failed: " + str(prot_res))
		
	# Test 2: delete_file yetki seviyesi ve approval gereksinimi (PermissionPolicy)
	var req_app = AISidebarPermissionPolicy.requires_user_approval("delete_file", {"file_path": test_path})
	var level = AISidebarPermissionPolicy.get_tool_permission_level("delete_file")
	if req_app and level == AISidebarPermissionPolicy.PermissionLevel.DESTRUCTIVE:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (delete_file PermissionPolicy) failed.")
		
	# Test 3: delete_file dosya silme ve ChangeSet (Apply)
	var f = FileAccess.open(test_path, FileAccess.WRITE)
	f.store_string("extends Node\nvar x = 10\n")
	f.close()
	
	var del_res = AISidebarScriptTools.execute("delete_file", {"file_path": test_path})
	if del_res.get("success", false) and not FileAccess.file_exists(test_path):
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (delete_file apply) failed.")
		
	# Test 4: delete_file Undo ile eski içeriğin geri getirilmesi (Rollback)
	var cs = del_res.get("change_set")
	if cs:
		var undo_res = cs.rollback()
		if undo_res.get("success", false) and FileAccess.file_exists(test_path):
			var restored_f = FileAccess.open(test_path, FileAccess.READ)
			var restored_content = restored_f.get_as_text() if restored_f else ""
			if restored_f: restored_f.close()
			if "var x = 10" in restored_content:
				passed += 1
			else:
				failed += 1
				errors.append("Test 4 (delete_file Undo content mismatch): " + restored_content)
		else:
			failed += 1
			errors.append("Test 4 (delete_file Undo failed): " + str(undo_res))
	else:
		failed += 1
		errors.append("Test 4 (delete_file ChangeSet missing).")
		
	# Temizlik
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)
		
	# Test 5: ChangesCard meta_clicked sinyali
	var dummy_cs = AISidebarChangeSet.new("res://player.gd", AISidebarChangeSet.ChangeType.MODIFY_FILE, "var a = 1", "", "desc")
	var card = AISidebarChangesCard.new(dummy_cs)
	card._ready()
	var signal_caught = [false]
	card.meta_clicked.connect(func(m): signal_caught[0] = true)
	card.meta_clicked.emit("file:res://player.gd")
	if signal_caught[0]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (ChangesCard meta_clicked signal) failed.")
	card.queue_free()
	
	# Test 6: ChatExporter Nil/Null güvenliği (Null Safety)
	var null_history = [
		{"role": "assistant", "content": null, "tool_calls": [{"function": {"name": "delete_file", "arguments": "{\"file_path\":\"res://old.gd\"}"}}]},
		{"role": "tool", "name": "delete_file", "content": "{\"success\": true}"},
		{"role": "user", "content": null}
	]
	var exported_md = AISidebarChatExporter.export_to_markdown(null_history)
	if "Tool Executed" in exported_md and "Tool Result" in exported_md:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (ChatExporter null-safety) failed: " + exported_md)
		
	return {"name": "FileDeletionAndSignalsTests", "passed": passed, "failed": failed, "errors": errors}
