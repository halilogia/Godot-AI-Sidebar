@tool
extends RefCounted
class_name AISidebarSourceMapper

## Kaynak Eşleyici ve Hata Ayrıştırıcı (Source Mapper & Log Parser) (SRP).
## Godot loglarından dosya yolu, satır numarası, fonksiyon adı ve ilgili kod parçacığını çıkarır.
## Tek satırlı ve çok satırlı Godot 4 SCRIPT ERROR / Backtrace formatlarını tam olarak destekler.

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
	
	if not ("ERROR" in raw_line or "SCRIPT ERROR" in raw_line or "CRASH" in raw_line or "Invalid" in raw_line or "USER ERROR" in raw_line or "FATAL" in raw_line):
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

## Log metnini tarayıp bir RuntimeObservation nesnesi üretir (Multi-Line Aware)
static func parse_log_text(log_text: String) -> AISidebarRuntimeObservation:
	var obs = AISidebarRuntimeObservation.new()
	var lines = log_text.split("\n")
	
	var loc_reg = RegEx.new()
	loc_reg.compile("(?i)at:\\s*([a-zA-Z0-9_]+)?\\s*\\((res://[^:]+):(\\d+)\\)")
	
	var simple_reg = RegEx.new()
	simple_reg.compile("(res://[a-zA-Z0-9_/\\-\\.]+\\.gd):(\\d+)")
	
	var bt_reg = RegEx.new()
	bt_reg.compile("\\[\\d+\\]\\s*([a-zA-Z0-9_]+)?\\s*\\((res://[^:]+):(\\d+)\\)")
	
	var i = 0
	while i < lines.size():
		var line = lines[i].strip_edges()
		if line.is_empty():
			i += 1
			continue
			
		var is_err = ("ERROR" in line or "SCRIPT ERROR" in line or "CRASH" in line or "USER ERROR" in line or "Invalid" in line or "FATAL" in line)
		if is_err:
			var msg = line
			var file_loc = ""
			var line_num = 0
			var fn_name = ""
			var err_type = "RUNTIME_ERROR"
			
			var m = loc_reg.search(line)
			if m:
				fn_name = m.get_string(1)
				file_loc = m.get_string(2)
				line_num = int(m.get_string(3))
			else:
				var sm = simple_reg.search(line)
				if sm:
					file_loc = sm.get_string(1)
					line_num = int(sm.get_string(2))
					
			var j = i + 1
			while j < lines.size():
				var next_l = lines[j].strip_edges()
				if next_l.begins_with("at:") or next_l.begins_with("USER SCRIPT ERROR") or next_l.begins_with("SCRIPT ERROR"):
					var m_next = loc_reg.search(next_l)
					if m_next:
						if fn_name.is_empty(): fn_name = m_next.get_string(1)
						if file_loc.is_empty(): file_loc = m_next.get_string(2)
						if line_num == 0: line_num = int(m_next.get_string(3))
					else:
						var sm_next = simple_reg.search(next_l)
						if sm_next and file_loc.is_empty():
							file_loc = sm_next.get_string(1)
							line_num = int(sm_next.get_string(2))
					j += 1
				elif "GDScript backtrace" in next_l or next_l.begins_with("["):
					var bt_match = bt_reg.search(next_l)
					if bt_match:
						obs.add_stack_frame(bt_match.get_string(2), int(bt_match.get_string(3)), bt_match.get_string(1))
						if file_loc.is_empty():
							file_loc = bt_match.get_string(2)
							line_num = int(bt_match.get_string(3))
							fn_name = bt_match.get_string(1)
					j += 1
				else:
					break
					
			obs.add_error(msg, file_loc, line_num, fn_name, err_type)
			i = j
			continue
			
		i += 1
		
	return obs
