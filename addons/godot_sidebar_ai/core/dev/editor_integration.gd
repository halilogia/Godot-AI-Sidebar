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
	await _mouse_fidelity()
	await _ui_audit()
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
		{"file_path": script, "content": "extends Node2D\n\nvar ticks: int = 0\n\nfunc _ready() -> void:\n\tprint(\"I9_GAME_MARKER token=abcdef1234567890\")\n\tEngine.time_scale = 0.0\n\nfunc _process(_d: float) -> void:\n\tticks += 1\n"},
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

	# I9: get_output okur: editörün kendi hatası (push_error) ve oyunun print satırı; sırlar maskelenir.
	push_error("I9_EDITOR_PROBE")
	await _wait(0.3)
	var out := await _tool("get_output", {"source": "both", "contains": "I9_"})
	var out_data: Dictionary = out.get("data", {}) if out.get("data") is Dictionary else {}
	var ed_lines: Array = out_data.get("editor", [])
	var game_lines: Array = out_data.get("game", [])
	var editor_ok := false
	for l: Variant in ed_lines:
		if str(l).contains("I9_EDITOR_PROBE"):
			editor_ok = true
	var game_ok := false
	var leaked := false
	for l: Variant in game_lines:
		if str(l).contains("I9_GAME_MARKER"):
			game_ok = true
		if str(l).contains("abcdef1234567890"):
			leaked = true
	_check.call("i9_get_output_editor_and_game", _ok(out) and editor_ok and game_ok and not leaked, "editor=%s game=%s leaked=%s lines=%d/%d" % [str(editor_ok), str(game_ok), str(leaked), ed_lines.size(), game_lines.size()])
	await _tool("stop_game", {})
	await _wait(0.5)

## I10: oyun tıklamayı event.position yerine get_local_mouse_position() ile okuyorsa da sentetik tıklama doğru
## konumu vermeli (benchmark: grand strateji oyunu böyle okuyordu).
func _mouse_fidelity() -> void:
	var script := DIR + "/mouse.gd"
	var scene := DIR + "/mouse.tscn"
	var text := "[gd_scene load_steps=2 format=3]

[ext_resource type=\"Script\" path=\"%s\" id=\"1_m\"]

[node name=\"MouseProbe\" type=\"Node2D\"]
script = ExtResource(\"1_m\")
" % script
	var code := "extends Node2D

var seen_local: Vector2 = Vector2(-1, -1)
var seen_event: Vector2 = Vector2(-1, -1)
var seen_global: Vector2 = Vector2(-1, -1)
var clicks: int = 0

func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		clicks += 1
		seen_local = get_local_mouse_position()
		seen_global = get_global_mouse_position()
		seen_event = e.position
"
	await _tool("write_files", {"files": [{"file_path": script, "content": code}, {"file_path": scene, "content": text}]})
	EditorInterface.get_resource_filesystem().scan()
	await _wait(1.0)
	await _tool("manage_project_settings", {"action": "set", "key": "application/run/main_scene", "value": scene})
	await _tool("play_game", {})
	await _wait(3.0)
	var click := await _tool("send_input", {"kind": "click", "x": 0.25, "y": 0.5})
	var seen := await _tool("inspect_runtime_node", {"node_path": "MouseProbe"})
	var data: Dictionary = seen.get("data", {}) if seen.get("data") is Dictionary else {}
	var node_info: Dictionary = data.get("node", data)
	var vars: Dictionary = node_info.get("script_vars", {}) if node_info.get("script_vars") is Dictionary else {}
	var clicks: int = vars.get("clicks", 0)
	var want := Vector2(0.25 * 1152.0, 0.5 * 648.0)
	var got_event := _vec(str(vars.get("seen_event", "")))
	var got_local := _vec(str(vars.get("seen_local", "")))
	var got_global := _vec(str(vars.get("seen_global", "")))
	var near := got_event.distance_to(want) < 3.0 and got_local.distance_to(want) < 3.0 and got_global.distance_to(want) < 3.0
	_check.call("i10_click_position_matches_mouse_position", _ok(click) and clicks >= 1 and near, "want=%s event=%s local=%s global=%s" % [want, got_event, got_local, got_global])
	await _tool("stop_game", {})
	await _wait(0.5)

## I11: audit_runtime_ui gerçek oyunda düşük kontrastı, üst üste binmeyi ve ekran dışı metni bulur; temiz metni suçlamaz.
func _ui_audit() -> void:
	var scene := DIR + "/audit.tscn"
	var text := "[gd_scene format=3]

[node name=\"Audit\" type=\"Control\"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name=\"Bg\" type=\"ColorRect\" parent=\".\"]
layout_mode = 0
offset_right = 1152.0
offset_bottom = 648.0
color = Color(0.7, 0.62, 0.45, 1)

[node name=\"Faint\" type=\"Label\" parent=\".\"]
layout_mode = 0
offset_left = 100.0
offset_top = 100.0
offset_right = 400.0
offset_bottom = 140.0
theme_override_colors/font_color = Color(0.75, 0.68, 0.5, 1)
text = \"Faint text on tan\"

[node name=\"Clear\" type=\"Label\" parent=\".\"]
layout_mode = 0
offset_left = 100.0
offset_top = 300.0
offset_right = 500.0
offset_bottom = 340.0
theme_override_colors/font_color = Color(0.05, 0.05, 0.05, 1)
text = \"Clear dark text\"

[node name=\"A\" type=\"Label\" parent=\".\"]
layout_mode = 0
offset_left = 600.0
offset_top = 200.0
offset_right = 800.0
offset_bottom = 240.0
theme_override_colors/font_color = Color(0.05, 0.05, 0.05, 1)
text = \"Overlap A\"

[node name=\"B\" type=\"Label\" parent=\".\"]
layout_mode = 0
offset_left = 610.0
offset_top = 205.0
offset_right = 810.0
offset_bottom = 245.0
theme_override_colors/font_color = Color(0.05, 0.05, 0.05, 1)
text = \"Overlap B\"
"
	await _tool("write_files", {"files": [{"file_path": scene, "content": text}]})
	EditorInterface.get_resource_filesystem().scan()
	await _wait(1.0)
	await _tool("manage_project_settings", {"action": "set", "key": "application/run/main_scene", "value": scene})
	await _tool("play_game", {})
	await _wait(3.0)
	var res := await _tool("audit_runtime_ui", {})
	var data: Dictionary = res.get("data", {}) if res.get("data") is Dictionary else {}
	var codes := {}
	var nodes := ""
	for i: Variant in data.get("issues", []):
		if i is Dictionary:
			codes[str((i as Dictionary).get("code", ""))] = true
			nodes += str((i as Dictionary).get("node", "")) + ";"
	var ok := _ok(res) and codes.has("LOW_CONTRAST") and codes.has("OVERLAP") and nodes.contains("Faint") and not nodes.contains("Clear")
	_check.call("i11_ui_audit_finds_contrast_and_overlap", ok, "codes=%s nodes=%s" % [str(codes.keys()), nodes.left(160)])
	await _tool("stop_game", {})
	await _wait(0.5)

## "(288.0, 324.0)" biçimindeki metin -> Vector2 (okunamazsa çok uzak bir nokta).
static func _vec(text: String) -> Vector2:
	var parts := text.trim_prefix("(").trim_suffix(")").split(",")
	if parts.size() != 2:
		return Vector2(-9999, -9999)
	return Vector2(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float())

## I8: oyun betiği tıklamada hata verse de oyun hata ayıklayıcıda durmaz (play_game hata molalarını yoksaydırır);
## send_input döner; hata hem send_input sonucunda hem get_runtime_errors'ta görünür (günlük dosyası oyun
## çalışırken kilitli: hatalar oyunun kendi hata dinleyicisinden gelir).
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
	var errs := await _tool("get_runtime_errors", {})
	var click_data: Dictionary = click.get("data", {}) if click.get("data") is Dictionary else {}
	var reported: Array = click_data.get("new_runtime_errors", [])
	var errs_data: Dictionary = errs.get("data", {}) if errs.get("data") is Dictionary else {}
	var listed: Array = errs_data.get("errors", [])
	var mentions_foo := false
	for e_v: Variant in listed:
		var e: Dictionary = e_v
		if str(e.get("message", "")).contains("foo"):
			mentions_foo = true
	var ok8: bool = _ok(click) and not breaked and not reported.is_empty() and mentions_foo
	_check.call("i8_script_error_does_not_freeze_the_game", ok8, "click=%s breaked=%s reported=%d listed=%d foo=%s" % [str(click.get("error", "ok")).left(60), str(breaked), reported.size(), listed.size(), str(mentions_foo)])
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
