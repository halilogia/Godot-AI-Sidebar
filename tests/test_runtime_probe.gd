@tool
extends RefCounted

## wait_for_runtime koşulu (AISidebarRuntimeProbe) ve send_input adım dizisi doğrulaması
## (AISidebarRuntimeInputTools.build_spec). Oyun gerektirmez: düğüm ağacı ağaç dışında kurulur.

const AISidebarRuntimeProbe = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_probe.gd")
const AISidebarRuntimeInputTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/runtime_input_tools.gd")

static func _met(root: Node, spec: Dictionary) -> Variant:
	var r := AISidebarRuntimeProbe.evaluate(root, spec)
	return r.get("met") if not r.has("error") else "error:" + str(r["error"])

static func run() -> Dictionary:
	var checks: Array = []
	var root := Node.new()
	var main := Node2D.new()
	main.name = "Main"
	root.add_child(main)
	var player := Node2D.new()
	player.name = "Player"
	player.position = Vector2(10, 250)
	main.add_child(player)
	var label := Label.new()
	label.name = "Score"
	label.text = "Score: 30"
	label.visible = false
	main.add_child(label)

	# R1 sayı ve iç içe özellik
	checks.append(["R1 numeric + nested (position.y)", _met(root, {"node_path": "Main/Player", "property": "position.y", "operator": ">", "value": 200}) == true and _met(root, {"node_path": "/root/Main/Player", "property": "position.x", "operator": "<=", "value": 9}) == false])
	# R2 bool, metin, contains
	checks.append(["R2 bool / string / contains", _met(root, {"node_path": "Main/Score", "property": "visible", "operator": "==", "value": false}) == true and _met(root, {"node_path": "Main/Score", "property": "text", "operator": "contains", "value": "30"}) == true and _met(root, {"node_path": "Main/Score", "property": "text", "operator": "!=", "value": "Score: 30"}) == false])
	# R3 exists / not_exists (düğüm ve özellik)
	checks.append(["R3 exists / not_exists", _met(root, {"node_path": "Main/Player", "operator": "exists"}) == true and _met(root, {"node_path": "Main/Enemy", "operator": "not_exists"}) == true and _met(root, {"node_path": "Main/Player", "property": "nope", "operator": "exists"}) == false])
	# R4 eksik düğüm karşılaştırmada "met: false, missing"; geçersiz operatör hata
	var miss := AISidebarRuntimeProbe.evaluate(root, {"node_path": "Main/Enemy", "property": "health", "operator": "==", "value": 0})
	checks.append(["R4 missing node / invalid operator", miss.get("met") == false and miss.get("missing") == "node" and str(_met(root, {"node_path": "Main", "property": "x", "operator": "~"})).begins_with("error:")])
	# R5 sayı karşılaştırması tür karışık (int / float) ve sayı olmayanla > yanlış
	checks.append(["R5 compare types", AISidebarRuntimeProbe.compare(3, "==", 3.0) and not AISidebarRuntimeProbe.compare("a", ">", 1) and AISidebarRuntimeProbe.compare([1, "x"], "contains", "x")])

	# R6 send_input steps: geriye uyumlu tek girdi + dizi + hatalı adım
	var single := AISidebarRuntimeInputTools.build_spec({"kind": "action", "action": "jump", "hold_ms": 100})
	var seq := AISidebarRuntimeInputTools.build_spec({"steps": [{"kind": "action", "action": "move_right", "hold_ms": 800}, {"kind": "wait", "wait_ms": 300}, {"kind": "key", "key": "Space"}]})
	var bad := AISidebarRuntimeInputTools.build_spec({"steps": [{"kind": "key", "key": "A"}, {"kind": "action"}]})
	var seq_spec: Dictionary = seq.get("spec", {})
	var bad_err: Dictionary = (bad.get("error", {}) as Dictionary).get("error", {}) if bad.get("error") is Dictionary else {}
	checks.append(["R6 steps spec (single kept, sequence built, bad step named)", (single.get("spec", {}) as Dictionary).get("kind") == "action" and seq_spec.get("kind") == "steps" and (seq_spec.get("steps", []) as Array).size() == 3 and int(seq_spec.get("hold_ms", 0)) == 1180 and str(bad_err.get("message", "")).begins_with("steps[1]")])

	root.free()
	var passed := 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "RuntimeProbeTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
