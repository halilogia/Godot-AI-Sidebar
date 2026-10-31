extends SceneTree

## Headless UI Audit CLI Runner (Godot AI Sidebar)
## Kullanım:
##   godot --headless --path <proje> -s <bu_betik> -- [--platform desktop|mobile] [--scenario <dosya.json>] [--scene <res://...>] [--json]

const AISidebarUITelemetryTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd")
const AISidebarUIAuditRules = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_audit_rules.gd")
const AISidebarUIAuditScenario = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_audit_scenario.gd")

func _initialize() -> void:
	var uargs: PackedStringArray = OS.get_cmdline_user_args()
	var platform: String = "desktop"
	var scenario_path: String = ""
	var scene_path: String = ""
	var json_out: bool = false
	var i: int = 0
	while i < uargs.size():
		var a: String = uargs[i]
		match a:
			"--platform", "-p":
				if i + 1 < uargs.size():
					platform = uargs[i + 1]
					i += 1
			"--scenario":
				if i + 1 < uargs.size():
					scenario_path = uargs[i + 1]
					i += 1
			"--scene":
				if i + 1 < uargs.size():
					scene_path = uargs[i + 1]
					i += 1
			"--json":
				json_out = true
		i += 1
	ProjectSettings.set_setting(AISidebarUIAuditRules.PLATFORM_SETTING, platform)
	var args: Dictionary = {"platform": platform}
	var holder: Node = null
	var target: Node = null
	if not scenario_path.is_empty():
		args["scenario_path"] = scenario_path
	else:
		if scene_path.is_empty():
			scene_path = str(ProjectSettings.get_setting("application/run/main_scene", ""))
		if scene_path.is_empty():
			printerr("[ui_audit] HATA: Denetlenecek sahne veya senaryo bulunamadı.")
			quit(2)
			return
		var mounted: Dictionary = AISidebarUIAuditScenario.mount_scene(scene_path, Vector2i(1600, 900))
		if mounted.has("error"):
			printerr("[ui_audit] HATA: ", mounted["error"])
			quit(2)
			return
		holder = mounted["holder"]
		target = mounted["root"]
		for _f: int in 4:
			await process_frame
		args["target_node"] = target
	var layout_res: Dictionary = await AISidebarUITelemetryTools.execute_async("audit_ui_layout", args.duplicate())
	var touch_res: Dictionary = await AISidebarUITelemetryTools.execute_async("audit_ui_touch", args.duplicate())
	if holder != null:
		holder.queue_free()
	var ldata: Dictionary = layout_res.get("data", layout_res)
	var tdata: Dictionary = touch_res.get("data", touch_res)
	var l_by: Dictionary = ldata.get("by_priority", {"P0": 0, "P1": 0, "P2": 0})
	var t_by: Dictionary = tdata.get("by_priority", {"P0": 0, "P1": 0, "P2": 0})
	var p0: int = int(l_by.get("P0", 0)) + int(t_by.get("P0", 0))
	var p1: int = int(l_by.get("P1", 0)) + int(t_by.get("P1", 0))
	var p2: int = int(l_by.get("P2", 0)) + int(t_by.get("P2", 0))
	var passed: bool = bool(ldata.get("passed", false)) and bool(tdata.get("passed", false)) and (p0 + p1 == 0)
	if json_out:
		print(JSON.stringify({"passed": passed, "platform": platform, "by_priority": {"P0": p0, "P1": p1, "P2": p2}, "layout": ldata, "touch": tdata}, "  "))
	else:
		print("[ui_audit] platform=%s passed=%s P0=%d P1=%d P2=%d" % [platform, str(passed), p0, p1, p2])
		for src: Array in [["layout", ldata.get("issues", [])], ["touch", tdata.get("issues", [])]]:
			for iss: Dictionary in src[1]:
				var st: String = (" [%s]" % str(iss["state"])) if iss.has("state") else ""
				print("  [%s]%s (%s) %s -> %s: %s" % [str(iss.get("priority", "?")), st, str(src[0]), str(iss.get("rule_id", "")), str(iss.get("node_path", "")), str(iss.get("message", ""))])
	quit(0 if passed else 1)
