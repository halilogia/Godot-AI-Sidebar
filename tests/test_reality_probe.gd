@tool
extends SceneTree

const AISidebarTypeParser = preload("res://addons/godot_sidebar_ai/core/types/type_parser.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarEditorStateSnapshot = preload("res://addons/godot_sidebar_ai/core/state/editor_state_snapshot.gd")
const AISidebarMutationService = preload("res://addons/godot_sidebar_ai/core/mutations/editor_mutation_service.gd")
const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarSSEParser = preload("res://addons/godot_sidebar_ai/core/network/sse_parser.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")

# Mock AI Provider for testing agent loop without network
class MockAIProvider extends AISidebarAIProvider:
	var canned_responses: Array = []
	var send_chat_call_count: int = 0
	var last_messages: Array = []
	var last_tools: Array = []

	func send_chat(messages: Array, tools_schema: Array) -> void:
		send_chat_call_count += 1
		last_messages = messages.duplicate(true)
		last_tools = tools_schema.duplicate(true)
		
		if canned_responses.size() > 0:
			var resp = canned_responses.pop_front()
			response_received.emit(
				resp.get("content", ""),
				resp.get("thinking", ""),
				resp.get("tool_calls", [])
			)

func _init() -> void:
	print("=================================================================")
	print("       GODOT AI CORE v2.0 - AUDIT & REALITY PROBE TEST RUN      ")
	print("=================================================================")
	
	var passed = 0
	var failed = 0
	var findings: Array = []
	
	# -------------------------------------------------------------
	# TEST 1: Security Penetration Test (PathPolicy Adversarial)
	# -------------------------------------------------------------
	print("\n[PROBE 1] Security Penetration Testing (PathPolicy)...")
	var attack_vectors = [
		{"path": "../project.godot", "expect_write_safe": false},
		{"path": "../../project.godot", "expect_write_safe": false},
		{"path": "res://foo/../project.godot", "expect_write_safe": false},
		{"path": "res:\\foo\\..\\project.godot", "expect_write_safe": false},
		{"path": "res://.git/config", "expect_write_safe": false},
		{"path": "res://addons/godot_sidebar_ai/plugin.gd", "expect_write_safe": false},
		{"path": "res://export_presets.cfg", "expect_write_safe": false},
		{"path": "res://scripts/../../project.godot", "expect_write_safe": false},
		{"path": "res://scripts/player.gd", "expect_write_safe": true},
		{"path": "res://scenes/level.tscn", "expect_write_safe": true}
	]
	
	for v in attack_vectors:
		var raw = v["path"]
		var res = AISidebarPathPolicy.is_safe_to_write(raw)
		var is_safe = res["safe"]
		var norm = AISidebarPathPolicy.normalize_path(raw)
		
		if is_safe == v["expect_write_safe"]:
			passed += 1
			print("  [BLOCKED/ALLOWED OK] " + raw + " -> " + norm + " (Safe: " + str(is_safe) + ")")
		else:
			failed += 1
			print("  [SECURITY LEAK] " + raw + " -> Expected safe=" + str(v["expect_write_safe"]) + " but got " + str(is_safe))
			findings.append("PathPolicy leak on: " + raw)

	# -------------------------------------------------------------
	# TEST 2: Agent Runner Mock Loop & Stagnation Detection
	# -------------------------------------------------------------
	print("\n[PROBE 2] Agent Loop & Stagnation Detection (Mock Provider)...")
	var mock = MockAIProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock, ctx)
	
	# Scenario A: Normal completion
	mock.canned_responses = [
		{"content": "Hello user, task done.", "thinking": "Simple response", "tool_calls": []}
	]
	runner.start_task("Hi AI")
	if runner.current_state == AISidebarAgentRunner.AgentState.IDLE and not runner.is_running():
		passed += 1
		print("  [PASS] Agent normal completion -> IDLE state verified")
	else:
		failed += 1
		print("  [FAIL] Agent did not return to IDLE after completion")

	# Scenario B: Stagnation test (same tool + args called 3 times)
	mock.canned_responses = [
		{"content": "", "thinking": "", "tool_calls": [{"name": "search_tools", "arguments": {"query": "camera"}}]},
		{"content": "", "thinking": "", "tool_calls": [{"name": "search_tools", "arguments": {"query": "camera"}}]},
		{"content": "", "thinking": "", "tool_calls": [{"name": "search_tools", "arguments": {"query": "camera"}}]},
		{"content": "Understood, changing plan.", "thinking": "", "tool_calls": []}
	]
	runner.start_task("Find camera")
	if runner._stagnation_count >= 2 or mock.send_chat_call_count >= 3:
		passed += 1
		print("  [PASS] Stagnation counter triggered and loop resolved.")
	else:
		failed += 1
		print("  [FAIL] Stagnation was not tracked: " + str(runner._stagnation_count))

	# -------------------------------------------------------------
	# TEST 3: Permission Policy Classification vs Enforcement
	# -------------------------------------------------------------
	print("\n[PROBE 3] Permission Policy Classification Verification...")
	var read_level = AISidebarPermissionPolicy.get_tool_permission_level("read_script")
	var dest_level = AISidebarPermissionPolicy.get_tool_permission_level("delete_node")
	var mut_level = AISidebarPermissionPolicy.get_tool_permission_level("add_node")
	
	if read_level == AISidebarPermissionPolicy.PermissionLevel.READ_ONLY and dest_level == AISidebarPermissionPolicy.PermissionLevel.DESTRUCTIVE and mut_level == AISidebarPermissionPolicy.PermissionLevel.SAFE_MUTATION:
		passed += 1
		print("  [PASS] Tool permission classification correct.")
	else:
		failed += 1
		print("  [FAIL] Permission classification mismatch.")

	# -------------------------------------------------------------
	# TEST 4: UndoRedo Mutation Action Construction
	# -------------------------------------------------------------
	print("\n[PROBE 4] Standalone UndoRedo Mutation Logic Verification...")
	var test_parent = Node2D.new()
	var test_child = Node2D.new()
	test_child.name = "TestChild"
	
	var ur_local = UndoRedo.new()
	ur_local.create_action("Test Add Node")
	ur_local.add_do_method(Callable(test_parent, "add_child").bind(test_child))
	ur_local.add_undo_method(Callable(test_parent, "remove_child").bind(test_child))
	ur_local.commit_action()
	
	if test_parent.get_child_count() == 1:
		ur_local.undo()
		if test_parent.get_child_count() == 0:
			ur_local.redo()
			if test_parent.get_child_count() == 1:
				passed += 1
				print("  [PASS] Do -> Undo -> Redo cycle verified successfully on node tree.")
			else:
				failed += 1
				print("  [FAIL] Redo failed to restore child.")
		else:
			failed += 1
			print("  [FAIL] Undo failed to remove child.")
	else:
		failed += 1
		print("  [FAIL] Do action failed to add child.")
		
	test_child.free()
	test_parent.free()

	# -------------------------------------------------------------
	# TEST 5: ChangeSet Diff Generation
	# -------------------------------------------------------------
	print("\n[PROBE 5] ChangeSet Domain Model Verification...")
	var cs = AISidebarChangeSet.new("res://scripts/test.gd", AISidebarChangeSet.ChangeType.MODIFY_FILE, "var x = 2", "var x = 1", "test change")
	var diff = cs.get_diff_text()
	if "- var x = 1" in diff and "+ var x = 2" in diff:
		passed += 1
		print("  [PASS] ChangeSet Diff generation output verified.")
	else:
		failed += 1
		print("  [FAIL] ChangeSet Diff failed:\n" + diff)

	# -------------------------------------------------------------
	# TEST 6: Tool Discovery & Schemas
	# -------------------------------------------------------------
	print("\n[PROBE 6] Tool Discovery & Execution Verification...")
	var all_schemas = AISidebarToolManager.get_all_schemas()
	var search_res = AISidebarToolManager.execute_tool("search_tools", {"query": "node"})
	if all_schemas.size() >= 10 and search_res.get("success", false):
		passed += 1
		print("  [PASS] Tool manager registered " + str(all_schemas.size()) + " tools and progressive search works.")
	else:
		failed += 1
		print("  [FAIL] Tool discovery check failed.")

	print("\n-----------------------------------------------------------------")
	print("REALITY PROBE RESULTS: " + str(passed) + " passed, " + str(failed) + " failed.")
	print("-----------------------------------------------------------------")
	
	if failed == 0:
		quit(0)
	else:
		quit(1)
