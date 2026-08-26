@tool
extends RefCounted
class_name AISidebarSSEParser

## Server-Sent Events (SSE) ve Standart JSON yanıtlarını ayrıştıran bağımsız ayrıştırıcı (SRP).

static func parse_response(raw_text: String) -> Dictionary:
	var total_content: String = ""
	var total_thinking: String = ""
	var raw_tool_calls: Array = []
	var finish_reason: String = ""
	
	var trimmed_raw = raw_text.strip_edges()
	if trimmed_raw.is_empty():
		return {"error": "Sunucudan boş yanıt döndü (PROVIDER_EMPTY_RESPONSE)."}
		
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
					return {"error": "API Hatası: " + err_msg}
					
				if chunk.has("choices") and chunk["choices"].size() > 0:
					var c = chunk["choices"][0]
					if c.has("finish_reason") and c["finish_reason"] != null:
						finish_reason = str(c["finish_reason"])
						
					var delta = c.get("delta", {})
					if delta.has("reasoning_content") and delta["reasoning_content"] != null:
						total_thinking += str(delta["reasoning_content"])
					if delta.has("reasoning") and delta["reasoning"] != null:
						total_thinking += str(delta["reasoning"])
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
				return {"error": "API Hatası: " + err_msg}
				
			if json_res.has("choices") and json_res["choices"].size() > 0:
				var choice = json_res["choices"][0]
				if choice.has("finish_reason") and choice["finish_reason"] != null:
					finish_reason = str(choice["finish_reason"])
					
				var msg = choice.get("message", {})
				if msg.has("reasoning_content") and msg["reasoning_content"] != null:
					total_thinking = str(msg["reasoning_content"])
				elif msg.has("reasoning") and msg["reasoning"] != null:
					total_thinking = str(msg["reasoning"])
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
		if not str(tc.get("name", "")).is_empty():
			final_tools.append({
				"id": tc.get("id", ""),
				"name": tc.get("name", ""),
				"arguments": args_obj
			})

	var clean_content = total_content.strip_edges()
	var clean_thinking = total_thinking.strip_edges()
	
	# Boş Yanıt Denetimi (Empty Response Guard)
	if clean_content.is_empty() and clean_thinking.is_empty() and final_tools.is_empty():
		return {
			"error": "Model boş yanıt döndürdü (PROVIDER_EMPTY_RESPONSE). Lütfen model seçimini veya API parametrelerini kontrol edin."
		}

	return {
		"content": clean_content,
		"thinking": clean_thinking,
		"tool_calls": final_tools,
		"finish_reason": finish_reason
	}
