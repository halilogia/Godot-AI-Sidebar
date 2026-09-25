@tool
extends RefCounted

## Tipin göremediğini test görür (Refactor Faz 4.A.7):
## 1. addons/ + tests/ + tools/ içindeki her sabit preload / load yolu (res://…, tırnak içinde)
##    diskte vardır (typecheck yalnızca derlenen dosyanın kendi preload'larını görür;
##    `load()` çalışma anına kadar denetlenmez).
## 2. Sinyal ↔ handler argüman sayısı: kurulmuş bir dock + host + runner üzerinden erişilen
##    her nesnenin her sinyal bağlantısı gezilir; handler'ın zorunlu/toplam parametre sayısı
##    sinyalin argüman sayısıyla (bind/unbind dahil) uyuşmalıdır. Uyuşmazlık derlemede
##    görünmez, yalnızca sinyal yayıldığında hata verir.

const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarAgentHost = preload("res://addons/godot_sidebar_ai/core/agent/agent_host.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")

const SCAN_DIRS = ["res://addons/godot_sidebar_ai", "res://tests", "res://tools"]

class SilentProvider extends AISidebarAIProvider:
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		pass

static func _collect(path: String, out: Array) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(path.path_join(f))
	for d in dir.get_directories():
		_collect(path.path_join(d), out)

## Kaynak metindeki sabit (pre)load yollarından diskte olmayanları döndürür (saf).
static func missing_load_paths(sources: Dictionary) -> Array:
	var re = RegEx.create_from_string("\\b(?:pre)?load\\(\\s*\"(res://[^\"]+)\"\\s*\\)")
	var missing: Array = []
	for file in sources.keys():
		for m in re.search_all(str(sources[file])):
			var p = m.get_string(1)
			if not FileAccess.file_exists(p) and not DirAccess.dir_exists_absolute(p):
				missing.append(str(file).get_file() + " -> " + p)
	return missing

## Tek bağlantının arity hükmü: "" uyumlu; değilse açıklama.
static func connection_mismatch(emitter: Object, signal_info: Dictionary, conn: Dictionary) -> String:
	var c: Callable = conn["callable"]
	if not c.is_valid() or c.get_object() == null:
		return ""  # geçersiz / nesnesiz callable: iç gözlem yok (lambda metot listesinde bulunmaz, aşağıda atlanır)
	var target = c.get_object()
	var method = str(c.get_method())
	var info: Dictionary = {}
	for m in target.get_method_list():
		if str(m["name"]) == method:
			info = m
	if info.is_empty() or (int(info.get("flags", 0)) & METHOD_FLAG_VARARG) != 0:
		return ""
	var total = (info["args"] as Array).size()
	var required = total - (info.get("default_args", []) as Array).size()
	var provided = (signal_info["args"] as Array).size() - c.get_unbound_arguments_count() + c.get_bound_arguments_count()
	if provided < required or provided > total:
		return "%s.%s(%d arg) -> %s.%s(zorunlu %d, toplam %d)" % [emitter.get_class() if emitter.get_script() == null else str(emitter.get_script().resource_path.get_file()), signal_info["name"], provided, str(target.get_script().resource_path.get_file()) if target.get_script() else target.get_class(), method, required, total]
	return ""

## Başlangıç nesnelerinden bağlantı hedeflerine ve alt düğümlere yürür; uyuşmazlıkları toplar.
static func scan_signal_arity(roots: Array) -> Dictionary:
	var seen: Dictionary = {}
	var queue: Array = roots.duplicate()
	var mismatches: Array = []
	var checked = 0
	while not queue.is_empty():
		var o = queue.pop_front()
		if not (o is Object) or not is_instance_valid(o) or seen.has(o.get_instance_id()):
			continue
		seen[o.get_instance_id()] = true
		if o is Node:
			for ch in (o as Node).get_children(true):
				queue.append(ch)
		for s in o.get_signal_list():
			for conn in o.get_signal_connection_list(s["name"]):
				checked += 1
				var bad = connection_mismatch(o, s, conn)
				if not bad.is_empty():
					mismatches.append(bad)
				var t = (conn["callable"] as Callable).get_object()
				if t != null:
					queue.append(t)
	return {"mismatches": mismatches, "checked": checked, "objects": seen.size()}

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Sabit (pre)load yolları
	var files: Array = []
	for d in SCAN_DIRS:
		_collect(d, files)
	var sources: Dictionary = {}
	for f in files:
		sources[f] = FileAccess.get_file_as_string(f)
	var missing = missing_load_paths(sources)
	# Kendini sınar: uydurma yol yakalanmalı, var olan yol yakalanmamalı.
	var self_check = missing_load_paths({"x.gd": "const A = preload(\"res://__nope__/a.gd\")\nvar b = load(\"res://tests/test_runner.gd\")"}) == ["x.gd -> res://__nope__/a.gd"]
	if files.size() > 100 and self_check and missing.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T1 (load paths) failed: files=%d self_check=%s missing=%s" % [files.size(), str(self_check), str(missing)])

	# 2. Sinyal ↔ handler argüman sayısı (editör yolundaki bağlama; dock ağaçta değil)
	var dock = ChatDockScene.instantiate()
	dock._ready()
	var host = AISidebarAgentHost.new()
	host.set_provider(SilentProvider.new())
	dock.attach_agent_host(host)
	var scan = scan_signal_arity([dock, host, host.runner, host.context, host.provider])
	# Kendini sınar: bilerek yanlış bağlanmış bir handler yakalanmalı.
	var probe = Node.new()
	var probe_target = Node.new()
	probe.child_entered_tree.connect(probe_target.set_name.unbind(1).bind("a", "b"))
	var probe_scan = scan_signal_arity([probe])
	probe.free()
	probe_target.free()
	if scan["checked"] > 20 and scan["mismatches"].is_empty() and probe_scan["mismatches"].size() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (signal arity) failed: checked=%d objects=%d probe=%s mismatches=%s" % [scan["checked"], scan["objects"], str(probe_scan["mismatches"]), str(scan["mismatches"])])
	dock.stream.stop_thinking_timer()
	for child in dock.message_stream.get_children():
		child.free()
	dock.free()
	host.free()

	return {"name": "StaticReferenceTests", "passed": passed, "failed": failed, "errors": errors}
