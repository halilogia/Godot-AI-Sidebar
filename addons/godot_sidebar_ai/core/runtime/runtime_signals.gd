@tool
extends RefCounted
class_name AISidebarRuntimeSignals

## `trace_runtime_signals` (oyun sürecinde, RuntimeBridge çağırır): bir düğümün sinyalleri süre boyunca
## dinlenir; hangi sinyal, hangi anda, hangi argümanla çıktığı sıralı bir olay listesi olur ("score_changed
## 842 ms'de 10 ile çıktı, game_over hiç çıkmadı"). Ekran görüntüsü ya da tekrar tekrar düğüm incelemeden
## davranışın kanıtı. Sinyal adı verilmezse düğümün betiğinde tanımlı sinyaller dinlenir.

const MAX_EVENTS := 200
const MAX_DURATION_MSEC := 10000

## Betikte tanımlı (motor sınıfından gelmeyen) sinyaller.
static func script_signals(node: Object) -> Array[String]:
	var out: Array[String] = []
	for sig: Dictionary in node.get_signal_list():
		var sig_name := str(sig.get("name", ""))
		if not ClassDB.class_has_signal(node.get_class(), sig_name):
			out.append(sig_name)
	return out

## Dinlemeyi başlatır. Dönüş: {"events": Array, "connected": Array, "missing": Array, "_calls": Array}.
static func begin(node: Object, names: Array, started_msec: int) -> Dictionary:
	var events: Array = []
	var connected: Array = []
	var missing: Array = []
	var calls: Array = []
	var session := {"events": events, "connected": connected, "missing": missing, "_calls": calls, "dropped": 0}
	var wanted: Array = names
	if wanted.is_empty():
		wanted = script_signals(node)
	for n: Variant in wanted:
		var sig_name := str(n)
		if not node.has_signal(sig_name):
			missing.append(sig_name)
			continue
		var dropped_ref := session
		var cb := func(...args: Array) -> void:
			if events.size() >= MAX_EVENTS:
				var dropped_so_far: int = dropped_ref["dropped"]
				dropped_ref["dropped"] = dropped_so_far + 1
				return
			var shown: Array = []
			for a: Variant in args:
				shown.append(AISidebarRuntimeBridge.safe_value(a, 0))
			events.append({"t_ms": Time.get_ticks_msec() - started_msec, "signal": sig_name, "args": shown})
		node.connect(sig_name, cb)
		calls.append([sig_name, cb])
		connected.append(sig_name)
	return session

## Bağlantıları söker ve raporu döndürür.
static func finish(node: Object, session: Dictionary) -> Dictionary:
	var calls: Array = session["_calls"]
	var events: Array = session["events"]
	var connected: Array = session["connected"]
	if is_instance_valid(node):
		for pair: Variant in calls:
			var p: Array = pair
			var sig_name := str(p[0])
			var cb: Callable = p[1]
			if node.is_connected(sig_name, cb):
				node.disconnect(sig_name, cb)
	var counts := {}
	for e: Variant in events:
		var ed: Dictionary = e
		var k := str(ed["signal"])
		var seen: int = counts.get(k, 0)
		counts[k] = seen + 1
	var silent: Array = []
	for c: Variant in connected:
		if not counts.has(str(c)):
			silent.append(c)
	return {"events": events, "count": events.size(), "counts": counts,
		"silent": silent, "missing": session["missing"], "dropped": session["dropped"]}

## Süre boyunca dinler (gerçek saat, kare başına).
static func trace(tree: SceneTree, node_path: String, names: Array, duration_ms: int) -> Dictionary:
	var node := AISidebarRuntimeBridge.resolve_node_path(tree.root, node_path)
	if node == null:
		return {"success": false, "error": "NODE_NOT_FOUND", "message": "Node not found in the running game: " + node_path}
	var duration := clampi(duration_ms, 100, MAX_DURATION_MSEC)
	var start := Time.get_ticks_msec()
	var session := begin(node, names, start)
	var connected: Array = session["connected"]
	if connected.is_empty():
		var hint := "None of the requested signals exist on %s." % node_path if not names.is_empty() else "%s has no script-defined signals; name the signals to trace." % node_path
		return {"success": false, "error": "NO_SIGNALS", "message": hint, "missing": session["missing"]}
	while Time.get_ticks_msec() - start < duration:
		await tree.process_frame
	var report := finish(node, session)
	report["success"] = true
	report["duration_ms"] = duration
	report["node"] = node_path
	return report
