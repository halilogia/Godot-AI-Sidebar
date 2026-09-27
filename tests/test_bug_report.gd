@tool
extends RefCounted

## Hata raporu paketi gizli bilgi sızdırmaz: ayarlardan yalnız izin listesi girer, anahtar / token değeri
## hiçbir dosyada yoktur, adresten kullanıcı bilgisi atılır; paket beklenen dosyalarla yazılır.

const AISidebarBugReport = preload("res://addons/godot_sidebar_ai/core/diagnostics/bug_report.gd")

const OUT := "user://test_bug_report"
const SECRET := "fake-secret-DO-NOT-LEAK-123456"

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	# T1 Güvenli ayar özeti: gizli değerler yok, yalnız dolu / boş; bilinmeyen alan girmez.
	var cfg := {"api_key": SECRET, "mcp_bridge_token": SECRET, "base_url": "https://user:" + SECRET + "@api.example.com/v1?key=" + SECRET,
		"provider_type": "openai_compatible", "unknown_future_secret": SECRET, "system_prompt": "özel"}
	var safe := AISidebarBugReport.safe_settings(cfg)
	var dumped := JSON.stringify(safe)
	if not SECRET in dumped and safe.get("api_key") == "set" and safe.get("base_url_host") == "https://api.example.com" and not safe.has("unknown_future_secret") and safe.get("system_prompt") == "custom":
		passed += 1
	else:
		failed += 1
		errors.append("T1 safe_settings leaked or wrong: " + dumped)

	# T2 Paket yazılır; açıklamadaki gizli desen maskelenir; beklenen dosyalar içeride.
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var res := AISidebarBugReport.build("panel dondu api_key=" + SECRET, AISidebarBugReport.environment({"editor_scale": 1.0}), {"status": "failed", "stop_code": "step_limit"},
		{"chat_md": "# chat", "screenshot": img, "include_log": false}, OUT)
	var names: Array = []
	var leaked := false
	var reader := ZIPReader.new()
	if res.get("ok", false) == true and reader.open(str(res["path"])) == OK:
		for f: String in reader.get_files():
			names.append(f)
			if SECRET in reader.read_file(f).get_string_from_utf8():
				leaked = true
		reader.close()
	var want := ["report.md", "environment.json", "settings.json", "chat.md", "sidebar.png"]
	var has_all := want.all(func(n: String) -> bool: return names.has(n))
	if has_all and not leaked and "step_limit" in str(res.get("markdown", "")):
		passed += 1
	else:
		failed += 1
		errors.append("T2 package: ok=%s files=%s leaked=%s" % [str(res.get("ok")), str(names), str(leaked)])

	if res.has("path"):
		DirAccess.remove_absolute(str(res["path"]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT))
	return {"name": "BugReportTests", "passed": passed, "failed": failed, "errors": errors}
