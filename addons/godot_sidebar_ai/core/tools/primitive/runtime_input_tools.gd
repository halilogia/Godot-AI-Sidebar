@tool
extends RefCounted
class_name AISidebarRuntimeInputTools

## `send_input`: çalışan oyuna tuş, input action ya da fare tıklaması gönderir (debugger kanalı →
## oyundaki RuntimeBridge → AISidebarRuntimeInput). Yalnız editörden başlatılmış oyuna gider,
## proje dosyalarına dokunmaz; yazıcı kilidine tabi değildir (oyun kontrolü, play_game gibi).

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarDebuggerPlugin = preload("res://addons/godot_sidebar_ai/core/runtime/debugger_plugin.gd")

const TOOL_NAME := "send_input"
const MAX_HOLD_MSEC := 2000

static func get_schemas() -> Array:
	return [{
		"type": "function",
		"function": {
			"name": TOOL_NAME,
			"description": "Sends input to the running game (play_game first): a key press, an input action, or a mouse click. Prefer clicking by node_path (a Control's center, a Node2D's position, or a Node3D projected through the active camera); otherwise give x and y as fractions of the game view (screenshot pixel / screenshot width or height). Clicks reach GUI and _input/_unhandled_input; Area2D/3D picking also needs physics_object_picking on the viewport. Check the effect afterwards with take_runtime_screenshot or inspect_runtime_node.",
			"parameters": {
				"type": "object",
				"properties": {
					"kind": {"type": "string", "enum": ["key", "action", "click"], "description": "What to send."},
					"key": {"type": "string", "description": "For kind=key: key name, e.g. Space, Escape, Enter, A, 1, Up, F1."},
					"action": {"type": "string", "description": "For kind=action: an input action defined in the project's Input Map."},
					"node_path": {"type": "string", "description": "For kind=click: path of the node to click in the running game (e.g. 'Main/UI/StartButton')."},
					"x": {"type": "number", "description": "For kind=click without node_path: horizontal position as a fraction of the game view (0.0 to 1.0)."},
					"y": {"type": "number", "description": "For kind=click without node_path: vertical position as a fraction of the game view (0.0 to 1.0)."},
					"button": {"type": "string", "enum": ["left", "right"], "description": "Mouse button for kind=click (default: left)."},
					"hold_ms": {"type": "integer", "description": "How long to hold the key / action / button, in milliseconds (default 80, max 2000)."},
				},
				"required": ["kind"],
			},
		},
	}]

## Oyun ve debugger hazır mı; değilse hata sonucu, hazırsa {}.
static func readiness_error() -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "send_input needs the Godot editor.")
	if not EditorInterface.is_playing_scene():
		return AISidebarToolResult.err("GAME_NOT_RUNNING", "The game is not running; call play_game first.")
	var dbg := AISidebarDebuggerPlugin.instance
	if dbg == null or not dbg.has_active_session():
		return AISidebarToolResult.err("DEBUGGER_NOT_CONNECTED", "The game is running but its debugger session is not connected yet; retry in a second.")
	return {}

## Argümanları doğrular ve oyuna gidecek sade sözlüğe çevirir. Dönüş: {"spec"} ya da {"error": ToolResult}.
static func build_spec(args: Dictionary) -> Dictionary:
	var kind := str(args.get("kind", ""))
	if not kind in ["key", "action", "click"]:
		return {"error": AISidebarToolResult.err("INVALID_ARGUMENT", "kind must be key, action or click.")}
	var spec := {"kind": kind, "hold_ms": clampi(int(str(args.get("hold_ms", 80)).to_float()), 0, MAX_HOLD_MSEC)}
	match kind:
		"key":
			if str(args.get("key", "")).strip_edges().is_empty():
				return {"error": AISidebarToolResult.err("INVALID_ARGUMENT", "kind=key needs key.")}
			spec["key"] = str(args["key"])
		"action":
			if str(args.get("action", "")).strip_edges().is_empty():
				return {"error": AISidebarToolResult.err("INVALID_ARGUMENT", "kind=action needs action.")}
			spec["action"] = str(args["action"])
		"click":
			if not str(args.get("node_path", "")).strip_edges().is_empty():
				spec["node_path"] = str(args["node_path"])
			elif args.has("x") and args.has("y"):
				spec["x"] = str(args["x"]).to_float()
				spec["y"] = str(args["y"]).to_float()
			else:
				return {"error": AISidebarToolResult.err("INVALID_ARGUMENT", "kind=click needs node_path, or x and y (fractions 0.0 to 1.0).")}
			spec["button"] = "right" if str(args.get("button", "left")) == "right" else "left"
	return {"spec": spec}

static func execute_async(args: Dictionary) -> Dictionary:
	var built := build_spec(args)
	if built.has("error"):
		return built["error"]
	var not_ready := readiness_error()
	if not not_ready.is_empty():
		return not_ready
	var spec: Dictionary = built["spec"]
	var hold_ms: int = spec["hold_ms"]
	var hold_sec := hold_ms / 1000.0
	var resp: Dictionary = await AISidebarDebuggerPlugin.instance.query_with_ready_check("send_input", [spec], 1.0, 3.0 + hold_sec)
	if resp.get("success", false) != true:
		return AISidebarToolResult.err(str(resp.get("error", "SEND_INPUT_FAILED")), str(resp.get("message", "The input could not be delivered to the game.")))
	return AISidebarToolResult.ok(resp, "Input sent: " + str(spec["kind"]))
