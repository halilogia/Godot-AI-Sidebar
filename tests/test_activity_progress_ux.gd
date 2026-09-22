@tool
extends RefCounted

## Activity / Task Progress UX için DETERMINISTIK testler.
## Kapsar: running->success/fail ikon uyumu, error özeti, 20/20 stop nedeni,
## count doğruluğu, technical details default kapalı, redaction,
## completion collapse, raw JSON sızıntısı yok, prose korunur, ask_user kartı sağlam.

const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarClarificationCard = preload("res://addons/godot_sidebar_ai/ui/components/clarification_card.gd")
const AISidebarChatDock = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. running activity -> play/running ikonu
	var grp = AISidebarActivityGroup.new(true)
	grp._ready()
	var idx = grp.add_activity("▶", "Running Validated GDScript source", -1, "tool: validate_script\nargs: {}")
	if grp.get_item(idx).get("icon", "") == "▶":
		passed += 1
	else:
		failed += 1
		errors.append("T1 (running icon ▶) failed: " + str(grp.get_item(idx)))

	# 2. successful tool -> success/check (running satırı yerinde güncellenir, satır çoğalmaz)
	var count_before = grp.get_item_count()
	grp.update_activity(idx, "✓", "Validated GDScript source", 100, "tool: validate_script\nresult: {\"success\": true}")
	if grp.get_item_count() == count_before and grp.get_item(idx).get("icon", "") == "✓":
		passed += 1
	else:
		failed += 1
		errors.append("T2 (success update in place) failed.")

	# 3. failed tool -> red X + error summary
	var fidx = grp.add_activity("▶", "Running Updated script", -1, "tool: create_or_update_script")
	grp.update_activity(fidx, "✕", "Updated script", 120, "tool: create_or_update_script\nresult: {\"success\": false}", "Parse error at line 12: unexpected indent")
	var fitem = grp.get_item(fidx)
	if fitem.get("icon", "") == "✕" and "Error:" in str(fitem.get("title", "")) and "Parse error" in str(fitem.get("title", "")):
		passed += 1
	else:
		failed += 1
		errors.append("T3 (failed X + error summary) failed: " + str(fitem.get("title", "")))

	# 4. 20/20 limit -> görünür stop reason
	grp.set_stop_reason("Tool-call limit reached: 20/20")
	grp.complete_group_keep_open(true)
	if "20/20" in grp.get_header_text() and grp.is_expanded and not grp.is_active:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (limit stop reason visible) failed: '" + grp.get_header_text() + "'")

	# 5. Activity count doğru
	if grp.get_item_count() == 2 and "2 steps" in grp.get_header_text():
		passed += 1
	else:
		failed += 1
		errors.append("T5 (count 2 steps) failed: '" + grp.get_header_text() + "'")

	# 6. Technical details default closed
	if not grp.is_details_expanded(idx) and not grp.is_details_expanded(fidx):
		passed += 1
	else:
		failed += 1
		errors.append("T6 (details default closed) failed.")

	# 7. Technical details açılınca request/result görülebiliyor
	grp._on_details_toggled(fidx)
	var det_visible = grp._item_rows[fidx].get("details_lbl").visible if grp._item_rows.size() > fidx else false
	if grp.is_details_expanded(fidx) and det_visible:
		passed += 1
	else:
		failed += 1
		errors.append("T7 (details expandable) failed.")
	grp._on_details_toggled(fidx)

	# 8. secret/token redaction
	var leaked = AISidebarActivityGroup.redact_secrets('"api_key": "sk-live-1234567890" Bearer abcdef123456 "token": "tok_secret_xyz"')
	if not "sk-live-1234567890" in leaked and not "tok_secret_xyz" in leaked and "[REDACTED]" in leaked:
		passed += 1
	else:
		failed += 1
		errors.append("T8 (redaction) failed: '" + leaked + "'")

	# 9. task completion -> ActivityGroup collapsed (varsayılan)
	var grp2 = AISidebarActivityGroup.new(true)
	grp2._ready()
	grp2.add_activity("✓", "Inspected HexCell.gd", 50, "")
	grp2.complete_group()
	if not grp2.is_active and not grp2.is_expanded:
		passed += 1
	else:
		failed += 1
		errors.append("T9 (completion collapsed) failed.")
	grp2.queue_free()

	# 10. raw tool JSON normal chat bubble'da görünmüyor
	var envelope = '{"tool_calls": [{"name": "read_script", "arguments": {"file_path": "res://HexCell.gd"}}]}'
	if AISidebarMessageBubble.strip_tool_call_envelopes(envelope, true).strip_edges().is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T10 (raw JSON stripped) failed.")

	# 11. normal assistant text görünmeye devam ediyor
	var prose = "Hex grid yapısını inceledim, 3D için hazır."
	if AISidebarMessageBubble.strip_tool_call_envelopes(prose, true) == prose:
		passed += 1
	else:
		failed += 1
		errors.append("T11 (prose preserved) failed.")

	# 12. ask_user -> ClarificationCard bozulmuyor + dock helper'ları (limit/human-title)
	var card = AISidebarClarificationCard.new("2D mi 3D mi?", ["2D", "3D"])
	card._ready()
	var dock = AISidebarChatDock.new()
	var t_ok = dock._get_human_tool_title("read_script", {"file_path": "res://HexCell.gd"}) == "Read script: HexCell.gd"
	var l_ok = dock.is_task_limit_error("Maksimum ajan adım limitine (20) ulaşıldı.")
	var f_ok = dock.format_limit_stop_reason(20, 20) == "Tool-call limit reached: 20/20"
	var tech = dock._build_tech_details("read_script", {"api_key": "sk-999"}, {"success": true})
	var r_ok = not "sk-999" in tech and "[REDACTED]" in tech
	if card.question_text == "2D mi 3D mi?" and t_ok and l_ok and f_ok and r_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T12 (clarification + dock helpers) failed: t=%s l=%s f=%s r=%s" % [str(t_ok), str(l_ok), str(f_ok), str(r_ok)])
	card.queue_free()
	dock.queue_free()

	grp.queue_free()
	return {"name": "ActivityProgressUX", "passed": passed, "failed": failed, "errors": errors}
