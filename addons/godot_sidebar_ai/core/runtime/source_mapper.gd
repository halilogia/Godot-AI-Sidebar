@tool
extends RefCounted
class_name AISidebarSourceMapper

## Kaynak Eşleyici ve Hata Ayrıştırıcı (Source Mapper & Log Parser) (SRP).
## Godot loglarından dosya yolu, satır numarası, fonksiyon adı ve ilgili kod parçacığını çıkarır.

const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")

static func parse_error_line(raw_line: String) -> Dictionary:
	var parsed: Dictionary = {
		"is_error": false,
		"file": "",
		"line": 0,
		"function": "",
		"message": raw_line.strip_edges(),
		"error_type": "GENERIC_ERROR"
	}
	
	if not ("ERROR" in raw_line or "SCRIPT ERROR" in raw_line or "CRASH" in raw_line or "Invalid" in raw_line):
		return parsed
		
	parsed["is_error"] = true
	
	# RegEx 1: Standard Godot SCRIPT ERROR with location: at: fn (res://path.gd:42)
	var regex = RegEx.new()
	regex.compile("(?i)at:\\s*([a-zA-Z0-9_]+)?\\s*\\((res://[^:]+):(\\d+)\\)")
	var match_res = regex.search(raw_line)
	if match_res:
		parsed["function"] = match_res.get_string(1)
		parsed["file"] = match_res.get_string(2)
		parsed["line"] = int(match_res.get_string(3))
		parsed["error_type"] = "SCRIPT_ERROR"
	else:
		# RegEx 2: Simple file path match (res://...:42)
		var simple_reg = RegEx.new()
		simple_reg.compile("(res://[a-zA-Z0-9_/\\-\\.]+\\.gd):(\\d+)")
		var s_match = simple_reg.search(raw_line)
		if s_match:
			parsed["file"] = s_match.get_string(1)
			parsed["line"] = int(s_match.get_string(2))
			parsed["error_type"] = "RUNTIME_EXCEPTION"
			
	return parsed

## Hata satırının etrafındaki kaynak kod bağlamını (Snippet) okur
static func get_source_snippet(file_path: String, target_line: int, radius: int = 4) -> String:
	if not FileAccess.file_exists(file_path):
		return "[Dosya bulunamadı: " + file_path + "]"
		
	var f = FileAccess.open(file_path, FileAccess.READ)
	if not f:
		return "[Dosya okunamadı: " + file_path + "]"
		
	var lines = f.get_as_text().split("\n")
	f.close()
	
	var start_idx = maxi(0, target_line - radius - 1)
	var end_idx = mini(lines.size(), target_line + radius)
	var output: PackedStringArray = []
	
	output.append("--- " + file_path + " (Satır " + str(target_line) + " civarı) ---")
	for i in range(start_idx, end_idx):
		var line_num = i + 1
		var marker = ">> " if line_num == target_line else "   "
		output.append(marker + str(line_num).rpad(4) + "| " + lines[i])
		
	return "\n".join(output)

## Log metnini tarayıp bir RuntimeObservation nesnesi üretir
static func parse_log_text(log_text: String) -> AISidebarRuntimeObservation:
	var obs = AISidebarRuntimeObservation.new()
	var lines = log_text.split("\n")
	
	var is_in_backtrace = false
	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed.is_empty():
			continue
			
		if "GDScript backtrace" in trimmed:
			is_in_backtrace = true
			continue
			
		if is_in_backtrace:
			if trimmed.begins_with("["):
				# Backtrace frame parse: [0] _physics_process (res://scripts/player.gd:15)
				var bt_reg = RegEx.new()
				bt_reg.compile("\\[\\d+\\]\\s*([a-zA-Z0-9_]+)\\s*\\((res://[^:]+):(\\d+)\\)")
				var bt_match = bt_reg.search(trimmed)
				if bt_match:
					obs.add_stack_frame(bt_match.get_string(2), int(bt_match.get_string(3)), bt_match.get_string(1))
				continue
			else:
				is_in_backtrace = false
				
		var err_check = parse_error_line(trimmed)
		if err_check["is_error"]:
			obs.add_error(
				err_check["message"],
				err_check["file"],
				err_check["line"],
				err_check["function"],
				err_check["error_type"]
			)
			
	return obs
