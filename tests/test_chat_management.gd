@tool
extends RefCounted

const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarHistoryPanel = preload("res://addons/godot_sidebar_ai/ui/components/history_panel.gd")
const AISidebarAgentHost = preload("res://addons/godot_sidebar_ai/core/agent/agent_host.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")

class ScriptedProvider extends AISidebarAIProvider:
	var responses: Array = []
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		if responses.size() > 0:
			var r = responses.pop_front()
			response_received.emit(r.get("content", ""), r.get("thinking", ""), r.get("tool_calls", []))

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test Öncesi Temizlik
	AISidebarChatManager.clear_all_sessions()
	
	# Test 1: new_chat
	var session1 = AISidebarChatSession.new("", "Test Chat 1")
	if not session1.id.is_empty() and session1.title == "Test Chat 1" and session1.messages.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (new_chat) failed.")
		
	# Test 2: save_chat & auto_title_from_first_message
	session1.messages.append({
		"role": "user",
		"content": "2D Platformer karakter kontrolcüsü oluştur ve zıplama ekle."
	})
	session1.messages.append({
		"role": "assistant",
		"content": "CharacterBody2D scripti başarıyla oluşturuldu."
	})
	session1.telemetry = {"llm_turns": 1, "tool_calls": 2, "elapsed_seconds": 1.5}
	
	var save_ok = AISidebarChatManager.save_session(session1)
	var list_after_save = AISidebarChatManager.list_sessions()
	
	if save_ok and list_after_save.size() == 1 and list_after_save[0]["id"] == session1.id:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (save_chat) failed: size=" + str(list_after_save.size()))
		
	# Test 3: load_chat
	var loaded1 = AISidebarChatManager.load_session(session1.id)
	if loaded1 and loaded1.id == session1.id and loaded1.messages.size() == 2 and loaded1.telemetry.get("llm_turns", 0) == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (load_chat) failed.")
		
	# Test 4: switch_chat
	var session2 = AISidebarChatSession.new("", "Test Chat 2")
	session2.messages.append({"role": "user", "content": "3D Kamera sistemi kur."})
	AISidebarChatManager.save_session(session2)
	
	var all_sessions = AISidebarChatManager.list_sessions()
	var loaded2 = AISidebarChatManager.load_session(session2.id)
	
	if all_sessions.size() == 2 and loaded2 and loaded2.title == "Test Chat 2" and loaded2.messages.size() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (switch_chat) failed.")
		
	# Test 5: rename_chat
	var ren_ok = AISidebarChatManager.rename_session(session2.id, "3D Kamera ve Takip Sistemi")
	var loaded_renamed = AISidebarChatManager.load_session(session2.id)
	
	if ren_ok and loaded_renamed and loaded_renamed.title == "3D Kamera ve Takip Sistemi":
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (rename_chat) failed.")
		
	# Test 6: delete_chat
	var del_ok = AISidebarChatManager.delete_session(session2.id)
	var list_after_del = AISidebarChatManager.list_sessions()
	var load_deleted = AISidebarChatManager.load_session(session2.id)
	
	if del_ok and list_after_del.size() == 1 and load_deleted == null:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (delete_chat) failed.")
		
	# Test 7: chat_persistence & ordering
	var session3 = AISidebarChatSession.new("", "Persistence Alpha")
	session3.messages.append({"role": "user", "content": "Alpha görevi"})
	AISidebarChatManager.save_session(session3)
	
	var list_persisted = AISidebarChatManager.list_sessions()
	var has_s1 = false
	var has_s3 = false
	for s in list_persisted:
		if s.get("id") == session1.id:
			has_s1 = true
		if s.get("id") == session3.id:
			has_s3 = true
			
	if has_s1 and has_s3 and list_persisted.size() == 2:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (chat_persistence) failed.")
		
	# Test 8: export_loaded_chat
	var export_sess = AISidebarChatManager.load_session(session1.id)
	var md_out = AISidebarChatExporter.export_to_markdown(export_sess.messages, export_sess.telemetry)
	var json_out = AISidebarChatExporter.export_to_json(export_sess.messages, export_sess.telemetry)
	
	if "2D Platformer" in md_out and "llm_turns" in json_out and "CharacterBody2D" in md_out:
		passed += 1
	else:
		failed += 1
		errors.append("Test 8 (export_loaded_chat) failed.")
		
	# Gerçek dock + runner (editör yolundaki bağlama; dock ağaçta değil).
	var dock = ChatDockScene.instantiate()
	dock._ready()
	dock._auto_scroll_enabled = false
	var host = AISidebarAgentHost.new()
	var prov = ScriptedProvider.new()
	host.set_provider(prov)
	dock.attach_agent_host(host)
	var runner = host.runner

	# Test 9: queue_isolated_between_chats — New Chat ve History'den yükleme kuyruğu boşaltır
	dock._queue_panel.enqueue("Sıradaki prompt 1", "Sıradaki prompt 1")
	dock._queue_panel.enqueue("Sıradaki prompt 2", "Sıradaki prompt 2")
	dock.history_panel.new_chat_requested.emit()
	var after_new = dock._queue_panel.count()
	dock._queue_panel.enqueue("Sıradaki prompt 3", "Sıradaki prompt 3")
	dock.history_panel.session_selected.emit(session1.id)
	var after_load = dock._queue_panel.count()
	if after_new == 0 and after_load == 0 and dock._sessions.is_current(session1.id):
		passed += 1
	else:
		failed += 1
		errors.append("Test 9 (queue_isolated_between_chats) failed: after_new=%d after_load=%d" % [after_new, after_load])

	# Test 10: approval_state_not_replayed — onay beklerken başka sohbete geçmek bekleyen kararı düşürür
	dock.history_panel.new_chat_requested.emit()
	prov.responses = [{"content": "", "thinking": "", "tool_calls": [{"name": "delete_node", "arguments": {"node_path": "TempNode"}}]}]
	dock.input_field.text = "Delete TempNode"
	dock._tasks.submit_input()
	var was_waiting = runner.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL and runner.pending.has_approval()
	dock.history_panel.session_selected.emit(session1.id)
	if was_waiting and not runner.pending.has_approval() and runner.current_state != AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL and not runner.is_running():
		passed += 1
	else:
		failed += 1
		errors.append("Test 10 (approval_state_not_replayed) failed: was_waiting=%s state=%s" % [str(was_waiting), str(runner.current_state)])

	# Test 11: clarification_state_not_replayed — soru beklerken yeni sohbet bekleyen soruyu düşürür
	prov.responses = [{"content": "", "thinking": "", "tool_calls": [{"name": "ask_user", "arguments": {"question": "Hangisi?", "options": ["A", "B"]}}]}]
	dock.input_field.text = "Belirsiz istek"
	dock._tasks.submit_input()
	var was_asking = runner.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION and runner.pending.has_clarification()
	dock.history_panel.new_chat_requested.emit()
	if was_asking and not runner.pending.has_clarification() and runner.current_state != AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION and not runner.is_running():
		passed += 1
	else:
		failed += 1
		errors.append("Test 11 (clarification_state_not_replayed) failed: was_asking=%s state=%s" % [str(was_asking), str(runner.current_state)])

	# Test 12: runtime_state_not_replayed — yüklenen eski sohbet runner'ı çalışma/runtime durumuna sokmaz
	dock.history_panel.session_selected.emit(session1.id)
	var rs = runner.current_state
	if not runner.is_running() and rs != AISidebarAgentRunner.AgentState.DEBUGGING and rs != AISidebarAgentRunner.AgentState.RUNNING_GAME and rs != AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL:
		passed += 1
	else:
		failed += 1
		errors.append("Test 12 (runtime_state_not_replayed) failed: state=" + str(rs))
	dock.free()
	host.free()

	# Test 13: HistoryPanel UI Component
	var panel = AISidebarHistoryPanel.new()
	panel._ready()
	panel.set_active_session(session1.id)
	panel._search_input.text = "Alpha"
	panel._on_search_text_changed("Alpha")
	
	if panel._items_vbox.get_child_count() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 13 (HistoryPanel UI filter) failed: count=" + str(panel._items_vbox.get_child_count()))
	panel.queue_free()
	
	# Temizlik
	AISidebarChatManager.clear_all_sessions()
	
	return {"name": "ChatManagementTests", "passed": passed, "failed": failed, "errors": errors}
