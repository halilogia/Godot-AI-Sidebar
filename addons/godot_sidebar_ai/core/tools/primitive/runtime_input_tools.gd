@tool
extends RefCounted
class_name AISidebarRuntimeInputTools

## `send_input`: çalışan oyuna tuş, input action ya da fare tıklaması gönderir; `steps` ile bir dizi girdi
## (ve aradaki beklemeler) tek çağrıda oynatılır (debugger kanalı → oyundaki RuntimeBridge →
## AISidebarRuntimeInput). `wait_for_runtime`: bir düğüm özelliği koşulu sağlanana kadar oyunun içinde
## bekler; timeout_ms=0 anlık doğrulamadır (AISidebarRuntimeProbe). Yalnız editörden başlatılmış oyuna
## gider, proje dosyalarına dokunmaz; yazıcı kilidine tabi değildir (oyun kontrolü, play_game gibi).

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarDebuggerPlugin = preload("res://addons/godot_sidebar_ai/core/runtime/debugger_plugin.gd")

const TOOL_NAME := "send_input"
const WAIT_TOOL := "wait_for_runtime"
const PERF_TOOL := "get_runtime_performance"
const TRACE_TOOL := "trace_runtime_signals"
const UI_AUDIT_TOOL := "audit_runtime_ui"
const MAX_HOLD_MSEC := 2000
const MAX_STEPS := 30
const MAX_STEP_WAIT_MSEC := 5000
## Bir dizinin toplam süresi (basılı tutma + bekleme): kör uzun makro yerine arada etkisine bakılsın.
const MAX_SEQUENCE_MSEC := 15000
const MAX_WAIT_MSEC := 15000

static func get_schemas() -> Array:
	return [{
		"type": "function",
		"function": {
			"name": TOOL_NAME,
			"description": "Sends input to the running game (play_game first): a key press, an input action, or a mouse click. Prefer clicking by node_path (a Control's center, a Node2D's position, or a Node3D projected through the active camera); otherwise give x and y as fractions of the game view (screenshot pixel / screenshot width or height). Clicks reach GUI and _input/_unhandled_input; Area2D/3D picking also needs physics_object_picking on the viewport. Check the effect afterwards with take_runtime_screenshot or inspect_runtime_node.",
			"parameters": {
				"type": "object",
				"properties": {
					"kind": {"type": "string", "enum": ["key", "action", "actions", "click", "drag"], "description": "What to send. actions: several input actions held together (e.g. move_right + jump). drag: press at the start, move, release at the end (node_path or x, y start; to_node_path or to_x, to_y end; hold_ms is the drag duration)."},
					"actions": {"type": "array", "items": {"type": "string"}, "description": "For kind=actions: input actions to hold at the same time."},
					"to_node_path": {"type": "string", "description": "For kind=drag: node to drop on."},
					"to_x": {"type": "number", "description": "For kind=drag without to_node_path: end position as a fraction of the game view."},
					"to_y": {"type": "number", "description": "For kind=drag without to_node_path: end position as a fraction of the game view."},
					"key": {"type": "string", "description": "For kind=key: key name, e.g. Space, Escape, Enter, A, 1, Up, F1."},
					"action": {"type": "string", "description": "For kind=action: an input action defined in the project's Input Map."},
					"node_path": {"type": "string", "description": "For kind=click: path of the node to click in the running game (e.g. 'Main/UI/StartButton')."},
					"x": {"type": "number", "description": "For kind=click without node_path: horizontal position as a fraction of the game view (0.0 to 1.0)."},
					"y": {"type": "number", "description": "For kind=click without node_path: vertical position as a fraction of the game view (0.0 to 1.0)."},
					"button": {"type": "string", "enum": ["left", "right"], "description": "Mouse button for kind=click (default: left)."},
					"hold_ms": {"type": "integer", "description": "How long to hold the key / action / button, in milliseconds (default 80, max 2000)."},
					"steps": {"type": "array", "description": "Instead of kind: several inputs played in order in ONE call, e.g. [{kind:'action', action:'move_right', hold_ms:800}, {kind:'wait', wait_ms:300}, {kind:'key', key:'Space'}]. Each step takes the same fields as a single input plus wait_ms (pause after the step); kind 'wait' only waits. Max 30 steps.", "items": {"type": "object"}},
				},
				"required": [],
			},
		},
	}, {
		"type": "function",
		"function": {
			"name": TRACE_TOOL,
			"description": "Listens to a node's signals in the running game for a few seconds and returns them in order: which signal fired, when (ms) and with which arguments, plus which listened signals stayed silent. Use it instead of inspecting a node again and again, e.g. node_path 'Main/Game', signals ['score_changed', 'game_over'], then send_input while it listens (or call send_input right after starting the game). Without signals, the signals defined in the node's script are traced.",
			"parameters": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Node in the running game (e.g. 'Main/Game')."},
					"signals": {"type": "array", "items": {"type": "string"}, "description": "Signal names to listen to (default: the node's script-defined signals)."},
					"duration_ms": {"type": "integer", "description": "How long to listen, in milliseconds (default 3000, max 10000)."},
				},
				"required": ["node_path"],
			},
		},
	}, {
		"type": "function",
		"function": {
			"name": UI_AUDIT_TOOL,
			"description": "Audits the running game's on-screen text (Labels, Buttons, RichTextLabels, LineEdits) with measurements instead of eyesight: text partly off screen, text wider than its box, texts overlapping each other, and text with low WCAG contrast against the pixels behind it (under 3:1). Each issue names the node and the problem. Call it once near the end, after the game is running and showing its main screen, then fix what it lists (nodes are in the play scene tree; use inspect_runtime_node to find the script or scene that owns them). An empty list means nothing measurable was wrong, not that the design is good.",
			"parameters": {"type": "object", "properties": {}, "required": []},
		},
	}, {
		"type": "function",
		"function": {
			"name": PERF_TOOL,
			"description": "Measures the running game's health over a few seconds: average FPS, frame time (avg / p95 / worst), and how node count, object count, orphan nodes and memory changed (a growing node count means a leak or unbounded spawning). Returns warnings for low FPS, hitches, growth and orphans. Play the game and exercise it (send_input) while it samples, or run it right after a burst of activity.",
			"parameters": {
				"type": "object",
				"properties": {
					"duration_ms": {"type": "integer", "description": "How long to sample, in milliseconds (default 2000, 200 to 10000)."},
				},
				"required": [],
			},
		},
	}, {
		"type": "function",
		"function": {
			"name": WAIT_TOOL,
			"description": "Waits inside the running game until a node property meets a condition, then reports how long it took (CONDITION_MET) or TIMEOUT with the last value. With timeout_ms 0 it is an instant check: ASSERTION_PASSED / ASSERTION_FAILED. Use it after send_input instead of inspecting repeatedly, e.g. node_path 'Main/UI/GameOver', property 'visible', operator '==', value true, timeout_ms 5000.",
			"parameters": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Node in the running game (e.g. 'Main/Player' or '/root/Main/Player')."},
					"property": {"type": "string", "description": "Property or script variable; nested with dots (e.g. 'health', 'visible', 'position.y'). Optional for exists / not_exists (then the node itself)."},
					"operator": {"type": "string", "enum": ["==", "!=", ">", ">=", "<", "<=", "exists", "not_exists", "contains"], "description": "Comparison (default ==). contains: substring, array item or dictionary key."},
					"value": {"description": "Expected value (number, bool or string)."},
					"timeout_ms": {"type": "integer", "description": "How long to wait (default 3000, max 15000). 0: check once now."},
					"poll_ms": {"type": "integer", "description": "How often to check inside the game (default 100)."},
				},
				"required": ["node_path"],
			},
		},
	}]

## Oyun ve debugger hazır mı; değilse hata sonucu, hazırsa {}.
static func readiness_error() -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Runtime tools (send_input, wait_for_runtime) need the Godot editor.")
	if not EditorInterface.is_playing_scene():
		return AISidebarToolResult.err("GAME_NOT_RUNNING", "The game is not running; call play_game first.")
	var dbg := AISidebarDebuggerPlugin.instance
	if dbg == null or not dbg.has_active_session():
		return AISidebarToolResult.err("DEBUGGER_NOT_CONNECTED", "The game is running but its debugger session is not connected yet; retry in a second.")
	return {}

## Argümanları doğrular ve oyuna gidecek sade sözlüğe çevirir. Dönüş: {"spec"} ya da {"error": ToolResult}.
static func build_spec(args: Dictionary) -> Dictionary:
	var steps_v: Variant = args.get("steps", null)
	if steps_v is Array:
		var steps: Array = steps_v
		if not steps.is_empty():
			return _build_steps(steps)
	var kind := str(args.get("kind", ""))
	if not kind in ["key", "action", "actions", "click", "drag"]:
		return {"error": AISidebarToolResult.err("INVALID_ARGUMENT", "kind must be key, action, actions, click or drag.")}
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
		"actions":
			var list: Array = args["actions"] if args.get("actions") is Array else []
			if list.is_empty():
				return {"error": AISidebarToolResult.err("INVALID_ARGUMENT", "kind=actions needs actions (a list of input action names).")}
			spec["actions"] = list
		"drag":
			var has_from := not str(args.get("node_path", "")).strip_edges().is_empty() or (args.has("x") and args.has("y"))
			var has_to := not str(args.get("to_node_path", "")).strip_edges().is_empty() or (args.has("to_x") and args.has("to_y"))
			if not has_from or not has_to:
				return {"error": AISidebarToolResult.err("INVALID_ARGUMENT", "kind=drag needs a start (node_path or x, y) and an end (to_node_path or to_x, to_y).")}
			for k: String in ["node_path", "x", "y", "to_node_path", "to_x", "to_y"]:
				if args.has(k):
					spec[k] = args[k]
			spec["hold_ms"] = clampi(int(str(args.get("hold_ms", 300)).to_float()), 100, MAX_HOLD_MSEC)
			spec["button"] = "right" if str(args.get("button", "left")) == "right" else "left"
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

## Dizi: her adım tek girdi gibi doğrulanır (kind="wait" yalnız bekler); toplam süre editör zaman aşımına girer.
static func _build_steps(steps: Array) -> Dictionary:
	if steps.size() > MAX_STEPS:
		return {"error": AISidebarToolResult.err("INVALID_ARGUMENT", "At most %d steps per call." % MAX_STEPS)}
	var out: Array = []
	var total_ms := 0
	for i in steps.size():
		if not (steps[i] is Dictionary):
			return {"error": AISidebarToolResult.err("INVALID_ARGUMENT", "steps[%d] must be an object." % i)}
		var step: Dictionary = steps[i]
		var wait_ms := clampi(int(str(step.get("wait_ms", 0)).to_float()), 0, MAX_STEP_WAIT_MSEC)
		var spec: Dictionary = {"kind": "wait"}
		if str(step.get("kind", "wait")) != "wait":
			var one := build_spec(step)
			if one.has("error"):
				var e: Dictionary = one["error"]
				var err: Dictionary = e["error"]
				return {"error": AISidebarToolResult.err("INVALID_ARGUMENT", "steps[%d]: %s" % [i, str(err.get("message", ""))])}
			spec = one["spec"]
			var hold: int = spec["hold_ms"]
			total_ms += hold
		spec["wait_ms"] = wait_ms
		total_ms += wait_ms
		out.append(spec)
	if total_ms > MAX_SEQUENCE_MSEC:
		return {"error": AISidebarToolResult.err("INVALID_ARGUMENT", "The steps take %d ms in total; at most %d ms per call (split the sequence and check the effect in between)." % [total_ms, MAX_SEQUENCE_MSEC])}
	return {"spec": {"kind": "steps", "steps": out, "hold_ms": total_ms}}

## Eylem sırasında oyunda çıkan yeni betik hataları (oyunun hata dinleyicisi yanıta ekler) araç sonucuna yazılır:
## ajan tıklamanın oyunda hata verdiğini sonuçta görür (benchmark: hata yalnız günlükteydi, ajan çırpındı).
static func annotate_errors(res: Dictionary, resp: Dictionary) -> Dictionary:
	var errs: Array = resp["new_errors"] if resp.get("new_errors") is Array else []
	if errs.is_empty():
		return res
	var shown: Array = []
	for e_v: Variant in errs.slice(0, 3):
		var e: Dictionary = e_v
		shown.append("%s:%s %s" % [str(e.get("file", "")), str(e.get("line", "")), str(e.get("message", "")).left(160)])
	var note := " | The game logged %d new error(s) meanwhile: %s" % [errs.size(), " ; ".join(PackedStringArray(shown))]
	if res.get("success", false) == true:
		var data: Dictionary = res["data"] if res.get("data") is Dictionary else {}
		data["new_runtime_errors"] = shown
		res["data"] = data
		res["message"] = str(res.get("message", "")) + note
	else:
		var err: Dictionary = res["error"] if res.get("error") is Dictionary else {}
		err["message"] = str(err.get("message", "")) + note
		res["error"] = err
	return res

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
		var msg := str(resp.get("message", "The input could not be delivered to the game."))
		if resp.has("failed_step"):
			var failed_step: int = resp["failed_step"]
			msg = "steps[%d] failed: %s (earlier steps were played)" % [failed_step, msg]
		return annotate_errors(AISidebarToolResult.err(str(resp.get("error", "SEND_INPUT_FAILED")), msg), resp)
	return annotate_errors(AISidebarToolResult.ok(resp, "Input sent: " + str(spec["kind"])), resp)

## Bazı modeller karşılaştırma işaretlerini HTML kaçışıyla yollar ("&gt;="): araç çağrısı boşa gitmesin.
static func unescape_html(text: String) -> String:
	return text.replace("&gt;", ">").replace("&lt;", "<").replace("&quot;", "\"").replace("&amp;", "&")

static func _clean_value(v: Variant) -> Variant:
	if v is String:
		var s: String = v
		return unescape_html(s)
	return v

static func execute_trace_async(args: Dictionary) -> Dictionary:
	var node_path := str(args.get("node_path", "")).strip_edges()
	if node_path.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "node_path is required.")
	var not_ready := readiness_error()
	if not not_ready.is_empty():
		return not_ready
	var names: Array = args["signals"] if args.get("signals") is Array else []
	var duration := clampi(int(str(args.get("duration_ms", 3000)).to_float()), 100, 10000)
	var resp: Dictionary = await AISidebarDebuggerPlugin.instance.query_with_ready_check("trace_signals", [{"node_path": node_path, "signals": names, "duration_ms": duration}], 1.0, 4.0 + duration / 1000.0)
	if resp.get("success", false) != true:
		return AISidebarToolResult.err(str(resp.get("error", "TRACE_FAILED")), str(resp.get("message", "The game did not return a signal trace.")))
	var n: int = resp.get("count", 0)
	return AISidebarToolResult.ok(resp, "%d signal event(s) on %s in %d ms" % [n, node_path, duration])

static func execute_ui_audit_async() -> Dictionary:
	var not_ready := readiness_error()
	if not not_ready.is_empty():
		return not_ready
	var resp: Dictionary = await AISidebarDebuggerPlugin.instance.query_with_ready_check("ui_audit", [{}], 1.0, 5.0)
	if resp.get("success", false) != true:
		return AISidebarToolResult.err(str(resp.get("error", "UI_AUDIT_FAILED")), str(resp.get("message", "The game did not return a UI audit.")))
	return AISidebarToolResult.ok(resp, str(resp.get("summary", "")))

static func execute_perf_async(args: Dictionary) -> Dictionary:
	var not_ready := readiness_error()
	if not not_ready.is_empty():
		return not_ready
	var duration := clampi(int(str(args.get("duration_ms", 2000)).to_float()), 200, 10000)
	var resp: Dictionary = await AISidebarDebuggerPlugin.instance.query_with_ready_check("perf", [{"duration_ms": duration}], 1.0, 4.0 + duration / 1000.0)
	if resp.get("success", false) != true:
		return AISidebarToolResult.err(str(resp.get("error", "PERF_FAILED")), str(resp.get("message", "The game did not return a performance report.")))
	var ms: Dictionary = resp.get("frame_ms", {})
	return AISidebarToolResult.ok(resp, "Performance: %s FPS avg, frame %s ms avg / %s p95 / %s worst" % [str(resp.get("fps_avg")), str(ms.get("avg")), str(ms.get("p95")), str(ms.get("worst"))])

static func execute_wait_async(args: Dictionary) -> Dictionary:
	var op := unescape_html(str(args.get("operator", "==")).strip_edges())
	var node_path := str(args.get("node_path", "")).strip_edges()
	var prop := str(args.get("property", "")).strip_edges()
	if node_path.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "node_path is required.")
	if not op in ["exists", "not_exists"] and (prop.is_empty() or not args.has("value")):
		return AISidebarToolResult.err("INVALID_ARGUMENT", "property and value are required for operator " + op + ".")
	var not_ready := readiness_error()
	if not not_ready.is_empty():
		return not_ready
	var timeout := clampi(int(str(args.get("timeout_ms", 3000)).to_float()), 0, MAX_WAIT_MSEC)
	var spec := {"node_path": node_path, "property": prop, "operator": op, "value": _clean_value(args.get("value", null)),
		"timeout_ms": timeout, "poll_ms": int(str(args.get("poll_ms", 100)).to_float())}
	var resp: Dictionary = await AISidebarDebuggerPlugin.instance.query_with_ready_check("wait_for", [spec], 1.0, 3.0 + timeout / 1000.0)
	var status := str(resp.get("status", resp.get("error", "WAIT_FAILED")))
	var cond := "%s %s %s" % [prop if not prop.is_empty() else node_path, op, JSON.stringify(args.get("value", null)) if args.has("value") else ""]
	if resp.get("success", false) == true:
		var elapsed: int = resp.get("elapsed_ms", 0)
		return annotate_errors(AISidebarToolResult.ok(resp, "%s: %s (%d ms)" % [status, cond.strip_edges(), elapsed]), resp)
	var msg := str(resp.get("message", ""))
	if status in ["TIMEOUT", "ASSERTION_FAILED"]:
		msg = "%s: %s on %s; actual value: %s" % [status, cond.strip_edges(), node_path, JSON.stringify(resp.get("actual"))]
		if resp.has("missing"):
			msg += " (the %s was not found)" % str(resp["missing"])
	return annotate_errors(AISidebarToolResult.err(status, msg, true, resp), resp)
