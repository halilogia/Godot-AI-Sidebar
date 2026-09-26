@tool
extends RefCounted
class_name AISidebarGoalTools

## `report_goal`: /goal modunda ajanın her turun sonunda hedefin durumunu bildirdiği araç. Salt okunur:
## hiçbir şeyi değiştirmez, argümanları doğrulayıp geri verir; hedef oturumu (AISidebarGoalSession)
## sonucu tool_completed sinyalinden okur. Yalnız hedef modunun istemi araç adını içerdiğinde sunulur;
## köprüde (MCP) açılmaz.

const AISidebarGoalSession = preload("res://addons/godot_sidebar_ai/core/agent/goal_session.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

const TOOL_NAME := AISidebarGoalSession.TOOL_NAME

static func get_schemas() -> Array:
	return [{
		"type": "function",
		"function": {
			"name": TOOL_NAME,
			"description": "Goal mode only: reports the state of the user's goal at the end of a round. status=achieved only when every part of the goal is met and verified (evidence required); in_progress with the next concrete step; blocked when the user is needed, with the reason.",
			"parameters": {
				"type": "object",
				"properties": {
					"status": {"type": "string", "enum": [AISidebarGoalSession.STATUS_ACHIEVED, AISidebarGoalSession.STATUS_IN_PROGRESS, AISidebarGoalSession.STATUS_BLOCKED]},
					"evidence": {"type": "string", "description": "What proves the finished parts (validated scripts, runtime errors checked, screenshot, node state)."},
					"next_step": {"type": "string", "description": "in_progress: the next concrete step. blocked: what you need from the user."},
				},
				"required": ["status", "evidence"],
			},
		},
	}]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != TOOL_NAME:
		return AISidebarToolResult.err("UNKNOWN_TOOL", "Unknown goal tool: " + tool_name)
	var status := str(args.get("status", ""))
	if status not in [AISidebarGoalSession.STATUS_ACHIEVED, AISidebarGoalSession.STATUS_IN_PROGRESS, AISidebarGoalSession.STATUS_BLOCKED]:
		return AISidebarToolResult.err("INVALID_STATUS", "status must be achieved, in_progress or blocked")
	var evidence := str(args.get("evidence", "")).strip_edges()
	if status == AISidebarGoalSession.STATUS_ACHIEVED and evidence.is_empty():
		return AISidebarToolResult.err("EVIDENCE_REQUIRED", "achieved needs evidence: say what you verified and how")
	var data := {"status": status, "evidence": evidence, "next_step": str(args.get("next_step", "")).strip_edges()}
	return AISidebarToolResult.ok(data, "Goal status recorded: " + status)
