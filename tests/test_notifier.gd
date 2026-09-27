@tool
extends RefCounted

## Bildirim: editör odaktayken ya da ayar kapalıyken uyarmaz; arka plandayken uyarır.

const AISidebarNotifier = preload("res://addons/godot_sidebar_ai/ui/controllers/notifier.gd")

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []
	var n := AISidebarNotifier.new()
	n.is_focused = func() -> bool: return true
	var focused_quiet := not n.notify("done")
	n.is_focused = func() -> bool: return false
	var background := n.notify("question") if AISidebarNotifier.is_enabled() else true
	if focused_quiet and background and (n.last.get("kind", "") == "question" or not AISidebarNotifier.is_enabled()):
		passed += 1
	else:
		failed += 1
		errors.append("T1 notifier: focused_quiet=%s background=%s last=%s" % [focused_quiet, background, n.last])
	var tone := AISidebarNotifier.make_tone()
	if tone.data.size() > 1000 and tone.mix_rate == AISidebarNotifier.MIX_RATE:
		passed += 1
	else:
		failed += 1
		errors.append("T2 tone")
	n.free()
	return {"name": "NotifierTests", "passed": passed, "failed": failed, "errors": errors}
