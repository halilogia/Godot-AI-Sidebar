@tool
extends RefCounted

## audit_runtime_ui: WCAG kontrast hesabı, araç şeması ve yönlendirme (oyun tarafı düğüm taraması editör smoke I11'de).

const AISidebarRuntimeUiAudit = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_ui_audit.gd")
const AISidebarRuntimeInputTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/runtime_input_tools.gd")

static func run() -> Dictionary:
	var checks: Array = []
	var white_on_black := AISidebarRuntimeUiAudit.contrast(Color.WHITE, 0.0)
	var same := AISidebarRuntimeUiAudit.contrast(Color(0.5, 0.5, 0.5), AISidebarRuntimeUiAudit._luminance(Color(0.5, 0.5, 0.5)))
	var gray_on_tan := AISidebarRuntimeUiAudit.contrast(Color(0.6, 0.6, 0.6), AISidebarRuntimeUiAudit._luminance(Color(0.45, 0.38, 0.3)))
	checks.append(["U1 contrast: white on black 21:1, identical 1:1, gray on tan is below 3:1", absf(white_on_black - 21.0) < 0.01 and absf(same - 1.0) < 0.01 and gray_on_tan < AISidebarRuntimeUiAudit.MIN_CONTRAST])
	checks.append(["U2 unknown background is not judged", AISidebarRuntimeUiAudit.contrast(Color.WHITE, -1.0) < 0.0])
	var found := false
	for s: Dictionary in AISidebarRuntimeInputTools.get_schemas():
		if str((s.get("function", {}) as Dictionary).get("name", "")) == AISidebarRuntimeInputTools.UI_AUDIT_TOOL:
			found = true
	checks.append(["U3 audit_runtime_ui schema is registered", found])
	var wrapped := AISidebarRuntimeInputTools.name_list({"item": ["move_right", "jump"]})
	var listed := AISidebarRuntimeInputTools.name_list("move_right, jump")
	checks.append(["U4 send_input actions accepts {item:[..]} and comma text", wrapped == ["move_right", "jump"] and listed == ["move_right", "jump"] and AISidebarRuntimeInputTools.name_list(5).is_empty()])
	var passed := 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "UiAuditTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
