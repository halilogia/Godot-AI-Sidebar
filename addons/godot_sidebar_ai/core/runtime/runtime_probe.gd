@tool
extends RefCounted
class_name AISidebarRuntimeProbe

## `wait_for_runtime` koşulu (oyun sürecinde, RuntimeBridge çağırır): düğüm özelliği bir değere göre
## karşılaştırılır; koşul sağlanana ya da süre dolana kadar oyunun içinde yoklanır (her yoklama için
## editöre gidip gelinmez). Benchmark bulgusu: ajan "girdi gönder → düğümü incele" döngüsünde tower
## defense'te 54 send_input + 39 inspect_runtime_node turu harcıyordu; bekleme de yoktu (girdinin etkisi
## görünmeden bakılıyordu).
##   property: "health", "visible", iç içe "position.y" ya da "script_vars" değişkeni; exists / not_exists
##             için boş bırakılabilir (düğümün varlığı).

const OPERATORS: Array[String] = ["==", "!=", ">", ">=", "<", "<=", "exists", "not_exists", "contains"]
const MAX_TIMEOUT_MSEC := 15000
const MIN_POLL_MSEC := 16

## Koşulu bir kez değerlendirir. Dönüş: {"met": bool, "actual": değer} ya da {"error", "message"}.
static func evaluate(root: Node, spec: Dictionary) -> Dictionary:
	var op := str(spec.get("operator", "=="))
	if not op in OPERATORS:
		return {"error": "INVALID_OPERATOR", "message": "operator must be one of: " + ", ".join(OPERATORS)}
	var node := AISidebarRuntimeBridge.resolve_node_path(root, str(spec.get("node_path", "")))
	var prop := str(spec.get("property", "")).strip_edges()
	if op in ["exists", "not_exists"]:
		var present := node != null
		if present and not prop.is_empty():
			present = _read(node, prop).get("found", false) == true
		return {"met": present == (op == "exists"), "actual": present}
	if node == null:
		return {"met": false, "actual": null, "missing": "node"}
	if prop.is_empty():
		return {"error": "INVALID_ARGUMENT", "message": "property is required for operator " + op}
	var read := _read(node, prop)
	if read.get("found", false) != true:
		return {"met": false, "actual": null, "missing": "property"}
	var actual: Variant = read["value"]
	return {"met": compare(actual, op, spec.get("value", null)), "actual": AISidebarRuntimeBridge.safe_value(actual, 0)}

## "position.y" gibi iç içe özellik: düğüm özelliği, sonra alt alanlar (vektör bileşeni, sözlük anahtarı).
static func _read(node: Node, prop: String) -> Dictionary:
	var parts := prop.split(".", false)
	if parts.is_empty():
		return {"found": false}
	var head := parts[0]
	var value: Variant
	if head in node:
		value = node.get(head)
	elif head == "child_count":
		# inspect_runtime_node bunu "child_count" diye gösterir; Godot'da özellik değil, yöntemdir.
		value = node.get_child_count()
	else:
		return {"found": false}
	for i in range(1, parts.size()):
		var key := parts[i]
		if value is Dictionary:
			var d: Dictionary = value
			if not d.has(key):
				return {"found": false}
			value = d[key]
		elif value is Object:
			var o: Object = value
			if not key in o:
				return {"found": false}
			value = o.get(key)
		elif typeof(value) in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_COLOR, TYPE_RECT2]:
			var sub: Variant = _component(value, key)
			if sub == null:
				return {"found": false}
			value = sub
		else:
			return {"found": false}
	return {"found": true, "value": value}

static func _component(v: Variant, key: String) -> Variant:
	var d: Dictionary = {}
	match typeof(v):
		TYPE_VECTOR2:
			var v2: Vector2 = v
			d = {"x": v2.x, "y": v2.y}
		TYPE_VECTOR2I:
			var v2i: Vector2i = v
			d = {"x": v2i.x, "y": v2i.y}
		TYPE_VECTOR3:
			var v3: Vector3 = v
			d = {"x": v3.x, "y": v3.y, "z": v3.z}
		TYPE_VECTOR3I:
			var v3i: Vector3i = v
			d = {"x": v3i.x, "y": v3i.y, "z": v3i.z}
		TYPE_COLOR:
			var c: Color = v
			d = {"r": c.r, "g": c.g, "b": c.b, "a": c.a}
		TYPE_RECT2:
			var r: Rect2 = v
			d = {"position": r.position, "size": r.size}
	return d.get(key, null)

## Karşılaştırma: iki taraf da sayıysa sayı olarak; bool ile bool; yoksa metin olarak (== / !=).
## contains: metinde alt metin, dizide öğe, sözlükte anahtar.
static func compare(actual: Variant, op: String, expected_raw: Variant) -> bool:
	var expected: Variant = coerce_expected(actual, expected_raw)
	if op == "contains":
		if actual is String or actual is StringName:
			return str(actual).contains(str(expected))
		if actual is Array:
			var arr: Array = actual
			for item: Variant in arr:
				if _equal(item, expected):
					return true
			return false
		if actual is Dictionary:
			var d: Dictionary = actual
			return d.has(expected) or d.has(str(expected))
		return false
	if op in [">", ">=", "<", "<="]:
		if not (_is_number(actual) and _is_number(expected)):
			return false
		var a := _num(actual)
		var e := _num(expected)
		match op:
			">":
				return a > e
			">=":
				return a >= e
			"<":
				return a < e
			_:
				return a <= e
	var same := _equal(actual, expected)
	return same if op == "==" else not same

## Modeller değeri çoğunlukla metin yollar ("1", "true"): gerçek değer sayı ya da bool ise beklenen de
## o türe çevrilir (yoksa `round >= "1"` hiçbir zaman sağlanmazdı).
static func coerce_expected(actual: Variant, expected: Variant) -> Variant:
	if expected is String:
		var s: String = expected
		if _is_number(actual) and s.strip_edges().is_valid_float():
			return s.strip_edges().to_float()
		if actual is bool and s.strip_edges().to_lower() in ["true", "false"]:
			return s.strip_edges().to_lower() == "true"
	if actual is Vector2 or actual is Vector3 or actual is Vector2i or actual is Vector3i or actual is Color:
		var numbers := vector_numbers(expected)
		if not numbers.is_empty():
			return _vector_like(actual, numbers)
	return expected

## Modeller vektörü "(776, 176)", "Vector2(776, 176)", "776, 176", [776, 176] ya da {"x": 776, "y": 176} diye
## yollar: sayıları çıkarır (çıkarılamazsa boş dizi).
static func vector_numbers(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for item: Variant in value:
			if _is_number(item):
				out.append(_num(item))
			elif item is String:
				var piece: String = item
				if not piece.strip_edges().is_valid_float():
					return []
				out.append(piece.strip_edges().to_float())
			else:
				return []
		return out
	if value is Dictionary:
		var d: Dictionary = value
		for key: String in ["x", "y", "z"] if d.has("x") else ["r", "g", "b", "a"]:
			if d.has(key):
				var n := vector_numbers([d[key]])
				if n.is_empty():
					return []
				out.append(n[0])
		return out
	if value is String:
		var raw: String = value
		var text: String = raw.strip_edges()
		var open := text.find("(")
		if open >= 0:
			text = text.substr(open + 1)
		text = text.replace(")", "").replace("[", "").replace("]", "").replace(";", ",")
		var pieces: PackedStringArray = text.replace(",", " ").split(" ", false)
		return vector_numbers(Array(pieces)) if pieces.size() >= 2 else []
	return []

static func _vector_like(actual: Variant, n: Array) -> Variant:
	var f: Array = n
	if actual is Vector2 and f.size() == 2:
		return Vector2(_num(f[0]), _num(f[1]))
	if actual is Vector3 and f.size() == 3:
		return Vector3(_num(f[0]), _num(f[1]), _num(f[2]))
	if actual is Vector2i and f.size() == 2:
		return Vector2i(roundi(_num(f[0])), roundi(_num(f[1])))
	if actual is Vector3i and f.size() == 3:
		return Vector3i(roundi(_num(f[0])), roundi(_num(f[1])), roundi(_num(f[2])))
	if actual is Color and (f.size() == 3 or f.size() == 4):
		return Color(_num(f[0]), _num(f[1]), _num(f[2]), _num(f[3]) if f.size() == 4 else 1.0)
	return null

static func _equal(a: Variant, b: Variant) -> bool:
	if _is_number(a) and _is_number(b):
		return is_equal_approx(_num(a), _num(b))
	if a is bool or b is bool:
		return typeof(a) == typeof(b) and a == b
	if a == null or b == null:
		return a == null and b == null
	return str(a) == str(b)

static func _num(v: Variant) -> float:
	var f: float = v
	return f

static func _is_number(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT]

## Koşul sağlanana ya da süre dolana kadar yoklar (timeout 0: tek değerlendirme = anlık doğrulama).
static func wait(tree: SceneTree, spec: Dictionary) -> Dictionary:
	var timeout := clampi(int(str(spec.get("timeout_ms", 3000)).to_float()), 0, MAX_TIMEOUT_MSEC)
	var poll := maxi(MIN_POLL_MSEC, int(str(spec.get("poll_ms", 100)).to_float()))
	var start := Time.get_ticks_msec()
	var last: Dictionary = {}
	var polls := 0
	while true:
		last = evaluate(tree.root, spec)
		polls += 1
		if last.has("error"):
			return {"success": false, "error": str(last["error"]), "message": str(last.get("message", ""))}
		var elapsed := Time.get_ticks_msec() - start
		if last.get("met", false) == true:
			return _report(true, "ASSERTION_PASSED" if timeout == 0 else "CONDITION_MET", elapsed, polls, last, spec)
		if elapsed >= timeout:
			break
		await AISidebarRuntimeInput.wait_ms(tree, poll)
	return _report(false, "ASSERTION_FAILED" if timeout == 0 else "TIMEOUT", Time.get_ticks_msec() - start, polls, last, spec)

## Sonuç ve teşhis alanları: kaç kez yoklandı, düğüm / özellik bulundu mu, beklenen ve son değer.
static func _report(ok: bool, status: String, elapsed: int, polls: int, last: Dictionary, spec: Dictionary) -> Dictionary:
	var missing := str(last.get("missing", ""))
	var out := {"success": ok, "status": status, "elapsed_ms": elapsed, "poll_count": polls,
		"operator": str(spec.get("operator", "==")), "expected": spec.get("value", null), "actual": last.get("actual"),
		"node_found": missing != "node", "property_found": missing.is_empty()}
	if not ok:
		out["error"] = status
		if not missing.is_empty():
			out["missing"] = missing
	return out
