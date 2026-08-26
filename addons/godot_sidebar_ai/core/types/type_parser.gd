@tool
extends RefCounted
class_name AISidebarTypeParser

## Smart Variant & Tip Dönüştürücü (SRP).
## String olarak gelen verileri ('Vector2(100, 200)', '#ff0000', 'true') Godot Variant tiplerine çevirir.

static func parse_smart_variant(val: Variant) -> Variant:
	if not (val is String):
		return val
		
	var s: String = str(val).strip_edges()
	
	# Vector2(x, y)
	if s.begins_with("Vector2(") and s.ends_with(")"):
		var inner = s.trim_prefix("Vector2(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() == 2:
			return Vector2(parts[0].to_float(), parts[1].to_float())
			
	# Vector3(x, y, z)
	if s.begins_with("Vector3(") and s.ends_with(")"):
		var inner = s.trim_prefix("Vector3(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() == 3:
			return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
			
	# Color(#hex) veya Color(r, g, b, a)
	if s.begins_with("#"):
		return Color.from_string(s, Color.WHITE)
	if s.begins_with("Color(") and s.ends_with(")"):
		var inner = s.trim_prefix("Color(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() >= 3:
			var r = parts[0].to_float()
			var g = parts[1].to_float()
			var b = parts[2].to_float()
			var a = parts[3].to_float() if parts.size() > 3 else 1.0
			return Color(r, g, b, a)
			
	# Boolean
	if s.to_lower() == "true":
		return true
	if s.to_lower() == "false":
		return false
		
	# Float / Int
	if s.is_valid_int():
		return s.to_int()
	if s.is_valid_float():
		return s.to_float()
		
	return s
