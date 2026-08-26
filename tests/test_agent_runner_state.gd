@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var runner = AISidebarAgentRunner.new(null, null)
	
	# Test 1: Initial state is IDLE
	if runner.current_state == AISidebarAgentRunner.AgentState.IDLE and not runner.is_running():
		passed += 1
	else:
		failed += 1
		errors.append("Initial state should be IDLE")
		
	# Test 2: State changes
	runner._set_state(AISidebarAgentRunner.AgentState.PLANNING)
	if runner.is_running():
		passed += 1
	else:
		failed += 1
		errors.append("Runner should be running in PLANNING state")
		
	runner._set_state(AISidebarAgentRunner.AgentState.COMPLETED)
	if not runner.is_running():
		passed += 1
	else:
		failed += 1
		errors.append("Runner should NOT be running in COMPLETED state")
		
	return {"name": "AgentRunnerStateTests", "passed": passed, "failed": failed, "errors": errors}
