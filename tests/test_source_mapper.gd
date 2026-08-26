@tool
extends RefCounted

const AISidebarSourceMapper = preload("res://addons/godot_sidebar_ai/core/runtime/source_mapper.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: SCRIPT ERROR parsing
	var log_line = "SCRIPT ERROR: Invalid get index 'speed' (on base: 'Nil'). at: _physics_process (res://scripts/player.gd:25)"
	var parsed = AISidebarSourceMapper.parse_error_line(log_line)
	
	if parsed["is_error"] and parsed["file"] == "res://scripts/player.gd" and parsed["line"] == 25 and parsed["function"] == "_physics_process":
		passed += 1
	else:
		failed += 1
		errors.append("SCRIPT ERROR ayrıştırılamadı: " + str(parsed))
		
	# Test 2: Full Log parsing with Backtrace
	var full_log = """
Godot Engine v4.7.2
SCRIPT ERROR: Parse Error: Unexpected end of file.
   at: GDScript::reload (res://scripts/enemy.gd:12)
GDScript backtrace (most recent call first):
   [0] _ready (res://scripts/enemy.gd:12)
   [1] _init (res://scenes/main.gd:5)
"""
	var obs = AISidebarSourceMapper.parse_log_text(full_log)
	if obs.errors.size() >= 1 and obs.stack_trace.size() >= 2:
		passed += 1
	else:
		failed += 1
		errors.append("Log ve backtrace ayrıştırma eksik: errors=" + str(obs.errors.size()) + ", stack=" + str(obs.stack_trace.size()))
		
	return {"name": "SourceMapperTests", "passed": passed, "failed": failed, "errors": errors}
