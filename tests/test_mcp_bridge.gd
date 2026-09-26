@tool
extends RefCounted

## MCP dış ajan köprüsü (v3.0): HTTP ayrıştırma, JSON-RPC / MCP yönlendirmesi, araç izin
## listesi ve gerçek loopback TCP üzerinden uçtan uca istekler (kimlik doğrulama dahil).

const AISidebarMcpHttp = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_http.gd")
const AISidebarMcpProtocol = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_protocol.gd")
const AISidebarMcpBridgeServer = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_bridge_server.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarWriterLock = preload("res://addons/godot_sidebar_ai/core/security/writer_lock.gd")

const TOKEN = "test-token-123"

static func _req(method: String, path: String, body: String, headers: Dictionary) -> PackedByteArray:
	var head := "%s %s HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: %d\r\n" % [method, path, body.to_utf8_buffer().size()]
	for k in headers.keys():
		head += "%s: %s\r\n" % [k, headers[k]]
	var out := (head + "\r\n").to_utf8_buffer()
	out.append_array(body.to_utf8_buffer())
	return out

## Sunucuya gerçek TCP ile bir istek gönderir, yanıtı {status, body} olarak döner.
static func _roundtrip(server: AISidebarMcpBridgeServer, raw: PackedByteArray) -> Dictionary:
	var client := StreamPeerTCP.new()
	client.connect_to_host("127.0.0.1", server.port)
	var sent := false
	var got := PackedByteArray()
	for _i in 400:
		server.poll()
		client.poll()
		var st := client.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED:
			if not sent:
				client.put_data(raw)
				sent = true
			var n := client.get_available_bytes()
			if n > 0:
				var r: Array = client.get_partial_data(n)
				got.append_array(r[1])
		elif sent and (st == StreamPeerTCP.STATUS_NONE or st == StreamPeerTCP.STATUS_ERROR):
			break
		OS.delay_msec(5)
	client.disconnect_from_host()
	var text := got.get_string_from_utf8()
	var sep := text.find("\r\n\r\n")
	if sep < 0:
		return {"status": 0, "body": text}
	var status := text.get_slice(" ", 1).to_int()
	return {"status": status, "body": text.substr(sep + 4)}

static func _rpc(method: String, params: Dictionary = {}, id: Variant = 1) -> String:
	var m := {"jsonrpc": "2.0", "method": method, "params": params}
	if id != null:
		m["id"] = id
	return JSON.stringify(m)

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. HTTP ayrıştırma: eksik başlık / eksik gövde beklenir, tam istek ayrışır, chunked reddedilir
	var full := _req("POST", "/mcp", "{\"a\":1}", {"Authorization": "Bearer x"})
	var partial_head := AISidebarMcpHttp.parse_request(full.slice(0, 20))
	var partial_body := AISidebarMcpHttp.parse_request(full.slice(0, full.size() - 2))
	var parsed := AISidebarMcpHttp.parse_request(full)
	var chunked := AISidebarMcpHttp.parse_request("POST /mcp HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n".to_utf8_buffer())
	var resp_text := AISidebarMcpHttp.build_response(202).get_string_from_utf8()
	if not partial_head["complete"] and not partial_body["complete"] and parsed["complete"] and parsed["method"] == "POST" \
			and parsed["path"] == "/mcp" and parsed["body"] == "{\"a\":1}" and parsed["headers"].get("authorization") == "Bearer x" \
			and chunked.get("error_status") == 411 and resp_text.begins_with("HTTP/1.1 202 Accepted\r\n") and resp_text.contains("Content-Length: 0\r\n") and resp_text.contains("Connection: close\r\n\r\n"):
		passed += 1
	else:
		failed += 1
		errors.append("T1 (http parse/build) failed: " + str(parsed))

	# 2. Protokol: initialize sürümü yansıtır, bildirim yanıtsız, bilinmeyen metot / geçersiz istek hata
	var init := AISidebarMcpProtocol.route(JSON.parse_string(_rpc("initialize", {"protocolVersion": "2099-01-01", "capabilities": {}, "clientInfo": {"name": "t"}})))
	var init_default := AISidebarMcpProtocol.route(JSON.parse_string(_rpc("initialize", {})))
	var notif := AISidebarMcpProtocol.route(JSON.parse_string(_rpc("notifications/initialized", {}, null)))
	var unknown := AISidebarMcpProtocol.route(JSON.parse_string(_rpc("resources/list")))
	var invalid := AISidebarMcpProtocol.route({"id": 3, "method": "ping"})
	var batch := AISidebarMcpProtocol.route([{"jsonrpc": "2.0", "id": 1, "method": "ping"}])
	var ir: Dictionary = init["reply"]["result"]
	# Dış ajana dosya-öncelikli çalışma kuralı initialize ile verilir.
	var instr_ok: bool = ir.get("instructions") == AISidebarMcpProtocol.INSTRUCTIONS and AISidebarMcpProtocol.INSTRUCTIONS.contains("file-first") \
			and AISidebarMcpProtocol.SYNC_PROJECT_TOOL["inputSchema"]["properties"].has("changed_files")
	if instr_ok and ir["protocolVersion"] == "2099-01-01" and ir["serverInfo"]["name"] == "godot-ai-sidebar" and ir["capabilities"].has("tools") \
			and init_default["reply"]["result"]["protocolVersion"] == AISidebarMcpProtocol.DEFAULT_PROTOCOL_VERSION \
			and notif.get("notification", false) and unknown["reply"]["error"]["code"] == -32601 \
			and invalid["reply"]["error"]["code"] == -32600 and batch["reply"]["error"]["code"] == -32600:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (protocol routing) failed: init=%s unknown=%s" % [str(init), str(unknown)])

	# 3. İzin listesi: tools/list tam olarak açılan araçlar + sync_project; değiştiriciler kapalı
	var tools: Array = AISidebarMcpProtocol.route(JSON.parse_string(_rpc("tools/list")))["reply"]["result"]["tools"]
	var names: Array = []
	var schemas_ok := true
	for t in tools:
		names.append(t["name"])
		if not (t.get("inputSchema") is Dictionary) or t["inputSchema"].get("type") != "object" or str(t.get("description", "")).is_empty():
			schemas_ok = false
	var want: Array = AISidebarMcpProtocol.EXPOSED_TOOLS.duplicate()
	want.append_array(AISidebarMcpProtocol.MUTATION_TOOLS)
	want.append("sync_project")
	names.sort()
	want.sort()
	var blocked := AISidebarMcpProtocol.route(JSON.parse_string(_rpc("tools/call", {"name": "delete_file", "arguments": {"file_path": "res://x.gd"}})))
	var allowed := AISidebarMcpProtocol.route(JSON.parse_string(_rpc("tools/call", {"name": "analyze_project", "arguments": {}}, 7)))
	# Silen / dosya yazan / sahne dosyası üreten araçlar kapalı kalır (dış ajanın kendi dosya araçları var).
	var mutating_exposed := false
	for m in ["delete_node", "delete_file", "write_files", "create_or_update_script", "replace_file_content", "create_scene", "reparent_node", "duplicate_node", "rename_node", "connect_signal", "create_character_scene"]:
		if names.has(m):
			mutating_exposed = true
	# Mutasyon araçları köprüye özgü zorunlu expected_scene_path taşır; ToolManager şeması değişmez;
	# instantiate_scene'in kendi scene_path'i (kaynak sahne) korunur.
	var guard_schema_ok := true
	for t in tools:
		if AISidebarMcpProtocol.MUTATION_TOOLS.has(t["name"]):
			var req: Array = t["inputSchema"].get("required", [])
			if not req.has("expected_scene_path") or not t["inputSchema"]["properties"].has("expected_scene_path"):
				guard_schema_ok = false
			if t["name"] == "instantiate_scene" and not (req.has("scene_path") and t["inputSchema"]["properties"].has("scene_path")):
				guard_schema_ok = false
	for s in AISidebarToolManager.get_all_schemas():
		if s["function"]["parameters"].get("properties", {}).has("expected_scene_path"):
			guard_schema_ok = false
	if names == want and schemas_ok and guard_schema_ok and not mutating_exposed and blocked["reply"]["error"]["code"] == -32602 \
			and allowed.has("call") and allowed["call"]["name"] == "analyze_project" and allowed["call"]["id"] == 7:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (tool allowlist) failed: names=%s blocked=%s" % [str(names), str(blocked)])

	# 4. Araç sonucu: base64 görsel ayrı "image" içeriği olur ve metinden çıkar; hata isError
	var img_res := AISidebarMcpProtocol.to_call_result({"success": true, "data": {"path": "user://a.png", "base64": "QUJD"}, "message": "ok"})
	var err_res := AISidebarMcpProtocol.to_call_result({"success": false, "error": {"code": "X", "message": "boom"}})
	var content: Array = img_res["content"]
	if content.size() == 2 and content[0]["type"] == "text" and not str(content[0]["text"]).contains("QUJD") and str(content[0]["text"]).contains("user://a.png") \
			and content[1] == {"type": "image", "data": "QUJD", "mimeType": "image/png"} and img_res["isError"] == false and err_res["isError"] == true:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (call result content) failed: " + str(img_res))

	# 5. Gerçek loopback TCP: kimlik / köken / metot / yol reddi, initialize, bildirim ve araç çağrısı
	var server := AISidebarMcpBridgeServer.new()
	var port := 0
	for p in [46570, 46571, 46572, 46573]:
		if server.start(p, TOKEN) == OK:
			port = p
			break
	var auth := {"Authorization": "Bearer " + TOKEN}
	var r_noauth := _roundtrip(server, _req("POST", "/mcp", _rpc("ping"), {}))
	var r_badauth := _roundtrip(server, _req("POST", "/mcp", _rpc("ping"), {"Authorization": "Bearer nope"}))
	var r_origin := _roundtrip(server, _req("POST", "/mcp", _rpc("ping"), {"Authorization": "Bearer " + TOKEN, "Origin": "http://evil.example"}))
	var r_get := _roundtrip(server, _req("GET", "/mcp", "", auth))
	var r_path := _roundtrip(server, _req("POST", "/other", _rpc("ping"), auth))
	var r_parse := _roundtrip(server, _req("POST", "/mcp", "{not json", auth))
	var r_init := _roundtrip(server, _req("POST", "/mcp", _rpc("initialize", {"protocolVersion": "2025-06-18"}), auth))
	var r_notif := _roundtrip(server, _req("POST", "/mcp", _rpc("notifications/initialized", {}, null), auth))
	var r_call := _roundtrip(server, _req("POST", "/mcp", _rpc("tools/call", {"name": "analyze_project", "arguments": {}}, 9), auth))
	# Mutasyon tel üzerinden sahne korumasına ulaşır (headless: editör yok → EDITOR_REQUIRED, isError).
	var r_mut := _roundtrip(server, _req("POST", "/mcp", _rpc("tools/call", {"name": "add_node", "arguments": {"node_type": "Node2D", "node_name": "X", "expected_scene_path": "res://a.tscn"}}, 10), auth))
	server.stop()
	var mut_json: Variant = JSON.parse_string(str(r_mut["body"]))
	var mut_ok: bool = mut_json is Dictionary and mut_json["result"]["isError"] == true and str(r_mut["body"]).contains("EDITOR_REQUIRED")
	var init_json: Variant = JSON.parse_string(str(r_init["body"]))
	var call_json: Variant = JSON.parse_string(str(r_call["body"]))
	# id tel üzerinde tam sayı olarak dönmeli ("id":9, "9.0" değil)
	var call_ok: bool = call_json is Dictionary and str(r_call["body"]).contains("\"id\":9,") and call_json["result"]["isError"] == false \
			and str(call_json["result"]["content"][0]["text"]).contains("project_name")
	var statuses := [r_noauth["status"], r_badauth["status"], r_origin["status"], r_get["status"], r_path["status"], r_parse["status"], r_init["status"], r_notif["status"], r_call["status"]]
	if port > 0 and statuses == [401, 401, 403, 405, 404, 400, 200, 202, 200] \
			and init_json is Dictionary and init_json["result"]["serverInfo"]["name"] == "godot-ai-sidebar" and call_ok and mut_ok and not server.is_running():
		passed += 1
	else:
		failed += 1
		errors.append("T5 (loopback end-to-end) failed: port=%d statuses=%s call=%s" % [port, str(statuses), str(r_call["body"]).left(200)])
	server.free()

	# 6. eval_gdscript (keyfi kod yürütme) hiçbir yoldan ulaşılamaz: şeması yok, izin listesinde
	# yok, köprü reddeder, ToolManager (onaylı çağrıda bile) UNKNOWN_TOOL döner.
	var eval_in_schemas := false
	for s in AISidebarToolManager.get_all_schemas():
		if s["function"]["name"] == "eval_gdscript":
			eval_in_schemas = true
	var eval_call := AISidebarMcpProtocol.route(JSON.parse_string(_rpc("tools/call", {"name": "eval_gdscript", "arguments": {"code": "1 + 1"}})))
	var eval_direct := AISidebarToolManager.execute_tool("eval_gdscript", {"code": "1 + 1"}, true)
	if not eval_in_schemas and not names.has("eval_gdscript") and not AISidebarMcpProtocol.is_exposed("eval_gdscript") \
			and eval_call["reply"]["error"]["code"] == -32602 and eval_direct.get("success", true) == false \
			and eval_direct["error"]["code"] == "UNKNOWN_TOOL":
		passed += 1
	else:
		failed += 1
		errors.append("T6 (eval_gdscript unreachable) failed: call=%s direct=%s" % [str(eval_call), str(eval_direct)])

	# 7. Mutasyon koruma sırası: expected_scene_path → etkin sahne → yazıcı kilidi → sahne tekrar → ToolManager.
	AISidebarWriterLock.reset()
	var ms := AISidebarMcpBridgeServer.new()
	var fake_root := Node.new()
	fake_root.scene_file_path = "res://scenes/main.tscn"
	ms.scene_root_provider = func() -> Node: return fake_root
	var add_args := {"node_type": "Node2D", "node_name": "X", "expected_scene_path": "res://scenes/main.tscn"}
	var m_ok := ms.precheck_mutation("add_node", add_args).is_empty()
	var m_missing := ms.precheck_mutation("add_node", {"node_type": "Node2D", "node_name": "X"})
	var wrong_args := {"node_type": "Node2D", "node_name": "X", "expected_scene_path": "res://scenes/other.tscn"}
	var m_wrong := ms.precheck_mutation("add_node", wrong_args)
	# apply de sahneyi kilidin ardından tekrar kontrol eder ve yeni aldığı kilidi bırakır.
	var m_wrong_apply := ms.apply_mutation("add_node", wrong_args)
	var lock_after_wrong := AISidebarWriterLock.holder()
	AISidebarWriterLock.try_acquire(AISidebarWriterLock.Holder.SIDEBAR)
	var m_busy := ms.apply_mutation("add_node", add_args)
	AISidebarWriterLock.reset()
	var m_pass := ms.run_mutation("add_node", add_args)
	var lock_after_pass := AISidebarWriterLock.holder()
	ms.stop()
	var lock_after_stop := AISidebarWriterLock.holder()
	var guard_codes := ["INVALID_ARGUMENT", "ACTIVE_SCENE_NOT_CONFIRMED", "WRITER_BUSY"]
	var pass_code := str(m_pass["error"]["code"]) if m_pass.get("error") is Dictionary else ""
	var split := AISidebarMcpProtocol.split_mutation_args({"scene_path": "res://p.tscn", "expected_scene_path": " res://scenes/main.tscn "})
	var any_async := false
	for mt in AISidebarMcpProtocol.MUTATION_TOOLS:
		if AISidebarToolManager.is_async_tool(mt):
			any_async = true
	if m_ok and m_missing["error"]["code"] == "INVALID_ARGUMENT" \
			and m_wrong["error"]["code"] == "ACTIVE_SCENE_NOT_CONFIRMED" and m_wrong_apply["error"]["code"] == "ACTIVE_SCENE_NOT_CONFIRMED" \
			and lock_after_wrong == AISidebarWriterLock.Holder.NONE \
			and m_busy["error"]["code"] == "WRITER_BUSY" and not guard_codes.has(pass_code) \
			and lock_after_pass == AISidebarWriterLock.Holder.EXTERNAL and lock_after_stop == AISidebarWriterLock.Holder.NONE \
			and split["expected_scene_path"] == "res://scenes/main.tscn" and split["args"] == {"scene_path": "res://p.tscn"} and not any_async:
		passed += 1
	else:
		failed += 1
		errors.append("T7 (mutation guards) failed: ok=%s missing=%s wrong=%s busy=%s pass=%s lock=%s/%s split=%s" % [str(m_ok), str(m_missing), str(m_wrong), str(m_busy), str(m_pass), str(lock_after_pass), str(lock_after_stop), str(split)])
	fake_root.free()
	ms.free()
	AISidebarWriterLock.reset()

	return {"name": "McpBridgeTests", "passed": passed, "failed": failed, "errors": errors}
