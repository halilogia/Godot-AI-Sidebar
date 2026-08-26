@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

class MockStepProvider extends AISidebarAIProvider:
	var responses: Array = []
	var history: Array = []
	
	func send_chat(messages: Array, _tools_schema: Array) -> void:
		history.append(messages.duplicate(true))
		if responses.size() > 0:
			var r = responses.pop_front()
			response_received.emit(
				r.get("content", ""),
				r.get("thinking", ""),
				r.get("tool_calls", [])
			)
		else:
			response_received.emit("Bitti.", "", [])

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Varsayılan max_agent_steps = 20
	var def_cfg = AISidebarConfig.DEFAULT_CONFIG
	var runner1 = AISidebarAgentRunner.new(null, null)
	if def_cfg.get("max_agent_steps", 0) == 20 and runner1.max_steps == 20:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (Default max_agent_steps = 20) failed: cfg=" + str(def_cfg.get("max_agent_steps")) + " runner=" + str(runner1.max_steps))
		
	# Test 2: Doğal Erken Tamamlanma (Natural completion terminates early at Step 1)
	var prov2 = MockStepProvider.new()
	var ctx2 = AISidebarAgentContext.new()
	var runner2 = AISidebarAgentRunner.new(prov2, ctx2)
	prov2.responses = [
		{"content": "Merhaba! Ben hazırım.", "thinking": "", "tool_calls": []}
	]
	
	var completed_metrics = [{}]
	runner2.task_completed.connect(func(m): completed_metrics[0] = m)
	runner2.start_task("Selam")
	
	if runner2.current_state == AISidebarAgentRunner.AgentState.IDLE and prov2.history.size() == 1:
		var m = completed_metrics[0]
		if m.get("used_steps", 0) == 1 and m.get("max_steps", 0) == 20:
			passed += 1
		else:
			failed += 1
			errors.append("Test 2 (Telemetry step counts) failed: " + str(m))
	else:
		failed += 1
		errors.append("Test 2 (Natural early termination) failed: history_size=" + str(prov2.history.size()))
		
	# Test 3: Stagnation Detection Hala Devrede ve Görevi Sonlandırıyor (Stagnation guard)
	var prov3 = MockStepProvider.new()
	var ctx3 = AISidebarAgentContext.new()
	var runner3 = AISidebarAgentRunner.new(prov3, ctx3)
	prov3.responses = [
		{"content": "", "tool_calls": [{"name": "analyze_project", "id": "c1", "arguments": {}}]},
		{"content": "", "tool_calls": [{"name": "analyze_project", "id": "c2", "arguments": {}}]},
		{"content": "", "tool_calls": [{"name": "analyze_project", "id": "c3", "arguments": {}}]}
	]
	
	var err3_received = [false]
	runner3.error_occurred.connect(func(_e): err3_received[0] = true)
	runner3.start_task("Test stagnation")
	
	if err3_received[0] and runner3.current_step < runner3.max_steps:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (Stagnation termination) failed: step=" + str(runner3.current_step) + " max=" + str(runner3.max_steps))
		
	# Test 4: Maksimum Adım Sınırına Ulaşıldığında Güvenli Sonlanma (Max steps safety limit)
	var prov4 = MockStepProvider.new()
	var ctx4 = AISidebarAgentContext.new()
	var runner4 = AISidebarAgentRunner.new(prov4, ctx4)
	runner4.max_steps = 3 # Test için özel limit
	
	prov4.responses = [
		{"content": "", "tool_calls": [{"name": "analyze_project", "id": "c1", "arguments": {"p": 1}}]},
		{"content": "", "tool_calls": [{"name": "analyze_project", "id": "c2", "arguments": {"p": 2}}]},
		{"content": "", "tool_calls": [{"name": "analyze_project", "id": "c3", "arguments": {"p": 3}}]},
		{"content": "", "tool_calls": [{"name": "analyze_project", "id": "c4", "arguments": {"p": 4}}]}
	]
	
	var err4_received = [false]
	runner4.error_occurred.connect(func(_e): err4_received[0] = true)
	# start_task config'ten okuduğu için doğrudan adım döngüsünü tetikliyoruz:
	runner4.context.add_user_message("Infinite unique tools")
	runner4._set_state(AISidebarAgentRunner.AgentState.PLANNING)
	runner4._run_next_step()
	
	if err4_received[0] and runner4.current_step == 4: # 3 adım icra edildi, 4. adımda limit aşıldı ve durduruldu
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (Max steps termination) failed: err=" + str(err4_received[0]) + " step=" + str(runner4.current_step))
		
	# Test 5: Step Progress Sinyali Kontrolü (step_progress signal emitted)
	var prov5 = MockStepProvider.new()
	var ctx5 = AISidebarAgentContext.new()
	var runner5 = AISidebarAgentRunner.new(prov5, ctx5)
	
	var progress_data = []
	runner5.step_progress.connect(func(cur, mx): progress_data.append({"cur": cur, "max": mx}))
	prov5.responses = [
		{"content": "Step progress test", "tool_calls": []}
	]
	runner5.start_task("Progress test")
	
	if progress_data.size() == 1 and progress_data[0]["cur"] == 1 and progress_data[0]["max"] == 20:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (step_progress signal) failed: " + str(progress_data))
		
	return {"name": "MaxStepsAndTelemetryTests", "passed": passed, "failed": failed, "errors": errors}
