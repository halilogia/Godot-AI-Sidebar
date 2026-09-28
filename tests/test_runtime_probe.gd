@tool
extends RefCounted

## wait_for_runtime koşulu (AISidebarRuntimeProbe) ve send_input adım dizisi doğrulaması
## (AISidebarRuntimeInputTools.build_spec). Oyun gerektirmez: düğüm ağacı ağaç dışında kurulur.

const AISidebarRuntimeProbe = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_probe.gd")
const AISidebarRuntimeMetrics = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_metrics.gd")
const AISidebarRuntimeSignals = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_signals.gd")
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

	# R5b metin olarak gelen sayı / bool gerçek türe çevrilir
	checks.append(["R5b string-typed expected values", AISidebarRuntimeProbe.compare(3, ">=", "1") and not AISidebarRuntimeProbe.compare(3, "<", "1") and AISidebarRuntimeProbe.compare(true, "==", "true") and AISidebarRuntimeProbe.compare(2.5, "==", "2.5") and AISidebarRuntimeProbe.compare("abc", "==", "abc") and not AISidebarRuntimeProbe.compare(0, "==", "abc")])

	# R6 send_input steps: geriye uyumlu tek girdi + dizi + hatalı adım
	var single := AISidebarRuntimeInputTools.build_spec({"kind": "action", "action": "jump", "hold_ms": 100})
	var seq := AISidebarRuntimeInputTools.build_spec({"steps": [{"kind": "action", "action": "move_right", "hold_ms": 800}, {"kind": "wait", "wait_ms": 300}, {"kind": "key", "key": "Space"}]})
	var bad := AISidebarRuntimeInputTools.build_spec({"steps": [{"kind": "key", "key": "A"}, {"kind": "action"}]})
	var seq_spec: Dictionary = seq.get("spec", {})
	var bad_err: Dictionary = (bad.get("error", {}) as Dictionary).get("error", {}) if bad.get("error") is Dictionary else {}
	checks.append(["R6 steps spec (single kept, sequence built, bad step named)", (single.get("spec", {}) as Dictionary).get("kind") == "action" and seq_spec.get("kind") == "steps" and (seq_spec.get("steps", []) as Array).size() == 3 and int(seq_spec.get("hold_ms", 0)) == 1180 and str(bad_err.get("message", "")).begins_with("steps[1]")])

	# R6b drag ve actions doğrulaması
	var drag_ok := AISidebarRuntimeInputTools.build_spec({"kind": "drag", "x": 0.2, "y": 0.5, "to_x": 0.8, "to_y": 0.5, "hold_ms": 500})
	var drag_bad := AISidebarRuntimeInputTools.build_spec({"kind": "drag", "x": 0.2, "y": 0.5})
	var multi_ok := AISidebarRuntimeInputTools.build_spec({"kind": "actions", "actions": ["move_right", "jump"], "hold_ms": 300})
	var multi_bad := AISidebarRuntimeInputTools.build_spec({"kind": "actions"})
	var drag_spec: Dictionary = drag_ok.get("spec", {})
	var multi_spec: Dictionary = multi_ok.get("spec", {})
	checks.append(["R6b drag / actions specs", drag_spec.get("kind") == "drag" and int(drag_spec.get("hold_ms", 0)) == 500 and drag_spec.has("to_x") and drag_bad.has("error") and (multi_spec.get("actions", []) as Array).size() == 2 and multi_bad.has("error")])

	# R7 dizinin toplam süresi sınırlı (4 × (2000 + 5000) ms > 15000)
	var long_steps: Array = []
	for i in 4:
		long_steps.append({"kind": "key", "key": "A", "hold_ms": 2000, "wait_ms": 5000})
	var too_long := AISidebarRuntimeInputTools.build_spec({"steps": long_steps})
	var long_err: Dictionary = (too_long.get("error", {}) as Dictionary).get("error", {}) if too_long.get("error") is Dictionary else {}
	checks.append(["R7 sequence total duration capped", str(long_err.get("message", "")).contains("in total")])

	# R8 model karşılaştırma işaretini HTML kaçışıyla yollarsa araç yine anlar
	checks.append(["R8 html-escaped operator", AISidebarRuntimeInputTools.unescape_html("&gt;=") == ">=" and AISidebarRuntimeInputTools.unescape_html("&lt;") == "<" and AISidebarRuntimeInputTools.unescape_html("a &amp;&amp; b") == "a && b"])

	# R9 performans özeti: kare süreleri, büyüme ve uyarılar
	var frames: Array = []
	for i in 100:
		frames.append(16.0)
	frames.append(150.0)
	var rep := AISidebarRuntimeMetrics.summarize(frames, {"nodes": 100, "orphan_nodes": 0, "objects": 500, "memory_mb": 50.0}, {"nodes": 400, "orphan_nodes": 2, "objects": 900, "memory_mb": 60.0}, 1700)
	var warn_text := " ".join(PackedStringArray(rep.get("warnings", [])))
	var fm: Dictionary = rep.get("frame_ms", {})
	checks.append(["R9 performance summary", int(rep.get("frames", 0)) == 101 and float(fm.get("worst", 0)) == 150.0 and float(fm.get("p95", 0)) == 16.0 and warn_text.contains("hitch") and warn_text.contains("grew by 300") and warn_text.contains("orphan") and float((rep["growth"]["nodes"] as Dictionary)["change"]) == 300.0])

	# R10 sinyal izleme: betikte tanımlı sinyaller bulunur, çıkışlar sırayla kaydedilir, sessiz olan söylenir
	var sig_script := GDScript.new()
	sig_script.source_code = "extends Node
signal score_changed(v)
signal game_over
"
	sig_script.reload()
	var game := Node.new()
	game.set_script(sig_script)
	var found := AISidebarRuntimeSignals.script_signals(game)
	var session := AISidebarRuntimeSignals.begin(game, [], Time.get_ticks_msec())
	game.emit_signal("score_changed", 10)
	game.emit_signal("score_changed", 20)
	var trace_report := AISidebarRuntimeSignals.finish(game, session)
	var counts: Dictionary = trace_report.get("counts", {})
	var trace_events: Array = trace_report.get("events", [])
	var first_args: Array = (trace_events[0] as Dictionary).get("args", []) if not trace_events.is_empty() else []
	checks.append(["R10 signal trace", found.has("score_changed") and found.has("game_over") and not found.has("ready") and trace_events.size() == 2 and int(counts.get("score_changed", 0)) == 2 and first_args == [10] and (trace_report.get("silent", []) as Array).has("game_over") and not game.is_connected("score_changed", (session["_calls"] as Array)[0][1])])
	game.free()

	root.free()
	var passed := 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "RuntimeProbeTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
