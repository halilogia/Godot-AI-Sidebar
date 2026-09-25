@tool
extends RefCounted

## ChatDock ↔ AgentRunner sinyal bağlantıları (editörde kurulur, headless'ta normalde hiç
## çalışmaz). Gerçek AgentHost/AgentRunner ile attach_agent_host() kurulur ve her sinyal
## yayınlanır: yanlış handler / argüman sayısı / kopuk presenter bağlantısı burada yakalanır.

const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentHost = preload("res://addons/godot_sidebar_ai/core/agent/agent_host.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarImplementationPlan = preload("res://addons/godot_sidebar_ai/core/types/implementation_plan.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarThinkingCard = preload("res://addons/godot_sidebar_ai/ui/components/thinking_card.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarApprovalCard = preload("res://addons/godot_sidebar_ai/ui/components/approval_card.gd")
const AISidebarClarificationCard = preload("res://addons/godot_sidebar_ai/ui/components/clarification_card.gd")
const AISidebarPlanCard = preload("res://addons/godot_sidebar_ai/ui/components/plan_card.gd")
const AISidebarChangesCard = preload("res://addons/godot_sidebar_ai/ui/components/changes_card.gd")
const AISidebarRuntimeCard = preload("res://addons/godot_sidebar_ai/ui/components/runtime_card.gd")
const AISidebarTelemetryCard = preload("res://addons/godot_sidebar_ai/ui/components/telemetry_card.gd")
const AISidebarErrorCard = preload("res://addons/godot_sidebar_ai/ui/components/error_card.gd")

class SilentProvider extends AISidebarAIProvider:
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		pass

static func _count(dock, script) -> int:
	var n = 0
	for child in dock.message_stream.get_children():
		if child.get_script() == script:
			n += 1
	return n

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	var dock = ChatDockScene.instantiate()
	dock._ready()
	dock._auto_scroll_enabled = false
	for child in dock.message_stream.get_children():
		child.free()
	# _ready'nin editör yolundaki bağlama ile aynı (host plugin.gd yerine burada kurulur)
	var host = AISidebarAgentHost.new()
	host.set_provider(SilentProvider.new())
	dock.attach_agent_host(host)
	var ctx = host.context
	var runner = host.runner

	# 1. Her sinyalin bir dinleyicisi var (bağlantı listesi eksiksiz)
	var expected = ["state_changed", "thinking_received", "chunk_received", "text_received",
		"tool_executing", "tool_completed", "approval_requested", "clarification_requested",
		"plan_proposed", "changes_applied", "verification_started", "verification_completed",
		"runtime_observation_received", "debugging_started", "error_occurred", "task_completed", "step_progress"]
	var unconnected: Array = []
	for sig in expected:
		if runner.get_signal_connection_list(sig).is_empty():
			unconnected.append(sig)
	if unconnected.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T1 (all signals connected) failed: " + str(unconnected))

	# 2. Sinyaller yayınlanınca doğru presenter doğru kartı üretir
	runner.state_changed.emit(AISidebarAgentRunner.AgentState.PLANNING, "")
	runner.thinking_received.emit("Plan düşünülüyor")
	runner.chunk_received.emit("Cevap", "")
	runner.text_received.emit("assistant", "Cevap tamam")
	runner.tool_executing.emit("read_script", {"path": "res://a.gd"})
	runner.tool_completed.emit("read_script", {"success": true, "data": {}, "message": "ok"})
	runner.verification_started.emit("validate_script")
	runner.verification_completed.emit("validate_script", true, "ok")
	runner.debugging_started.emit("null instance")
	runner.step_progress.emit(2, 20)
	runner.runtime_observation_received.emit(AISidebarRuntimeObservation.new())
	runner.approval_requested.emit("delete_file", {"file_path": "res://x.gd"}, null)
	runner.clarification_requested.emit("Hangi tuş?", ["Space"], "cid")
	runner.plan_proposed.emit(AISidebarImplementationPlan.new({"goal": "Zıpla", "steps": ["Kod yaz"], "verification": ["Oyunu çalıştır"]}))
	runner.changes_applied.emit(AISidebarChangeSet.new("res://y.gd"))
	runner.task_completed.emit({"success": true, "elapsed_seconds": 1.0})
	runner.error_occurred.emit("Bağlantı hatası")
	dock._stream.stop_thinking_timer()

	var counts = {
		"thinking": _count(dock, AISidebarThinkingCard), "bubble": _count(dock, AISidebarMessageBubble),
		"activity": _count(dock, AISidebarActivityGroup), "approval": _count(dock, AISidebarApprovalCard),
		"clarification": _count(dock, AISidebarClarificationCard), "plan": _count(dock, AISidebarPlanCard),
		"changes": _count(dock, AISidebarChangesCard), "runtime": _count(dock, AISidebarRuntimeCard),
		"telemetry": _count(dock, AISidebarTelemetryCard), "error": _count(dock, AISidebarErrorCard),
	}
	var missing: Array = []
	for k in counts:
		if counts[k] < 1:
			missing.append(k)
	if missing.is_empty() and dock.status_badge.text != "":
		passed += 1
	else:
		failed += 1
		errors.append("T2 (signals render cards) failed: missing=%s counts=%s" % [str(missing), str(counts)])

	# 3. Onay ve plan kararları karttan transcript'e ve checklist'e ulaşır
	ctx.begin_task("Karar testi", "")
	dock._interaction._on_approve_pressed()
	dock._interaction._on_plan_applied()
	var types: Array = []
	for e in ctx.get_transcript().get_current_task().get("events", []):
		types.append(str(e.get("t", "")))
	var approved = dock._interaction.approval_card.is_resolved
	if "approval_granted" in types and "plan_approved" in types and approved and dock._checklist_tracker.has_checklist():
		passed += 1
	else:
		failed += 1
		errors.append("T3 (decisions) failed: events=%s approved=%s checklist=%s" % [str(types), str(approved), str(dock._checklist_tracker.has_checklist())])

	for child in dock.message_stream.get_children():
		child.free()
	dock.free()
	host.free()
	return {"name": "DockAgentWiringTests", "passed": passed, "failed": failed, "errors": errors}
