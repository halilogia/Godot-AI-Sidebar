@tool
extends SceneTree

const TestTypeParser = preload("res://tests/test_type_parser.gd")
const TestPathPolicy = preload("res://tests/test_path_policy.gd")
const TestChangeSet = preload("res://tests/test_change_set.gd")
const TestSSEParser = preload("res://tests/test_sse_parser.gd")
const TestToolManager = preload("res://tests/test_tool_manager.gd")
const TestAgentContext = preload("res://tests/test_agent_context.gd")
const TestAgentRunnerState = preload("res://tests/test_agent_runner_state.gd")
const TestPermissionEnforcement = preload("res://tests/test_permission_enforcement.gd")
const TestVerificationPipeline = preload("res://tests/test_verification_pipeline.gd")
const TestAgentApprovalState = preload("res://tests/test_agent_approval_state.gd")
const TestVisionInput = preload("res://tests/test_vision_input.gd")
const TestRuntimeObservation = preload("res://tests/test_runtime_observation.gd")
const TestSourceMapper = preload("res://tests/test_source_mapper.gd")
const TestRuntimeRecovery = preload("res://tests/test_runtime_recovery.gd")
const TestMultimodalProvider = preload("res://tests/test_multimodal_provider.gd")
const TestVisualObservation = preload("res://tests/test_visual_observation.gd")
const TestDiagnosisContext = preload("res://tests/test_diagnosis_context.gd")
const TestExtendedVerification = preload("res://tests/test_extended_verification.gd")
const TestVisualHealingLoop = preload("res://tests/test_visual_healing_loop.gd")
const TestEditorGrounding = preload("res://tests/test_editor_grounding.gd")
const TestAssetDiscovery = preload("res://tests/test_asset_discovery.gd")
const TestMultiChangeSet = preload("res://tests/test_multi_changeset.gd")
const TestRealUserScenarios = preload("res://tests/test_real_user_scenarios.gd")
const TestPluginResources = preload("res://tests/test_plugin_resources.gd")

func _init() -> void:
	print("==================================================")
	print("   GODOT AI CORE v2.0 - MASTER UNIT TESTS        ")
	print("==================================================")
	
	var suites = [
		TestTypeParser,
		TestPathPolicy,
		TestChangeSet,
		TestSSEParser,
		TestToolManager,
		TestAgentContext,
		TestAgentRunnerState,
		TestPermissionEnforcement,
		TestVerificationPipeline,
		TestAgentApprovalState,
		TestVisionInput,
		TestRuntimeObservation,
		TestSourceMapper,
		TestRuntimeRecovery,
		TestMultimodalProvider,
		TestVisualObservation,
		TestDiagnosisContext,
		TestExtendedVerification,
		TestVisualHealingLoop,
		TestEditorGrounding,
		TestAssetDiscovery,
		TestMultiChangeSet,
		TestRealUserScenarios,
		TestPluginResources
	]
	
	var total_passed = 0
	var total_failed = 0
	
	for suite in suites:
		var res: Dictionary = suite.run()
		var s_name = res.get("name", "Unknown")
		var s_pass = res.get("passed", 0)
		var s_fail = res.get("failed", 0)
		var s_errs = res.get("errors", [])
		
		total_passed += s_pass
		total_failed += s_fail
		
		if s_fail == 0:
			print(" [PASS] " + s_name + " (" + str(s_pass) + "/" + str(s_pass + s_fail) + " passed)")
		else:
			print(" [FAIL] " + s_name + " (" + str(s_fail) + " FAILED):")
			for e in s_errs:
				print("   - " + str(e))
				
	print("--------------------------------------------------")
	if total_failed == 0:
		print("🎉 ALL TESTS PASSED! Total: " + str(total_passed) + " assertions.")
		quit(0)
	else:
		print("❌ TEST SUITE FAILED! Passed: " + str(total_passed) + ", Failed: " + str(total_failed))
		quit(1)
