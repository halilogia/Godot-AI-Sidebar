@tool
extends RefCounted
class_name AISidebarSSEParser

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

## Server-Sent Events (SSE) ve Standart JSON yanıtlarını ayrıştıran bağımsız ayrıştırıcı (SRP).

## Tek delta/message için thinking çıkarımı (öncelik sırası; çift sayımı önler).
static func extract_delta_thinking(delta: Dictionary) -> String:
	if delta == null or not (delta is Dictionary):
		return ""
	if delta.has("reasoning_content") and delta["reasoning_content"] != null:
		var rc = str(delta["reasoning_content"])
		if not rc.is_empty():
			return rc
	if delta.has("reasoning") and delta["reasoning"] != null:
		var r = delta["reasoning"]
		if r is String and not r.is_empty():
			return r
	if delta.has("reasoning_details"):
		return extract_reasoning_details(delta["reasoning_details"])
	return ""

## OpenRouter tarzı reasoning_details dizisinden metin çıkarır
## ([{type, text/summary}, ...] veya düz string dizisi; bilinmeyen şekil yok sayılır).
static func extract_reasoning_details(value: Variant) -> String:
	if value == null:
		return ""
	if value is String:
		return value
	if not (value is Array):
		return ""
	var parts: PackedStringArray = []
	for item in (value as Array):
		if item is Dictionary:
			var t = str((item as Dictionary).get("text", (item as Dictionary).get("summary", "")))
			if not t.strip_edges().is_empty():
				parts.append(t)
		elif item is String and not (item as String).strip_edges().is_empty():
			parts.append(item)
	return "".join(parts)

static func parse_response(raw_text: String) -> Dictionary:
	var total_content: String = ""
	var total_thinking: String = ""
	var raw_tool_calls: Array = []
	var finish_reason: String = ""
	## Sağlayıcının bildirdiği token kullanımı (akışta son parçada, include_usage ile); yoksa null.
	var usage: Variant = null
	
	var trimmed_raw = raw_text.strip_edges()
	if trimmed_raw.is_empty():
		return {"error": AISidebarI18n.get_text("provider_server_empty")}
		
	var lines = raw_text.split("\n")
	var is_sse: bool = false
	
	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed.begins_with("data:"):
			is_sse = true
			var json_str = trimmed.trim_prefix("data:").strip_edges()
			if json_str == "[DONE]" or json_str.is_empty():
				continue
				
			var chunk = JSON.parse_string(json_str)
			if chunk is Dictionary:
				if chunk.has("error"):
					var err_val = chunk["error"]
					var err_msg = err_val.get("message", str(err_val)) if err_val is Dictionary else str(err_val)
					return {"error": AISidebarI18n.get_text("provider_api_error", {"message": str(err_msg)})}
				var chunk_d: Dictionary = chunk
				if chunk_d.get("usage", null) is Dictionary:
					usage = chunk_d["usage"]
					
				if chunk.has("choices") and chunk["choices"].size() > 0:
					var c = chunk["choices"][0]
					if c.has("finish_reason") and c["finish_reason"] != null:
						finish_reason = str(c["finish_reason"])
						
					var delta = c.get("delta", {})
					# Aynı delta birden çok alanda aynı metni taşıyabilir;
					# ilk dolu olan kazanır (duplicate birikimi yok).
					total_thinking += extract_delta_thinking(delta)
					if delta.has("content") and delta["content"] != null:
						total_content += str(delta["content"])
						
					if delta.has("tool_calls"):
						for tc in delta["tool_calls"]:
							var tc_idx = tc.get("index", 0)
							while raw_tool_calls.size() <= tc_idx:
								raw_tool_calls.append({"id": "", "name": "", "arguments_str": ""})
							if tc.has("id") and not str(tc["id"]).is_empty():
								raw_tool_calls[tc_idx]["id"] = tc["id"]
							var fn = tc.get("function", {})
							if fn.has("name") and not str(fn["name"]).is_empty():
								raw_tool_calls[tc_idx]["name"] = fn["name"]
							if fn.has("arguments") and not str(fn["arguments"]).is_empty():
								raw_tool_calls[tc_idx]["arguments_str"] += fn["arguments"]

	if not is_sse:
		var json_res = JSON.parse_string(raw_text)
		if json_res is Dictionary:
			if json_res.has("error"):
				var err_val = json_res["error"]
				var err_msg = err_val.get("message", str(err_val)) if err_val is Dictionary else str(err_val)
				return {"error": AISidebarI18n.get_text("provider_api_error", {"message": str(err_msg)})}
			var json_d: Dictionary = json_res
			if json_d.get("usage", null) is Dictionary:
				usage = json_d["usage"]
				
			if json_res.has("choices") and json_res["choices"].size() > 0:
				var choice = json_res["choices"][0]
				if choice.has("finish_reason") and choice["finish_reason"] != null:
					finish_reason = str(choice["finish_reason"])
					
				var msg = choice.get("message", {})
				if msg.has("reasoning_content") and msg["reasoning_content"] != null:
					total_thinking = str(msg["reasoning_content"])
				elif msg.has("reasoning") and msg["reasoning"] != null:
					total_thinking = str(msg["reasoning"])
				elif msg.has("reasoning_details"):
					total_thinking = extract_reasoning_details(msg["reasoning_details"])
				total_content = msg.get("content", "")
				if total_content == null:
					total_content = ""
					
				if msg.has("tool_calls") and msg["tool_calls"] is Array:
					for tc in msg["tool_calls"]:
						var fn = tc.get("function", {})
						var args = fn.get("arguments", "{}")
						if args is String:
							args = JSON.parse_string(args)
						raw_tool_calls.append({
							"id": tc.get("id", ""),
							"name": fn.get("name", ""),
							"arguments": args if args is Dictionary else {}
						})

	# Metin içindeki <think> veya <thought> bloklarını ayıkla
	if total_thinking.is_empty() and ("<think>" in total_content or "<thought>" in total_content):
		var think_regex = RegEx.new()
		think_regex.compile("(?s)<(?:think|thought)>(.*?)</(?:think|thought)>")
		var match = think_regex.search(total_content)
		if match:
			total_thinking = match.get_string(1).strip_edges()
			total_content = think_regex.sub(total_content, "", true).strip_edges()

	# Akıştan gelen tool call argümanlarını nesneye dönüştür
	var final_tools: Array = []
	for tc in raw_tool_calls:
		var args_obj = {}
		if tc.has("arguments") and tc["arguments"] is Dictionary:
			args_obj = tc["arguments"]
		elif tc.has("arguments_str") and not str(tc["arguments_str"]).is_empty():
			var parsed_args = JSON.parse_string(tc["arguments_str"])
			if parsed_args is Dictionary:
				args_obj = parsed_args
		var tool_name := clean_tool_name(str(tc.get("name", "")))
		if not tool_name.is_empty():
			final_tools.append({
				"id": tc.get("id", ""),
				"name": tool_name,
				"arguments": args_obj
			})

	var clean_content = total_content.strip_edges()
	var clean_thinking = total_thinking.strip_edges()
	
	# Boş Yanıt Denetimi (Empty Response Guard)
	if clean_content.is_empty() and clean_thinking.is_empty() and final_tools.is_empty():
		return {
			"error": AISidebarI18n.get_text("provider_model_empty")
		}

	var out := {
		"content": clean_content,
		"thinking": clean_thinking,
		"tool_calls": final_tools,
		"finish_reason": finish_reason
	}
	if usage != null:
		out["usage"] = usage
	return out

## Bazı modeller kendi araç çağrısı biçimini ada karıştırır (`<tool_call> <invoke name="send_input`);
## argümanlar doğru gelir, yalnız ad bozuktur. Ad bir tanımlayıcı değilse içindeki name="..." (yoksa son
## tanımlayıcı) alınır; aksi halde "Bilinmeyen araç" hatası adımı boşa harcıyordu.
static func clean_tool_name(raw: String) -> String:
	var name := raw.strip_edges()
	var ident := RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$")
	if name.is_empty() or ident.search(name) != null:
		return name
	var attr := RegEx.create_from_string("name\\s*=\\s*\"?([A-Za-z_][A-Za-z0-9_]*)")
	var m := attr.search(name)
	if m != null:
		return m.get_string(1)
	var all := RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*").search_all(name)
	return all[-1].get_string() if not all.is_empty() else name
