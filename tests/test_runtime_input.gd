@tool
extends RefCounted

## Benchmark bulgusu: çalışan oyuna girdi gönderilemiyordu (tıklama / tuş kriterleri elle test).
## send_input argüman doğrulaması ve oyun tarafında tıklama konumunun hesaplanması.

const AISidebarRuntimeInputTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/runtime_input_tools.gd")
const AISidebarRuntimeInput = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_input.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarMcpProtocol = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_protocol.gd")
const AISidebarWriterLock = preload("res://addons/godot_sidebar_ai/core/security/writer_lock.gd")

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	# 1. Argüman doğrulaması ve oyuna gidecek sade sözlük.
	var k := AISidebarRuntimeInputTools.build_spec({"kind": "key", "key": "Space", "hold_ms": 99999})
	var a := AISidebarRuntimeInputTools.build_spec({"kind": "action", "action": "ui_accept"})
	var c1 := AISidebarRuntimeInputTools.build_spec({"kind": "click", "node_path": "Main/UI/Start", "button": "right"})
	var c2 := AISidebarRuntimeInputTools.build_spec({"kind": "click", "x": 0.25, "y": "0.5"})
	var bad_kind := AISidebarRuntimeInputTools.build_spec({"kind": "tap"})
	var no_key := AISidebarRuntimeInputTools.build_spec({"kind": "key"})
	var no_target := AISidebarRuntimeInputTools.build_spec({"kind": "click"})
	if k.has("spec") and k["spec"]["hold_ms"] == 2000 and k["spec"]["key"] == "Space" \
			and a["spec"]["action"] == "ui_accept" and a["spec"]["hold_ms"] == 80 \
			and c1["spec"]["node_path"] == "Main/UI/Start" and c1["spec"]["button"] == "right" \
			and is_equal_approx(float(c2["spec"]["x"]), 0.25) and is_equal_approx(float(c2["spec"]["y"]), 0.5) and c2["spec"]["button"] == "left" \
			and bad_kind.has("error") and no_key.has("error") and no_target.has("error"):
		passed += 1
	else:
		failed += 1
		errors.append("T1 (build_spec) failed: k=%s c2=%s" % [str(k), str(c2)])

	# 2. Tıklama konumu (ağaç dışı viewport; runner SceneTree._init içinde koşar, ana döngü yoktur):
	# oran, bilinmeyen düğüm, aralık dışı, hedefsiz, ekran konumu olmayan düğüm. Control / Node2D /
	# Node3D konum hesabı sahne ağacı gerektirir; final GUI / E2E doğrulamasında sınanır.
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 600)
	var holder := Node.new()
	holder.name = "InputTestRoot"
	vp.add_child(holder)
	var p_frac := AISidebarRuntimeInput.click_position(vp, {"x": 0.25, "y": 0.5})
	var p_missing := AISidebarRuntimeInput.click_position(vp, {"node_path": "/root/Nope/Nothing"})
	var p_range := AISidebarRuntimeInput.click_position(vp, {"x": 1.5, "y": 0.2})
	var p_none := AISidebarRuntimeInput.click_position(vp, {})
	var p_plain := AISidebarRuntimeInput.click_position(vp, {"node_path": "/root/InputTestRoot"})
	vp.free()
	if p_frac["ok"] and (p_frac["position"] as Vector2).is_equal_approx(Vector2(200, 300)) \
			and p_missing["error"] == "NODE_NOT_FOUND" and p_range["error"] == "OUT_OF_RANGE" \
			and p_none["error"] == "MISSING_TARGET" and p_plain["error"] == "NOT_CLICKABLE":
		passed += 1
	else:
		failed += 1
		errors.append("T2 (click_position) failed: frac=%s missing=%s plain=%s" % [str(p_frac), str(p_missing), str(p_plain)])

	# 3. Kayıt: araç listelerde, asenkron, köprüde açık, yazıcı kilidine tabi değil; oyun yokken net hata.
	var in_schemas := false
	for s in AISidebarToolManager.get_all_schemas():
		if s["function"]["name"] == "send_input":
			in_schemas = true
	if in_schemas and AISidebarToolManager.is_async_tool("send_input") and AISidebarMcpProtocol.is_exposed("send_input") \
			and not AISidebarWriterLock.is_write_tool("send_input") and not AISidebarRuntimeInputTools.readiness_error().is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T3 (registration) failed")

	return {"name": "RuntimeInputTests", "passed": passed, "failed": failed, "errors": errors}
