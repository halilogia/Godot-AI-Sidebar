@tool
extends RefCounted

## Slash Command (/) Sistemi Kapsamlı Test Paketi (SRP).
## 10 Çekirdek komutun kayıt defterini, ayrıştırıcısını (parser),
## otomatik tamamlama / sorgu tespitini ve icra işleyicilerini test eder.

const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")

class MockSlashCommandProvider extends AISidebarAIProvider:
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		response_received.emit("Test yanıtı", "", [])

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var expected_commands = [
		"help", "clear", "analyze", "inspect", "test",
		"run", "debug", "fix", "review", "explain"
	]
	
	# Gelecekte eklenecek, henüz implement edilmemesi gereken komutlar
	var prohibited_commands = ["git", "web", "commit", "deploy", "custom", "plan"]
	
	# Test 1: 10 Çekirdek Komutun Kayıt Defterinde (Registry) Varlığı
	var all_cmds = AISidebarSlashCommandManager.get_commands()
	var all_present = true
	for cmd_name in expected_commands:
		if not all_cmds.has(cmd_name):
			all_present = false
			errors.append("Test 1: Çekirdek komut kayıt defterinde eksik: /" + cmd_name)
			break
			
	if all_present:
		passed += 1
	else:
		failed += 1
		
	# Test 2: İstenmeyen / Erken Komutların Bulunmadığı Doğrulaması
	var prohibited_found = false
	for p_cmd in prohibited_commands:
		if all_cmds.has(p_cmd):
			prohibited_found = true
			errors.append("Test 2: Henüz implement edilmemesi gereken komut kayıtlı: /" + p_cmd)
			break
			
	if not prohibited_found:
		passed += 1
	else:
		failed += 1
		
	# Test 3: Komut Risk Sınıflandırmaları
	var risks_correct = true
	var ro = AISidebarPermissionPolicy.RiskLevel.READ_ONLY
	var wr = AISidebarPermissionPolicy.RiskLevel.WRITE
	
	var expected_risks = {
		"help": ro, "clear": ro, "analyze": ro, "inspect": ro, "test": ro,
		"run": wr, "debug": ro, "fix": wr, "review": ro, "explain": ro
	}
	
	for c_name in expected_risks.keys():
		var cmd = AISidebarSlashCommandManager.get_command(c_name)
		if cmd.is_empty() or cmd.get("risk") != expected_risks[c_name]:
			risks_correct = false
			errors.append("Test 3: /%s komutunun risk seviyesi hatalı (beklenen %d, bulunan %s)" % [
				c_name, expected_risks[c_name], str(cmd.get("risk", -1))
			])
			break
			
	if risks_correct:
		passed += 1
	else:
		failed += 1
		
	# Test 4: Parser - Temel ve Argümansız Komutlar
	var p_help = AISidebarSlashCommandManager.parse("/help")
	var p_clear = AISidebarSlashCommandManager.parse("/clear")
	var p_run = AISidebarSlashCommandManager.parse("/run")
	var p_review = AISidebarSlashCommandManager.parse("/review")
	
	if p_help.get("is_command") == true and p_help.get("name") == "help" and p_help.get("args") == "" \
		and p_clear.get("is_command") == true and p_clear.get("name") == "clear" \
		and p_run.get("is_command") == true and p_run.get("name") == "run" \
		and p_review.get("is_command") == true and p_review.get("name") == "review":
		passed += 1
	else:
		failed += 1
		errors.append("Test 4: Argümansız komut ayrıştırması başarısız.")
		
	# Test 5: Parser - Argümanlı Komutlar
	var p_inspect_node = AISidebarSlashCommandManager.parse("/inspect Player")
	var p_inspect_path = AISidebarSlashCommandManager.parse("/inspect res://scenes/Player.tscn")
	var p_explain_file = AISidebarSlashCommandManager.parse("/explain res://player.gd")
	var p_test_arg = AISidebarSlashCommandManager.parse("/test integration")
	var p_debug_arg = AISidebarSlashCommandManager.parse("/debug NullReferenceException")
	
	if p_inspect_node.get("name") == "inspect" and p_inspect_node.get("args") == "Player" \
		and p_inspect_path.get("name") == "inspect" and p_inspect_path.get("args") == "res://scenes/Player.tscn" \
		and p_explain_file.get("name") == "explain" and p_explain_file.get("args") == "res://player.gd" \
		and p_test_arg.get("name") == "test" and p_test_arg.get("args") == "integration" \
		and p_debug_arg.get("name") == "debug" and p_debug_arg.get("args") == "NullReferenceException":
		passed += 1
	else:
		failed += 1
		errors.append("Test 5: Argümanlı komut ayrıştırması başarısız.")
		
	# Test 6: Parser - Normal Metin ve Bilinmeyen Komutlar
	var p_normal = AISidebarSlashCommandManager.parse("Merhaba Godot AI")
	var p_url = AISidebarSlashCommandManager.parse("res://player.gd incele")
	var p_unknown = AISidebarSlashCommandManager.parse("/unknown_foobar 123")
	
	if p_normal.get("is_command") == false \
		and p_url.get("is_command") == false \
		and p_unknown.get("is_command") == true and p_unknown.has("error"):
		passed += 1
	else:
		failed += 1
		errors.append("Test 6: Normal metin veya bilinmeyen komut ayrıştırma davranışı hatalı.")
		
	# Test 7: detect_slash_query - İmleç Konumu ve Autocomplete Tespiti
	var q1 = AISidebarSlashCommandManager.detect_slash_query("/", 1)
	var q2 = AISidebarSlashCommandManager.detect_slash_query("/de", 3)
	var q3 = AISidebarSlashCommandManager.detect_slash_query("res://player.gd", 7)
	var q4 = AISidebarSlashCommandManager.detect_slash_query("/inspect player ", 16)
	var q5 = AISidebarSlashCommandManager.detect_slash_query("lütfen /ex", 10)
	
	if q1.get("active") == true and q1.get("query") == "" \
		and q2.get("active") == true and q2.get("query") == "de" \
		and q3.get("active") == false \
		and q4.get("active") == false \
		and q5.get("active") == true and q5.get("query") == "ex":
		passed += 1
	else:
		failed += 1
		errors.append("Test 7: detect_slash_query sorgu tespit mantığı hatalı.")
		
	# Test 8: get_suggestions - Öneri Listesi ve Filtreleme
	var sugg_de = AISidebarSlashCommandManager.get_suggestions("de")
	var sugg_all = AISidebarSlashCommandManager.get_suggestions("")
	
	var has_debug = false
	for s in sugg_de:
		if s.get("name") == "debug":
			has_debug = true
			break
			
	if has_debug and sugg_all.size() >= 10:
		passed += 1
	else:
		failed += 1
		errors.append("Test 8: get_suggestions öneri filtreleme başarısız.")
		
	# Test 9: /help ve /clear Yerel İcra (Local Response)
	var help_res = AISidebarSlashCommandManager.execute_command("help", "")
	var clear_ctx = AISidebarAgentContext.new()
	clear_ctx.add_user_message("Mesaj 1")
	clear_ctx.add_assistant_message("Mesaj 2")
	var clear_res = AISidebarSlashCommandManager.execute_command("clear", "", {"agent_context": clear_ctx})
	
	var help_msg = help_res.get("message", "")
	var help_has_all = true
	for c_name in expected_commands:
		if not ("/" + c_name) in help_msg:
			help_has_all = false
			break
			
	if help_res.get("action") == "local_response" and help_has_all \
		and clear_res.get("action") == "local_response" and clear_ctx.messages.size() == 0:
		passed += 1
	else:
		failed += 1
		errors.append("Test 9: /help veya /clear yerel icra davranışı hatalı.")
		
	# Test 10: Agent Görevi Başlatan Komutların Prompt Üretimi
	var ana_res = AISidebarSlashCommandManager.execute_command("analyze", "")
	var insp_res = AISidebarSlashCommandManager.execute_command("inspect", "Player")
	var test_res = AISidebarSlashCommandManager.execute_command("test", "")
	var run_res = AISidebarSlashCommandManager.execute_command("run", "")
	var deb_res = AISidebarSlashCommandManager.execute_command("debug", "")
	var fix_res = AISidebarSlashCommandManager.execute_command("fix", "Null error")
	var rev_res = AISidebarSlashCommandManager.execute_command("review", "")
	var exp_res = AISidebarSlashCommandManager.execute_command("explain", "res://player.gd")
	
	if ana_res.get("action") == "run_agent" and ("Read-Only" in ana_res.get("prompt", "")) \
		and insp_res.get("action") == "run_agent" and ("Player" in insp_res.get("prompt", "")) \
		and test_res.get("action") == "run_agent" and ("validate_script" in test_res.get("prompt", "")) \
		and run_res.get("action") == "run_agent" and ("play_game" in run_res.get("prompt", "")) \
		and deb_res.get("action") == "run_agent" and ("get_editor_errors" in deb_res.get("prompt", "")) \
		and fix_res.get("action") == "run_agent" and ("Verification Pipeline" in fix_res.get("prompt", "")) \
		and rev_res.get("action") == "run_agent" and ("6 kriter" in rev_res.get("prompt", "")) \
		and exp_res.get("action") == "run_agent" and ("res://player.gd" in exp_res.get("prompt", "")):
		passed += 1
	else:
		failed += 1
		errors.append("Test 10: Agent görev prompt üretimi içerik kriterlerini karşılamadı.")
		
	# Test 11: Display Prompt Ayrımı ve AgentRunner İletimi
	var mock_p = MockSlashCommandProvider.new()
	var test_ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock_p, test_ctx)
	
	var received_events: Array = []
	runner.text_received.connect(func(role: String, txt: String):
		received_events.append({"role": role, "text": txt})
	)
	
	var insp_cmd_res = AISidebarSlashCommandManager.execute_command("inspect", "Player")
	runner.start_task(insp_cmd_res.get("prompt"), insp_cmd_res.get("display_prompt"))
	
	var first_event = received_events[0] if received_events.size() > 0 else {}
	if first_event.get("role") == "user" and first_event.get("text") == "/inspect Player" \
		and test_ctx.messages.size() > 0 and test_ctx.messages[0].get("display_text") == "/inspect Player":
		passed += 1
	else:
		failed += 1
		errors.append("Test 11: AgentRunner display_prompt ve context display_text iletimi hatalı (events: %s)." % str(received_events))
		
	# Test 12: Bilinmeyen Komut İcra Denemesi
	var err_res = AISidebarSlashCommandManager.execute_command("non_existent_command", "")
	if err_res.get("action") == "error":
		passed += 1
	else:
		failed += 1
		errors.append("Test 12: Bilinmeyen komut çalıştırması hata döndürmedi.")
		
	return {
		"name": "SlashCommandTests",
		"passed": passed,
		"failed": failed,
		"errors": errors
	}
