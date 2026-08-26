@tool
extends RefCounted

const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")

class MockDynamicToolProvider extends AISidebarAIProvider:
	var received_schemas_history: Array = []
	var responses: Array = []
	
	func send_chat(messages: Array, tools_schema: Array) -> void:
		received_schemas_history.append(tools_schema.duplicate(true))
		if responses.size() > 0:
			var r = responses.pop_front()
			response_received.emit(
				r.get("content", ""),
				r.get("thinking", ""),
				r.get("tool_calls", [])
			)
		else:
			response_received.emit("Tamamlandı.", "", [])

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var total_all_tools = AISidebarToolManager.get_all_schemas().size()
	
	# Test 1: "Yeni bir GDScript oluştur" senaryosu (Script / File Tools)
	var script_schemas = AISidebarToolManager.get_relevant_schemas("Yeni bir GDScript oluştur")
	var script_names: Array = []
	for s in script_schemas:
		script_names.append(s["function"]["name"])
		
	if script_schemas.size() < total_all_tools and "create_or_update_script" in script_names and "validate_script" in script_names:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (Script filtering) failed: count=" + str(script_schemas.size()) + " total=" + str(total_all_tools))
		
	# Test 2: "3D sahne oluştur" senaryosu (Scene / Node / Intent Tools)
	var scene_schemas = AISidebarToolManager.get_relevant_schemas("3D sahne oluştur")
	var scene_names: Array = []
	for s in scene_schemas:
		scene_names.append(s["function"]["name"])
		
	if scene_schemas.size() < total_all_tools and "create_scene" in scene_names and "add_node" in scene_names:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (Scene filtering) failed: count=" + str(scene_schemas.size()) + " total=" + str(total_all_tools))
		
	# Test 3: "Runtime hatasını düzelt" senaryosu (Runtime / Debug / Script Tools)
	var runtime_schemas = AISidebarToolManager.get_relevant_schemas("Runtime hatasını düzelt")
	var runtime_names: Array = []
	for s in runtime_schemas:
		runtime_names.append(s["function"]["name"])
		
	if runtime_schemas.size() < total_all_tools and "get_runtime_errors" in runtime_names and "create_or_update_script" in runtime_names:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (Runtime filtering) failed: count=" + str(runtime_schemas.size()) + " total=" + str(total_all_tools))
		
	# Test 4 & 5: Progressive Discovery ile Arama ve Dinamik Araç Açma & Telemetri
	var prov = MockDynamicToolProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(prov, ctx)
	
	prov.responses = [
		# 1. Adım: Ajan search_tools çağırır
		{
			"content": "Kamera araçlarını arıyorum.",
			"tool_calls": [
				{
					"name": "search_tools",
					"id": "c_search",
					"arguments": {"query": "camera"}
				}
			]
		},
		# 2. Adım: Ajan açılan aracı çağırır
		{
			"content": "Kamera ayarlandı.",
			"tool_calls": []
		}
	]
	
	var completed_metrics = [{}]
	runner.task_completed.connect(func(m): completed_metrics[0] = m)
	
	runner.start_task("Proje için kamera sistemini ayarla")
	
	if prov.received_schemas_history.size() == 2:
		var step2_schemas = prov.received_schemas_history[1]
		var step2_names: Array = []
		for s in step2_schemas:
			step2_names.append(s["function"]["name"])
			
		if "setup_camera_follow" in step2_names:
			passed += 1
		else:
			failed += 1
			errors.append("Test 4 (Progressive search_tools unlocking) failed: setup_camera_follow not in step2 tools: " + str(step2_names))
	else:
		failed += 1
		errors.append("Test 4 (Provider turns) failed: history_size=" + str(prov.received_schemas_history.size()))
		
	# Test 5: Telemetry Çıktısında tools_sent ve total_tools Doğrulaması
	var m = completed_metrics[0]
	if m.has("tools_sent") and m.has("total_tools") and m.get("total_tools", 0) == total_all_tools:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (Telemetry tools ratio) failed: " + str(m))
		
	return {"name": "DynamicToolFilteringTests", "passed": passed, "failed": failed, "errors": errors}
