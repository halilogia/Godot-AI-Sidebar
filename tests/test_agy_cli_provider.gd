@tool
extends RefCounted

const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	var prov = AISidebarAGYProvider.new()

	# Test 1: Capabilities
	if prov.supports_vision() and prov.supports_streaming() and prov.supports_tool_calling():
		passed += 1
	else:
		failed += 1
		errors.append("AGY Provider yetenekleri (vision, streaming, tool_calling) hatalı.")

	# Test 2: Official Model List Fetch
	var fetched_models: Array = []
	var on_models = func(m: Array):
		fetched_models.append_array(m)
	prov.models_fetched.connect(on_models)
	prov.fetch_models()

	if fetched_models.has("gemini-3.8-flash-low") and fetched_models.has("claude-sonnet-4-6"):
		passed += 1
	else:
		failed += 1
		errors.append("Resmi Antigravity modelleri listesi eksik: " + str(fetched_models))

	# Test 3: Sandbox Directory Isolation
	var sandbox = prov._ensure_sandbox_dir()
	if not sandbox.is_empty() and DirAccess.dir_exists_absolute(sandbox) and "agy_sandbox" in sandbox:
		passed += 1
	else:
		failed += 1
		errors.append("Sandbox dizini izole edilemedi: " + str(sandbox))

	# Test 4: Tool Call JSON Extraction (Markdown Code Block)
	var sample_response_with_block = "Karakter kontrolcüsü oluşturuldu.\n```json\n{\n  \"tool_calls\": [\n    {\n      \"name\": \"create_script\",\n      \"arguments\": {\"path\": \"res://player.gd\", \"code\": \"extends Node\"}\n    }\n  ]\n}\n```\nİşlem tamamlandı."
	var tool_calls = AISidebarAGYProvider.extract_tool_calls(sample_response_with_block)
	if tool_calls.size() == 1 and tool_calls[0].get("name") == "create_script" and tool_calls[0].get("arguments", {}).get("path") == "res://player.gd":
		passed += 1
	else:
		failed += 1
		errors.append("Markdown JSON tool_calls çıkarma hatası: " + str(tool_calls))

	# Test 5: Clean Text Extraction
	var clean_text = AISidebarAGYProvider.extract_clean_text(sample_response_with_block, true)
	if "Karakter kontrolcüsü oluşturuldu." in clean_text and "İşlem tamamlandı." in clean_text and not "```json" in clean_text:
		passed += 1
	else:
		failed += 1
		errors.append("Temiz metin ayıklama hatası: " + str(clean_text))

	# Test 6: Raw JSON tool_calls Extraction (Without code block)
	var raw_json_resp = "{\"tool_calls\": [{\"name\": \"create_scene\", \"arguments\": {\"path\": \"res://world.tscn\"}}]}"
	var raw_tool_calls = AISidebarAGYProvider.extract_tool_calls(raw_json_resp)
	if raw_tool_calls.size() == 1 and raw_tool_calls[0].get("name") == "create_scene":
		passed += 1
	else:
		failed += 1
		errors.append("Ham JSON tool_calls çıkarma hatası: " + str(raw_tool_calls))

	# Test 7: Prompt Formatting with System Prompt & Tool Schemas
	var dummy_tools = [
		{
			"function": {
				"name": "create_script",
				"description": "Script oluşturur",
				"parameters": {"properties": {"path": {"type": "string"}}}
			}
		}
	]
	var dummy_messages = [
		{"role": "user", "content": "Bana karakter yap"}
	]
	var dummy_cfg = {
		"system_prompt": "Sen Godot uzmanısın."
	}
	var formatted_prompt = prov._format_prompt(dummy_messages, dummy_tools, [], dummy_cfg)
	if "=== SYSTEM DIRECTIVE ===" in formatted_prompt and "create_script" in formatted_prompt and "Bana karakter yap" in formatted_prompt and "TOOL CALLING INSTRUCTIONS" in formatted_prompt:
		passed += 1
	else:
		failed += 1
		errors.append("Prompt formatlama yönergesi eksik veya hatalı: " + formatted_prompt)

	# Temizlik
	prov.stop_process()

	return {"name": "AGYCLIProviderTests", "passed": passed, "failed": failed, "errors": errors}
