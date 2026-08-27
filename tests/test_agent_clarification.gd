@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarClarificationCard = preload("res://addons/godot_sidebar_ai/ui/components/clarification_card.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")

class MockClarificationProvider extends AISidebarAIProvider:
	var response_queue: Array = []
	var recorded_requests: Array = []
	
	func send_chat(messages: Array, tools_schema: Array) -> void:
		recorded_requests.append({"messages": messages.duplicate(true), "tools": tools_schema.duplicate(true)})
		if response_queue.size() > 0:
			var r = response_queue.pop_front()
			var thinking_txt = str(r.get("thinking", ""))
			var content_txt = str(r.get("content", ""))
			var tool_calls = r.get("tool_calls", [])
			
			# Simüle Akış (Streaming)
			if not thinking_txt.is_empty():
				chunk_received.emit("", thinking_txt)
			if not content_txt.is_empty():
				chunk_received.emit(content_txt, "")
				
			response_received.emit(content_txt, thinking_txt, tool_calls)

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Ambiguous Request -> Clarification Requested
	var mock1 = MockClarificationProvider.new()
	var ctx1 = AISidebarAgentContext.new()
	var runner1 = AISidebarAgentRunner.new(mock1, ctx1)
	
	mock1.response_queue = [
		{
			"content": "",
			"thinking": "Slime oluşturmak için 2D veya 3D olduğunu bilmem gerekiyor.",
			"tool_calls": [
				{
					"id": "call_clarify_1",
					"name": "ask_user",
					"arguments": {
						"question": "2D mi 3D mi oluşturayım?",
						"options": ["2D", "3D"]
					}
				}
			]
		}
	]
	
	var caught = {"q": "", "opts": [], "id": ""}
	runner1.clarification_requested.connect(func(q, opts, cid):
		caught["q"] = q
		caught["opts"] = opts
		caught["id"] = cid
	)
	
	runner1.start_task("Sahne oluştur ve slime yap.")
	
	var is_opts_equal = (caught["opts"].size() == 2 and caught["opts"][0] == "2D" and caught["opts"][1] == "3D")
	if runner1.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION and caught["q"] == "2D mi 3D mi oluşturayım?" and is_opts_equal and caught["id"] == "call_clarify_1":
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (ambiguous_request_triggers_clarification) failed: state=" + str(runner1.current_state) + " q=" + caught["q"] + " opts=" + str(caught["opts"]) + " id=" + caught["id"])
		
	# Test 2: Unambiguous Request -> Direct Continuation (No Clarification)
	var mock2 = MockClarificationProvider.new()
	var ctx2 = AISidebarAgentContext.new()
	var runner2 = AISidebarAgentRunner.new(mock2, ctx2)
	
	mock2.response_queue = [
		{
			"content": "Health 100 olarak ayarlandı.",
			"thinking": "İstek açık, soru sormaya gerek yok.",
			"tool_calls": []
		}
	]
	
	var clarification_fired2 = [false]
	runner2.clarification_requested.connect(func(_q, _opts, _cid): clarification_fired2[0] = true)
	runner2.start_task("health değerini 100 yap.")
	
	if not clarification_fired2[0] and runner2.current_state == AISidebarAgentRunner.AgentState.IDLE:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (unambiguous_request_no_clarification) failed.")
		
	# Test 3: Clarification Answer Resumes Original Task
	# 1. adımdaki runner1'e kullanıcının cevabını ("2D") gönderiyoruz
	mock1.response_queue = [
		{
			"content": "2D Slime karakteri başarıyla oluşturuldu.",
			"thinking": "Kullanıcı 2D seçti, Node2D tabanlı CharacterBody2D yapıyorum.",
			"tool_calls": []
		}
	]
	
	var completed_metrics = {"data": {}}
	runner1.task_completed.connect(func(m): completed_metrics["data"] = m)
	runner1.submit_clarification_response("2D")
	
	# Kontrol: Görevin 2. adımı çalıştı mı, context'e "ask_user" tool cevabı eklendi mi?
	var has_clarification_result = false
	for m in ctx1.messages:
		if m.get("role") == "tool" and m.get("name") == "ask_user":
			var c = JSON.parse_string(str(m.get("content", "{}")))
			if c is Dictionary and c.get("data", {}).get("user_answer", "") == "2D":
				has_clarification_result = true
				
	var is_success = completed_metrics["data"].get("success", false)
	if has_clarification_result and runner1.current_step == 2 and is_success:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (clarification_answer_resumes_original_task) failed: step=" + str(runner1.current_step) + " has_clar=" + str(has_clarification_result) + " succ=" + str(is_success) + " msgs=" + str(ctx1.messages.size()))
		
	# Test 4: ClarificationCard UI Quick Choice Interaction
	var card_ui = AISidebarClarificationCard.new("Harita boyutu ne olsun?", ["Küçük", "Orta", "Büyük"])
	card_ui._ready()
	var selected_ans = [""]
	card_ui.response_submitted.connect(func(ans): selected_ans[0] = ans)
	card_ui._on_option_selected("Orta")
	
	if selected_ans[0] == "Orta" and card_ui.is_answered and card_ui._status_lbl.visible and "Orta" in card_ui._status_lbl.text:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (multiple_choice_answer_ui_flow) failed: " + str(selected_ans))
	card_ui.queue_free()
	
	# Test 5: ClarificationCard Free Text Interaction
	var card_text = AISidebarClarificationCard.new("Karakterin yeteneği ne olsun?", [])
	card_text._ready()
	var submitted_text = [""]
	card_text.response_submitted.connect(func(ans): submitted_text[0] = ans)
	card_text._on_text_submitted("Çift zıplama ve ateş topu")
	
	if submitted_text[0] == "Çift zıplama ve ateş topu" and card_text.is_answered:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (free_text_answer_ui_flow) failed: " + str(submitted_text))
	card_text.queue_free()
	
	# Test 6: Clarification followed by Approval Flow
	var mock6 = MockClarificationProvider.new()
	var ctx6 = AISidebarAgentContext.new()
	var runner6 = AISidebarAgentRunner.new(mock6, ctx6)
	
	mock6.response_queue = [
		# 1. Turn: Clarification
		{
			"content": "",
			"thinking": "Hangi script dili?",
			"tool_calls": [{"id": "c1", "name": "ask_user", "arguments": {"question": "GDScript mi C# mı?", "options": ["GDScript", "C#"]}}]
		},
		# 2. Turn: Destructive / Approval Tool Call
		{
			"content": "",
			"thinking": "GDScript seçildi, player.gd dosyasını siliyorum.",
			"tool_calls": [{"id": "c2", "name": "delete_file", "arguments": {"file_path": "res://test_temp_del.gd"}}]
		},
		# 3. Turn: Final Answer
		{
			"content": "İşlem tamamlandı.",
			"thinking": "Dosya silindi.",
			"tool_calls": []
		}
	]
	
	runner6.start_task("Karakter dosyasını sıfırla.")
	if runner6.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION:
		runner6.submit_clarification_response("GDScript")
		
	# Şimdi WAITING_FOR_APPROVAL olmalı
	var is_in_approval = (runner6.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL)
	if is_in_approval:
		runner6.approve_pending_action()
		
	if is_in_approval and runner6.current_state == AISidebarAgentRunner.AgentState.IDLE and runner6.current_step == 3:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (clarification_with_approval) failed: state=" + str(runner6.current_state) + ", step=" + str(runner6.current_step))
		
	# Test 7: Clarification with Queue Integration
	var mock7 = MockClarificationProvider.new()
	var ctx7 = AISidebarAgentContext.new()
	var runner7 = AISidebarAgentRunner.new(mock7, ctx7)
	
	mock7.response_queue = [
		{"content": "", "thinking": "", "tool_calls": [{"id": "cq", "name": "ask_user", "arguments": {"question": "Seçim?"}}]}
	]
	runner7.start_task("Görev 1")
	
	var is_runner7_busy = runner7.is_running() # True because in WAITING_FOR_CLARIFICATION
	var queue_mock: Array = []
	if is_runner7_busy:
		queue_mock.append({"prompt": "Görev 2 (Kuyrukta)"})
		
	if runner7.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION and is_runner7_busy and queue_mock.size() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (clarification_with_queue) failed.")
		
	# Test 8: Clarification with Stop
	runner7.stop()
	if runner7.current_state == AISidebarAgentRunner.AgentState.IDLE and runner7._pending_clarification_id.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("Test 8 (clarification_with_stop) failed: state=" + str(runner7.current_state))
		
	# Test 9: Tool Manager includes ask_user schema
	var all_schemas = AISidebarToolManager.get_all_schemas()
	var has_ask_user_schema = false
	for s in all_schemas:
		if s.get("function", {}).get("name", "") == "ask_user":
			has_ask_user_schema = true
			break
			
	if has_ask_user_schema:
		passed += 1
	else:
		failed += 1
		errors.append("Test 9 (ask_user schema in ToolManager) missing.")
		
	# Test 10: Direct ask_user tool execution
	var direct_exec = AISidebarToolManager.execute_tool("ask_user", {"question": "Test Soru", "options": ["A", "B"]})
	if direct_exec.get("success", false) and direct_exec.get("data", {}).get("clarification", false):
		passed += 1
	else:
		failed += 1
		errors.append("Test 10 (ask_user direct execution) failed: " + str(direct_exec))
		
	return {"name": "AgentClarificationTests", "passed": passed, "failed": failed, "errors": errors}
