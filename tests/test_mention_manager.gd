@tool
extends RefCounted

const AISidebarMentionManager = preload("res://addons/godot_sidebar_ai/core/chat/mention_manager.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: detect_mention_query
	var q1 = AISidebarMentionManager.detect_mention_query("@", 1)
	if q1["active"] and q1["query"] == "" and q1["start_pos"] == 0:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1a (detect @ at start) failed: " + str(q1))
		
	var q2 = AISidebarMentionManager.detect_mention_query("Lütfen @DiffTest", 16)
	if q2["active"] and q2["query"] == "DiffTest" and q2["start_pos"] == 7:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1b (detect @DiffTest) failed: " + str(q2))
		
	var q3 = AISidebarMentionManager.detect_mention_query("user@example.com", 16)
	if not q3["active"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1c (ignore email @) failed: " + str(q3))
		
	var q4 = AISidebarMentionManager.detect_mention_query("@Player tamamlandı", 18)
	if not q4["active"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1d (ignore completed mention after space) failed: " + str(q4))
		
	# Test 2: get_suggestions
	var suggs = AISidebarMentionManager.get_suggestions("mention", 10)
	var found_mention_manager = false
	for s in suggs:
		if "mention_manager" in s["label"]:
			found_mention_manager = true
			break
	if found_mention_manager:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (get_suggestions finds mention_manager.gd) failed.")
		
	# Test 3: resolve_prompt_context with File Mention
	var test_file = "res://tests/temp_mention_test.gd"
	var f = FileAccess.open(test_file, FileAccess.WRITE)
	f.store_string("extends Node\nvar player_speed = 15.0\nfunc jump(): pass\n")
	f.close()
	
	var prompt_with_mention = "Lütfen @" + test_file + " içindeki hızı 20 yap."
	var res = AISidebarMentionManager.resolve_prompt_context(prompt_with_mention)
	
	if res["has_mentions"] and test_file in res["files_attached"] and "player_speed = 15.0" in res["augmented_prompt"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (resolve_prompt_context file attachment) failed.")
		
	# Test 4: resolve_prompt_context with File Name only (@temp_mention_test.gd)
	var prompt_short = "Lütfen @temp_mention_test.gd dosyasını incele."
	var res_short = AISidebarMentionManager.resolve_prompt_context(prompt_short)
	if res_short["has_mentions"] and "player_speed = 15.0" in res_short["augmented_prompt"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (resolve_prompt_context filename only) failed.")
		
	# Clean up test file
	if FileAccess.file_exists(test_file):
		DirAccess.remove_absolute(test_file)
		
	# Test 5: Safe Large File Truncation (200 Lines / 12KB Limit)
	var large_file = "res://tests/temp_large_mention.gd"
	var lf = FileAccess.open(large_file, FileAccess.WRITE)
	for i in range(250):
		lf.store_line("var line_%d = %d" % [i, i])
	lf.close()
	
	var res_large = AISidebarMentionManager.resolve_prompt_context("Bak @" + large_file)
	if res_large["has_mentions"] and "güvenlik limitiyle sınırlandırıldı" in res_large["augmented_prompt"] and "line_190" in res_large["augmented_prompt"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (Large file safe truncation) failed.")
		
	if FileAccess.file_exists(large_file):
		DirAccess.remove_absolute(large_file)
		
	# Test 6: Prompt without mention unchanged
	var normal_prompt = "Normal bir Godot sorusu."
	var res_normal = AISidebarMentionManager.resolve_prompt_context(normal_prompt)
	if not res_normal["has_mentions"] and res_normal["augmented_prompt"] == normal_prompt:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (Normal prompt without mention) failed.")
		
	# Test 7: MessageBubble Mention Highlighting
	var bubble = AISidebarMessageBubble.new("user", "Check @res://player.gd and @Node:Player")
	bubble._ready()
	if "[url=file:res://player.gd]" in bubble._content_label.text and "@Node:Player" in bubble._content_label.text:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (MessageBubble @ mention styling) failed: " + bubble._content_label.text)
	bubble.queue_free()
	
	return {"name": "MentionManagerTests", "passed": passed, "failed": failed, "errors": errors}
