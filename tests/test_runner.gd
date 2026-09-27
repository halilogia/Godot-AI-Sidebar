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
const TestResponsePipeline = preload("res://tests/test_response_pipeline.gd")
const TestToolTermination = preload("res://tests/test_tool_termination.gd")
const TestToolDataIntegrity = preload("res://tests/test_tool_data_integrity.gd")
const TestAtomicScriptValidation = preload("res://tests/test_atomic_script_validation.gd")
const TestBatchAndTelemetry = preload("res://tests/test_batch_and_telemetry.gd")
const TestDependencyAwareBatch = preload("res://tests/test_dependency_aware_batch.gd")
const TestChangeSetAndNetworkTiming = preload("res://tests/test_changeset_and_network_timing.gd")
const TestURLNormalization = preload("res://tests/test_url_normalization.gd")
const TestUndoAndDialogUX = preload("res://tests/test_undo_and_dialog_ux.gd")
const TestUIComponents = preload("res://tests/test_ui_components.gd")
const TestChatExporter = preload("res://tests/test_chat_exporter.gd")
const TestFileDeletionAndSignals = preload("res://tests/test_file_deletion_and_signals.gd")
const TestRuntimeStateMachine = preload("res://tests/test_runtime_state_machine.gd")
const TestApprovalAndSelfHealing = preload("res://tests/test_approval_and_self_healing.gd")
const TestMaxStepsAndTelemetry = preload("res://tests/test_max_steps_and_telemetry.gd")
const TestDynamicToolFiltering = preload("res://tests/test_dynamic_tool_filtering.gd")
const TestSurgicalFileEditing = preload("res://tests/test_surgical_file_editing.gd")
const TestStreamingAndSSE = preload("res://tests/test_streaming_and_sse.gd")
const TestMentionManager = preload("res://tests/test_mention_manager.gd")
const TestContextCompactor = preload("res://tests/test_context_compactor.gd")
const TestSkillToolNames = preload("res://tests/test_skill_tool_names.gd")
const TestProjectSettingsTools = preload("res://tests/test_project_settings_tools.gd")
const TestLongTask = preload("res://tests/test_long_task.gd")
const TestNetworkRecovery = preload("res://tests/test_network_recovery.gd")
const TestViewportScreenshot = preload("res://tests/test_viewport_screenshot.gd")
const TestUIUXQueueAndInput = preload("res://tests/test_ui_ux_queue_and_input.gd")
const TestAgentClarification = preload("res://tests/test_agent_clarification.gd")
const TestChatManagement = preload("res://tests/test_chat_management.gd")
const TestTSCNVerification = preload("res://tests/test_tscn_verification.gd")
const TestAutoApprove = preload("res://tests/test_auto_approve.gd")
const TestSlashCommands = preload("res://tests/test_slash_commands.gd")
const TestAGYCLIProvider = preload("res://tests/test_agy_cli_provider.gd")
const TestUITelemetry = preload("res://tests/test_ui_telemetry.gd")
const TestRuntimeInspection = preload("res://tests/test_runtime_inspection.gd")
const TestImplementationPlanning = preload("res://tests/test_implementation_planning.gd")
const TestStreamEnvelopeGuard = preload("res://tests/test_stream_envelope_guard.gd")
const TestActivityProgressUX = preload("res://tests/test_activity_progress_ux.gd")
const TestEverythingExport = preload("res://tests/test_everything_export.gd")
const TestCopyTaskChecklist = preload("res://tests/test_copy_task_checklist.gd")
const TestPerformanceTelemetry = preload("res://tests/test_performance_telemetry.gd")
const TestBenchmarkReadiness = preload("res://tests/test_benchmark_readiness.gd")
const TestTaskCopyOrder = preload("res://tests/test_task_copy_order.gd")
const TestCopyChat = preload("res://tests/test_copy_chat.gd")
const TestMultiToolAndSceneGuard = preload("res://tests/test_multi_tool_and_scene_guard.gd")
const TestSceneReliability = preload("res://tests/test_scene_reliability.gd")
const TestSceneStateSync = preload("res://tests/test_scene_state_sync.gd")
const TestRuntimeVisionChain = preload("res://tests/test_runtime_vision_chain.gd")
const TestPauseResume = preload("res://tests/test_pause_resume.gd")
const TestChatImageUX = preload("res://tests/test_chat_image_ux.gd")
const TestHistoryExport = preload("res://tests/test_history_export.gd")
const TestReasoningUI = preload("res://tests/test_reasoning_ui.gd")
const TestExportCoverage = preload("res://tests/test_export_coverage.gd")
const TestTypecheckGuard = preload("res://tests/test_typecheck_guard.gd")
const TestCompletionIntegrity = preload("res://tests/test_completion_integrity.gd")
const TestDebuggerLink = preload("res://tests/test_debugger_link.gd")
const TestPlanChecklistTracker = preload("res://tests/test_plan_checklist_tracker.gd")
const TestChatExportActions = preload("res://tests/test_chat_export_actions.gd")
const TestChatSessionStore = preload("res://tests/test_chat_session_store.gd")
const TestSessionReplay = preload("res://tests/test_session_replay.gd")
const TestIconSystem = preload("res://tests/test_icon_system.gd")
const TestDockAgentWiring = preload("res://tests/test_dock_agent_wiring.gd")
const TestModelBarController = preload("res://tests/test_model_bar_controller.gd")
const TestTaskDispatch = preload("res://tests/test_task_dispatch.gd")
const TestProviderComposition = preload("res://tests/test_provider_composition.gd")
const TestAgentTelemetry = preload("res://tests/test_agent_telemetry.gd")
const TestPendingInteraction = preload("res://tests/test_pending_interaction.gd")
const TestProviderResponse = preload("res://tests/test_provider_response.gd")
const TestRunnerIndependence = preload("res://tests/test_runner_independence.gd")
const TestRuntimeOwnership = preload("res://tests/test_runtime_ownership.gd")
const TestMarkdownRenderer = preload("res://tests/test_markdown_renderer.gd")
const TestDocsCoverage = preload("res://tests/test_docs_coverage.gd")
const TestLineBudget = preload("res://tests/test_line_budget.gd")
const TestStaticReferences = preload("res://tests/test_static_references.gd")
const TestI18n = preload("res://tests/test_i18n.gd")
const TestMcpBridge = preload("res://tests/test_mcp_bridge.gd")
const TestWriterLock = preload("res://tests/test_writer_lock.gd")
const TestValidateOwnClassName = preload("res://tests/test_validate_own_class_name.gd")
const TestLogRotation = preload("res://tests/test_log_rotation.gd")
const TestSkills = preload("res://tests/test_skills.gd")
const TestRuntimeScriptVars = preload("res://tests/test_runtime_script_vars.gd")
const TestRuntimeInput = preload("res://tests/test_runtime_input.gd")
const TestSettingsCoverage = preload("res://tests/test_settings_coverage.gd")
const TestUiQuality = preload("res://tests/test_ui_quality.gd")
const TestGoal = preload("res://tests/test_goal.gd")
const TestHelp = preload("res://tests/test_help.gd")
const TestBugReport = preload("res://tests/test_bug_report.gd")
const TestContextBudget = preload("res://tests/test_context_budget.gd")
const TestProjectValidator = preload("res://tests/test_project_validator.gd")
const TestRewind = preload("res://tests/test_rewind.gd")
const TestApiTools = preload("res://tests/test_api_tools.gd")
const TestNotifier = preload("res://tests/test_notifier.gd")
const TestEditorScreenshot = preload("res://tests/test_editor_screenshot.gd")
const TestConfigSafety = preload("res://tests/test_config_safety.gd")

## Test izolasyonu: testler geliştiricinin kişisel ayar dosyalarını (config.json ve yedekleri:
## .bak / .corrupt / .tmp) görmez; CI'daki gibi ayarsız (varsayılanlar: MANUAL, TR) koşar. Dosyalar koşu
## başında git'e girmeyen .test_config_backup/ klasörüne taşınır, sonunda bayt bayt geri konur; testlerin
## yazdıkları silinir. Koşu yarıda çökerse klasör kalır; bir sonraki koşu başlarken önce o geri yüklenir.
const USER_CONFIG_FILES: Array[String] = [
	"res://addons/godot_sidebar_ai/config.json",
	"res://addons/godot_sidebar_ai/config.json.bak",
	"res://addons/godot_sidebar_ai/config.json.corrupt",
	"res://addons/godot_sidebar_ai/config.json.tmp",
]
const CONFIG_BACKUP_DIR = "res://.test_config_backup"
## Eski sürümün user:// yedeği (bir kez geri yüklenip kaldırılır).
const LEGACY_BACKUP = "user://test_runner_user_config.backup"

static func isolate_user_config() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(CONFIG_BACKUP_DIR)):
		restore_user_config()
	if FileAccess.file_exists(LEGACY_BACKUP):
		var legacy := FileAccess.get_file_as_bytes(LEGACY_BACKUP)
		var lf := FileAccess.open(USER_CONFIG_FILES[0], FileAccess.WRITE)
		lf.store_buffer(legacy)
		lf.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_BACKUP))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONFIG_BACKUP_DIR))
	# Editör bu klasörü taramasın.
	var gi := FileAccess.open(CONFIG_BACKUP_DIR.path_join(".gdignore"), FileAccess.WRITE)
	gi.close()
	for path: String in USER_CONFIG_FILES:
		if FileAccess.file_exists(path):
			var bytes := FileAccess.get_file_as_bytes(path)
			var f := FileAccess.open(CONFIG_BACKUP_DIR.path_join(path.get_file()), FileAccess.WRITE)
			f.store_buffer(bytes)
			f.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func restore_user_config() -> void:
	var backup_dir := ProjectSettings.globalize_path(CONFIG_BACKUP_DIR)
	if not DirAccess.dir_exists_absolute(backup_dir):
		return
	for path: String in USER_CONFIG_FILES:
		var saved := CONFIG_BACKUP_DIR.path_join(path.get_file())
		if FileAccess.file_exists(saved):
			var bytes := FileAccess.get_file_as_bytes(saved)
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(bytes)
			f.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(saved))
		elif FileAccess.file_exists(path):
			# Başta bu dosya yoktu; testlerin yazdığı kalmasın.
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG_BACKUP_DIR.path_join(".gdignore")))
	DirAccess.remove_absolute(backup_dir)

func _init() -> void:
	print("==================================================")
	print("   GODOT AI CORE v2.0 - MASTER UNIT TESTS        ")
	print("==================================================")
	isolate_user_config()

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
		TestPluginResources,
		TestResponsePipeline,
		TestToolTermination,
		TestToolDataIntegrity,
		TestAtomicScriptValidation,
		TestBatchAndTelemetry,
		TestDependencyAwareBatch,
		TestChangeSetAndNetworkTiming,
		TestURLNormalization,
		TestUndoAndDialogUX,
		TestUIComponents,
		TestChatExporter,
		TestFileDeletionAndSignals,
		TestRuntimeStateMachine,
		TestApprovalAndSelfHealing,
		TestMaxStepsAndTelemetry,
		TestDynamicToolFiltering,
		TestSurgicalFileEditing,
		TestStreamingAndSSE,
		TestMentionManager,
		TestContextCompactor,
		TestSkillToolNames,
		TestProjectSettingsTools,
		TestLongTask,
		TestNetworkRecovery,
		TestViewportScreenshot,
		TestUIUXQueueAndInput,
		TestAgentClarification,
		TestChatManagement,
		TestTSCNVerification,
		TestAutoApprove,
		TestSlashCommands,
		TestAGYCLIProvider,
		TestUITelemetry,
		TestRuntimeInspection,
		TestImplementationPlanning,
		TestStreamEnvelopeGuard,
		TestActivityProgressUX,
		TestEverythingExport,
		TestCopyTaskChecklist,
		TestPerformanceTelemetry,
		TestBenchmarkReadiness,
		TestTaskCopyOrder,
		TestCopyChat,
		TestMultiToolAndSceneGuard,
		TestSceneReliability,
		TestSceneStateSync,
		TestRuntimeVisionChain,
		TestPauseResume,
		TestChatImageUX,
		TestHistoryExport,
		TestDebuggerLink,
		TestPlanChecklistTracker,
		TestChatExportActions,
		TestChatSessionStore,
		TestSessionReplay,
		TestIconSystem,
		TestDockAgentWiring,
		TestModelBarController,
		TestTaskDispatch,
		TestProviderComposition,
		TestAgentTelemetry,
		TestPendingInteraction,
		TestProviderResponse,
		TestRunnerIndependence,
		TestRuntimeOwnership,
		TestMarkdownRenderer,
		TestDocsCoverage,
		TestLineBudget,
		TestStaticReferences,
		TestI18n,
		TestMcpBridge,
		TestWriterLock,
		TestValidateOwnClassName,
		TestLogRotation,
		TestSkills,
		TestRuntimeScriptVars,
		TestRuntimeInput,
		TestSettingsCoverage,
		TestUiQuality,
		TestGoal,
		TestHelp,
		TestBugReport,
		TestContextBudget,
		TestProjectValidator,
		TestRewind,
		TestApiTools,
		TestNotifier,
		TestEditorScreenshot,
		TestConfigSafety,
		TestReasoningUI,
		TestExportCoverage,
		TestTypecheckGuard,
		TestCompletionIntegrity
	]
	
	var total_passed = 0
	var total_failed = 0
	
	for suite in suites:
		# Derlenemeyen paket `run()` taşımaz; çağırmak _init'i yarıda keser, runner quit()'e ve
		# config geri yüklemesine hiç ulaşmaz. Böyle paket boş sonuç sayılır (aşağıda FAIL olur).
		var runnable := false
		for m in (suite as Script).get_script_method_list():
			if str(m.get("name", "")) == "run":
				runnable = true
		var res: Dictionary = suite.run() if runnable else {}
		var s_name = res.get("name", "Unknown")
		var s_pass = res.get("passed", 0)
		var s_fail = res.get("failed", 0)
		var s_errs = res.get("errors", [])
		# Fail-closed: run() çalışma anında çökerse GDScript boş sonuç döndürür
		# ("Unknown 0/0"). Sonuç yoksa veya hiç assertion koşmadıysa paket başarısızdır.
		if not res.has("name") or s_pass + s_fail == 0:
			s_name = str(res.get("name", suite.resource_path.get_file()))
			s_fail = 1
			s_errs = ["Suite crashed or ran no assertions (see SCRIPT ERROR above)."]

		total_passed += s_pass
		total_failed += s_fail
		
		if s_fail == 0:
			print(" [PASS] " + s_name + " (" + str(s_pass) + "/" + str(s_pass + s_fail) + " passed)")
		else:
			print(" [FAIL] " + s_name + " (" + str(s_fail) + " FAILED):")
			for e in s_errs:
				print("   - " + str(e))
				
	restore_user_config()
	print("--------------------------------------------------")
	if total_failed == 0:
		print("🎉 ALL TESTS PASSED! Total: " + str(total_passed) + " assertions.")
		quit(0)
	else:
		print("❌ TEST SUITE FAILED! Passed: " + str(total_passed) + ", Failed: " + str(total_failed))
		quit(1)
