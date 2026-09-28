@tool
extends RefCounted

## Gerçek editörde entegrasyon senaryoları (editor_smoke.gd çağırır; tools/editor_smoke.ps1 başlatır).
## Ajanın gerçek araç yolunu (AISidebarToolManager) kullanır; headless testlerin göremediği editör
## davranışını sınar. Her senaryo bir benchmark'ta bulunmuş hatadan gelir:
##   I1 açık sahne üzerine yazılınca editör yeni hali yükler, kaydetmek dosyayı eski kopyayla ezmez
##   I2 manage_project_settings ile eklenen autoload'u kullanan betik doğrulamadan geçer
##   I3 ana sahne ayarlanır, oyun çalışır, runtime köprüsünden ekran görüntüsü alınır
##   I4 görünmeyen viewport 2x2 "başarılı" ekran görüntüsü döndürmez
##   I5 send_input adım dizisi ve wait_for_runtime gerçek oyunda (anlık doğrulama, koşul, zaman aşımı)
##   I6 oyun Engine.time_scale = 0 yapsa da bekleyen araçlar döner
##   I7 get_runtime_performance ve trace_runtime_signals gerçek oyunda
##   I8 oyun betiği hata verse de oyun donmaz (hata molaları yoksayılır), send_input döner
## Geçici dosyalar DIR altında; sonda silinir. project.godot'u editor_smoke.ps1 bayt bayt geri koyar.

const AISidebarDebuggerPlugin = preload("res://addons/godot_sidebar_ai/core/runtime/debugger_plugin.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")

const DIR := "res://tests/tmp_integration"
const AUTOLOAD := "TmpIntegSingleton"

var _host: Node
var _check: Callable

func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	DirAccess.make_dir_recursive_absolute(DIR)
	await _stale_scene()
	await _autoload()
	await _play_and_bridge()
	await _frozen_time_scale()
	await _error_break()
	await _hidden_viewport()
	_cleanup()

func _tool(tool_name: String, args: Dictionary) -> Dictionary:
	if AISidebarToolManager.is_async_tool(tool_name):
		return await AISidebarToolManager.execute_tool_async(tool_name, args, true)
	return AISidebarToolManager.execute_tool(tool_name, args, true)

static func _ok(r: Dictionary) -> bool:
	return r.get("success") == true

static func _width(data: Dictionary) -> int:
	var w: Variant = data.get("width", 0)
	return w if w is int else 0

func _wait(sec: float) -> void:
	await _host.get_tree().create_timer(sec).timeout

func _scene_text(root_name: String, child: String = "") -> String:
	var text := "[gd_scene format=3]\n\n[node name=\"%s\" type=\"Node2D\"]\n" % root_name
	if not child.is_empty():
		text += "\n[node name=\"%s\" type=\"Node2D\" parent=\".\"]\n" % child
	return text

func _stale_scene() -> void:
	var path := DIR + "/stale.tscn"
	var first := await _tool("write_files", {"files": [{"file_path": path, "content": _scene_text("Stale")}]})
	EditorInterface.get_resource_filesystem().scan()
	await _wait(1.0)
	EditorInterface.open_scene_from_path(path)
	await _wait(0.5)
	var second := await _tool("write_files", {"files": [{"file_path": path, "content": _scene_text("Stale", "Marker")}]})
	await _wait(0.5)
	var root := EditorInterface.get_edited_scene_root()
	var reloaded := root != null and root.has_node("Marker")
	EditorInterface.save_scene()
	await _wait(0.3)
	var on_disk := FileAccess.get_file_as_string(path).contains("Marker")
	_check.call("i1_stale_scene_reload", _ok(first) and _ok(second) and reloaded and on_disk,
		"reloaded=%s on_disk=%s" % [reloaded, on_disk])

func _autoload() -> void:
	var singleton := DIR + "/singleton.gd"
	await _tool("write_files", {"files": [{"file_path": singleton, "content": "extends Node\n\nfunc answer() -> int:\n\treturn 7\n"}]})
	EditorInterface.get_resource_filesystem().scan()
	await _wait(1.0)
	var added := await _tool("manage_project_settings", {"action": "add_autoload", "name": AUTOLOAD, "path": singleton})
	await _wait(0.5)
	var user := await _tool("create_or_update_script", {"file_path": DIR + "/uses_singleton.gd", "content": "extends Node\n\nfunc read() -> int:\n\treturn %s.answer()\n" % AUTOLOAD})
	_check.call("i2_autoload_usable", _ok(added) and _ok(user), str(user.get("error", "")).left(160))
	await _tool("manage_project_settings", {"action": "remove_autoload", "name": AUTOLOAD})

func _play_and_bridge() -> void:
	var main := DIR + "/main.tscn"
	await _tool("write_files", {"files": [{"file_path": main, "content": _scene_text("IntegMain")}]})
	EditorInterface.get_resource_filesystem().scan()
	await _wait(1.0)
	var set_main := await _tool("manage_project_settings", {"action": "set", "key": "application/run/main_scene", "value": main})
	var played := await _tool("play_game", {})
	var shot: Dictionary = {}
	# Köprü oyun açıldıktan sonra hazır olur: birkaç deneme (ajanın yapacağı gibi).
	for i in 6:
		await _wait(1.5)
		shot = await _tool("take_runtime_screenshot", {"max_dimension": 320})
		if _ok(shot):
			break
	var data: Dictionary = shot.get("data", {}) if shot.get("data") is Dictionary else {}
	var ok := _ok(set_main) and _ok(played) and _ok(shot) and _width(data) >= 16
	_check.call("i3_play_and_runtime_screenshot", ok, str(shot.get("error", "")).left(160))
	await _input_and_wait()
	await _tool("stop_game", {})
	await _wait(0.5)

## I5 (oyun açıkken): send_input dizisi tek çağrıda oynar; wait_for_runtime oyunun içinde yoklar ve
## anlık doğrulama / koşul / zaman aşımı sonuçlarını ayırır.
func _input_and_wait() -> void:
	var seq := await _tool("send_input", {"steps": [{"kind": "key", "key": "A", "hold_ms": 50, "wait_ms": 100}, {"kind": "wait", "wait_ms": 100}, {"kind": "key", "key": "Space"}]})
	var passed := await _tool("wait_for_runtime", {"node_path": "IntegMain", "operator": "exists", "timeout_ms": 0})
	var met := await _tool("wait_for_runtime", {"node_path": "/root/IntegMain", "property": "visible", "operator": "==", "value": true, "timeout_ms": 1000})
	var timed_out := await _tool("wait_for_runtime", {"node_path": "IntegMain/Nope", "operator": "exists", "timeout_ms": 300})
	var p_data: Dictionary = passed.get("data", {}) if passed.get("data") is Dictionary else {}
	var m_data: Dictionary = met.get("data", {}) if met.get("data") is Dictionary else {}
	var t_err: Dictionary = timed_out.get("error", {}) if timed_out.get("error") is Dictionary else {}
	var ok: bool = _ok(seq) and p_data.get("status") == "ASSERTION_PASSED" and m_data.get("status") == "CONDITION_MET" and t_err.get("code") == "TIMEOUT"
	_check.call("i5_input_steps_and_wait_for_runtime", ok, "seq=%s passed=%s met=%s timeout=%s" % [seq.get("success"), p_data.get("status"), m_data.get("status"), t_err.get("code")])

	# I5b: aynı anda birden çok action ve sürükle-bırak
	var multi := await _tool("send_input", {"kind": "actions", "actions": ["ui_left", "ui_right"], "hold_ms": 100})
	var drag := await _tool("send_input", {"kind": "drag", "x": 0.2, "y": 0.5, "to_x": 0.8, "to_y": 0.5, "hold_ms": 300})
	var bad_drag := await _tool("send_input", {"kind": "drag", "x": 0.2, "y": 0.5, "to_x": 2.0, "to_y": 0.5})
	var bd_err: Dictionary = bad_drag.get("error", {}) if bad_drag.get("error") is Dictionary else {}
	_check.call("i5b_multi_action_and_drag", _ok(multi) and _ok(drag) and bd_err.get("code") == "OUT_OF_RANGE", "multi=%s drag=%s bad=%s" % [str(multi.get("error", "ok")).left(80), str(drag.get("error", "ok")).left(80), bd_err.get("code")])

	# I7: performans ölçümü ve sinyal izleme gerçek oyunda
	var perf := await _tool("get_runtime_performance", {"duration_ms": 400})
	var trace := await _tool("trace_runtime_signals", {"node_path": "IntegMain", "signals": ["visibility_changed"], "duration_ms": 300})
	var no_signals := await _tool("trace_runtime_signals", {"node_path": "IntegMain", "signals": ["nope_not_a_signal"], "duration_ms": 200})
	var perf_data: Dictionary = perf.get("data", {}) if perf.get("data") is Dictionary else {}
	var trace_data: Dictionary = trace.get("data", {}) if trace.get("data") is Dictionary else {}
	var ns_err: Dictionary = no_signals.get("error", {}) if no_signals.get("error") is Dictionary else {}
	var frames: int = perf_data.get("frames", 0)
	var silent: Array = trace_data.get("silent", [])
	var ok7: bool = _ok(perf) and frames > 0 and _ok(trace) and silent.has("visibility_changed") and ns_err.get("code") == "NO_SIGNALS"
	_check.call("i7_performance_and_signal_trace", ok7, "perf=%s frames=%s trace=%s nosig=%s" % [perf.get("success"), perf_data.get("frames"), trace.get("success"), ns_err.get("code")])

## I6: oyun Engine.time_scale = 0 yapsa da (tur tabanlı oyun) send_input ve wait_for_runtime dönmeli;
## SceneTreeTimer'lı ilk sürüm burada "çalışma zamanı sorgusu zaman aşımı" veriyordu.
func _frozen_time_scale() -> void:
	var script := DIR + "/frozen.gd"
	var scene := DIR + "/frozen.tscn"
	var text := "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"%s\" id=\"1_f\"]\n\n[node name=\"Frozen\" type=\"Node2D\"]\nscript = ExtResource(\"1_f\")\n" % script
	await _tool("write_files", {"files": [
		{"file_path": script, "content": "extends Node2D\n\nvar ticks: int = 0\n\nfunc _ready() -> void:\n\tEngine.time_scale = 0.0\n\nfunc _process(_d: float) -> void:\n\tticks += 1\n"},
		{"file_path": scene, "content": text}]})
	EditorInterface.get_resource_filesystem().scan()
	await _wait(1.0)
	await _tool("manage_project_settings", {"action": "set", "key": "application/run/main_scene", "value": scene})
	await _tool("play_game", {})
	await _wait(3.0)
	var seq := await _tool("send_input", {"steps": [{"kind": "key", "key": "A", "hold_ms": 200, "wait_ms": 200}]})
	var waited := await _tool("wait_for_runtime", {"node_path": "Frozen", "property": "ticks", "operator": ">", "value": 3, "timeout_ms": 2000})
	var ok: bool = _ok(seq) and _ok(waited)
	_check.call("i6_inputs_work_with_time_scale_zero", ok, "seq=%s wait=%s" % [str(seq.get("error", "ok")).left(90), str(waited.get("error", "ok")).left(90)])
	await _tool("stop_game", {})
	await _wait(0.5)

## I8: oyun betiği tıklamada hata verse de oyun hata ayıklayıcıda durmaz (play_game hata molalarını yoksaydırır);
## send_input döner, düğüm hâlâ okunur.
func _error_break() -> void:
	var script := DIR + "/breaker.gd"
	var scene := DIR + "/breaker.tscn"
	var text := "[gd_scene load_steps=2 format=3]

[ext_resource type=\"Script\" path=\"%s\" id=\"1_b\"]

[node name=\"Breaker\" type=\"Node2D\"]
script = ExtResource(\"1_b\")
" % script
	await _tool("write_files", {"files": [
		{"file_path": script, "content": "extends Node2D

var hits: int = 0

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		hits += 1
		var n = null
		n.foo()
"},
		{"file_path": scene, "content": text}]})
	EditorInterface.get_resource_filesystem().scan()
	await _wait(1.0)
	await _tool("manage_project_settings", {"action": "set", "key": "application/run/main_scene", "value": scene})
	await _tool("play_game", {})
	await _wait(3.0)
	var click := await _tool("send_input", {"kind": "click", "x": 0.5, "y": 0.5})
	var dbg := AISidebarDebuggerPlugin.instance
	var breaked := false
	if dbg != null and dbg.get_active_session() != null:
		breaked = dbg.get_active_session().is_breaked()
	var after := await _tool("inspect_runtime_node", {"node_path": "Breaker"})
	var ok8: bool = _ok(click) and not breaked and _ok(after)
	_check.call("i8_script_error_does_not_freeze_the_game", ok8, "click=%s breaked=%s" % [str(click.get("error", "ok")).left(60), str(breaked)])
	await _tool("stop_game", {})
	await _wait(0.5)

func _hidden_viewport() -> void:
	EditorInterface.set_main_screen_editor("Script")
	await _wait(0.5)
	var shot := await _tool("take_viewport_screenshot", {"viewport_type": "2d"})
	var data: Dictionary = shot.get("data", {}) if shot.get("data") is Dictionary else {}
	var fake_success := _ok(shot) and _width(data) < 16
	_check.call("i4_hidden_viewport_not_success", not fake_success, "success=%s width=%s" % [shot.get("success"), data.get("width", "-")])
	EditorInterface.set_main_screen_editor("2D")

func _cleanup() -> void:
	for f: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))
	DirAccess.remove_absolute(DIR)
