@tool
extends RefCounted

const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	var prov = AISidebarAGYProvider.new()

	# Test 1: Capabilities (Vision must be false for AGY CLI stream-json adapter)
	if not prov.supports_vision() and prov.supports_streaming() and prov.supports_tool_calling():
		passed += 1
	else:
		failed += 1
		errors.append("AGY Provider yetenekleri (supports_vision must be false, streaming, tool_calling) hatalı.")

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

	# Test 8: Multimodal Vision Guard Regression Test
	var captured_errors: Array = []
	var on_err = func(err: String):
		captured_errors.append(err)
	prov.error_occurred.connect(on_err)
	var dummy_img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var dummy_vi = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd").from_image(dummy_img)
	prov.send_multimodal_chat([], [], [dummy_vi])
	if captured_errors.size() > 0 and "desteklememektedir" in captured_errors[0]:
		passed += 1
	else:
		failed += 1
		errors.append("AGY Provider multimodal rejection guard failed: " + str(captured_errors))

	# Test 9: Readiness baslangic durumu STARTING olmali (READY varsayilmamali)
	if not prov.is_ready() and prov._state == AISidebarAGYProvider.AgyState.STARTING:
		passed += 1
	else:
		failed += 1
		errors.append("AGY baslangic durumu STARTING degil: state=" + str(prov._state))

	# Test 10: READY olmadan yazma KUYRUGA alinir; store_string CAGRILMAZ
	# (_stdio null oldugu icin yazma denenseydi hata yayilirdi -> hata beklenmiyor)
	var readiness_errors: Array = []
	var on_readiness_err = func(err: String):
		readiness_errors.append(err)
	prov.error_occurred.connect(on_readiness_err)
	prov._write_or_queue("payload-A")
	prov.error_occurred.disconnect(on_readiness_err)
	if not prov.is_ready() and prov._has_pending and prov._pending_payload == "payload-A" and readiness_errors.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("READY olmadan istek kuyruga alinmadi: %s" % str({"ready": prov.is_ready(), "pending": prov._has_pending, "payload": prov._pending_payload, "errors": readiness_errors}))

	# Test 11: Ayni anda YALNIZCA TEK pending request tutulur (en son istek kazanir)
	prov._write_or_queue("payload-B")
	if prov._has_pending and prov._pending_payload == "payload-B":
		passed += 1
	else:
		failed += 1
		errors.append("Tek pending request kuralı bozuldu: " + str(prov._pending_payload))

	# Test 12: Eski prosesin (stale generation) 'init' bildirimi YOK SAYILMALI
	prov._on_agy_ready(prov._generation + 99)
	if not prov.is_ready() and prov._has_pending:
		passed += 1
	else:
		failed += 1
		errors.append("Stale 'init' bildirimi yanlislikla READY yapti (restart yarisi).")

	# Test 13: Guncel generation 'init' bildirimi READY yapar ve pending istegi bosaltir
	var readiness_states: Array = []
	var on_readiness = func(st: int, _msg: String):
		readiness_states.append(st)
	prov.readiness_changed.connect(on_readiness)
	prov._on_agy_ready(prov._generation)
	prov.readiness_changed.disconnect(on_readiness)
	if prov.is_ready() and not prov._has_pending and prov._pending_payload.is_empty() and readiness_states.has(AISidebarAGYProvider.AgyState.READY):
		passed += 1
	else:
		failed += 1
		errors.append("Guncel 'init' bildirimi READY yapmadi veya pending temizlenmedi: " + str(readiness_states))

	# Temizlik
	prov.stop_process()

	return {"name": "AGYCLIProviderTests", "passed": passed, "failed": failed, "errors": errors}
