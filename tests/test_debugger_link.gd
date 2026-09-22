@tool
extends RefCounted

## Runtime debugger iletişim zinciri (headless-kanıtlanabilir kısım):
## capture eşleşmesi, komut normalizasyonu, ping, response routing,
## error kodları, async yönlendirme sözleşmesi.
## CANLI editor<->oyun transportu GUI prosedürüyle doğrulanır (rapora bakın).

const AISidebarDebuggerPlugin = preload("res://addons/godot_sidebar_ai/core/runtime/debugger_plugin.gd")
const AISidebarRuntimeBridge = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_bridge.gd")
const AISidebarEditorTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/editor_tools.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# A) bridge registration sözleşmesi: normalize + ping builder (tree gerektirmez)
	var norm_ok = (
		AISidebarRuntimeBridge.normalize_command("godot_ai:inspect_tree") == "inspect_tree"
		and AISidebarRuntimeBridge.normalize_command("inspect_tree") == "inspect_tree"
		and AISidebarRuntimeBridge.normalize_command("godot_ai:ping") == "ping"
		and AISidebarRuntimeBridge.normalize_command("godot_ai:capture_viewport") == "capture_viewport"
		and AISidebarRuntimeBridge.normalize_command("") == ""
		and AISidebarRuntimeBridge.normalize_command("other") == "other"
	)
	var ping = AISidebarRuntimeBridge.build_ping_response("req_1")
	if norm_ok and ping is Dictionary and bool(ping.get("success", false)) and bool(ping.get("pong", false)):
		passed += 1
	else:
		failed += 1
		errors.append("A (bridge normalize+ping) failed.")

	# B) capture eşleşmesi: tam ad, önekli mesaj, yabancı (static — instance gerektirmez)
	if AISidebarDebuggerPlugin.matches_capture("godot_ai") and AISidebarDebuggerPlugin.matches_capture("godot_ai:response") and AISidebarDebuggerPlugin.matches_capture("godot_ai:inspect_tree") and not AISidebarDebuggerPlugin.matches_capture("other") and not AISidebarDebuggerPlugin.matches_capture(""):
		passed += 1
	else:
		failed += 1
		errors.append("B (capture matching) failed.")

	# C) ping-first kararı: session yokken çağrılmadan da dallanma kanıtlı
	var go_ok = AISidebarDebuggerPlugin.ready_check_result({"success": true})
	var stop_bad = AISidebarDebuggerPlugin.ready_check_result({"success": false, "error": "RUNTIME_QUERY_TIMEOUT"})
	var stop_empty = AISidebarDebuggerPlugin.ready_check_result({})
	if bool(go_ok.get("proceed", false)) and not bool(stop_bad.get("proceed", true)) and str((stop_bad.get("result", {}) as Dictionary).get("error", "")) == "BRIDGE_NOT_READY" and not bool(stop_empty.get("proceed", true)):
		passed += 1
	else:
		failed += 1
		errors.append("C (ready-check branching) failed.")

	# D) game->editor response routing (düz sözlük üzerinde, tree yok)
	var pending: Dictionary = {"req_9": {"completed": false, "payload": {}}}
	var routed = AISidebarDebuggerPlugin.route_response(pending, "godot_ai:response", ["req_9", {"success": true, "pong": true}])
	var routed_bad = AISidebarDebuggerPlugin.route_response({}, "godot_ai:other", ["x"])
	if bool(routed.get("handled", false)) and bool((pending["req_9"] as Dictionary).get("completed", false)) and str(((pending["req_9"] as Dictionary).get("payload", {}) as Dictionary).get("pong", "")) != "" and not bool(routed_bad.get("handled", true)):
		passed += 1
	else:
		failed += 1
		errors.append("D (response routing) failed.")

	# E/F) async yönlendirme sözleşmesi: üç araç da ready_check hattında
	if AISidebarEditorTools.is_async_tool("inspect_runtime_tree") and AISidebarEditorTools.is_async_tool("inspect_runtime_node") and AISidebarEditorTools.is_async_tool("take_runtime_screenshot"):
		passed += 1
	else:
		failed += 1
		errors.append("E/F (async routing contract) failed.")

	# G) ping yanıtsızlığı BRIDGE_NOT_READY üretir (ready_check_result üzerinden)
	var no_bridge = AISidebarDebuggerPlugin.ready_check_result(AISidebarDebuggerPlugin.timeout_result(1.0))
	if not bool(no_bridge.get("proceed", true)) and str((no_bridge.get("result", {}) as Dictionary).get("error", "")) == "BRIDGE_NOT_READY":
		passed += 1
	else:
		failed += 1
		errors.append("G (bridge-not-ready mapping) failed.")

	# H) timeout kodu ayrık: RUNTIME_QUERY_TIMEOUT (eski TIMEOUT değil)
	var to = AISidebarDebuggerPlugin.timeout_result(3.0)
	if str(to.get("error", "")) == "RUNTIME_QUERY_TIMEOUT" and not bool(to.get("success", true)) and "3.0" in str(to.get("message", "")):
		passed += 1
	else:
		failed += 1
		errors.append("H (timeout code) failed: " + str(to))

	return {"name": "DebuggerLinkTests", "passed": passed, "failed": failed, "errors": errors}
