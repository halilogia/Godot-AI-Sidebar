@tool
extends RefCounted
class_name AISidebarUIAuditScenario

## Gizli panel / durum senaryosu (SRP): oyunlarda açılıp kapanan paneller (teknoloji ağacı, olay penceresi,
## ordu listesi …) varsayılan durumda görünmez, bu yüzden audit_ui_layout / audit_ui_touch onlara bakamaz.
## Bir senaryo "states" listesidir; her durum sırayla uygulanır, yerleşimin oturması için kare beklenir,
## denetim çalışır ve durum GERİ ALINIR (açık sahne kirlenmez).
##
## Durum biçimi (hepsi isteğe bağlı):
##   {"name": "tech", "show": ["TechTreePanel"], "hide": ["TopBar"],
##    "set": {"EventPopup": {"modulate": "Color(1,1,1,1)"}},
##    "call": [{"node": "StrategyHud", "method": "open_tech", "args": ["p_hucum"]}],
##    "audit": ["TechTreePanel"]}        # boşsa kök denetlenir
## Düğüm başvurusu: "" = kök, "%Ad" = benzersiz ad, "A/B" = göreli yol, "Ad" = ada göre ilk eşleşme.
## Senaryo dosyası (JSON): {"scene": "res://...", "viewport": [1600, 900], "platform": "desktop", "states": [...]}.

## Çağrılması yasak yöntemler: senaryo yalnız arayüzü açıp kapatmalı, düğümü / sahneyi yok etmemeli.
const BLOCKED_METHODS: Array[String] = ["free", "queue_free", "set_script", "replace_by", "reparent", "remove_child", "add_child", "set_owner"]
## Her durumdan sonra yerleşimin oturması için beklenen kare sayısı.
const SETTLE_FRAMES: int = 3
const MAX_STATES: int = 64

## JSON senaryo dosyasını okur. Dönüş: {"ok": bool, "scenario": Dictionary, "error": String}.
static func load_scenario(path: String) -> Dictionary:
	var clean: String = path.strip_edges()
	if clean.is_empty() or not FileAccess.file_exists(clean):
		return {"ok": false, "scenario": {}, "error": "Senaryo dosyası bulunamadı: " + clean}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(clean))
	if not (parsed is Dictionary):
		return {"ok": false, "scenario": {}, "error": "Senaryo geçerli bir JSON nesnesi değil: " + clean}
	return {"ok": true, "scenario": parsed, "error": ""}

## "states" değerini sözlük listesine çevirir: düz metin = o düğümü göster; geçersiz girdi atlanır; sayı sınırlıdır.
static func normalize_states(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw is Array):
		return out
	var list: Array = raw
	for item: Variant in list:
		if out.size() >= MAX_STATES:
			break
		if item is Dictionary:
			out.append(item)
		elif item is String and not str(item).strip_edges().is_empty():
			out.append({"name": str(item), "show": [str(item)], "audit": [str(item)]})
	return out

## Düğüm başvurusunu çözer; bulunamazsa null.
static func resolve(root: Node, ref: String) -> Node:
	var r: String = ref.strip_edges()
	if r.is_empty() or r == ".":
		return root
	if r.begins_with("%"):
		return root.get_node_or_null(r)
	var by_path: Node = root.get_node_or_null(r)
	if by_path:
		return by_path
	return root.find_child(r, true, false)

## Durumu uygular. Dönüş: {"undo": Array[Callable], "errors": Array[String]}. "call" yalnız allow_calls ile çalışır
## (editörde açık sahneye yöntem çağrısı geri alınamaz; çalışan oyunda / örneklenmiş sahnede serbesttir).
static func apply_state(root: Node, state: Dictionary, allow_calls: bool) -> Dictionary:
	var undo: Array[Callable] = []
	var errors: Array[String] = []
	for ref: Variant in _as_array(state.get("show", [])):
		_set_visible(root, str(ref), true, undo, errors)
	for ref: Variant in _as_array(state.get("hide", [])):
		_set_visible(root, str(ref), false, undo, errors)
	var props: Variant = state.get("set", {})
	if props is Dictionary:
		var pd: Dictionary = props
		for ref: Variant in pd.keys():
			_set_properties(root, str(ref), pd[ref], undo, errors)
	for call_v: Variant in _as_array(state.get("call", [])):
		if not allow_calls:
			errors.append("'call' bu bağlamda kapalı (açık sahne geri alınamaz); çalışan oyunda veya scenario ile kullan.")
			break
		_call_method(root, call_v, errors)
	return {"undo": undo, "errors": errors}

static func revert(undo: Array[Callable]) -> void:
	for i: int in range(undo.size() - 1, -1, -1):
		undo[i].call()

## Her durumu sırayla uygular ve audit(node) çağrısını bekler. audit: Callable(Node) -> Dictionary (araç sonucu).
## Dönüş: {"states": [...], "issues": [...], "by_priority": {...}, "passed": bool, "state_errors": [...]}.
static func run(root: Node, states: Array[Dictionary], audit: Callable, allow_calls: bool) -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var reports: Array[Dictionary] = []
	var all_issues: Array[Dictionary] = []
	var totals: Dictionary = {"P0": 0, "P1": 0, "P2": 0}
	var state_errors: Array[String] = []
	var index: int = 0
	for state: Dictionary in states:
		index += 1
		var sname: String = str(state.get("name", "state_%d" % index))
		var applied: Dictionary = apply_state(root, state, allow_calls)
		for e: Variant in applied["errors"]:
			state_errors.append("[%s] %s" % [sname, str(e)])
		if tree:
			for _i: int in SETTLE_FRAMES:
				await tree.process_frame
		var targets: Array = _as_array(state.get("audit", []))
		if targets.is_empty():
			targets = [""]
		var rep: Dictionary = {"name": sname, "audited": [], "issue_count": 0, "by_priority": {"P0": 0, "P1": 0, "P2": 0}}
		for ref: Variant in targets:
			var node: Node = resolve(root, str(ref))
			if node == null:
				state_errors.append("[%s] denetim hedefi bulunamadı: %s" % [sname, str(ref)])
				continue
			var res: Dictionary = audit.call(node)
			var data: Dictionary = res.get("data", res)
			if not data.has("issues"):
				state_errors.append("[%s] denetim çalışmadı (%s): %s" % [sname, str(ref), str(res.get("error", res.get("message", "")))])
				continue
			(rep["audited"] as Array).append(str(ref) if str(ref) != "" else "(root)")
			var by_p: Dictionary = data.get("by_priority", {})
			for k: String in totals.keys():
				totals[k] = int(totals[k]) + int(by_p.get(k, 0))
				(rep["by_priority"] as Dictionary)[k] = int((rep["by_priority"] as Dictionary)[k]) + int(by_p.get(k, 0))
			for iss: Variant in data["issues"]:
				if iss is Dictionary:
					var tagged: Dictionary = (iss as Dictionary).duplicate()
					tagged["state"] = sname
					all_issues.append(tagged)
					rep["issue_count"] = int(rep["issue_count"]) + 1
		reports.append(rep)
		revert(applied["undo"])
	if tree:
		await tree.process_frame
	return {"states": reports, "issues": all_issues, "by_priority": totals, "state_errors": state_errors,
		"passed": int(totals["P0"]) + int(totals["P1"]) == 0 and state_errors.is_empty()}

## Sahneyi verilen boyutlu bir SubViewport içine örnekler (editör / oyun penceresinden bağımsız ölçüm).
## Dönüş: {"holder": SubViewport, "root": Node} ya da {"error": String}. Bitince holder.queue_free() çağrılır.
static func mount_scene(scene_path: String, size: Vector2i) -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load(scene_path) as PackedScene if ResourceLoader.exists(scene_path) else null
	if tree == null or packed == null:
		return {"error": "Sahne yüklenemedi: " + scene_path}
	var holder := SubViewport.new()
	holder.size = size
	holder.disable_3d = true
	holder.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(holder)
	var inst: Node = packed.instantiate()
	holder.add_child(inst)
	return {"holder": holder, "root": inst}

## "viewport": [w, h] → Vector2i (geçersizse varsayılan).
static func viewport_size(v: Variant, fallback: Vector2i = Vector2i(1280, 720)) -> Vector2i:
	if v is Array and (v as Array).size() == 2:
		var a: Array = v
		var w: int = clampi(int(a[0]), 320, 7680)
		var h: int = clampi(int(a[1]), 240, 4320)
		return Vector2i(w, h)
	return fallback

# --- iç yardımcılar ---

static func _as_array(v: Variant) -> Array:
	if v is Array:
		return v
	if v is String and not str(v).is_empty():
		return [v]
	return []

static func _set_visible(root: Node, ref: String, value: bool, undo: Array[Callable], errors: Array[String]) -> void:
	var node: Node = resolve(root, ref)
	if node == null or not ("visible" in node):
		errors.append("görünürlük için düğüm bulunamadı: " + ref)
		return
	var before: bool = bool(node.get("visible"))
	node.set("visible", value)
	# Üst zincirdeki gizli kapsayıcılar da açılır; aksi halde panel yine görünmez kalır.
	if value:
		var p: Node = node.get_parent()
		while p != null and p != root.get_parent():
			if "visible" in p and not bool(p.get("visible")):
				var parent_node: Node = p
				parent_node.set("visible", true)
				undo.append(func() -> void: if is_instance_valid(parent_node): parent_node.set("visible", false))
			p = p.get_parent()
	undo.append(func() -> void: if is_instance_valid(node): node.set("visible", before))

static func _set_properties(root: Node, ref: String, props: Variant, undo: Array[Callable], errors: Array[String]) -> void:
	var node: Node = resolve(root, ref)
	if node == null or not (props is Dictionary):
		errors.append("özellik atamak için düğüm bulunamadı: " + ref)
		return
	var pd: Dictionary = props
	for key: Variant in pd.keys():
		var prop: String = str(key)
		var before: Variant = node.get(prop)
		var value: Variant = pd[key]
		if value is String and str(value).contains("("):
			value = str_to_var(str(value))
		node.set(prop, value)
		undo.append(func() -> void: if is_instance_valid(node): node.set(prop, before))

static func _call_method(root: Node, call_v: Variant, errors: Array[String]) -> void:
	if not (call_v is Dictionary):
		errors.append("'call' girdisi sözlük olmalı.")
		return
	var spec: Dictionary = call_v
	var method: String = str(spec.get("method", ""))
	var node: Node = resolve(root, str(spec.get("node", "")))
	if node == null or method.is_empty() or method in BLOCKED_METHODS or not node.has_method(method):
		errors.append("çağrı yapılamadı: %s.%s" % [str(spec.get("node", "")), method])
		return
	node.callv(method, _as_array(spec.get("args", [])))
