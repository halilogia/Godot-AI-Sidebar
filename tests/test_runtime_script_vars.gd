@tool
extends RefCounted

## Benchmark bulgusu: inspect_runtime_node script değişkenlerini okuyamıyordu; ajan oyun durumunu
## düğüm adlarına yazmak zorunda kalıyordu. serialize_node artık script_vars döndürür.

const AISidebarRuntimeBridge = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_bridge.gd")

const SRC := """extends Node2D
@export var hp: int = 42
var owner_tag := "Aurelia"
var treasury := 196.25
var neighbors := [1, 2, 3]
var stats := {"income": 48, "nested": {"a": [1, 2]}}
var target: Node = null
var long_text := ""
"""

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	var script := GDScript.new()
	script.source_code = SRC
	script.reload()
	var root := Node2D.new()
	root.name = "Province_07"
	var other := Node.new()
	other.name = "Capital"
	root.add_child(other)
	root.set_script(script)
	root.set("target", other)
	root.set("long_text", "x".repeat(500))
	var big: Array = []
	for i in 30:
		big.append(i)
	root.set("neighbors", big)

	var info := AISidebarRuntimeBridge.serialize_node(root)
	var vars: Dictionary = info.get("script_vars", {})
	var neighbors: Array = vars.get("neighbors", [])
	var stats: Dictionary = vars.get("stats", {})
	var target: Dictionary = vars.get("target", {})
	var plain := AISidebarRuntimeBridge.serialize_node(Node.new())
	if vars.get("hp") == 42 and vars.get("owner_tag") == "Aurelia" and is_equal_approx(float(vars.get("treasury", 0.0)), 196.25) \
			and neighbors.size() == 21 and str(neighbors[20]).contains("30 items") \
			and int(stats.get("income", 0)) == 48 and str(stats.get("nested")).contains("<array size=2>") \
			and str(target.get("type", "")) == "Node" and str(target.get("node", "")) == "Capital" \
			and str(vars.get("long_text", "")).length() == 303 and not plain.has("script_vars") \
			and JSON.stringify(info).length() > 0:
		passed += 1
	else:
		failed += 1
		vars.erase("long_text")
		errors.append("T1 (script vars) failed: " + JSON.stringify(vars).left(600))
	root.free()

	return {"name": "RuntimeScriptVarsTests", "passed": passed, "failed": failed, "errors": errors}
