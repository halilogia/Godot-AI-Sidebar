@tool
extends RefCounted
class_name AISidebarBlenderClient

## Blender Copilot'un MCP köprüsüne (Blender'da açık pencere ya da başsız Blender) konuşan küçük istemci.
## Köprü durumsuzdur: her çağrı tek bir JSON-RPC POST'tur (oturum yok). Saf yardımcılar (istek gövdesi, yanıt
## ayrıştırma, sonuç biçimlendirme) ağ bilmez ve birim testlenir; `request_async` HTTPClient ile konuşur.

const DEFAULT_URL := "http://127.0.0.1:6592/mcp"
const CONNECT_TIMEOUT_SEC := 5.0
const MAX_RESULT_CHARS := 6000

## Variant'ı sözlüğe çevirir (değilse boş sözlük); `as` dönüşümü yerine tipli, uyarısız yol.
static func as_dict(v: Variant) -> Dictionary:
	if v is Dictionary:
		var d: Dictionary = v
		return d
	return {}

## Ayarlardan okunan bağlantı: {enabled, url, token}.
static func settings_from(cfg: Dictionary) -> Dictionary:
	var url := str(cfg.get("blender_bridge_url", "")).strip_edges()
	return {
		"enabled": cfg.get("blender_bridge_enabled", false) == true,
		"url": url if not url.is_empty() else DEFAULT_URL,
		"token": str(cfg.get("blender_bridge_token", "")).strip_edges(),
	}

static func build_body(method: String, params: Dictionary, id: int = 1) -> String:
	return JSON.stringify({"jsonrpc": "2.0", "id": id, "method": method, "params": params})

## "http://127.0.0.1:6592/mcp" -> {ok, host, port, path}. Yalnız yerel adres kabul edilir (köprü loopback'tir).
static func parse_url(url: String) -> Dictionary:
	var rest := url.strip_edges()
	if not rest.begins_with("http://"):
		return {"ok": false, "error": "The Blender bridge address must start with http:// (it only runs on this computer)."}
	rest = rest.substr(7)
	var slash := rest.find("/")
	var hostport := rest if slash < 0 else rest.left(slash)
	var path := "/" if slash < 0 else rest.substr(slash)
	var colon := hostport.rfind(":")
	var host := hostport if colon < 0 else hostport.left(colon)
	var port := 80 if colon < 0 else hostport.substr(colon + 1).to_int()
	if not host in ["127.0.0.1", "localhost", "::1"]:
		return {"ok": false, "error": "The Blender bridge is local only: use 127.0.0.1 (got '%s')." % host}
	if port < 1 or port > 65535:
		return {"ok": false, "error": "The Blender bridge address has no valid port."}
	return {"ok": true, "host": "127.0.0.1" if host == "localhost" else host, "port": port, "path": path}

## JSON-RPC yanıt metni -> {ok: true, result} ya da {ok: false, error}.
static func parse_reply(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"ok": false, "error": "The Blender bridge sent something that is not JSON."}
	var reply: Dictionary = parsed
	if reply.has("error"):
		var err: Variant = reply["error"]
		var msg := str(as_dict(err).get("message", "")) if err is Dictionary else str(err)
		return {"ok": false, "error": msg}
	return {"ok": true, "result": as_dict(reply.get("result", {}))}

## tools/list sonucundan "ad - ilk cümle" satırları (modelin bağlamını şişirmemek için kısa).
static func summarize_tools(result: Dictionary) -> Array:
	var out: Array = []
	var tools: Variant = result.get("tools", [])
	if not tools is Array:
		return out
	for t_v: Variant in tools:
		var t: Dictionary = as_dict(t_v)
		if t.is_empty():
			continue
		var desc := str(t.get("description", "")).strip_edges()
		var cut := desc.find(". ")
		if cut > 0:
			desc = desc.left(cut + 1)
		if desc.length() > 140:
			desc = desc.left(137) + "..."
		out.append({"name": str(t.get("name", "")), "about": desc})
	return out

## Tek bir aracın tam tanımı (açıklama + argüman şeması) ya da boş sözlük.
static func find_tool(result: Dictionary, tool_name: String) -> Dictionary:
	var tools: Variant = result.get("tools", [])
	if tools is Array:
		for t_v: Variant in tools:
			var t: Dictionary = as_dict(t_v)
			if str(t.get("name", "")) == tool_name:
				return t
	return {}

## tools/call sonucu -> {success, data, error} (Blender'ın kendi ToolResult biçimi).
## Görüntü baytları modele gitmez (çok büyük); yalnız "image" olduğu söylenir.
static func unwrap_call(result: Dictionary) -> Dictionary:
	var structured: Variant = result.get("structuredContent", null)
	if structured is Dictionary:
		var s: Dictionary = as_dict(structured).duplicate(true)
		var data: Dictionary = as_dict(s.get("data", null))
		for k: String in ["image_base64", "base64"]:
			if data.has(k):
				data.erase(k)
				data["image"] = "captured (not sent to you; use the file path or ask the user)"
		return s
	var text := ""
	var content: Variant = result.get("content", [])
	if content is Array:
		for c_v: Variant in content:
			var c: Dictionary = as_dict(c_v)
			if str(c.get("type", "")) == "text":
				text += str(c.get("text", ""))
	return {"success": result.get("isError", false) != true, "data": {"text": text}, "error": null}

## Blender sonucundaki .glb yolu (export_gltf ...) varsa döner, yoksa "".
static func glb_path_of(call_result: Dictionary) -> String:
	var p := str(as_dict(call_result.get("data", null)).get("path", ""))
	if p.to_lower().ends_with(".glb") or p.to_lower().ends_with(".gltf"):
		return p
	return ""

## Uzun sonuçları keser (bağlam tasarrufu).
static func clip(text: String) -> String:
	if text.length() <= MAX_RESULT_CHARS:
		return text
	return text.left(MAX_RESULT_CHARS) + "... [cut]"

## Köprüye tek bir JSON-RPC isteği yollar. Dönüş: parse_reply() biçimi.
static func request_async(cfg: Dictionary, method: String, params: Dictionary, timeout_sec: float) -> Dictionary:
	var target := parse_url(str(cfg.get("url", DEFAULT_URL)))
	if target.get("ok", false) != true:
		return {"ok": false, "error": str(target.get("error", "")), "unreachable": true}
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"ok": false, "error": "No main loop to wait on.", "unreachable": true}
	var host: String = target["host"]
	var port: int = target["port"]
	var path: String = target["path"]
	var http := HTTPClient.new()
	if http.connect_to_host(host, port) != OK:
		return {"ok": false, "error": "Could not start a connection to the Blender bridge.", "unreachable": true}
	var started := Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		await tree.process_frame
		if float(Time.get_ticks_msec() - started) / 1000.0 > CONNECT_TIMEOUT_SEC:
			return {"ok": false, "error": "The Blender bridge did not answer.", "unreachable": true}
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"ok": false, "error": "Blender is not listening on %s:%d." % [host, port], "unreachable": true}
	var body := build_body(method, params)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"Authorization: Bearer " + str(cfg.get("token", "")),
		"Connection: close",
	])
	if http.request(HTTPClient.METHOD_POST, path, headers, body) != OK:
		return {"ok": false, "error": "Could not send the request to Blender.", "unreachable": true}
	started = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await tree.process_frame
		if float(Time.get_ticks_msec() - started) / 1000.0 > timeout_sec:
			return {"ok": false, "error": "Blender took longer than %d seconds." % int(timeout_sec)}
	if not http.has_response():
		return {"ok": false, "error": "Blender closed the connection without an answer.", "unreachable": true}
	var code := http.get_response_code()
	var raw := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.is_empty():
			await tree.process_frame
		else:
			raw.append_array(chunk)
		if float(Time.get_ticks_msec() - started) / 1000.0 > timeout_sec:
			return {"ok": false, "error": "Blender took longer than %d seconds." % int(timeout_sec)}
	if code == 401 or code == 403:
		return {"ok": false, "error": "Blender refused the token. Copy the token again from the add-on panel (MCP bridge) into Settings > Blender."}
	if code != 200:
		return {"ok": false, "error": "Blender answered HTTP %d." % code}
	return parse_reply(raw.get_string_from_utf8())
