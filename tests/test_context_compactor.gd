@tool
extends RefCounted

## Girdiler gerçek araç çıktısı biçimindedir (AISidebarToolResult: {success, data, error}); eski testler
## uydurma {status, result} biçimi kullandığı için sıkıştırıcı bozukken yeşil kalmıştı.

const AISidebarContextCompactor = preload("res://addons/godot_sidebar_ai/core/agent/context_compactor.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

static func _summary(tool_name: String, result: Dictionary) -> Dictionary:
	var out: Variant = JSON.parse_string(AISidebarContextCompactor.compact_tool_content(tool_name, JSON.stringify(result)))
	return out if out is Dictionary else {}

static func _tool_msg(id: String, tool_name: String, result: Dictionary) -> Dictionary:
	return {"role": "tool", "tool_call_id": id, "name": tool_name, "content": JSON.stringify(result)}

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	var checks: Array = []

	# T1 analyze_project: gerçek sayılar özette.
	var s1 := _summary("analyze_project", AISidebarToolResult.ok({"project_name": "MyGame3D", "main_scene": "res://Main.tscn", "total_files": 120, "scenes_count": 15, "scripts_count": 30}))
	checks.append(["T1 analyze_project", s1.get("is_compacted") == true and "MyGame3D" in str(s1.get("summary")) and "30 script" in str(s1.get("summary"))])

	# T2 dosya listesi tam yolla kalır (klasör bilgisi kaybolmaz).
	var files: Array = []
	for i in range(5):
		files.append("res://scripts/core/file_%d.gd" % i)
	var s2 := _summary("search_project_assets", AISidebarToolResult.ok({"query": "gd", "count": 5, "assets": files}))
	checks.append(["T2 asset list", "res://scripts/core/file_4.gd" in str(s2.get("summary"))])

	# T3 başarısız yazım başarılı görünmez; hata metni korunur.
	var s3 := _summary("write_files", AISidebarToolResult.err("SCRIPT_SYNTAX_ERROR", "Identifier \"GameData\" not declared"))
	checks.append(["T3 failed write", s3.get("success") == false and "GameData" in str(s3.get("summary"))])

	# T4 başarılı yazım yazılan yolları söyler.
	var s4 := _summary("write_files", AISidebarToolResult.ok({"count": 2, "written_files": ["res://a.gd", "res://b.gd"]}))
	checks.append(["T4 write paths", s4.get("success") == true and "res://b.gd" in str(s4.get("summary"))])

	# T5 read_script: yol ve satır sayısı gerçek.
	var s5 := _summary("read_script", AISidebarToolResult.ok({"file_path": "res://player.gd", "content": "extends Node\nvar x = 1\nvar y = 2"}))
	checks.append(["T5 read_script", "res://player.gd" in str(s5.get("summary")) and "3 satır" in str(s5.get("summary"))])

	# T6 compact_messages: eski sonuçlar sıkışır, son N tam kalır; bir dosyanın en son okuması eski
	# olsa da tam kalır, aynı dosyanın önceki okuması sıkışır.
	var read_a := AISidebarToolResult.ok({"file_path": "res://a.gd", "content": "extends Node\n"})
	var analyze := AISidebarToolResult.ok({"project_name": "P", "total_files": 1})
	var msgs: Array = [{"role": "user", "content": "istek"}]
	msgs.append(_tool_msg("c0", "read_script", read_a))
	msgs.append(_tool_msg("c1", "read_script", read_a))
	msgs.append(_tool_msg("c2", "analyze_project", analyze))
	msgs.append(_tool_msg("c3", "analyze_project", analyze))
	msgs.append(_tool_msg("c4", "analyze_project", analyze))
	var out := AISidebarContextCompactor.compact_messages(msgs, 2)
	var first_read_compacted := "is_compacted" in str(out[1]["content"])
	var last_read_full := str(out[2]["content"]) == JSON.stringify(read_a)
	var old_analyze_compacted := "is_compacted" in str(out[3]["content"])
	var recent_full := str(out[5]["content"]) == JSON.stringify(analyze)
	checks.append(["T6 compact_messages", first_read_compacted and last_read_full and old_analyze_compacted and recent_full])

	# T7 AgentContext varsayılanı yeni sonuçları sıkıştırmaz (eskiden son 2 dışındaki her şey gidiyordu).
	var ctx = AISidebarAgentContext.new()
	ctx.add_user_message("Proje analizi")
	for i in range(4):
		ctx.add_assistant_tool_call_message("", [{"id": "c%d" % i, "name": "analyze_project", "arguments": {}}])
		ctx.add_tool_result_message("c%d" % i, "analyze_project", analyze)
	var api_msgs: Array = ctx.get_messages_for_api()
	var any_compacted := false
	for m in api_msgs:
		if "is_compacted" in str((m as Dictionary).get("content", "")):
			any_compacted = true
	checks.append(["T7 default keep", not any_compacted])

	# T8 yedek (mesaj sayısı) sıkıştırması kısa görevde tetiklenmez; tetiklenince yazılan dosyalar özette kalır.
	var ctx2 = AISidebarAgentContext.new()
	ctx2.add_user_message("oyun yap")
	for i in range(30):
		ctx2.add_assistant_tool_call_message("", [{"id": "w%d" % i, "name": "create_or_update_script", "arguments": {}}])
		ctx2.add_tool_result_message("w%d" % i, "create_or_update_script", AISidebarToolResult.ok({"file_path": "res://s%d.gd" % i}))
	var short_kept: bool = ctx2.messages.size() == 61
	for i in range(30, 70):
		ctx2.add_assistant_tool_call_message("", [{"id": "w%d" % i, "name": "create_or_update_script", "arguments": {}}])
		ctx2.add_tool_result_message("w%d" % i, "create_or_update_script", AISidebarToolResult.ok({"file_path": "res://s%d.gd" % i}))
	var head := str((ctx2.messages[0] as Dictionary).get("content", ""))
	checks.append(["T8 fallback compaction", short_kept and head.begins_with("[ÖNCEKİ AJAN") and "res://s0.gd" in head and "oyun yap" in head])

	# T9 ekran görüntüsünün base64'ü modele metin olarak gitmez (her istekte 50-75 KB'tı); kayıt tutar.
	var ctx3 = AISidebarAgentContext.new()
	ctx3.begin_task("shot")
	var big_b64 := "A".repeat(60000)
	ctx3.add_tool_result_message("s1", "take_runtime_screenshot", AISidebarToolResult.ok({"base64": big_b64, "width": 640, "height": 360, "has_vision_data": true, "path": "user://x.png"}))
	var sent := str((ctx3.messages[ctx3.messages.size() - 1] as Dictionary).get("content", ""))
	checks.append(["T9 screenshot base64 not sent as text", sent.length() < 2000 and sent.contains("640x360") and JSON.stringify(ctx3.get_transcript().to_data()).contains("AAAAAAAAAA")])

	# T10 uzun diff'ten modele yalnız değişen satırlar gider (dosyanın başı değil).
	var long_diff := "--- a\n+++ b\n" + "  unchanged line\n".repeat(400) + "- old_call()\n+ new_call()\n"
	ctx3.add_tool_result_message("r1", "replace_file_content", AISidebarToolResult.ok({"diff": long_diff, "file_path": "res://x.gd"}))
	var sent_diff := str((ctx3.messages[ctx3.messages.size() - 1] as Dictionary).get("content", ""))
	checks.append(["T10 long diff: changed lines only", sent_diff.length() < 2500 and sent_diff.contains("new_call") and not sent_diff.contains("unchanged line")])

	for c in checks:
		if c[1]:
			passed += 1
		else:
			failed += 1
			errors.append(str(c[0]) + " failed")
	return {"name": "ContextCompactorTests", "passed": passed, "failed": failed, "errors": errors}
