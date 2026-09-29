@tool
extends RefCounted
class_name AISidebarRuntimeState

## `set_runtime_property`: çalışan oyunda bir düğüm özelliğini ya da script değişkenini ayarlar (yalnız o oyun
## süreci; proje dosyası değişmez). Kilit durumları saniyeler içinde denemek için: "skoru 99 yap, kazanma
## ekranı çıkıyor mu?", "canı 0 yap, oyun bitiyor mu?". Oyunu dakikalarca oynayarak aynı duruma varmaya çalışmanın
## (benchmark: platformer 3930 piksel yürüyüşte zaman aşımı) yerine geçer. Sonuç gerçek oynanış kanıtı değildir.

const BLOCKED := ["script", "name", "owner", "scene_file_path", "process_mode", "unique_name_in_owner"]
const COMPONENTS := ["x", "y", "z", "r", "g", "b", "a"]

static func set_value(root: Node, spec: Dictionary) -> Dictionary:
	var path := str(spec.get("node_path", "")).strip_edges()
	var prop := str(spec.get("property", "")).strip_edges()
	if path.is_empty() or prop.is_empty() or not spec.has("value"):
		return _fail("INVALID_ARGUMENT", "node_path, property and value are required.")
	var node := AISidebarRuntimeBridge.resolve_node_path(root, path)
	if node == null:
		return _fail("NODE_NOT_FOUND", "Node not found in the running game: " + path)
	var parts := prop.split(".", false)
	var head: String = parts[0]
	if head in BLOCKED:
		return _fail("PROPERTY_BLOCKED", "'%s' cannot be set at runtime with this tool." % head)
	if not head in node:
		return _fail("PROPERTY_NOT_FOUND", "%s has no property or script variable '%s' (inspect_runtime_node lists them)." % [path, head])
	var old: Variant = node.get(head)
	var updated: Variant = AISidebarRuntimeProbe.coerce_expected(old, spec["value"])
	if parts.size() == 2 and (old is Vector2 or old is Vector3 or old is Color):
		var comp: String = parts[1]
		if not comp in COMPONENTS or not AISidebarRuntimeProbe._is_number(updated):
			return _fail("INVALID_ARGUMENT", "Cannot set component '%s' of %s to that value." % [comp, head])
		var f: float = AISidebarRuntimeProbe._num(updated)
		if old is Vector2:
			var v2: Vector2 = old
			v2[comp] = f
			updated = v2
		elif old is Vector3:
			var v3: Vector3 = old
			v3[comp] = f
			updated = v3
		else:
			var col: Color = old
			col[comp] = f
			updated = col
	elif parts.size() > 1:
		return _fail("INVALID_ARGUMENT", "Only one vector / color component (e.g. position.x) can be set.")
	var both_numbers: bool = AISidebarRuntimeProbe._is_number(old) and AISidebarRuntimeProbe._is_number(updated)
	if typeof(old) != TYPE_NIL and typeof(updated) != typeof(old) and not both_numbers:
		return _fail("TYPE_MISMATCH", "%s is a %s; got a %s." % [head, type_string(typeof(old)), type_string(typeof(updated))])
	node.set(head, updated)
	return {"success": true, "node": path, "property": prop, "old_value": AISidebarRuntimeBridge.safe_value(old, 0), "new_value": AISidebarRuntimeBridge.safe_value(node.get(head), 0),
		"note": "State was injected into the running game. It proves how the game reacts to that state, not that a player can reach it."}

static func _fail(code: String, message: String) -> Dictionary:
	return {"success": false, "error": code, "message": message}
