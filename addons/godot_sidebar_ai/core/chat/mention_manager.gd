@tool
extends RefCounted
class_name AISidebarMentionManager

## @Mention Otomatik Tamamlama ve Akıllı Bağlam Enjektörü (SRP).
## Sohbet kutusunda @ yazıldığında proje dosyalarını ve sahne düğümlerini önerir,
## seçilen dosya ve düğümlerin içeriğini güvenli limitlerle LLM promptuna bağlam olarak ekler.

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")

const MAX_ATTACHED_FILE_LINES: int = 200
const MAX_ATTACHED_FILE_BYTES: int = 12288 # 12 KB

## Metin içindeki imleç konumunda aktif @mention sorgusu olup olmadığını tespit eder.
static func detect_mention_query(text: String, caret_pos: int) -> Dictionary:
	var invalid_result = {"active": false, "query": "", "start_pos": -1, "end_pos": -1}
	if text.is_empty() or caret_pos <= 0 or caret_pos > text.length():
		return invalid_result
		
	var text_before_caret = text.substr(0, caret_pos)
	var at_idx = text_before_caret.rfind("@")
	if at_idx == -1:
		return invalid_result
		
	# @ işaretinden önce bir boşluk veya satır başı olmalıdır (e-posta adresleri gibi durumlarda tetiklenmemesi için)
	if at_idx > 0:
		var char_before = text_before_caret[at_idx - 1]
		if char_before != " " and char_before != "\n" and char_before != "\t":
			return invalid_result
			
	var query_part = text_before_caret.substr(at_idx + 1)
	# Sorgu içinde boşluk varsa mention tamamlanmış veya iptal edilmiştir
	if " " in query_part or "\n" in query_part or "\t" in query_part:
		return invalid_result
		
	return {
		"active": true,
		"query": query_part,
		"start_pos": at_idx,
		"end_pos": caret_pos
	}

## Proje dosyaları ve sahne düğümleri arasından sorguya uygun önerileri listeler.
static func get_suggestions(query: String, max_results: int = 10) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var q_lower = query.to_lower().strip_edges()
	
	# 1. Proje Dosyalarını Tara (.gd, .tscn, .tres, .gdshader, .json vb.)
	var project_files: Array = []
	_scan_project_files("res://", project_files)
	
	var file_matches: Array[Dictionary] = []
	for f_path in project_files:
		var file_name = f_path.get_file()
		var fn_lower = file_name.to_lower()
		var fp_lower = f_path.to_lower()
		
		var is_match = q_lower.is_empty() or fn_lower.begins_with(q_lower) or q_lower in fn_lower or q_lower in fp_lower
		if is_match:
			var ext = file_name.get_extension().to_lower()
			var type_badge = ext.to_upper()
			if ext == "gd": type_badge = "GDSCRIPT"
			elif ext == "tscn": type_badge = "SCENE"
			elif ext == "tres": type_badge = "RESOURCE"
			elif ext == "gdshader": type_badge = "SHADER"
			
			file_matches.append({
				"type": "file",
				"label": file_name,
				"detail": f_path,
				"type_badge": type_badge,
				"insert_text": "@" + f_path,
				"path": f_path,
				"is_prefix": fn_lower.begins_with(q_lower)
			})
			
	# Önce dosya adıyla başlayanları öne al
	file_matches.sort_custom(func(a, b):
		if a["is_prefix"] and not b["is_prefix"]: return true
		if not a["is_prefix"] and b["is_prefix"]: return false
		return a["label"].length() < b["label"].length()
	)
	
	for fm in file_matches:
		if results.size() >= max_results:
			break
		results.append(fm)
		
	# 2. Açık Sahne Düğümlerini Tara (EditorInterface)
	var node_matches: Array[Dictionary] = []
	_scan_active_scene_nodes(node_matches, q_lower)
	
	for nm in node_matches:
		if results.size() >= max_results:
			break
		results.append(nm)
		
	return results

## Kullanıcı promptundaki @mention'ları çözümler ve ilgili dosya/node bağlamlarını ekler.
static func resolve_prompt_context(prompt: String) -> Dictionary:
	var clean_prompt = prompt.strip_edges()
	var attached_files: Array[String] = []
	var attached_nodes: Array[String] = []
	var context_blocks: Array[String] = []
	
	# Regex ile @res://... veya @dosya_adi.uzanti mention'larını bul
	var file_regex = RegEx.new()
	file_regex.compile("(?<=^|\\s)@(res://[a-zA-Z0-9_/\\.\\-]+|[a-zA-Z0-9_\\-\\.]+\\.(?:gd|tscn|tres|gdshader|json|txt))")
	
	var matches = file_regex.search_all(clean_prompt)
	var seen_paths: Array[String] = []
	
	for m in matches:
		var raw_mention = m.get_string(1)
		var resolved_path = _resolve_file_path(raw_mention)
		if not resolved_path.is_empty() and not resolved_path in seen_paths:
			seen_paths.append(resolved_path)
			var file_content = _read_file_content_safe(resolved_path)
			if not file_content.is_empty():
				attached_files.append(resolved_path)
				var ext = resolved_path.get_extension().to_lower()
				var lang = "gdscript" if ext == "gd" else ("gdshader" if ext == "gdshader" else "text")
				context_blocks.append("[ATTACHED CONTEXT - FILE: " + resolved_path + "]\n```" + lang + "\n" + file_content + "\n```")
				
	# Regex ile @Node:NodeAdi mention'larını bul
	var node_regex = RegEx.new()
	node_regex.compile("(?<=^|\\s)@Node:([a-zA-Z0-9_/\\.\\-]+)")
	var node_matches = node_regex.search_all(clean_prompt)
	var seen_nodes: Array[String] = []
	
	for nm in node_matches:
		var node_name = nm.get_string(1)
		if not node_name in seen_nodes:
			seen_nodes.append(node_name)
			var node_info = _resolve_node_info(node_name)
			if not node_info.is_empty():
				attached_nodes.append(node_name)
				context_blocks.append("[ATTACHED CONTEXT - NODE: " + node_name + "]\n" + node_info)
				
	if context_blocks.is_empty():
		return {
			"has_mentions": false,
			"clean_prompt": clean_prompt,
			"augmented_prompt": clean_prompt,
			"files_attached": [],
			"nodes_attached": []
		}
		
	var augmented = clean_prompt + "\n\n---\n" + "\n\n".join(context_blocks) + "\n---"
	return {
		"has_mentions": true,
		"clean_prompt": clean_prompt,
		"augmented_prompt": augmented,
		"files_attached": attached_files,
		"nodes_attached": attached_nodes
	}

# --- Dahili Yardımcı Fonksiyonlar ---

static func _scan_project_files(path: String, result: Array) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var item = dir.get_next()
	while not item.is_empty():
		if item != "." and item != ".." and not item.begins_with("."):
			var full_path = path.path_join(item)
			if dir.current_is_dir():
				if not full_path.begins_with("res://.git") and not full_path.begins_with("res://addons/godot_sidebar_ai"):
					_scan_project_files(full_path, result)
			else:
				var ext = item.get_extension().to_lower()
				if ext in ["gd", "tscn", "tres", "gdshader", "json", "txt", "cfg"]:
					result.append(full_path)
		item = dir.get_next()
	dir.list_dir_end()

static func _scan_active_scene_nodes(result: Array[Dictionary], q_lower: String) -> void:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return
	if not EditorInterface.has_method("get_edited_scene_root"):
		return
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return
		
	_traverse_node_tree(root, result, q_lower)

static func _traverse_node_tree(node: Node, result: Array[Dictionary], q_lower: String) -> void:
	if not node:
		return
	var n_name = node.name
	var n_type = node.get_class()
	var nn_lower = str(n_name).to_lower()
	var nt_lower = n_type.to_lower()
	
	if q_lower.is_empty() or nn_lower.begins_with(q_lower) or q_lower in nn_lower or q_lower in nt_lower:
		var script_path = ""
		var scr = node.get_script()
		if scr is Script and not scr.resource_path.is_empty():
			script_path = scr.resource_path
			
		result.append({
			"type": "node",
			"label": str(n_name),
			"detail": n_type + (" (" + script_path.get_file() + ")" if not script_path.is_empty() else ""),
			"type_badge": "NODE",
			"insert_text": "@Node:" + str(n_name),
			"node_path": str(node.get_path()),
			"node_type": n_type,
			"script_path": script_path,
			"is_prefix": nn_lower.begins_with(q_lower)
		})
		
	for child in node.get_children():
		_traverse_node_tree(child, result, q_lower)

static func _resolve_file_path(raw_path: String) -> String:
	if raw_path.begins_with("res://"):
		if FileAccess.file_exists(raw_path):
			return raw_path
		return ""
		
	# res:// olmadan sadece dosya adı verilmişse projede ara
	var all_files: Array = []
	_scan_project_files("res://", all_files)
	for f in all_files:
		if f.get_file().to_lower() == raw_path.to_lower() or f.to_lower().ends_with("/" + raw_path.to_lower()):
			return f
	return ""

static func _read_file_content_safe(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
		
	var lines: Array[String] = []
	var line_count = 0
	var byte_count = 0
	var was_truncated = false
	
	while not file.eof_reached() and line_count < MAX_ATTACHED_FILE_LINES:
		var line = file.get_line()
		byte_count += line.length() + 1
		if byte_count > MAX_ATTACHED_FILE_BYTES:
			was_truncated = true
			break
		lines.append(line)
		line_count += 1
		
	if not file.eof_reached():
		was_truncated = true
		
	file.close()
	
	var content = "\n".join(lines)
	if was_truncated:
		content += "\n# ... [İçerik %d satır / %d KB güvenlik limitiyle sınırlandırıldı] ...\n" % [MAX_ATTACHED_FILE_LINES, MAX_ATTACHED_FILE_BYTES / 1024]
	return content

static func _resolve_node_info(node_name: String) -> String:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return "Node: " + node_name
	if not EditorInterface.has_method("get_edited_scene_root"):
		return "Node: " + node_name
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return "Node: " + node_name
		
	var target = root.find_child(node_name, true, false)
	if not target:
		if root.name == node_name:
			target = root
			
	if not target:
		return "Node '" + node_name + "' sahnede bulunamadı."
		
	var info = "Name: %s\nType: %s\nPath: %s" % [target.name, target.get_class(), str(target.get_path())]
	var scr = target.get_script()
	if scr is Script and not scr.resource_path.is_empty():
		info += "\nScript: " + scr.resource_path
	return info
