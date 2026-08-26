@tool
extends RefCounted
class_name AISidebarChangeSet

## ChangeSet ve Diff Modeli (SRP).
## Dosya veya sahne değişiklik önerilerini, satır farklarını ve onay/geri alma durumunu temsil eder.

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
var created_at: int = 0

func _init(p_target_path: String = "", p_change_type: ChangeType = ChangeType.MODIFY_FILE, p_new_content: String = "", p_old_content: String = "", p_desc: String = "") -> void:
	id = str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)
	target_path = p_target_path
	change_type = p_change_type
	new_content = p_new_content
	old_content = p_old_content
	description = p_desc
	created_at = Time.get_unix_time_from_system()

## Basit satır bazlı Diff metni üretir (+ Eklenenler, - Silinenler)
func get_diff_text() -> String:
	var old_lines = old_content.split("\n")
	var new_lines = new_content.split("\n")
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

func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": change_type,
		"target_path": target_path,
		"description": description,
		"is_applied": is_applied,
		"old_length": old_content.length(),
		"new_length": new_content.length(),
		"created_at": created_at
	}
