@tool
extends RefCounted

const AISidebarTypeParser = preload("res://addons/godot_sidebar_ai/core/types/type_parser.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Vector2
	var v2 = AISidebarTypeParser.parse_smart_variant("Vector2(100, 200)")
	if v2 is Vector2 and v2.x == 100.0 and v2.y == 200.0:
		passed += 1
	else:
		failed += 1
		errors.append("Vector2 parse failed: " + str(v2))
		
	# Test 2: Vector3
	var v3 = AISidebarTypeParser.parse_smart_variant("Vector3(1, 2, 3)")
	if v3 is Vector3 and v3.x == 1.0 and v3.y == 2.0 and v3.z == 3.0:
		passed += 1
	else:
		failed += 1
		errors.append("Vector3 parse failed: " + str(v3))
		
	# Test 3: Hex Color
	var col = AISidebarTypeParser.parse_smart_variant("#ff0000")
	if col is Color and col.r == 1.0 and col.g == 0.0 and col.b == 0.0:
		passed += 1
	else:
		failed += 1
		errors.append("Color hex parse failed: " + str(col))
		
	# Test 4: Boolean
	var b_true = AISidebarTypeParser.parse_smart_variant("true")
	var b_false = AISidebarTypeParser.parse_smart_variant("false")
	if b_true == true and b_false == false:
		passed += 1
	else:
		failed += 1
		errors.append("Boolean parse failed")
		
	# Test 5: Number
	var num = AISidebarTypeParser.parse_smart_variant("42.5")
	if num is float and num == 42.5:
		passed += 1
	else:
		failed += 1
		errors.append("Float parse failed: " + str(num))
		
	return {"name": "TypeParserTests", "passed": passed, "failed": failed, "errors": errors}
