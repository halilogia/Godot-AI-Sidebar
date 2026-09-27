@tool
extends RefCounted

## Uzun görev: betikli sağlayıcıyla gerçek AgentRunner + gerçek yazma / okuma araçları, 45 adım.
## Kısa senaryolar sıkıştırma eşiğine hiç ulaşmıyordu; benchmark'ta ajan bu yüzden yazdığı dosyaları
## unutup "proje boş" diye baştan başladı ve başarısız yazımları başarılı sandı. Burada modele giden
## SON bağlam denetlenir: sıkıştırma oldu, istek duruyor, yazılan dosyalar ve "devam et" ipucu özette,
## başarısız yazım "yazıldı" listesinde değil, son okunan dosyanın içeriği tam.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")

const DIR := "res://tests/tmp_long"
const STEPS := 45
const BAD_STEP := 3
const REQUEST := "Uzun görev: strateji oyunu çekirdeğini dosya dosya yaz"

class ScriptedProvider extends AISidebarAIProvider:
	var last_messages: Array = []
	var sent: int = 0
	func send_chat(messages: Array, _tools_schema: Array) -> void:
		sent += 1
		last_messages = messages.duplicate(true)
	func respond(text: String, tool_calls: Array = []) -> void:
		response_received.emit(text, "", tool_calls)

static func _path(i: int) -> String:
	return DIR + "/part_%02d.gd" % i

static func _call(id: String, tool_name: String, args: Dictionary) -> Dictionary:
	return {"id": id, "name": tool_name, "arguments": args}

static func run() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(DIR)
	var provider := ScriptedProvider.new()
	var ctx := AISidebarAgentContext.new()
	var runner := AISidebarAgentRunner.new(provider, ctx)
	runner.enable_planning_gate = false
	runner.start_task(REQUEST)
	for i in STEPS:
		var content := "extends RefCounted\n\nfunc value() -> int:\n\treturn %d\n" % i
		if i == BAD_STEP:
			content = "extends RefCounted\n\nfunc value( -> int:\n"  # sözdizimi hatası: yazılmamalı
		var calls: Array = [_call("w%d" % i, "create_or_update_script", {"file_path": _path(i), "content": content})]
		if i > 0 and i != BAD_STEP + 1:
			calls.append(_call("r%d" % i, "read_script", {"file_path": _path(i - 1)}))
		provider.respond("", calls)
	var steps_ok := provider.sent >= STEPS and runner.is_running()

	var joined := ""
	for m: Variant in provider.last_messages:
		joined += str((m as Dictionary).get("content", "")) + "\n"
	var head := str((ctx.messages[0] as Dictionary).get("content", "")) if not ctx.messages.is_empty() else ""
	var compacted := head.begins_with("[ÖNCEKİ AJAN")
	var request_kept := joined.contains(REQUEST)
	var files_listed := joined.contains(_path(0)) and joined.contains(_path(STEPS - 1))
	var continue_hint := joined.contains("Aynı görev sürüyor")
	var bad_not_listed := not head.contains(_path(BAD_STEP))
	var bad_not_on_disk := not FileAccess.file_exists(_path(BAD_STEP))
	var last_read_full := joined.contains("return %d" % (STEPS - 2))

	if runner.is_running():
		runner.stop()
	for f: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))
	DirAccess.remove_absolute(DIR)

	var checks := [
		["L1 ran %d steps" % STEPS, steps_ok],
		["L2 compaction happened", compacted],
		["L3 user request kept", request_kept],
		["L4 written files listed", files_listed],
		["L5 continue hint", continue_hint],
		["L6 failed write not listed / not on disk", bad_not_listed and bad_not_on_disk],
		["L7 latest read in full", last_read_full],
	]
	var passed := 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed (sent=%d msgs=%d)" % [provider.sent, ctx.messages.size()])
	return {"name": "LongTaskTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
