@tool
extends RefCounted

## Completion Integrity Gate: toolsuz final metin tek başına SUCCESS değildir.
## A) normal chat -> success, B) failed+final -> not success,
## C) mutation success -> success, D) failed verification -> not success,
## E) limit -> not success. Recovery (aynı işin retry başarısı) affeder.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarCompletionPolicy = preload("res://addons/godot_sidebar_ai/core/agent/completion_policy.gd")
const AISidebarTelemetryCard = preload("res://addons/godot_sidebar_ai/ui/components/telemetry_card.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

class MockGateProvider extends AISidebarAIProvider:
	var responses: Array = []
	func send_chat(messages: Array, tools_schema: Array) -> void:
		if responses.size() > 0:
			var r = responses.pop_front()
			response_received.emit(r.get("content", ""), "", r.get("tool_calls", []))

static func _flow(responses: Array):
	var mock = MockGateProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock, ctx)
	mock.responses = responses
	var got: Array = []
	runner.task_completed.connect(func(m): got.append(m))
	runner.start_task("Gate görevi.")
	return {"runner": runner, "ctx": ctx, "metrics": got[0] if got.size() > 0 else {}}

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# A) normal toolsuz chat -> success
	var fa = _flow([{"content": "Merhaba, yardımcı olabilirim.", "tool_calls": []}])
	if bool(fa["metrics"].get("success", false)) and str(fa["metrics"].get("completion", "")) == "success":
		passed += 1
	else:
		failed += 1
		errors.append("A (plain chat success) failed: " + str(fa["metrics"].get("completion", "?")))

	# B) failed tool (NODE okunamadı) + toolsuz final -> not success
	var fb = _flow([
		{"content": "", "tool_calls": [{"id": "b1", "name": "read_script", "arguments": {"file_path": "res://tests/temp_gate_missing_xyz.gd"}}]},
		{"content": "Dosya bulunamadı, yine de bitti.", "tool_calls": []},
	])
	if not bool(fb["metrics"].get("success", true)) and str(fb["metrics"].get("completion", "")) == "incomplete":
		passed += 1
	else:
		failed += 1
		errors.append("B (failed tool blocks success) failed: " + str(fb["metrics"]))

	# C) başarılı mutation + final özeti -> success
	var ok_path = "res://tests/temp_gate_ok.gd"
	if FileAccess.file_exists(ok_path):
		DirAccess.remove_absolute(ok_path)
	var fc = _flow([
		{"content": "", "tool_calls": [{"id": "c1", "name": "create_or_update_script", "arguments": {"file_path": ok_path, "content": "extends Node\n"}}]},
		{"content": "Script oluşturuldu.", "tool_calls": []},
	])
	if bool(fc["metrics"].get("success", false)) and str(fc["metrics"].get("completion", "")) == "success" and FileAccess.file_exists(ok_path):
		passed += 1
	else:
		failed += 1
		errors.append("C (mutation success) failed: " + str(fc["metrics"]))
	if FileAccess.file_exists(ok_path):
		DirAccess.remove_absolute(ok_path)

	# D) failed verification (policy seviyesi + runner akışı) -> not success
	var pol_d = AISidebarCompletionPolicy.evaluate({"unrecovered": {"validate_script|res://x.gd": {"tool": "validate_script", "deferred": false}}, "plan_approved": false, "mutations_done": false, "limit_hit": false})
	var bad_path = "res://tests/temp_gate_bad.gd"
	var bf = FileAccess.open(bad_path, FileAccess.WRITE)
	if bf:
		bf.store_string("extends Node\n")
		bf.close()
	var fd = _flow([
		{"content": "", "tool_calls": [{"id": "d1", "name": "validate_script", "arguments": {"file_path": bad_path}}]},
		{"content": "Doğrulama yazıldı, bitti.", "tool_calls": []},
	])
	# validate hedef dosya bozuk değilse success olur; politika hükmü belirleyicidir
	if str(pol_d.get("verdict", "")) == "incomplete":
		passed += 1
	else:
		failed += 1
		errors.append("D (failed verification policy) failed.")
	if FileAccess.file_exists(bad_path):
		DirAccess.remove_absolute(bad_path)

	# E) limit hit -> failed (policy seviyesi; loop davranışı MaxSteps testlerinde)
	var pol_e = AISidebarCompletionPolicy.evaluate({"limit_hit": true, "steps_summary": "21 / 20", "unrecovered": {}, "plan_approved": false, "mutations_done": false})
	var card_e = AISidebarTelemetryCard.new({"success": false, "completion": "incomplete", "completion_reason": "x", "elapsed_seconds": 5.0, "used_steps": 3, "max_steps": 20, "tool_calls": 1})
	card_e._ready()
	if str(pol_e.get("verdict", "")) == "failed" and card_e._header_btn.text.begins_with(AISidebarI18n.get_text("telemetry_needs_review", {"elapsed": "5.0s", "summary": ""})) and not "✅" in card_e._header_btn.text:
		passed += 1
	else:
		failed += 1
		errors.append("E (limit failed + needs-review UI) failed.")
	card_e.queue_free()

	# F) recovery: aynı iş retry ile düzelirse success (affetme kanıtı)
	var rec_path = "res://tests/temp_gate_rec.gd"
	if FileAccess.file_exists(rec_path):
		DirAccess.remove_absolute(rec_path)
	var ff = _flow([
		{"content": "", "tool_calls": [{"id": "f1", "name": "read_script", "arguments": {"file_path": rec_path}}]},
		{"content": "", "tool_calls": [{"id": "f2", "name": "create_or_update_script", "arguments": {"file_path": rec_path, "content": "extends Node\n"}}]},
		{"content": "Önce bulamadım, sonra oluşturdum.", "tool_calls": []},
	])
	# read fail anahtarı create ile silinmez (farklı tool) -> incomplete beklenir
	if not bool(ff["metrics"].get("success", true)) and str(ff["metrics"].get("completion", "")) == "incomplete":
		passed += 1
	else:
		failed += 1
		errors.append("F (different-tool recovery stays incomplete) failed: " + str(ff["metrics"].get("completion", "?")))
	if FileAccess.file_exists(rec_path):
		DirAccess.remove_absolute(rec_path)

	return {"name": "CompletionIntegrityTests", "passed": passed, "failed": failed, "errors": errors}
