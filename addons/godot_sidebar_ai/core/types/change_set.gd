@tool
extends RefCounted
class_name AISidebarChangeSet

## ChangeSet ve Diff Modeli (SRP).
## Değişiklik önerilerini, satır farklarını, uygulama (apply) ve geri alma (rollback) mantığını yönetir.

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

enum ChangeType {
	CREATE_FILE,
	MODIFY_FILE,
	DELETE_FILE,
	MUTATE_SCENE
}

var id: String
var change_type: ChangeType
var target_path: String
var old_content: String = ""
var new_content: String = ""
var description: String = ""
var is_applied: bool = false
var is_rejected: bool = false
var created_at: int = 0

func _init(p_target_path: String = "", p_change_type: ChangeType = ChangeType.MODIFY_FILE, p_new_content: String = "", p_old_content: String = "", p_desc: String = "") -> void:
	id = str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)
	target_path = p_target_path
	change_type = p_change_type
	new_content = p_new_content
	old_content = p_old_content
	description = p_desc
	created_at = Time.get_unix_time_from_system()

## İnsan tarafından okunabilir özet metin
func get_summary() -> String:
	var path_base = target_path.get_file()
	if path_base.is_empty():
		path_base = target_path
		
	match change_type:
		ChangeType.CREATE_FILE:
			return "Oluşturulacak: " + path_base + " (" + target_path + ")"
		ChangeType.DELETE_FILE:
			return "Silinecek: " + path_base + " (" + target_path + ")"
		ChangeType.MUTATE_SCENE:
			return "Sahne Değişikliği: " + description
		_:
			var old_lines = old_content.split("\n").size() if not old_content.is_empty() else 0
			var new_lines = new_content.split("\n").size() if not new_content.is_empty() else 0
			return "Güncellenecek: " + path_base + " (" + str(new_lines) + " satır)"

## Satır bazlı Diff metni üretir (+ Eklenenler, - Silinenler)
func get_diff_text() -> String:
	var old_lines = old_content.split("\n") if not old_content.is_empty() else PackedStringArray()
	var new_lines = new_content.split("\n") if not new_content.is_empty() else PackedStringArray()
	var diff_output: PackedStringArray = []
	
	diff_output.append("--- a/" + target_path)
	diff_output.append("+++ b/" + target_path)
	
	var max_len = maxi(old_lines.size(), new_lines.size())
	for i in range(max_len):
		var old_l = old_lines[i] if i < old_lines.size() else null
		var new_l = new_lines[i] if i < new_lines.size() else null
		
		if old_l != null and new_l != null:
			if old_l == new_l:
				diff_output.append("  " + old_l)
			else:
				diff_output.append("- " + old_l)
				diff_output.append("+ " + new_l)
		elif old_l != null:
			diff_output.append("- " + old_l)
		elif new_l != null:
			diff_output.append("+ " + new_l)
			
	return "\n".join(diff_output)

## Değişikliği diske uygular (Apply)
func apply() -> Dictionary:
	if is_applied:
		return AISidebarToolResult.ok(null, "Değişiklik zaten uygulanmış.")
		
	var safe_check = AISidebarPathPolicy.is_safe_to_write(target_path)
	if not safe_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
		
	var path = safe_check["path"]
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	# Eski içeriği yedekle (Eğer daha önce kaydedilmediyse)
	if old_content.is_empty() and FileAccess.file_exists(path):
		var old_f = FileAccess.open(path, FileAccess.READ)
		if old_f:
			old_content = old_f.get_as_text()
			old_f.close()
			
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return AISidebarToolResult.err("WRITE_FAILED", "Dosya yazılamadı: " + path)
		
	file.store_string(new_content)
	file.close()
	is_applied = true
	is_rejected = false
	
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		if EditorInterface.has_method("get_resource_filesystem"):
			EditorInterface.get_resource_filesystem().scan()
			
	return AISidebarToolResult.ok({"path": path, "applied": true}, "Değişiklik başarıyla uygulandı.")

## Değişikliği geri alır (Rollback)
func rollback() -> Dictionary:
	if not is_applied:
		return AISidebarToolResult.err("NOT_APPLIED", "Uygulanmamış değişiklik geri alınamaz.")
		
	var safe_check = AISidebarPathPolicy.is_safe_to_write(target_path)
	if not safe_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
		
	var path = safe_check["path"]
	if change_type == ChangeType.CREATE_FILE and old_content.is_empty():
		# Yeni oluşturulan dosya ise sil
		DirAccess.remove_absolute(path)
	else:
		# Eski içeriği geri yaz
		var file = FileAccess.open(path, FileAccess.WRITE)
		if not file:
			return AISidebarToolResult.err("WRITE_FAILED", "Geri alma esnasında dosya yazılamadı: " + path)
		file.store_string(old_content)
		file.close()
		
	is_applied = false
	return AISidebarToolResult.ok({"path": path, "rolled_back": true}, "Değişiklik başarıyla geri alındı.")

func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": change_type,
		"target_path": target_path,
		"description": description,
		"is_applied": is_applied,
		"is_rejected": is_rejected,
		"old_length": old_content.length(),
		"new_length": new_content.length(),
		"created_at": created_at
	}
