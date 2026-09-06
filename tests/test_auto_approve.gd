@tool
extends RefCounted

## Auto Approve Sistemi Kapsamlı Test Paketi (SRP)
## MANUAL, AUTO ve FULL_AUTO modlarını, risk sınıflandırmasını,
## Verification-First doğrulama kalkanını ve PathPolicy güvenliğini test eder.

const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

class MockAutoApproveProvider extends AISidebarAIProvider:
	var queue: Array = []
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		if queue.size() > 0:
			var r = queue.pop_front()
			response_received.emit(r.get("content", ""), r.get("thinking", ""), r.get("tool_calls", []))

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var initial_mode = AISidebarPermissionPolicy.get_auto_approve_mode()
	var test_script_path = "res://tests/temp_auto_approve_test.gd"
	var broken_script_path = "res://tests/temp_broken_auto_test.gd"
	
	# Temizlik başlangıcı
	if FileAccess.file_exists(test_script_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_script_path))
	if FileAccess.file_exists(broken_script_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(broken_script_path))
		
	# Test 0: Merkezi Risk Sınıflandırma Kayıt Defteri (Registry) Doğrulaması
	var ro_risk = AISidebarPermissionPolicy.get_tool_risk("read_script")
	var wr_risk = AISidebarPermissionPolicy.get_tool_risk("create_or_update_script")
	var ds_risk = AISidebarPermissionPolicy.get_tool_risk("delete_file")
	var es_risk = AISidebarPermissionPolicy.get_tool_risk("eval_gdscript")
	
	if ro_risk == AISidebarPermissionPolicy.RiskLevel.READ_ONLY \
		and wr_risk == AISidebarPermissionPolicy.RiskLevel.WRITE \
		and ds_risk == AISidebarPermissionPolicy.RiskLevel.DESTRUCTIVE \
		and es_risk == AISidebarPermissionPolicy.RiskLevel.EXTERNAL_SENSITIVE:
		passed += 1
	else:
		failed += 1
		errors.append("Test 0: Tool risk registry varsayılan seviyeleri hatalı.")
		
	# Test 0b: Registry dinamik genişletilebilirlik
	AISidebarPermissionPolicy.register_tool_risk("custom_test_tool", AISidebarPermissionPolicy.RiskLevel.DESTRUCTIVE)
	if AISidebarPermissionPolicy.get_tool_risk("custom_test_tool") == AISidebarPermissionPolicy.RiskLevel.DESTRUCTIVE:
		passed += 1
	else:
		failed += 1
		errors.append("Test 0b: register_tool_risk dinamik aracı kaydedemedi.")

	# Başlangıç dosyası oluştur
	var f = FileAccess.open(test_script_path, FileAccess.WRITE)
	if f:
		f.store_string("extends Node\nvar original_val = 1\n")
		f.close()
		
	# --- SENARYO 1: MANUAL + normal write (overwrite) → approval ---
	AISidebarPermissionPolicy.set_auto_approve_mode(AISidebarPermissionPolicy.AutoApproveMode.MANUAL)
	var man_write_res = AISidebarToolManager.execute_tool("create_or_update_script", {
		"file_path": test_script_path,
		"content": "extends Node\nvar modified_val = 2\n"
	}, false)
	
	if not man_write_res.get("success", false) and man_write_res.get("error", {}).get("code", "") == "APPROVAL_REQUIRED":
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo 1 (MANUAL + write overwrite) onay istemedi: " + str(man_write_res))

	# --- SENARYO 2: AUTO + read-only → otomatik ---
	AISidebarPermissionPolicy.set_auto_approve_mode(AISidebarPermissionPolicy.AutoApproveMode.AUTO)
	var auto_ro_res = AISidebarToolManager.execute_tool("read_script", {
		"file_path": test_script_path
	}, false)
	
	if auto_ro_res.get("success", false) and not auto_ro_res.get("data", {}).get("content", "").is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo 2 (AUTO + read-only) otomatik çalışmadı: " + str(auto_ro_res))

	# --- SENARYO 3: AUTO + normal write + valid verification → otomatik ---
	var auto_write_res = AISidebarToolManager.execute_tool("create_or_update_script", {
		"file_path": test_script_path,
		"content": "extends Node\nvar auto_val = 100\n"
	}, false)
	
	if auto_write_res.get("success", false) and FileAccess.file_exists(test_script_path):
		var check_f = FileAccess.open(test_script_path, FileAccess.READ)
		var txt = check_f.get_as_text() if check_f else ""
		if check_f: check_f.close()
		if "auto_val" in txt:
			passed += 1
		else:
			failed += 1
			errors.append("Senaryo 3: Dosya içeriği güncellenmedi.")
	else:
		failed += 1
		errors.append("Senaryo 3 (AUTO + valid write) otomatik onaylanmadı: " + str(auto_write_res))

	# --- SENARYO 4: AUTO + normal write + verification FAIL → yazma yok ---
	var auto_fail_res = AISidebarToolManager.execute_tool("create_or_update_script", {
		"file_path": broken_script_path,
		"content": "extends Node\nfunc broken_func() var syntax_error_here\n"
	}, false)
	
	var broken_exists = FileAccess.file_exists(broken_script_path)
	if not auto_fail_res.get("success", false) and not broken_exists and auto_fail_res.get("error", {}).get("code", "") != "APPROVAL_REQUIRED":
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo 4 (AUTO + verification FAIL) engellenmedi veya dosya yazıldı: " + str(auto_fail_res) + " exists: " + str(broken_exists))

	# --- SENARYO 5: AUTO + delete → approval ---
	var auto_del_res = AISidebarToolManager.execute_tool("delete_file", {
		"file_path": test_script_path
	}, false)
	
	var still_exists = FileAccess.file_exists(test_script_path)
	if not auto_del_res.get("success", false) and auto_del_res.get("error", {}).get("code", "") == "APPROVAL_REQUIRED" and still_exists:
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo 5 (AUTO + delete) onay istemedi veya silindi: " + str(auto_del_res))

	# --- SENARYO 6: FULL_AUTO + write → otomatik ---
	AISidebarPermissionPolicy.set_auto_approve_mode(AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO)
	var full_write_res = AISidebarToolManager.execute_tool("create_or_update_script", {
		"file_path": test_script_path,
		"content": "extends Node\nvar full_auto_val = 999\n"
	}, false)
	
	if full_write_res.get("success", false):
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo 6 (FULL_AUTO + write) otomatik çalışmadı: " + str(full_write_res))

	# --- SENARYO 7: FULL_AUTO + delete → otomatik ---
	var full_del_res = AISidebarToolManager.execute_tool("delete_file", {
		"file_path": test_script_path
	}, false)
	
	var is_deleted = not FileAccess.file_exists(test_script_path)
	if full_del_res.get("success", false) and is_deleted:
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo 7 (FULL_AUTO + delete) silmedi veya başarısız oldu: " + str(full_del_res))

	# --- SENARYO 8: FULL_AUTO + PathPolicy güvenlik kalkanı → engellenmeli ---
	var full_hack_res = AISidebarToolManager.execute_tool("create_or_update_script", {
		"file_path": "res://project.godot",
		"content": "[application]\nname=\"Hacked\"\n"
	}, false)
	
	if not full_hack_res.get("success", false) and full_hack_res.get("error", {}).get("code", "") == "PERMISSION_DENIED":
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo 8 (FULL_AUTO + PathPolicy ihlali) engellenmedi: " + str(full_hack_res))

	# --- SENARYO 9: AgentRunner Entegrasyonu & Onay / Reddetme Akışı Bozulmadı ---
	AISidebarPermissionPolicy.set_auto_approve_mode(AISidebarPermissionPolicy.AutoApproveMode.MANUAL)
	
	# Yeniden temp dosya oluştur
	var f2 = FileAccess.open(test_script_path, FileAccess.WRITE)
	if f2:
		f2.store_string("extends Node\nvar x = 1\n")
		f2.close()
		
	var mock_p = MockAutoApproveProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock_p, ctx)
	
	var approval_signal_received = [false]
	runner.approval_requested.connect(func(_tool_name, _args, _cs):
		approval_signal_received[0] = true
	)
	
	# Model: mevcut dosyayı değiştirmek istiyor (MANUAL modda onay gerekir)
	mock_p.queue.append({
		"content": "Dosyayı güncelliyorum.",
		"thinking": "",
		"tool_calls": [{
			"id": "call_manual_1",
			"name": "create_or_update_script",
			"arguments": {"file_path": test_script_path, "content": "extends Node\nvar x = 2\n"}
		}]
	})
	
	runner.start_task("Kodu güncelle")
	
	if runner.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL and approval_signal_received[0]:
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo 9a: AgentRunner WAITING_FOR_APPROVAL durumuna geçmedi.")
		
	# Onay verildiğinde başarıyla devam etmeli
	mock_p.queue.append({
		"content": "Görev tamamlandı.",
		"thinking": "",
		"tool_calls": []
	})
	runner.approve_pending_action()
	
	if runner.current_state == AISidebarAgentRunner.AgentState.IDLE or runner.current_state == AISidebarAgentRunner.AgentState.COMPLETED:
		passed += 1
	else:
		failed += 1
		errors.append("Senaryo 9b: approve_pending_action sonrası tamamlanmadı, durum: " + str(runner.current_state))

	# Temizlik bitişi
	if FileAccess.file_exists(test_script_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_script_path))
	if FileAccess.file_exists(broken_script_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(broken_script_path))
		
	# Modu eski haline döndür
	AISidebarPermissionPolicy.set_auto_approve_mode(initial_mode)
	
	return {
		"name": "AutoApproveTests",
		"passed": passed,
		"failed": failed,
		"errors": errors
	}
