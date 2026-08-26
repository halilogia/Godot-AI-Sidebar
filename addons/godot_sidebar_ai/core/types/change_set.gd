@tool
extends RefCounted
class_name AISidebarChangeSet

## Atomik Değişiklik Seti ve Geri Alma (ChangeSet, Multi-File Unified Diff & Batch Support) (SRP).

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")

enum ChangeType {
	CREATE_FILE,
	MODIFY_FILE,
	DELETE_FILE,
	MUTATE_SCENE
}

var target_path: String = ""
var change_type: ChangeType = ChangeType.MODIFY_FILE
var new_content: String = ""
var old_content: String = ""
var description: String = ""
var timestamp: int = 0
var sub_changes: Array[Dictionary] = [] # Çoklu dosya ve sahne operasyonları için

func _init(p_path: String = "", p_type: ChangeType = ChangeType.MODIFY_FILE, p_new: String = "", p_old: String = "", p_desc: String = "") -> void:
	target_path = p_path
	change_type = p_type
	new_content = p_new
	old_content = p_old
	description = p_desc
	timestamp = Time.get_unix_time_from_system()

func add_sub_change(p_path: String, p_type: ChangeType, p_new: String, p_old: String, p_desc: String) -> void:
	sub_changes.append({
		"target_path": p_path,
		"change_type": p_type,
		"new_content": p_new,
		"old_content": p_old,
		"description": p_desc
	})

## Değişiklikleri diske / sahneye uygular (Apply)
func apply() -> Dictionary:
	# 1. Ana Değişikliği Uygula
	var main_res = _apply_single(target_path, change_type, new_content)
	if not main_res["success"]:
		return main_res
		
	# 2. Varsa Alt Değişiklikleri Uygula
	for sub in sub_changes:
		var sub_res = _apply_single(sub["target_path"], sub["change_type"], sub["new_content"])
		if not sub_res["success"]:
			return sub_res
			
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_resource_filesystem"):
		EditorInterface.get_resource_filesystem().scan()
		
	return {"success": true, "message": "ChangeSet başarıyla uygulandı (" + str(1 + sub_changes.size()) + " dosya/değişiklik)."}

func _apply_single(path: String, c_type: ChangeType, content: String) -> Dictionary:
	if path.is_empty():
		return {"success": true}
		
	var check = AISidebarPathPolicy.is_safe_to_write(path)
	if not check["safe"]:
		return {"success": false, "error": "Güvenlik Engeli: " + check["reason"]}
		
	match c_type:
		ChangeType.CREATE_FILE, ChangeType.MODIFY_FILE:
			var dir = path.get_base_dir()
			if not DirAccess.dir_exists_absolute(dir):
				DirAccess.make_dir_recursive_absolute(dir)
			var f = FileAccess.open(path, FileAccess.WRITE)
			if not f:
				return {"success": false, "error": "Dosya yazılamadı: " + path}
			f.store_string(content)
			f.close()
		ChangeType.DELETE_FILE:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		ChangeType.MUTATE_SCENE:
			pass
			
	return {"success": true}

## Değişiklikleri geri alır (Rollback)
func rollback() -> Dictionary:
	# Ters sırayla geri al
	for i in range(sub_changes.size() - 1, -1, -1):
		var sub = sub_changes[i]
		_rollback_single(sub["target_path"], sub["change_type"], sub["old_content"])
		
	_rollback_single(target_path, change_type, old_content)
	
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_resource_filesystem"):
		EditorInterface.get_resource_filesystem().scan()
		
	return {"success": true, "message": "ChangeSet geri alındı."}

func _rollback_single(path: String, c_type: ChangeType, old_c: String) -> Dictionary:
	if path.is_empty():
		return {"success": true}
	match c_type:
		ChangeType.CREATE_FILE:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		ChangeType.MODIFY_FILE:
			var f = FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_string(old_c)
				f.close()
		ChangeType.DELETE_FILE:
			var f = FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_string(old_c)
				f.close()
		ChangeType.MUTATE_SCENE:
			pass
	return {"success": true}

## Çoklu dosya ve satır farkı özeti üretir
func get_summary() -> String:
	var lines: PackedStringArray = []
	var total_items = (1 if not target_path.is_empty() else 0) + sub_changes.size()
	lines.append("Değişiklik Sayısı: " + str(total_items) + " dosya")
	
	if not target_path.is_empty():
		_append_item_summary(target_path, change_type, old_content, new_content, description, lines)
	
	for sub in sub_changes:
		_append_item_summary(sub["target_path"], sub["change_type"], sub["old_content"], sub["new_content"], sub["description"], lines)
		
	return "\n".join(lines)

func _append_item_summary(path: String, c_type: ChangeType, old_c: String, new_c: String, desc: String, out_lines: PackedStringArray) -> void:
	var name_str = path.get_file() if not path.is_empty() else desc
	match c_type:
		ChangeType.CREATE_FILE:
			var added = new_c.split("\n").size()
			out_lines.append(" + [YENİ] " + name_str + " (+" + str(added) + " satır)")
		ChangeType.MODIFY_FILE:
			var old_lines = old_c.split("\n")
			var new_lines = new_c.split("\n")
			out_lines.append(" ~ [DÜZENLEME] " + name_str + " (Eski: " + str(old_lines.size()) + " satır, Yeni: " + str(new_lines.size()) + " satır)")
		ChangeType.DELETE_FILE:
			out_lines.append(" - [SİLME] " + name_str)
		ChangeType.MUTATE_SCENE:
			out_lines.append(" ❖ [SAHNE] " + desc)

## Satır satır Çoklu Dosya Unified Diff üretir
func get_unified_diff() -> String:
	var diff_lines: PackedStringArray = []
	
	if not target_path.is_empty():
		_append_single_diff(target_path, old_content, new_content, diff_lines)
		
	for sub in sub_changes:
		if diff_lines.size() > 0:
			diff_lines.append("\n" + "=".repeat(40) + "\n")
		_append_single_diff(sub["target_path"], sub["old_content"], sub["new_content"], diff_lines)
		
	return "\n".join(diff_lines)

func _append_single_diff(path: String, old_c: String, new_c: String, out_diff: PackedStringArray) -> void:
	out_diff.append("--- a/" + path)
	out_diff.append("+++ b/" + path)
	
	var old_arr = old_c.split("\n")
	var new_arr = new_c.split("\n")
	
	var max_len = maxi(old_arr.size(), new_arr.size())
	for i in range(max_len):
		var o_line = old_arr[i] if i < old_arr.size() else null
		var n_line = new_arr[i] if i < new_arr.size() else null
		
		if o_line != null and n_line != null:
			if o_line == n_line:
				out_diff.append("  " + o_line)
			else:
				out_diff.append("- " + o_line)
				out_diff.append("+ " + n_line)
		elif o_line != null:
			out_diff.append("- " + o_line)
		elif n_line != null:
			out_diff.append("+ " + n_line)

func get_diff_text() -> String:
	return get_unified_diff()
