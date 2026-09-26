@tool
extends RefCounted
class_name AISidebarRuntimeInput

## Çalışan oyuna girdi (oyun sürecinde, RuntimeBridge çağırır). Benchmark bulgusu: tıklama ve tuş
## gerektiren kabul kriterleri elle test edilmek zorundaydı.
##   key    : InputEventKey, Input.parse_input_event ile (Input.is_key_pressed / action durumları görür)
##   action : InputEventAction, InputMap'te tanımlı olmalı
##   click  : fare hareketi + düğme bas / bırak, kök viewport'a yerel koordinatla (GUI, _input,
##            _unhandled_input alır). Konum: düğüm yolu (Control merkezi, Node2D konumu, Node3D kamera
##            izdüşümü) ya da görünümün oranı (x, y: 0..1).
## Yalnız editörden başlatılmış debug oyunda çalışır (köprü başka yerde kaydolmaz); proje dosyasına dokunmaz.

const MAX_HOLD_MSEC := 2000

## Olayları gönderir; basılı tutma süresi kadar bekleyip bırakır. Dönüş: sonuç sözlüğü.
static func perform(tree: SceneTree, spec: Dictionary) -> Dictionary:
	var kind := str(spec.get("kind", ""))
	var hold := clampi(int(str(spec.get("hold_ms", 80)).to_float()), 0, MAX_HOLD_MSEC)
	match kind:
		"key":
			var key_name := str(spec.get("key", "")).strip_edges()
			var code := OS.find_keycode_from_string(key_name)
			if key_name.is_empty() or code == KEY_NONE:
				return {"success": false, "error": "UNKNOWN_KEY", "message": "Unknown key name: '%s' (examples: Space, Escape, Enter, A, 1, Up, F1)." % key_name}
			var down := InputEventKey.new()
			down.keycode = code
			down.physical_keycode = code
			down.pressed = true
			Input.parse_input_event(down)
			await _wait(tree, hold)
			var up: InputEventKey = down.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
			return {"success": true, "kind": kind, "key": key_name, "hold_ms": hold}
		"action":
			var action := str(spec.get("action", "")).strip_edges()
			if not InputMap.has_action(action):
				return {"success": false, "error": "UNKNOWN_ACTION", "message": "Input action '%s' is not defined. Defined actions: %s" % [action, ", ".join(_project_actions())]}
			var press := InputEventAction.new()
			press.action = action
			press.pressed = true
			press.strength = 1.0
			Input.parse_input_event(press)
			await _wait(tree, hold)
			var release := InputEventAction.new()
			release.action = action
			release.pressed = false
			Input.parse_input_event(release)
			return {"success": true, "kind": kind, "action": action, "hold_ms": hold}
		"click":
			var target := click_position(tree.root, spec)
			if target.get("ok", false) != true:
				return {"success": false, "error": str(target.get("error", "CLICK_TARGET")), "message": str(target.get("message", ""))}
			var pos: Vector2 = target["position"]
			var button := MOUSE_BUTTON_RIGHT if str(spec.get("button", "left")) == "right" else MOUSE_BUTTON_LEFT
			var root := tree.root
			var motion := InputEventMouseMotion.new()
			motion.position = pos
			motion.global_position = pos
			root.push_input(motion, true)
			var bdown := InputEventMouseButton.new()
			bdown.position = pos
			bdown.global_position = pos
			bdown.button_index = button
			bdown.pressed = true
			root.push_input(bdown, true)
			await _wait(tree, hold)
			var bup: InputEventMouseButton = bdown.duplicate()
			bup.pressed = false
			root.push_input(bup, true)
			return {"success": true, "kind": kind, "position": [snappedf(pos.x, 0.1), snappedf(pos.y, 0.1)], "viewport_size": [root.get_visible_rect().size.x, root.get_visible_rect().size.y]}
	return {"success": false, "error": "INVALID_KIND", "message": "kind must be key, action or click."}

## Tıklanacak viewport konumu: düğüm yolu ya da görünüm oranı (x, y: 0..1).
static func click_position(root: Viewport, spec: Dictionary) -> Dictionary:
	var size := root.get_visible_rect().size
	var node_path := str(spec.get("node_path", "")).strip_edges()
	var pos := Vector2(-1, -1)
	if not node_path.is_empty():
		var node := _resolve(root, node_path)
		if node == null:
			return {"ok": false, "error": "NODE_NOT_FOUND", "message": "Node not found in the running game: " + node_path}
		if node is Control:
			var c: Control = node
			pos = c.get_global_transform_with_canvas() * (c.size * 0.5)
		elif node is Node2D:
			var n2: Node2D = node
			pos = n2.get_global_transform_with_canvas().origin
		elif node is Node3D:
			var n3: Node3D = node
			var cam := n3.get_viewport().get_camera_3d()
			if cam == null:
				return {"ok": false, "error": "NO_CAMERA", "message": "No active Camera3D to project the node onto the screen."}
			if cam.is_position_behind(n3.global_position):
				return {"ok": false, "error": "BEHIND_CAMERA", "message": "The node is behind the camera: " + node_path}
			pos = cam.unproject_position(n3.global_position)
		else:
			return {"ok": false, "error": "NOT_CLICKABLE", "message": "Only Control, Node2D and Node3D nodes have a screen position: " + node_path}
	elif spec.has("x") and spec.has("y"):
		var fx := str(spec["x"]).to_float()
		var fy := str(spec["y"]).to_float()
		if fx < 0.0 or fx > 1.0 or fy < 0.0 or fy > 1.0:
			return {"ok": false, "error": "OUT_OF_RANGE", "message": "x and y are fractions of the game view (0.0 to 1.0): pixel / screenshot width or height."}
		pos = Vector2(fx * size.x, fy * size.y)
	else:
		return {"ok": false, "error": "MISSING_TARGET", "message": "A click needs node_path, or x and y (fractions 0.0 to 1.0)."}
	if pos.x < 0.0 or pos.y < 0.0 or pos.x > size.x or pos.y > size.y:
		return {"ok": false, "error": "OFF_SCREEN", "message": "The click position %s is outside the game view %s." % [str(pos), str(size)]}
	return {"ok": true, "position": pos}

static func _resolve(root: Node, path_str: String) -> Node:
	var clean := path_str.strip_edges()
	for prefix: String in ["/root/", "root/", "/"]:
		if clean.begins_with(prefix):
			clean = clean.trim_prefix(prefix)
			break
	return root.get_node_or_null(clean)

static func _project_actions() -> PackedStringArray:
	var out := PackedStringArray()
	for a: StringName in InputMap.get_actions():
		var s := str(a)
		if not s.begins_with("ui_"):
			out.append(s)
	return out

static func _wait(tree: SceneTree, msec: int) -> void:
	if msec <= 0:
		await tree.process_frame
		return
	await tree.create_timer(msec / 1000.0).timeout
