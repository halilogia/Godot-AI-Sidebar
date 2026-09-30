@tool
extends RefCounted

## Blender köprüsü (Ayarlar → Blender): ayar okuma, adres doğrulama (yalnız yerel), yanıt ayrıştırma, araç
## listesi özeti, çağrı sonucu sadeleştirme, araç şemalarının açık / kapalı durumu ve risk sınıfı.
## Gerçek Blender'a uçtan uca bağlantı ayrı elle koşulur (docs/DEVELOPMENT.md).

const AISidebarBlenderClient = preload("res://addons/godot_sidebar_ai/core/bridge/blender_client.gd")
const AISidebarBlenderTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/blender_tools.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarPlanningPolicy = preload("res://addons/godot_sidebar_ai/core/agent/planning_policy.gd")

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	# 1. Ayarlar: varsayılan adres, boşluk kırpma, kapalı varsayılan
	var empty := AISidebarBlenderClient.settings_from({})
	var filled := AISidebarBlenderClient.settings_from({"blender_bridge_enabled": true, "blender_bridge_url": " http://127.0.0.1:7000/mcp ", "blender_bridge_token": " abc "})
	if empty["enabled"] == false and empty["url"] == AISidebarBlenderClient.DEFAULT_URL and empty["token"] == "" \
			and filled["enabled"] == true and filled["url"] == "http://127.0.0.1:7000/mcp" and filled["token"] == "abc":
		passed += 1
	else:
		failed += 1
		errors.append("T1 (settings) failed: %s %s" % [str(empty), str(filled)])

	# 2. Adres: yalnız yerel http; geçersiz port ve dış adres reddedilir
	var good := AISidebarBlenderClient.parse_url("http://127.0.0.1:6592/mcp")
	var local := AISidebarBlenderClient.parse_url("http://localhost:6592/mcp")
	var remote := AISidebarBlenderClient.parse_url("http://192.168.1.5:6592/mcp")
	var https := AISidebarBlenderClient.parse_url("https://127.0.0.1:6592/mcp")
	var noport := AISidebarBlenderClient.parse_url("http://127.0.0.1:99999/mcp")
	if good["ok"] == true and good["host"] == "127.0.0.1" and good["port"] == 6592 and good["path"] == "/mcp" \
			and local["ok"] == true and local["host"] == "127.0.0.1" and remote["ok"] == false and https["ok"] == false and noport["ok"] == false:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (url) failed: %s %s %s" % [str(good), str(remote), str(noport)])

	# 3. Yanıt ayrıştırma ve istek gövdesi
	var body: Variant = JSON.parse_string(AISidebarBlenderClient.build_body("tools/call", {"name": "create_prop"}, 7))
	var ok_reply := AISidebarBlenderClient.parse_reply('{"jsonrpc":"2.0","id":1,"result":{"tools":[]}}')
	var err_reply := AISidebarBlenderClient.parse_reply('{"jsonrpc":"2.0","id":1,"error":{"code":-32602,"message":"Unknown tool"}}')
	var junk := AISidebarBlenderClient.parse_reply("<html>")
	if body is Dictionary and (body as Dictionary)["jsonrpc"] == "2.0" and int((body as Dictionary)["id"]) == 7 and (body as Dictionary)["params"]["name"] == "create_prop" \
			and ok_reply["ok"] == true and err_reply["ok"] == false and err_reply["error"] == "Unknown tool" and junk["ok"] == false:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (rpc) failed: %s %s %s" % [str(body), str(err_reply), str(junk)])

	# 4. Araç listesi özeti (ilk cümle, kısa) ve tek araç şeması
	var listing := {"tools": [
		{"name": "create_prop", "description": "Build a prop. Many kinds. More words.", "inputSchema": {"type": "object"}},
		{"name": "x", "description": "y".repeat(300)},
	]}
	var summary := AISidebarBlenderClient.summarize_tools(listing)
	var found := AISidebarBlenderClient.find_tool(listing, "create_prop")
	var missing := AISidebarBlenderClient.find_tool(listing, "nope")
	if summary.size() == 2 and summary[0]["about"] == "Build a prop." and str(summary[1]["about"]).length() <= 140 and not found.is_empty() and missing.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T4 (list) failed: %s" % str(summary))

	# 5. Çağrı sonucu: görüntü baytları düşer, .glb yolu bulunur, düz metin sonuç desteklenir, uzun sonuç kesilir
	var call := AISidebarBlenderClient.unwrap_call({"structuredContent": {"success": true, "data": {"path": "C:/x/crate.glb", "image_base64": "AAAA"}, "error": null}})
	var plain := AISidebarBlenderClient.unwrap_call({"content": [{"type": "text", "text": "hello"}], "isError": true})
	var no_glb := AISidebarBlenderClient.glb_path_of({"data": {"path": "C:/x/shot.png"}})
	var clipped := AISidebarBlenderClient.clip("z".repeat(AISidebarBlenderClient.MAX_RESULT_CHARS + 50))
	if call["success"] == true and not (call["data"] as Dictionary).has("image_base64") and (call["data"] as Dictionary).has("image") \
			and AISidebarBlenderClient.glb_path_of(call) == "C:/x/crate.glb" and no_glb == "" \
			and plain["success"] == false and plain["data"]["text"] == "hello" and clipped.ends_with("[cut]"):
		passed += 1
	else:
		failed += 1
		errors.append("T5 (call result) failed: %s %s" % [str(call), str(plain)])

	# 6. Araçlar: risk sınıfı (liste okuma serbest, çağrı plan aşamasında engelli), adlar tanınır
	if AISidebarPermissionPolicy.get_tool_risk(AISidebarBlenderTools.LIST_TOOL) == AISidebarPermissionPolicy.RiskLevel.READ_ONLY \
			and AISidebarPermissionPolicy.get_tool_risk(AISidebarBlenderTools.CALL_TOOL) == AISidebarPermissionPolicy.RiskLevel.WRITE \
			and AISidebarPlanningPolicy.is_mutation_blocked(AISidebarBlenderTools.CALL_TOOL) and not AISidebarPlanningPolicy.is_mutation_blocked(AISidebarBlenderTools.LIST_TOOL) \
			and AISidebarBlenderTools.is_blender_tool("blender_call") and not AISidebarBlenderTools.is_blender_tool("get_output"):
		passed += 1
	else:
		failed += 1
		errors.append("T6 (risk) failed")

	# 7. Hata mesajı Blender'ı açıp köprüyü başlatmayı söyler
	var msg := AISidebarBlenderTools.unreachable_message("Blender is not listening.")
	if msg.contains("MCP bridge") and msg.contains("Settings > Blender"):
		passed += 1
	else:
		failed += 1
		errors.append("T7 (message) failed: " + msg)

	return {"name": "BlenderBridgeTests", "passed": passed, "failed": failed, "errors": errors}
