@tool
extends RefCounted
class_name AISidebarRuntimePhysicsDoctor

## Çalışan oyunda çarpışma / tetikleyici hatalarını ölçer (oyun tarafı): collision layer / mask uyuşmazlığı,
## şekilsiz ya da devre dışı CollisionShape, kapalı monitoring, bağlı sinyalin hiçbir cisimle eşleşmemesi.
## Benchmark'ta görülen tipik hata: Area layer 1'i dinliyor, oyuncu layer 2'de, body_entered hiç tetiklenmiyor.
## Çıktı: {"objects": [...], "issues": [{code, node, message}], "summary": String}.

const MAX_OBJECTS := 12

static func diagnose(root: Node, target: Node) -> Dictionary:
	var everything: Array[Node] = []
	_collect(root, everything)
	var subjects: Array[Node] = []
	if _is_body(target):
		subjects.append(target)
	else:
		for n in everything:
			if target.is_ancestor_of(n) and subjects.size() < MAX_OBJECTS:
				subjects.append(n)
	var objects: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	for s in subjects:
		objects.append(_describe(root, s))
		_check(root, s, everything, issues)
	if subjects.is_empty():
		issues.append({"code": "NO_COLLISION_OBJECT", "node": str(root.get_path_to(target)), "message": "no Area / PhysicsBody / CharacterBody at or below this node"})
	return {"objects": objects, "issues": issues, "summary": "%d collision object(s) checked, %d issue(s)" % [subjects.size(), issues.size()]}

static func _is_body(n: Node) -> bool:
	return n is CollisionObject2D or n is CollisionObject3D

static func _collect(n: Node, out: Array[Node]) -> void:
	if _is_body(n):
		out.append(n)
	for c in n.get_children():
		_collect(c, out)

static func layers_of(mask: int) -> Array[int]:
	var out: Array[int] = []
	for i in 32:
		if mask & (1 << i) != 0:
			out.append(i + 1)
	return out

static func _shapes(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in n.get_children():
		if c is CollisionShape2D or c is CollisionShape3D or c is CollisionPolygon2D or c is CollisionPolygon3D:
			out.append(c)
	return out

static func _shape_disabled(s: Node) -> bool:
	return _bool(s, "disabled")

static func _describe(root: Node, n: Node) -> Dictionary:
	var d := {"node": str(root.get_path_to(n)), "type": n.get_class(), "layers": layers_of(_int(n, "collision_layer")), "mask": layers_of(_int(n, "collision_mask")), "shapes": _shapes(n).size()}
	if n is Area2D or n is Area3D:
		d["monitoring"] = _bool(n, "monitoring")
		d["monitorable"] = _bool(n, "monitorable")
	return d

static func _check(root: Node, n: Node, everything: Array[Node], issues: Array[Dictionary]) -> void:
	var path := str(root.get_path_to(n))
	var layer := _int(n, "collision_layer")
	var mask := _int(n, "collision_mask")
	var shapes := _shapes(n)
	var live := 0
	for s in shapes:
		var shape: Variant = s.get("shape")
		if _shape_disabled(s):
			issues.append({"code": "SHAPE_DISABLED", "node": str(root.get_path_to(s)), "message": "collision shape is disabled"})
		elif shape == null and not (s is CollisionPolygon2D or s is CollisionPolygon3D):
			issues.append({"code": "SHAPE_MISSING", "node": str(root.get_path_to(s)), "message": "CollisionShape has no shape resource"})
		else:
			live += 1
	if live == 0:
		issues.append({"code": "NO_SHAPE", "node": path, "message": "%s has no enabled collision shape, so it can never collide or detect anything" % n.get_class()})
	if layer == 0 and mask == 0:
		issues.append({"code": "NO_LAYERS", "node": path, "message": "collision_layer and collision_mask are both empty: it neither exists for others nor detects any"})
	var is_area := n is Area2D or n is Area3D
	if is_area and not _bool(n, "monitoring") and _has_entry_connections(n):
		issues.append({"code": "MONITORING_OFF", "node": path, "message": "monitoring is off but body_entered / area_entered is connected: it will never fire"})
	if is_area and _has_entry_connections(n):
		var seen: Array[String] = []
		var matched := false
		for other in everything:
			if other == n or other.is_ancestor_of(n) or n.is_ancestor_of(other):
				continue
			var other_layer := _int(other, "collision_layer")
			seen.append("%s layers %s" % [root.get_path_to(other), str(layers_of(other_layer))])
			if mask & other_layer != 0:
				matched = true
		if not matched:
			issues.append({"code": "NO_MATCHING_LAYER", "node": path, "message": "detects layers %s but no other collision object is on them. Others: %s" % [str(layers_of(mask)), "; ".join(seen.slice(0, 6)) if not seen.is_empty() else "none in the scene"]})

static func _has_entry_connections(n: Node) -> bool:
	for sig: String in ["body_entered", "area_entered"]:
		if not n.get_signal_connection_list(sig).is_empty():
			return true
	return false

static func _int(n: Node, prop: String) -> int:
	var v: Variant = n.get(prop)
	return v if v is int else 0

static func _bool(n: Node, prop: String) -> bool:
	var v: Variant = n.get(prop)
	return v if v is bool else false
