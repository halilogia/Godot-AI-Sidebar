@tool
extends RefCounted
class_name AISidebarRuntimeMetrics

## `get_runtime_performance` ölçümü (oyun sürecinde, RuntimeBridge çağırır): "çalışıyor" ile "sağlıklı
## çalışıyor" arasındaki fark. Belirli bir süre boyunca kare süreleri ölçülür (ortalama / p95 / en kötü),
## başında ve sonunda motor sayaçları okunur (düğüm, nesne, yetim düğüm, bellek); fark sızıntıyı gösterir.

const MAX_DURATION_MSEC := 10000
const MIN_DURATION_MSEC := 200

## Anlık motor sayaçları.
static func snapshot() -> Dictionary:
	return {
		"fps": snappedf(Performance.get_monitor(Performance.TIME_FPS), 0.1),
		"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
		"physics_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"memory_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"physics_2d_objects": int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),
		"physics_3d_objects": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
	}

## Süre boyunca kare sürelerini toplar (gerçek saat, kare başına) ve özeti döndürür.
static func measure(tree: SceneTree, duration_ms: int) -> Dictionary:
	var duration := clampi(duration_ms, MIN_DURATION_MSEC, MAX_DURATION_MSEC)
	var before := snapshot()
	var frame_ms: Array = []
	var start := Time.get_ticks_usec()
	var last := start
	while (last - start) < duration * 1000:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append((now - last) / 1000.0)
		last = now
	return summarize(frame_ms, before, snapshot(), duration)

## Kare süreleri (ms) + başlangıç / bitiş sayaçları → rapor (saf; birim testi bunu sınar).
static func summarize(frame_ms: Array, before: Dictionary, after: Dictionary, duration_ms: int) -> Dictionary:
	var sorted: Array = frame_ms.duplicate()
	sorted.sort()
	var total := 0.0
	for f: Variant in sorted:
		var ms: float = f
		total += ms
	var count := sorted.size()
	var avg := total / count if count > 0 else 0.0
	var p95: float = sorted[mini(count - 1, int(count * 0.95))] if count > 0 else 0.0
	var worst: float = sorted[count - 1] if count > 0 else 0.0
	var growth := {}
	for k: String in ["nodes", "objects", "orphan_nodes", "memory_mb"]:
		var a: float = before.get(k, 0)
		var b: float = after.get(k, 0)
		growth[k] = {"from": a, "to": b, "change": snappedf(b - a, 0.1)}
	var notes: Array = []
	if avg > 0.0 and 1000.0 / avg < 30.0:
		notes.append("average FPS below 30")
	if worst > 100.0:
		notes.append("a frame took %.0f ms (hitch)" % worst)
	var node_growth: float = growth["nodes"]["change"]
	var start_nodes: float = before.get("nodes", 0)
	if node_growth > maxf(50.0, start_nodes * 0.5):
		notes.append("node count grew by %d during the sample (possible leak or unbounded spawning)" % int(node_growth))
	var orphans: float = after.get("orphan_nodes", 0)
	if orphans > 0:
		notes.append("%d orphan node(s): nodes created but never added to the tree or freed" % int(orphans))
	return {
		"duration_ms": duration_ms,
		"frames": count,
		"fps_avg": snappedf(1000.0 / avg, 0.1) if avg > 0.0 else 0.0,
		"frame_ms": {"avg": snappedf(avg, 0.01), "p95": snappedf(p95, 0.01), "worst": snappedf(worst, 0.01)},
		"now": after,
		"growth": growth,
		"warnings": notes,
	}
