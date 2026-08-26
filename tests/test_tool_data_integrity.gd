@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")

class MockDataTrackingProvider extends AISidebarAIProvider:
	var response_queue: Array = []
	var recorded_messages: Array = []
	
	func send_chat(messages: Array, tools_schema: Array) -> void:
		recorded_messages.append(messages.duplicate(true))
		if response_queue.size() > 0:
			var r = response_queue.pop_front()
			response_received.emit(
				r.get("content", ""),
				r.get("thinking", ""),
				r.get("tool_calls", [])
			)

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Tool actual result generated (analyze_project contains main_scene)
	var raw_tool_res = AISidebarToolManager.execute_tool("analyze_project", {})
	if raw_tool_res.get("success", false) and raw_tool_res.has("data") and raw_tool_res["data"] is Dictionary and raw_tool_res["data"].has("main_scene"):
		passed += 1
	else:
		failed += 1
		errors.append("analyze_project yapısal data üretmedi: " + str(raw_tool_res))
		
	# Test 2 & 3 & 4: Tool actual data reaches AgentContext -> provider messages -> Model answers directly
	var mock_p = MockDataTrackingProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock_p, ctx)
	
	mock_p.response_queue = [
		# 1. Turn: Model calls analyze_project
		{
			"content": "",
			"thinking": "Projeyi analiz ediyorum.",
			"tool_calls": [{"id": "call_gemini_101", "name": "analyze_project", "arguments": {}}]
		},
		# 2. Turn: Model reads tool data and answers directly without extra tool calls
		{
			"content": "Projenin ana sahnesi res://scenes/main.tscn olarak tespit edildi.",
			"thinking": "Tool sonucundaki main_scene verisini aldım.",
			"tool_calls": []
		}
	]
	
	var final_texts: Array = []
	runner.text_received.connect(func(role, txt):
		if role == "assistant":
			final_texts.append(txt)
	)
	
	runner.start_task("Projenin ana sahnesinin adını söyle")
	
	# Doğrulama: Provider'a giden 2. mesaj listesini denetle
	if mock_p.recorded_messages.size() == 2:
		var turn2_messages = mock_p.recorded_messages[1]
		var found_tool_data = false
		for msg in turn2_messages:
			if msg.get("role") == "tool" and msg.get("tool_call_id") == "call_gemini_101":
				var content_str = str(msg.get("content", ""))
				if "main_scene" in content_str and "success" in content_str:
					found_tool_data = true
					
		if found_tool_data:
			passed += 2 # Passes both AgentContext and Provider Messages checks
		else:
			failed += 2
			errors.append("Modele gönderilen tool mesajı main_scene verisini içermiyor: " + str(turn2_messages))
	else:
		failed += 2
		errors.append("Beklenen 2 turn gerçekleşmedi. Gerçek turn sayısı: " + str(mock_p.recorded_messages.size()))
		
	# Doğrulama 4: Model tek tool sonucuyla cevabı tamamladı mı?
	if final_texts.size() == 1 and "main.tscn" in final_texts[0]:
		passed += 1
	else:
		failed += 1
		errors.append("Model tek adımda doğru nihai yanıtı üretemedi: " + str(final_texts))
		
	# Test 5: eval_gdscript safe instance
	var eval_res = AISidebarScriptTools.execute("eval_gdscript", {"code": "2 + 2"})
	if eval_res.get("success", false) and str(eval_res.get("data", {}).get("result", "")) == "4":
		passed += 1
	else:
		failed += 1
		errors.append("eval_gdscript çalışmadı: " + str(eval_res))
		
	return {"name": "ToolDataIntegrityTests", "passed": passed, "failed": failed, "errors": errors}
