@tool
extends RefCounted

const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var ctx = AISidebarAgentContext.new()
	
	# Test 1: User message with grounding
	ctx.add_user_message("Hello AI", false)
	if ctx.size() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Context size mismatch: " + str(ctx.size()))
		
	# Test 2: Assistant message
	ctx.add_assistant_message("Hello User")
	if ctx.size() == 2:
		passed += 1
	else:
		failed += 1
		errors.append("Context size mismatch after assistant message")
		
	# Test 3: Clear
	ctx.clear()
	if ctx.size() == 0:
		passed += 1
	else:
		failed += 1
		errors.append("Context clear failed")
		
	return {"name": "AgentContextTests", "passed": passed, "failed": failed, "errors": errors}
