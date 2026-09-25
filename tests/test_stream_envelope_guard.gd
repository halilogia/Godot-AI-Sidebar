@tool
extends RefCounted

## Streaming sirasinda ham tool-call JSON'un kullaniciya chat mesaji olarak
## gorunmesini engelleyen akis guard'i icin DETERMINISTIK testler.
##
## Bu testler LLM metnine veya gercek aga bagimli DEGILDIR; dogrudan
## chat_dock sinyal isleyicileri cagrilir ve MessageStream icerigi denetlenir.

const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarClarificationCard = preload("res://addons/godot_sidebar_ai/ui/components/clarification_card.gd")
const AISidebarChatDock = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.gd")
const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")

# --- Test verileri ---
const ENVELOPE_ASK_USER = "{\"tool_calls\": [{\"name\": \"ask_user\", \"arguments\": {\"question\": \"GDScript mi C# mi?\", \"options\": [\"GDScript\", \"C#\"]}}]}"
const ENVELOPE_OTHER_TOOL = "{\n  \"tool_calls\": [\n    {\"name\": \"create_or_update_script\", \"arguments\": {\"file_path\": \"res://player.gd\"}}\n  ]\n}"
const PROSE_TEXT = "Player hareket sistemini olusturdum ve dogrulama gecti."
const PROSE_WITH_ENVELOPE = PROSE_TEXT + "\n\n" + ENVELOPE_OTHER_TOOL


## Testi sifirdan kosabilmek icin MessageStream icerigini aninda temizler.
## (queue_free() gecikmeli oldugu icin dogrudan free() kullanilir.)
static func _hard_clear(dock) -> void:
	if dock.message_stream:
		for child in dock.message_stream.get_children():
			child.free()
	dock._stream.assistant_bubble = null
	dock._current_activity_group = null
	dock._welcome_card = null
	dock._stream.reset_stream_buffer()


## MessageStream icinde ham JSON tasiyan bir balon var mi?
static func _has_raw_json_bubble(dock) -> bool:
	if not dock.message_stream:
		return false
	for child in dock.message_stream.get_children():
		if child is AISidebarMessageBubble:
			var txt: String = str(child.text_content).strip_edges()
			if txt.is_empty():
				continue
			if txt.begins_with("{") or txt.contains("\"tool_calls\""):
				return true
	return false


## MessageStream'de gorunen tum balon metinleri (birlestirilmis).
static func _visible_text(dock) -> String:
	var out := ""
	if not dock.message_stream:
		return out
	for child in dock.message_stream.get_children():
		if child is AISidebarMessageBubble:
			out += str(child.text_content)
	return out


## Chunk'lari sirayla besler ve HER adimda ham JSON sizintisi olup olmadigini izler.
static func _feed_chunks(dock, chunks: Array) -> Dictionary:
	var leaked := false
	var leaked_steps := 0
	for ch in chunks:
		dock._stream.on_chunk_received(str(ch), "")
		if _has_raw_json_bubble(dock):
			leaked = true
			leaked_steps += 1
	return {"leaked": leaked, "steps": leaked_steps}


static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# ============================================================
	# BOLUM A: Saf tespit mantigi (streaming'e gerek yok)
	# ============================================================

	# A1: Saf ask_user JSON tamamen sokulur (gorunur metin kalmaz)
	if AISidebarMessageBubble.is_tool_call_envelope(ENVELOPE_ASK_USER) and AISidebarMessageBubble.strip_tool_call_envelopes(ENVELOPE_ASK_USER, true).strip_edges().is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("A1 (ask_user envelope stripped) failed.")

	# A2: Saf baska arac JSON'u tamamen sokulur
	if AISidebarMessageBubble.strip_tool_call_envelopes(ENVELOPE_OTHER_TOOL, true).strip_edges().is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("A2 (other tool envelope stripped) failed.")

	# A3: Normal asistan metni aynen korunur
	if AISidebarMessageBubble.strip_tool_call_envelopes(PROSE_TEXT, true) == PROSE_TEXT:
		passed += 1
	else:
		failed += 1
		errors.append("A3 (prose preserved) failed.")

	# A4: Metin + zarf -> metin kalir, JSON gider
	var stripped4 := AISidebarMessageBubble.strip_tool_call_envelopes(PROSE_WITH_ENVELOPE, true)
	if PROSE_TEXT in stripped4 and not "tool_calls" in stripped4:
		passed += 1
	else:
		failed += 1
		errors.append("A4 (prose kept, JSON removed) failed: '" + stripped4 + "'")

	# A5: ```json sarmali da sokulur
	var fenced = "```json\n" + ENVELOPE_OTHER_TOOL + "\n```"
	if AISidebarMessageBubble.strip_tool_call_envelopes(fenced, true).strip_edges().is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("A5 (fenced envelope stripped) failed.")

	# A6: Yarim (parcali) zarf adaylari gorunur metin URETMEZ
	var partial_cases = [
		"{",
		"{\"tool_calls\"",
		"{\"tool_calls\": [",
		"{ \"tool_calls\"",
		"```json",
		"{\"tool_ca",
	]
	for pc in partial_cases:
		if AISidebarMessageBubble.strip_tool_call_envelopes(str(pc), true).strip_edges().is_empty():
			passed += 1
		else:
			failed += 1
			errors.append("A6 (partial '" + str(pc) + "' must not be visible) failed")

	# A7: Zarfla ILGISIZ yarim JSON gorunur kalmali (yanlis pozitif korumasi)
	var not_envelope = "{\"foo\": 1}"
	var ne_out := AISidebarMessageBubble.strip_tool_call_envelopes(not_envelope, true)
	if not ne_out.strip_edges().is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("A7 (non-envelope JSON must stay visible) failed")

	# ============================================================
	# BOLUM B: Gercek ChatDock akis isleyicileri (GUI degil, deterministik)
	# ============================================================
	var dock = ChatDockScene.instantiate()
	if dock == null:
		failed += 1
		errors.append("ChatDock instance could not be created.")
		return {"name": "StreamEnvelopeGuardTests", "passed": passed, "failed": failed, "errors": errors}

	dock._ready()
	dock._auto_scroll_enabled = false
	dock._sessions.current = null

	# --- Test 1: Saf ask_user JSON -> chat bubble GORUNMEZ ---
	_hard_clear(dock)
	dock._stream.on_text_received("assistant", ENVELOPE_ASK_USER)
	var t1 = not _has_raw_json_bubble(dock) and _visible_text(dock).strip_edges().is_empty()
	if t1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (pure ask_user JSON hidden) failed: visible='" + _visible_text(dock) + "'")

	# --- Test 2: Saf baska tool-call JSON -> chat bubble GORUNMEZ ---
	_hard_clear(dock)
	dock._stream.on_text_received("assistant", ENVELOPE_OTHER_TOOL)
	if not _has_raw_json_bubble(dock) and _visible_text(dock).strip_edges().is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (pure tool JSON hidden) failed: visible='" + _visible_text(dock) + "'")

	# --- Test 3: Normal assistant text -> GORUNUR ---
	_hard_clear(dock)
	dock._stream.on_text_received("assistant", PROSE_TEXT)
	if PROSE_TEXT in _visible_text(dock):
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (normal assistant text visible) failed: visible='" + _visible_text(dock) + "'")

	# --- Test 4: text + tool-call -> text GORUNUR, ham JSON gorunmez ---
	_hard_clear(dock)
	dock._stream.on_text_received("assistant", PROSE_WITH_ENVELOPE)
	var vis4 = _visible_text(dock)
	if PROSE_TEXT in vis4 and not _has_raw_json_bubble(dock):
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (text + tool-call keeps text) failed: visible='" + vis4 + "'")

	# --- Test 5: Streaming chunk'lara bolunmus tool-call JSON -> HICBIR asamada gorunmez ---
	# Chunk sinirlari JSON token'larini ortadan boler (gercek SSE davranisi).
	var leaked_any = false
	var detail = ""

	# 5a: ask_user zarfı, 8 karakterlik parcalar
	_hard_clear(dock)
	var chunks_ask: Array = []
	var s_ask: String = ENVELOPE_ASK_USER
	var i = 0
	while i < s_ask.length():
		chunks_ask.append(s_ask.substr(i, 8))
		i += 8
	var r_ask = _feed_chunks(dock, chunks_ask)
	dock._stream.on_text_received("assistant", ENVELOPE_ASK_USER)
	if r_ask["leaked"] or _has_raw_json_bubble(dock):
		leaked_any = true
		detail += "ask_user(8ch) "
	if leaked_any:
		failed += 1
		errors.append("Test 5a (fragmented ask_user JSON never leaks) failed: " + detail)
	else:
		passed += 1

	# 5b: baska arac zarfı, 5 karakterlik parcalar (daha agresif bolme)
	_hard_clear(dock)
	var chunks_tool: Array = []
	var s_tool: String = ENVELOPE_OTHER_TOOL
	var j = 0
	while j < s_tool.length():
		chunks_tool.append(s_tool.substr(j, 5))
		j += 5
	var r_tool = _feed_chunks(dock, chunks_tool)
	dock._stream.on_text_received("assistant", ENVELOPE_OTHER_TOOL)
	if r_tool["leaked"] or _has_raw_json_bubble(dock):
		failed += 1
		errors.append("Test 5b (fragmented tool JSON never leaks) failed: leaked_steps=" + str(r_tool["steps"]))
	else:
		passed += 1

	# 5c: karakter karakter besleme (en agresif senaryo)
	_hard_clear(dock)
	var chunks_char: Array = []
	for ci in range(ENVELOPE_ASK_USER.length()):
		chunks_char.append(ENVELOPE_ASK_USER[ci])
	var r_char = _feed_chunks(dock, chunks_char)
	if r_char["leaked"] or _has_raw_json_bubble(dock):
		failed += 1
		errors.append("Test 5c (char-by-char JSON never leaks) failed: leaked_steps=" + str(r_char["steps"]))
	else:
		passed += 1

	# 5d: Karisik akis - once normal metin, sonra zarf -> metin korunur, zarf gizlenir
	_hard_clear(dock)
	var mixed: Array = ["Player ", "hareket ", "sistemi ", "hazir. ", "{\"tool_calls\": [{\"name\": \"save_scene\", \"arguments\": {}}]}"]
	var r_mixed = _feed_chunks(dock, mixed)
	var vis_mixed = _visible_text(dock)
	if (not r_mixed["leaked"]) and ("Player hareket sistemi hazir." in vis_mixed) and (not _has_raw_json_bubble(dock)):
		passed += 1
	else:
		failed += 1
		errors.append("Test 5d (mixed text then envelope) failed: visible='" + vis_mixed + "' leaked=" + str(r_mixed["leaked"]))

	# 5e: Normal metin streaming'i bozulmamis olmali (parcalar birlestirilmeli)
	_hard_clear(dock)
	var prose_chunks: Array = ["Kod ", "yazildi ", "ve ", "testler ", "gecti."]
	_feed_chunks(dock, prose_chunks)
	if _visible_text(dock) == "Kod yazildi ve testler gecti.":
		passed += 1
	else:
		failed += 1
		errors.append("Test 5e (streamed prose intact) failed: visible='" + _visible_text(dock) + "'")

	# --- Test 6: ask_user -> ClarificationCard hala olusur ---
	_hard_clear(dock)
	# Once zarf akisi (kullaniciya gorunmemeli), ardindan clarification sinyali.
	dock._stream.on_text_received("assistant", ENVELOPE_ASK_USER)
	dock._on_agent_clarification_requested("GDScript mi C# mi?", ["GDScript", "C#"], "cid_test")

	var clarif_count = 0
	for child in dock.message_stream.get_children():
		if child is AISidebarClarificationCard:
			clarif_count += 1
	if clarif_count == 1 and not _has_raw_json_bubble(dock):
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (ask_user creates ClarificationCard) failed: count=" + str(clarif_count))

	# --- Test 7: Kullanici turu sonrasi tampon sizmamali (bayat metin tasinmaz) ---
	_hard_clear(dock)
	# Yarim bir zarf akisi (yeni turda iptal edilmis gibi)
	dock._stream.on_chunk_received("{\"tool_calls\": [{\"name\": \"ask_", "")
	# Kullanici mesaji gelir -> yeni tur, tampon temizlenir
	dock._stream.on_text_received("user", "Yeni bir istek gonderiyorum")
	# Asistan normal metinle cevap verir
	dock._stream.on_text_received("assistant", PROSE_TEXT)
	var vis7 = _visible_text(dock)
	if (not _has_raw_json_bubble(dock)) and (not "tool_calls" in vis7) and (PROSE_TEXT in vis7):
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (no stale buffer leak across turns) failed: visible='" + vis7 + "'")

	dock.free()

	return {"name": "StreamEnvelopeGuardTests", "passed": passed, "failed": failed, "errors": errors}
