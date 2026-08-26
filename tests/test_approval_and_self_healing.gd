@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarApprovalCard = preload("res://addons/godot_sidebar_ai/ui/components/approval_card.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")

class MockHealingProvider extends AISidebarAIProvider:
	var queue: Array = []
	var history: Array = []
	
	func send_chat(messages: Array, _tools_schema: Array) -> void:
		history.append(messages.duplicate(true))
		if queue.size() > 0:
			var r = queue.pop_front()
			if r.has("error"):
				error_occurred.emit(r["error"])
			else:
				response_received.emit(
					r.get("content", ""),
					r.get("thinking", ""),
					r.get("tool_calls", [])
				)

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Approval Card Tek Yüzey ve Durum Geçişleri (approval_single_surface & state transition)
	var dummy_cs = AISidebarChangeSet.new("res://temp.gd", AISidebarChangeSet.ChangeType.MODIFY_FILE, "var x = 1", "", "Test")
	var card = AISidebarApprovalCard.new("create_or_update_script", {"file_path": "res://temp.gd"}, dummy_cs)
	card._ready()
	
	if not card.is_resolved:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (Initial approval card state) failed.")
		
	card.mark_approved()
	if card.is_resolved:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1b (mark_approved transition) failed.")
		
	# Test 2: Approval Tekrar Çağrısı Güvenliği (Double approve prevention)
	var approve_emitted = 0
	card.action_approved.connect(func(): approve_emitted += 1)
	card._on_approve() # Should do nothing because already resolved
	if approve_emitted == 0:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (Double approve prevention) failed.")
	card.queue_free()
	
	# Test 3: Boş Yanıt Kontrollü Yeniden Deneme (empty_response_retry - 1 retry -> Success)
	var prov = MockHealingProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(prov, ctx)
	runner.max_empty_response_retries = 1
	
	prov.queue = [
		{"content": "", "thinking": "", "tool_calls": []}, # 1. Boş yanıt (retry tetiklemeli)
		{"content": "Başarılı tamamlandı.", "thinking": "", "tool_calls": []} # 2. Başarılı yanıt
	]
	
	runner.start_task("Test empty retry")
	if runner.current_state == AISidebarAgentRunner.AgentState.IDLE and prov.history.size() == 2:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (empty_response_retry attempt 1 -> success) failed: history_size=" + str(prov.history.size()) + " state=" + str(runner.current_state))
		
	# Test 4: Çift Boş Yanıt Durumunda Açık Hata Üretimi (Double empty -> Error)
	var prov2 = MockHealingProvider.new()
	var ctx2 = AISidebarAgentContext.new()
	var runner2 = AISidebarAgentRunner.new(prov2, ctx2)
	runner2.max_empty_response_retries = 1
	
	prov2.queue = [
		{"content": "", "thinking": "", "tool_calls": []}, # 1. Boş yanıt (retry)
		{"content": "", "thinking": "", "tool_calls": []}  # 2. Boş yanıt (hata vermeli)
	]
	
	var err_received = [false]
	runner2.error_occurred.connect(func(_e): err_received[0] = true)
	runner2.start_task("Test double empty")
	
	if err_received[0] and prov2.history.size() == 2:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (Double empty response error handling) failed: err_received=" + str(err_received[0]) + " history=" + str(prov2.history.size()))
		
	# Test 5: Self-Healing Zinciri (self_healing_state_transition)
	# Hata Tanısı -> Fix Önerisi -> Approval -> Doğrulama -> Tamamlanma
	var prov3 = MockHealingProvider.new()
	var ctx3 = AISidebarAgentContext.new()
	var runner3 = AISidebarAgentRunner.new(prov3, ctx3)
	
	var healing_file = "res://tests/temp_healing_test.gd"
	var f = FileAccess.open(healing_file, FileAccess.WRITE)
	f.store_string("extends Node\nfunc _ready():\n\tpass\n")
	f.close()
	
	prov3.queue = [
		# 1. Turn: Model hata teşhisini okur ve fix scripti önerir
		{
			"content": "Hatayı düzeltmek için scripti güncelliyorum.",
			"tool_calls": [
				{
					"name": "create_or_update_script",
					"id": "call_fix_001",
					"arguments": {
						"file_path": healing_file,
						"content": "extends Node\nfunc _ready():\n\tvar valid_obj = Node.new()\n\tadd_child(valid_obj)\n"
					}
				}
			]
		},
		# 2. Turn: Approval sonrası model sonucu açıklar
		{
			"content": "Hata giderildi ve script başarıyla güncellendi.",
			"tool_calls": []
		}
	]
	
	runner3.start_task("Fix runtime error")
	
	# Runner approval bekliyor olmalı
	if runner3.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5a (Self-healing approval pause) failed: state=" + str(runner3.current_state))
		
	# Kullanıcı Approve eder
	runner3.approve_pending_action()
	
	if runner3.current_state == AISidebarAgentRunner.AgentState.IDLE and prov3.history.size() == 2:
		var updated_f = FileAccess.open(healing_file, FileAccess.READ)
		var txt = updated_f.get_as_text() if updated_f else ""
		if updated_f: updated_f.close()
		if "valid_obj" in txt:
			passed += 1
		else:
			failed += 1
			errors.append("Test 5b (Script content not updated after approval): " + txt)
	else:
		failed += 1
		errors.append("Test 5b (Self-healing completion after approval) failed.")
		
	# Temizlik
	if FileAccess.file_exists(healing_file):
		DirAccess.remove_absolute(healing_file)
		
	return {"name": "ApprovalAndSelfHealingTests", "passed": passed, "failed": failed, "errors": errors}
