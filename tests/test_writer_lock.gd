@tool
extends RefCounted

## Tek aktif yazıcı (v3.0.1): kilit kuralları, dış kiranın süresi ve sidebar ajanının
## dış ajan yazarken değiştirici araç çalıştıramaması (okuma araçları etkilenmez).

const AISidebarWriterLock = preload("res://addons/godot_sidebar_ai/core/security/writer_lock.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")

class ScriptedProvider extends AISidebarAIProvider:
	var responses: Array = []
	var holders_seen: Array = []

	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		holders_seen.append(AISidebarWriterLock.holder())
		if responses.size() > 0:
			var r: Dictionary = responses.pop_front()
			response_received.emit(str(r.get("content", "")), "", r.get("tool_calls", []))

static func _tool_result(ctx: AISidebarAgentContext, tool_name: String) -> String:
	for m: Variant in ctx.messages:
		var msg: Dictionary = m
		if msg.get("role", "") == "tool" and msg.get("name", "") == tool_name:
			return str(msg.get("content", ""))
	return ""

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []
	var H := AISidebarWriterLock.Holder

	# 1. Kurallar: tutan yeniden alabilir, diğeri WRITER_BUSY alır, okuma / oyun kontrolü serbest,
	# yalnız tutan bırakabilir.
	AISidebarWriterLock.reset()
	var a1 := AISidebarWriterLock.try_acquire(H.SIDEBAR)
	var a2 := AISidebarWriterLock.try_acquire(H.SIDEBAR)
	var ext_write := AISidebarWriterLock.claim(H.EXTERNAL, "add_node")
	var ext_read := AISidebarWriterLock.claim(H.EXTERNAL, "get_scene_tree")
	var ext_play := AISidebarWriterLock.claim(H.EXTERNAL, "play_game")
	AISidebarWriterLock.release(H.EXTERNAL)
	var still_sidebar := AISidebarWriterLock.holder() == H.SIDEBAR
	AISidebarWriterLock.release(H.SIDEBAR)
	if a1 and a2 and ext_write.get("success", true) == false and ext_write["error"]["code"] == "WRITER_BUSY" \
			and str(ext_write["error"]["message"]).begins_with("Holder: SIDEBAR") and ext_read.is_empty() and ext_play.is_empty() \
			and still_sidebar and AISidebarWriterLock.holder() == H.NONE:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (lock rules) failed: ext_write=%s" % str(ext_write))

	# 2. Dış kira: sidebar'ı engeller, bekleme süresini bildirir, süresi dolunca kendiliğinden düşer.
	AISidebarWriterLock.reset()
	AISidebarWriterLock.external_lease_msec = 40
	var e1 := AISidebarWriterLock.try_acquire(H.EXTERNAL)
	var side_busy := AISidebarWriterLock.claim(H.SIDEBAR, "set_node_property")
	var side_msg := str(side_busy["error"]["message"]) if side_busy.get("error") is Dictionary else ""
	var ext_msg := str(AISidebarWriterLock.busy_error(H.EXTERNAL)["error"]["message"])
	OS.delay_msec(80)
	var expired := AISidebarWriterLock.holder() == H.NONE
	var side_after := AISidebarWriterLock.try_acquire(H.SIDEBAR)
	AISidebarWriterLock.reset()
	if e1 and side_busy.get("success", true) == false and side_msg.begins_with("Holder: EXTERNAL") \
			and side_msg.contains("was NOT made") and side_msg.contains("Do not retry") and ext_msg.contains("expires 1 s") and ext_msg.contains("retry after that") and expired and side_after:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (external lease) failed: busy=%s expired=%s" % [str(side_busy), str(expired)])

	# 3. Sidebar ajanı dış ajan yazarken: değiştirici araç çalışmaz (WRITER_BUSY), okuma çalışır,
	# kilit dış ajanda kalır.
	AISidebarWriterLock.reset()
	AISidebarWriterLock.try_acquire(H.EXTERNAL)
	var p3 := ScriptedProvider.new()
	var ctx3 := AISidebarAgentContext.new()
	var r3 := AISidebarAgentRunner.new(p3, ctx3)
	p3.responses = [
		{"tool_calls": [{"id": "c1", "name": "add_node", "arguments": {"node_type": "Node2D", "node_name": "X"}}]},
		{"tool_calls": [{"id": "c2", "name": "get_scene_tree", "arguments": {}}]},
		{"content": "Tamam."},
	]
	r3.start_task("Düğüm ekle")
	var add_res := _tool_result(ctx3, "add_node")
	var read_res := _tool_result(ctx3, "get_scene_tree")
	# Model hem kodu hem nedeni görmeli (yalnız çıplak veri değil).
	if add_res.contains("WRITER_BUSY") and add_res.contains("Holder: EXTERNAL") and add_res.contains("Do not retry") and not read_res.is_empty() and not read_res.contains("WRITER_BUSY") \
			and AISidebarWriterLock.holder() == H.EXTERNAL:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (sidebar blocked while external writes) failed: add=%s read=%s" % [add_res.left(160), read_res.left(160)])

	# 4. Kilit boşken sidebar ilk yazma aracında kilidi alır, görev bitince bırakır.
	AISidebarWriterLock.reset()
	var p4 := ScriptedProvider.new()
	var ctx4 := AISidebarAgentContext.new()
	var r4 := AISidebarAgentRunner.new(p4, ctx4)
	p4.responses = [
		{"tool_calls": [{"id": "c1", "name": "add_node", "arguments": {"node_type": "Node2D", "node_name": "X"}}]},
		{"content": "Tamam."},
	]
	r4.start_task("Düğüm ekle")
	var add4 := _tool_result(ctx4, "add_node")
	if p4.holders_seen.size() >= 2 and p4.holders_seen[0] == H.NONE and p4.holders_seen[1] == H.SIDEBAR \
			and not add4.contains("WRITER_BUSY") and AISidebarWriterLock.holder() == H.NONE:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (sidebar acquires then releases) failed: seen=%s add=%s" % [str(p4.holders_seen), add4.left(160)])

	AISidebarWriterLock.reset()
	return {"name": "WriterLockTests", "passed": passed, "failed": failed, "errors": errors}
