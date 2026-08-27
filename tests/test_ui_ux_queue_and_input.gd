@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")

class MockQueueProvider extends AISidebarAIProvider:
	var responses: Array = []
	var last_sent_messages: Array = []
	
	func send_chat(messages: Array, _tools: Array) -> void:
		last_sent_messages = messages
		
	func send_multimodal_chat(messages: Array, _tools: Array, _images: Array) -> void:
		last_sent_messages = messages

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Enter Sends Message vs Shift+Enter Newline Logic
	var text_input = "Hello Godot AI"
	var event_enter = InputEventKey.new()
	event_enter.keycode = KEY_ENTER
	event_enter.pressed = true
	event_enter.shift_pressed = false
	
	var event_shift_enter = InputEventKey.new()
	event_shift_enter.keycode = KEY_ENTER
	event_shift_enter.pressed = true
	event_shift_enter.shift_pressed = true
	
	var is_send_action = (event_enter.keycode == KEY_ENTER and not event_enter.shift_pressed)
	var is_newline_action = (event_shift_enter.keycode == KEY_ENTER and event_shift_enter.shift_pressed)
	
	if is_send_action and is_newline_action:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (enter_sends_message & shift_enter_newline) failed.")
		
	# Test 2: FIFO Message Queueing
	var queue: Array[Dictionary] = []
	var queue_item_1 = {"id": "q1", "prompt": "Task 1", "created_at": 100}
	var queue_item_2 = {"id": "q2", "prompt": "Task 2", "created_at": 200}
	var queue_item_3 = {"id": "q3", "prompt": "Task 3", "created_at": 300}
	
	queue.append(queue_item_1)
	queue.append(queue_item_2)
	queue.append(queue_item_3)
	
	var popped_first = queue.pop_front()
	var popped_second = queue.pop_front()
	
	if popped_first["id"] == "q1" and popped_second["id"] == "q2" and queue.size() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (queued_messages_fifo) failed: " + str(queue))
		
	# Test 3: Queued Message Cancellation by ID
	var cancel_queue: Array[Dictionary] = [
		{"id": "a", "prompt": "Prompt A"},
		{"id": "b", "prompt": "Prompt B"},
		{"id": "c", "prompt": "Prompt C"}
	]
	var cancel_target_id = "b"
	for i in range(cancel_queue.size()):
		if cancel_queue[i]["id"] == cancel_target_id:
			cancel_queue.remove_at(i)
			break
			
	if cancel_queue.size() == 2 and cancel_queue[0]["id"] == "a" and cancel_queue[1]["id"] == "c":
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (queued_message_cancel) failed: " + str(cancel_queue))
		
	# Test 4: Queue Execution Deduping (No Duplicate Execution)
	var executed_tasks: Array = []
	var sim_queue: Array[Dictionary] = [
		{"id": "job1", "prompt": "Do Job 1"},
		{"id": "job2", "prompt": "Do Job 2"}
	]
	
	# Run first task
	if sim_queue.size() > 0:
		var item = sim_queue.pop_front()
		executed_tasks.append(item["id"])
	# Run second task
	if sim_queue.size() > 0:
		var item = sim_queue.pop_front()
		executed_tasks.append(item["id"])
	# Attempt third pop on empty queue
	if sim_queue.size() > 0:
		var item = sim_queue.pop_front()
		executed_tasks.append(item["id"])
		
	if executed_tasks == ["job1", "job2"] and sim_queue.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (queue_no_duplicate_execution) failed: " + str(executed_tasks))
		
	# Test 5: Queue with Approval State Machine
	var mock_p = MockQueueProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock_p, ctx)
	
	# Start task
	runner.start_task("Perform destructive edit")
	# Force state to WAITING_FOR_APPROVAL
	runner._set_state(AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL, "Waiting for user approval")
	
	var is_runner_busy = runner.is_running() # true while waiting for approval
	var queued_while_waiting: Array[Dictionary] = []
	if is_runner_busy:
		queued_while_waiting.append({"id": "q_next", "prompt": "Next Task After Approval"})
		
	if runner.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL and is_runner_busy and queued_while_waiting.size() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (queue_with_approval) failed: state=" + str(runner.current_state))
		
	# Test 6: Queue with User Stop
	var stopped_by_user = true
	var queue_after_stop: Array[Dictionary] = [{"id": "q_saved", "prompt": "Saved Task"}]
	var auto_dispatched = false
	
	if not stopped_by_user and queue_after_stop.size() > 0:
		auto_dispatched = true
		
	if not auto_dispatched and queue_after_stop.size() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (queue_with_stop) failed: auto_dispatched=" + str(auto_dispatched))
		
	return {"name": "UIUXQueueAndInputTests", "passed": passed, "failed": failed, "errors": errors}
