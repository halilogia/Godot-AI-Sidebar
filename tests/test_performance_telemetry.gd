@tool
extends RefCounted

## Performance Telemetry için DETERMINISTIK testler.
## read/search/write ayrımı, dosya kümeleri, fail/retry/limit sayaçları,
## per-tool süreler ve research overhead formülü.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarTelemetryCard = preload("res://addons/godot_sidebar_ai/ui/components/telemetry_card.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")

static func _runner():
	return AISidebarAgentRunner.new()

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Tool türü sınıflandırması
	var mapping_ok = (
		AISidebarAgentRunner.classify_tool_kind("read_script") == "read"
		and AISidebarAgentRunner.classify_tool_kind("analyze_project") == "read"
		and AISidebarAgentRunner.classify_tool_kind("search_tools") == "search"
		and AISidebarAgentRunner.classify_tool_kind("create_or_update_script") == "write"
		and AISidebarAgentRunner.classify_tool_kind("write_files") == "write"
		and AISidebarAgentRunner.classify_tool_kind("validate_script") == "verify"
		and AISidebarAgentRunner.classify_tool_kind("play_game") == "runtime"
		and AISidebarAgentRunner.classify_tool_kind("delete_node") == "editor"
		and AISidebarAgentRunner.classify_tool_kind("ask_user") == "other"
		and AISidebarAgentRunner.classify_tool_kind("propose_plan") == "other"
	)
	if mapping_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (classify_tool_kind) failed.")

	# 2. read/search/write sayaçları + research süresi
	var r2 = _runner()
	r2._record_tool_telemetry("read_script", {"file_path": "res://a.gd"}, 120, {"success": true})
	r2._record_tool_telemetry("search_tools", {}, 80, {"success": true})
	r2._record_tool_telemetry("create_or_update_script", {"file_path": "res://b.gd"}, 200, {"success": true})
	if r2.read_ops_count == 1 and r2.search_ops_count == 1 and r2.write_ops_count == 1 and r2.research_time_msec == 200 and r2.tool_time_by_name.get("read_script", 0) == 120:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (op counters) failed: r=%d s=%d w=%d research=%d" % [r2.read_ops_count, r2.search_ops_count, r2.write_ops_count, r2.research_time_msec])

	# 3. Okunan dosya kümesi distinct sayılır
	var r3 = _runner()
	r3._record_tool_telemetry("read_script", {"file_path": "res://a.gd"}, 10, {"success": true})
	r3._record_tool_telemetry("read_script", {"file_path": "res://a.gd"}, 10, {"success": true})
	r3._record_tool_telemetry("read_script", {"file_path": "res://b.gd"}, 10, {"success": true})
	r3._record_tool_telemetry("write_files", {"files": [{"file_path": "res://c.gd"}, {"file_path": "res://c.gd"}]}, 10, {"success": true})
	if r3.files_read.size() == 2 and r3.files_written.size() == 1 and r3.files_written.has("res://c.gd"):
		passed += 1
	else:
		failed += 1
		errors.append("T3 (distinct files) failed: read=%s written=%s" % [str(r3.files_read.keys()), str(r3.files_written.keys())])

	# 4. Başarısız tool sayımı (outer ok + payload fail dahil)
	var r4 = _runner()
	r4._record_tool_telemetry("read_script", {}, 5, {"success": false, "message": "nope"})
	r4._record_tool_telemetry("validate_script", {}, 5, {"success": true, "message": "Tamamlandı.", "data": {"success": false, "status": 1, "error": {"code": "X", "message": "bad"}}})
	r4._record_tool_telemetry("read_script", {}, 5, {"success": true})
	if r4.failed_tool_count == 2:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (failed count) failed: %d" % r4.failed_tool_count)

	# 5. Retry sayacı metriğe yansıyor
	var r5 = _runner()
	r5._note_retry()
	r5._note_retry()
	var got5: Array = []
	r5.task_completed.connect(func(m): got5.append(m))
	r5._finish_task(true)
	if r5.retry_count == 2 and got5.size() == 1 and int(got5[0].get("retry_count", -1)) == 2:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (retry count) failed.")

	# 6. Research overhead formülü (2.5s / 10s = 0.25)
	var r6 = _runner()
	r6.task_start_time_msec = Time.get_ticks_msec() - 10000
	r6.research_time_msec = 2500
	var got6: Array = []
	r6.task_completed.connect(func(m): got6.append(m))
	r6._finish_task(true)
	if got6.size() == 1 and abs(float(got6[0].get("research_overhead_ratio", -1.0)) - 0.25) < 0.001 and abs(float(got6[0].get("research_time_s", -1.0)) - 2.5) < 0.05:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (overhead ratio) failed: " + str(got6[0].get("research_overhead_ratio", "?") if got6.size() > 0 else "no metrics"))

	# 7. Limit bayrağı + per-tool süreler + dosya listeleri metrikte
	var r7 = _runner()
	r7.limit_hit = true
	r7._record_tool_telemetry("read_script", {"file_path": "res://a.gd"}, 1500, {"success": true})
	r7._record_tool_telemetry("read_script", {"file_path": "res://a.gd"}, 500, {"success": true})
	var got7: Array = []
	r7.task_completed.connect(func(m): got7.append(m))
	r7._finish_task(false)
	var m7 = got7[0] if got7.size() > 0 else {}
	if bool(m7.get("limit_hit", false)) and abs(float((m7.get("tool_time_by_tool_s", {}) as Dictionary).get("read_script", -1.0)) - 2.0) < 0.05 and int(m7.get("files_read_count", -1)) == 1 and "res://a.gd" in (m7.get("files_read", [])):
		passed += 1
	else:
		failed += 1
		errors.append("T7 (limit+per-tool+files metrics) failed.")

	# 8. Sıfır sürede overhead güvenli (bölme hatası yok)
	var r8 = _runner()
	if r8._research_overhead_ratio(0.0) == 0.0 and r8._research_overhead_ratio(-5.0) == 0.0:
		passed += 1
	else:
		failed += 1
		errors.append("T8 (zero-division guard) failed.")

	# 9. TelemetryCard yeni alanları gösteriyor (header formatı aynı)
	var card = AISidebarTelemetryCard.new({"success": true, "elapsed_seconds": 73.0, "used_steps": 17, "max_steps": 20, "tool_calls": 12, "tools_sent": 28, "total_tools": 44, "file_ops": 2, "read_ops": 17, "search_ops": 12, "write_ops": 2, "failed_tools": 1, "retry_count": 2, "limit_hit": true, "files_read_count": 9, "files_written_count": 2, "research_time_s": 30.5, "research_overhead_ratio": 0.42})
	card._ready()
	var header_ok = "Completed in 73.0s" in card._header_btn.text
	var details_txt = card._details_lbl.text
	if header_ok and "Research" in details_txt and "42%" in details_txt and "R:17/S:12/W:2" in details_txt and "LIMIT" in details_txt and "Failed: 1" in details_txt:
		passed += 1
	else:
		failed += 1
		errors.append("T9 (card renders telemetry) failed: '" + card._header_btn.text + "' / '" + details_txt + "'")
	card.queue_free()

	# 10. Eski metrik sözlükleriyle geriye uyumluluk (kart + export çökmüyor)
	var old_metrics = {"success": true, "elapsed_seconds": 2.5, "used_steps": 1, "max_steps": 20, "tool_calls": 0, "file_ops": 0}
	var card10 = AISidebarTelemetryCard.new(old_metrics)
	card10._ready()
	var md10 = AISidebarChatExporter.export_transcript_to_markdown([], [], old_metrics)
	if "Completed in 2.5s" in card10._header_btn.text and "n/a" in card10._details_lbl.text and md10.length() > 0:
		passed += 1
	else:
		failed += 1
		errors.append("T10 (backwards compat) failed.")
	card10.queue_free()

	return {"name": "PerformanceTelemetryTests", "passed": passed, "failed": failed, "errors": errors}
