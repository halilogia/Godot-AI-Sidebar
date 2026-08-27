@tool
extends RefCounted
class_name AISidebarContextCompactor

## Context Window Optimizasyonu ve Tool Sonucu Sıkıştırıcı (SRP).
## Uzun görevlerde eski tool result ve gözlem verilerini yapılandırılmış 1-2 satırlık
## özetlere dönüştürerek token şişmesini önler; aktif adımdaki güncel veriyi korur.

const MAX_UNCOMPACTED_CHARS: int = 350

## Mesaj listesindeki eski tool sonuçlarını sıkıştırır.
## keep_recent_tools: Tam detayda korunacak en son tool sonucu sayısı (varsayılan: 2).
static func compact_messages(raw_messages: Array, keep_recent_tools: int = 2) -> Array:
	var compacted: Array = []
	
	# Tool mesajlarının indekslerini belirle
	var tool_indices: Array[int] = []
	for i in range(raw_messages.size()):
		var m = raw_messages[i]
		if m is Dictionary and m.get("role") == "tool":
			tool_indices.append(i)
			
	var cutoff_index = -1
	if tool_indices.size() > keep_recent_tools:
		var cutoff_pos = tool_indices.size() - keep_recent_tools
		cutoff_index = tool_indices[cutoff_pos]
		
	for i in range(raw_messages.size()):
		var msg = raw_messages[i].duplicate(true)
		if msg is Dictionary and msg.get("role") == "tool":
			# Eğer bu tool sonucu son keep_recent_tools içinde değilse sıkıştır
			if cutoff_index != -1 and i < cutoff_index:
				var tool_name = str(msg.get("name", ""))
				var content_str = str(msg.get("content", ""))
				msg["content"] = compact_tool_content(tool_name, content_str)
		compacted.append(msg)
		
	return compacted

## Belirli bir aracın çıktı metnini analiz edip yapılandırılmış özete dönüştürür.
static func compact_tool_content(tool_name: String, content_str: String) -> String:
	if content_str.is_empty():
		return content_str
		
	var json = JSON.new()
	var parse_err = json.parse(content_str)
	if parse_err != OK or not (json.data is Dictionary):
		if content_str.length() > MAX_UNCOMPACTED_CHARS:
			return content_str.left(MAX_UNCOMPACTED_CHARS) + "... [Truncated]"
		return content_str
		
	var data: Dictionary = json.data
	if data.get("is_compacted", false):
		return content_str
		
	var status = data.get("status", "ok")
	var res = data.get("result", {})
	var summary = ""
	
	match tool_name:
		"analyze_project":
			var p_name = res.get("project_name", "Godot Project")
			var main_s = res.get("main_scene", "res://")
			var total_f = res.get("total_files", 0)
			var sc_cnt = res.get("scenes_count", 0)
			var scr_cnt = res.get("scripts_count", 0)
			summary = "Proje: '%s', Ana Sahne: '%s', Toplam Dosya: %d (%d sahne, %d script)" % [p_name, main_s, total_f, sc_cnt, scr_cnt]
			
		"get_project_files":
			var count = res.get("count", 0)
			var path = res.get("path", "res://")
			var files = res.get("files", [])
			var samples: Array = []
			for idx in range(mini(3, files.size())):
				samples.append(str(files[idx]).get_file())
			summary = "'%s' altında %d dosya listelendi (örn: %s...)" % [path, count, ", ".join(samples)]
			
		"search_project_assets":
			var q = res.get("query", "")
			var count = res.get("count", 0)
			var assets = res.get("assets", [])
			var samples: Array = []
			for idx in range(mini(3, assets.size())):
				samples.append(str(assets[idx]).get_file())
			summary = "'%s' araması için %d asset bulundu (%s)" % [q, count, ", ".join(samples)]
			
		"get_scene_tree", "inspect_node":
			var root_name = res.get("root_name", res.get("node_name", "Node"))
			var node_type = res.get("node_type", res.get("type", "Node"))
			var node_count = res.get("node_count", 1)
			summary = "Sahne Ağacı: '%s' (%s), %d düğüm incelendi" % [root_name, node_type, node_count]
			
		"read_script", "read_files", "get_node_info":
			var f_path = res.get("file_path", res.get("path", ""))
			var lines_cnt = res.get("line_count", 0)
			if lines_cnt == 0 and res.has("content"):
				lines_cnt = str(res["content"]).split("\n").size()
			summary = "Dosya okundu: '%s' (%d satır)" % [f_path, lines_cnt]
			
		"get_runtime_errors":
			var err_count = res.get("error_count", 0)
			var errors = res.get("errors", [])
			var first_err = ""
			if errors.size() > 0:
				var e0 = errors[0]
				var f = str(e0.get("file", ""))
				var msg = str(e0.get("message", ""))
				first_err = (f + ": " if not f.is_empty() else "") + msg
			summary = "Runtime Hatası: %d adet tespit edildi (%s)" % [err_count, first_err.left(60)]
			
		"create_or_update_script", "replace_file_content", "write_files":
			var f_path = res.get("file_path", "")
			summary = "Dosya başarıyla güncellendi: '%s'" % [f_path]
			
		_:
			if content_str.length() > MAX_UNCOMPACTED_CHARS:
				summary = content_str.left(MAX_UNCOMPACTED_CHARS) + "..."
			else:
				return content_str
				
	var compacted_dict = {
		"status": status,
		"is_compacted": true,
		"summary": summary
	}
	return JSON.stringify(compacted_dict)
