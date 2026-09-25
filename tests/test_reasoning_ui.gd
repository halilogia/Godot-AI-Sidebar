@tool
extends RefCounted

## Action / Summary UI: özet gösterimi, ham reasoning sızıntısı yok,
## collapse/cap, cevap ayrımı, AGY boş akışı.

const AISidebarReasoningCard = preload("res://addons/godot_sidebar_ai/ui/components/reasoning_card.gd")
const AISidebarThinkingCard = preload("res://addons/godot_sidebar_ai/ui/components/thinking_card.gd")
const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarPendingIndicator = preload("res://addons/godot_sidebar_ai/ui/components/pending_indicator.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarToolPresentation = preload("res://addons/godot_sidebar_ai/ui/presenters/tool_presentation.gd")
const AISidebarRuntimeCard = preload("res://addons/godot_sidebar_ai/ui/components/runtime_card.gd")

const SECRET_MARKER = "GIZLI_DUSUNCE_XYZ_123"

static func _dock():
	var dock = ChatDockScene.instantiate()
	dock._ready()
	dock._auto_scroll_enabled = false
	for child in dock.message_stream.get_children():
		child.free()
	dock._stream.assistant_bubble = null
	dock._stream.reasoning_card = null
	dock._activity.group = null
	dock._stream.reset_stream_buffer()
	return dock

static func _reasoning_cards(dock) -> Array:
	var out: Array = []
	for child in dock.message_stream.get_children():
		if child is AISidebarReasoningCard:
			out.append(child)
	return out

static func _thinking_cards(dock) -> Array:
	var out: Array = []
	for child in dock.message_stream.get_children():
		if child is AISidebarThinkingCard:
			out.append(child)
	return out

static func _stream_text(dock) -> String:
	var out = ""
	for child in dock.message_stream.get_children():
		if child is AISidebarReasoningCard:
			out += child.get_text()
		elif child.has_method("get") and "text_content" in child:
			out += str(child.get("text_content"))
	return out

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. summary gösteriliyor (tool event -> action kartı)
	var dock1 = _dock()
	dock1._activity.on_tool_executing("validate_script", {})
	var cards1 = _reasoning_cards(dock1)
	for c in cards1:
		c._ready()
	if cards1.size() == 1 and "Validat" in cards1[0].get_text() and not cards1[0].is_expanded:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (summary shown) failed.")
	dock1.queue_free()

	# 2. ham reasoning UI'a sızmıyor (chunk + final + bubble + export metni)
	var dock2 = _dock()
	dock2._stream.on_chunk_received("", SECRET_MARKER + " bir plan düşünüyorum")
	dock2._stream.on_thinking_received(SECRET_MARKER + " tam gerekçe")
	dock2._activity.on_tool_executing("read_script", {"file_path": "res://a.gd"})
	dock2._stream.on_chunk_received("Görünen cevap.", "")
	if not SECRET_MARKER in _stream_text(dock2):
		passed += 1
	else:
		failed += 1
		errors.append("T2 (no raw reasoning leak) failed.")
	dock2.queue_free()

	# 3. no-reasoning provider normal çalışıyor (tool özeti + cevap akışı)
	var dock3 = _dock()
	dock3._activity.on_tool_executing("analyze_project", {})
	dock3._activity.on_tool_completed("analyze_project", {"success": true, "data": {}, "message": "ok"})
	dock3._stream.on_chunk_received("Analiz bitti.", "")
	var cards3 = _reasoning_cards(dock3)
	var bubble3 = dock3._stream.assistant_bubble.text_content if dock3._stream.assistant_bubble else ""
	if cards3.size() == 1 and bubble3 == "Analiz bitti.":
		passed += 1
	else:
		failed += 1
		errors.append("T3 (no-reasoning flow) failed.")
	dock3.queue_free()

	# 4. streaming sırasında UI bozulmuyor (tek kart, son action)
	var dock4 = _dock()
	dock4._activity.on_tool_executing("read_script", {"file_path": "res://a.gd"})
	dock4._activity.on_tool_executing("validate_script", {})
	dock4._activity.on_tool_completed("validate_script", {"success": true, "data": {}, "message": "ok"})
	var cards4 = _reasoning_cards(dock4)
	if cards4.size() == 1 and "Validat" in cards4[0].get_text():
		passed += 1
	else:
		failed += 1
		errors.append("T4 (streaming stable) failed.")
	dock4.queue_free()

	# 5. final response ayrı kalır
	var dock5 = _dock()
	dock5._activity.on_tool_executing("read_script", {"file_path": "res://a.gd"})
	dock5._stream.on_text_received("assistant", "Dosya okundu ve hazır.")
	var bubble5 = ""
	for child in dock5.message_stream.get_children():
		if "text_content" in child and not (child is AISidebarReasoningCard):
			bubble5 += str(child.get("text_content"))
	if bubble5 == "Dosya okundu ve hazır.":
		passed += 1
	else:
		failed += 1
		errors.append("T5 (answer separation) failed: '" + bubble5 + "'")
	dock5.queue_free()

	# 6. collapse + cap korunuyor
	var card6 = AISidebarReasoningCard.new()
	card6._ready()
	card6.set_action("▶ " + "x".repeat(5000))
	var collapsed_ok = card6.get_header_text().begins_with("▸")
	card6.set_expanded(true)
	if collapsed_ok and card6.get_text().length() <= AISidebarReasoningCard.MAX_DISPLAY_CHARS + 20 and card6.is_truncated():
		passed += 1
	else:
		failed += 1
		errors.append("T6 (collapse+cap) failed.")
	card6.queue_free()

	# 7. AGY tarzı akış: thinking yok, tool yoksa kart yok
	var dock7 = _dock()
	for i in range(3):
		dock7._stream.on_chunk_received("parça ", "")
	dock7._stream.on_thinking_received("")
	if _reasoning_cards(dock7).is_empty() and _thinking_cards(dock7).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T7 (AGY no card) failed.")
	dock7.queue_free()

	# 8. Thinking kartı: chunk ile oluşur, collapsed başlar, action kartından ayrı
	var dock8 = _dock()
	dock8._stream.on_chunk_received("", "Düşünce parçası.")
	var tcards8 = _thinking_cards(dock8)
	for c in tcards8:
		c._ready()
	if tcards8.size() == 1 and "Düşünce parçası." in tcards8[0].get_text() and not tcards8[0].is_expanded and tcards8[0].get_header_text().begins_with("▸") and _reasoning_cards(dock8).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T8 (thinking card) failed.")
	dock8.queue_free()

	# 9. Thinking birikimi + final duplicate yok
	var dock9 = _dock()
	dock9._stream.on_chunk_received("", "A. ")
	dock9._stream.on_chunk_received("", "B.")
	dock9._stream.on_thinking_received("A. B.")
	var tcards9 = _thinking_cards(dock9)
	if tcards9.size() == 1 and tcards9[0].get_text() == "A. B.":
		passed += 1
	else:
		failed += 1
		errors.append("T9 (thinking aggregation) failed.")
	dock9.queue_free()

	# 10. Thinking cap + boş thinking kart açmaz
	var dock10 = _dock()
	dock10._stream.on_chunk_received("", "")
	dock10._stream.on_thinking_received("   ")
	var card10 = AISidebarThinkingCard.new()
	card10._ready()
	card10.append_thinking("y".repeat(AISidebarThinkingCard.MAX_DISPLAY_CHARS + 1000))
	if _thinking_cards(dock10).is_empty() and card10.is_truncated() and card10.get_text().length() <= AISidebarThinkingCard.MAX_DISPLAY_CHARS + 20:
		passed += 1
	else:
		failed += 1
		errors.append("T10 (thinking cap+empty) failed.")
	card10.queue_free()
	dock10.queue_free()

	# 11. Yeni LLM turu: sahte "Düşünülüyor" asistan balonu açılmaz (bekleme göstergesi balon değildir).
	# Gerçek thinking kartı cevabın ÜSTÜNDE kalır (önce düşünce, sonra cevap).
	var dock11 = _dock()
	dock11._stream.on_state_changed(AISidebarAgentRunner.AgentState.PLANNING, "")
	var placeholder_after_planning = 0
	for child in dock11.message_stream.get_children():
		if child is AISidebarMessageBubble:
			placeholder_after_planning += 1
	dock11._stream.on_chunk_received("", "Kullanıcı selam veriyor.")
	dock11._stream.on_chunk_received("Merhaba!", "")
	var t_idx = -1
	var b_idx = -1
	var live_idx = 0
	for child in dock11.message_stream.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is AISidebarThinkingCard and t_idx < 0:
			t_idx = live_idx
		if child is AISidebarMessageBubble and b_idx < 0:
			b_idx = live_idx
		live_idx += 1
	if placeholder_after_planning == 0 and t_idx == 0 and b_idx > t_idx:
		passed += 1
	else:
		failed += 1
		errors.append("T11 (thinking above answer, no placeholder) failed: planning_children=%d thinking=%d bubble=%d" % [placeholder_after_planning, t_idx, b_idx])
	dock11._stream.stop_thinking_timer()
	dock11.free()

	# 12. Metinsiz tool turu: akışta asılı kalan bekleme balonu yok
	var dock12 = _dock()
	dock12._stream.on_state_changed(AISidebarAgentRunner.AgentState.PLANNING, "")
	dock12._activity.on_tool_executing("read_script", {"path": "res://a.gd"})
	var stale = 0
	for child in dock12.message_stream.get_children():
		if child is AISidebarMessageBubble:
			stale += 1
	if stale == 0:
		passed += 1
	else:
		failed += 1
		errors.append("T12 (no stale waiting bubble) failed: bubbles=%d" % stale)
	dock12._stream.stop_thinking_timer()
	dock12.free()

	# 13. Bekleme göstergesi: PLANNING'de akışın sonunda görünür, süre ve uzun bekleyiş
	# ipucu güncellenir; ilk thinking geldiğinde kaybolur ve kart onun yerine oturur.
	var dock13 = _dock()
	dock13._stream.on_state_changed(AISidebarAgentRunner.AgentState.PLANNING, "")
	var ind13 = dock13._stream.pending_indicator
	var shown = ind13 != null and ind13.get_parent() == dock13.message_stream and ind13.get_index() == dock13.message_stream.get_child_count() - 1
	var waiting_txt = shown and ind13.get_text() == AISidebarI18n.get_text("pending_waiting")
	for i in AISidebarPendingIndicator.SLOW_HINT_AFTER_SEC:
		dock13._stream._on_thinking_tick()
	var ticked = shown and ("%ds" % AISidebarPendingIndicator.SLOW_HINT_AFTER_SEC) in ind13.get_text() and ind13.is_hint_visible()
	dock13._stream.on_chunk_received("", "Düşünüyorum.")
	var gone = dock13._stream.pending_indicator == null and ind13.is_queued_for_deletion()
	if shown and waiting_txt and ticked and gone and _thinking_cards(dock13).size() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("T13 (pending indicator lifecycle) failed: shown=%s text=%s ticked=%s gone=%s" % [str(shown), str(waiting_txt), str(ticked), str(gone)])
	dock13._stream.stop_thinking_timer()
	dock13.free()

	# 14. Metinsiz tool turu (grup zaten açık): tool başlayınca gösterge kalmaz
	var dock14 = _dock()
	dock14._activity.on_tool_executing("read_script", {"path": "res://a.gd"})
	dock14._stream.on_state_changed(AISidebarAgentRunner.AgentState.PLANNING, "")
	var had14 = dock14._stream.pending_indicator != null
	dock14._activity.on_tool_executing("read_script", {"path": "res://b.gd"})
	if had14 and dock14._stream.pending_indicator == null:
		passed += 1
	else:
		failed += 1
		errors.append("T14 (indicator cleared on tool start) failed: had=%s" % str(had14))
	dock14._stream.stop_thinking_timer()
	dock14.free()

	# 15. Yeniden deneme (RECOVERING) göstergeyi korur ve nedenini yazar; hata kaldırır
	var dock15 = _dock()
	dock15._stream.on_state_changed(AISidebarAgentRunner.AgentState.PLANNING, "")
	dock15._stream.on_state_changed(AISidebarAgentRunner.AgentState.RECOVERING, "Tekrar deneniyor")
	var ind15 = dock15._stream.pending_indicator
	var kept = ind15 != null and "Tekrar deneniyor" in ind15.get_text()
	dock15._stream.on_state_changed(AISidebarAgentRunner.AgentState.ERROR, "Bağlantı hatası")
	if kept and dock15._stream.pending_indicator == null:
		passed += 1
	else:
		failed += 1
		errors.append("T15 (recovering keeps, error clears) failed: kept=%s" % str(kept))
	dock15._stream.stop_thinking_timer()
	dock15.free()

	# 16. Runtime kartı modele giden teşhis metnini değil kısa özeti gösterir
	var obs16 = AISidebarRuntimeObservation.new()
	obs16.add_error("Invalid access to property 'SPEED' on a base object of type 'null instance'.", "res://player/player.gd", 14, "_physics_process")
	obs16.add_error("Second error", "res://enemy.gd", 3)
	var sum16 = AISidebarToolPresentation.runtime_error_summary(obs16)
	var dock16 = _dock()
	# Dock ağaçta değil: kartın _ready'si elle çalıştırılır (editörde add_child tetikler).
	dock16._activity.runtime_card = AISidebarRuntimeCard.new()
	dock16._activity.runtime_card._ready()
	dock16._activity.on_runtime_observation(obs16)
	var card_txt = ""
	for rt in dock16._activity.runtime_card._status_list.get_children():
		for c in rt.get_children():
			if c is RichTextLabel:
				card_txt += c.get_parsed_text()
	var crashed = AISidebarRuntimeObservation.new()
	crashed.status = AISidebarRuntimeObservation.RuntimeStatus.CRASHED
	if sum16 == "Runtime error: Invalid access to property 'SPEED' on a base object of type 'null instance'. — player.gd:14 (+1 more)" \
			and card_txt == sum16 and not "===" in card_txt \
			and AISidebarToolPresentation.runtime_error_summary(crashed).begins_with("Runtime error"):
		passed += 1
	else:
		failed += 1
		errors.append("T16 (runtime summary) failed: sum='%s' card='%s'" % [sum16, card_txt])
	dock16._activity.runtime_card.free()
	dock16.free()

	# 17. "Model ne yapıyor?" başlığı dil ayarından gelir
	var cfg_path = "res://addons/godot_sidebar_ai/config.json"
	var had_cfg = FileAccess.file_exists(cfg_path)
	var raw_cfg = FileAccess.get_file_as_string(cfg_path) if had_cfg else ""
	AISidebarI18n.set_language("en")
	var dock17 = _dock()
	dock17._stream.set_action_summary("Reading files")
	var rc17 = dock17._stream.reasoning_card
	rc17._ready()
	var en_header = rc17.get_header_text()
	if had_cfg:
		var f17 = FileAccess.open(cfg_path, FileAccess.WRITE)
		f17.store_string(raw_cfg)
		f17.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
	if en_header.ends_with("What is the model doing?"):
		passed += 1
	else:
		failed += 1
		errors.append("T17 (reasoning title i18n) failed: " + en_header)
	dock17.free()

	# 18. Uzun thinking (gerçek oturumda ~5000 karakter) ekranda ve transcript'te kesilmez.
	# Önceden kart 3000'de "…[truncated]" yazıyor, transcript ilk 1000 karakteri tutuyordu.
	var long_thought = ""
	for i in 100:
		long_thought += "Adım %d: sahneyi ve scripti değerlendiriyorum. " % i
	var dock18 = _dock()
	var chunk_size = 120
	for start in range(0, long_thought.length(), chunk_size):
		dock18._stream.on_chunk_received("", long_thought.substr(start, chunk_size))
	var tc18 = dock18._stream.thinking_card
	var card_full = tc18 != null and not tc18.is_truncated() and tc18.get_text() == long_thought
	dock18._stream.stop_thinking_timer()
	dock18.free()
	var ctx18 = AISidebarAgentContext.new()
	ctx18.begin_task("uzun düşünce", "")
	ctx18.add_assistant_tool_call_message("", [{"id": "c1", "name": "read_script", "arguments": {}}], long_thought)
	var stored = ""
	var stored_trunc = true
	for e in ctx18.get_transcript().get_current_task().get("events", []):
		if str(e.get("t", "")) == "tool_call":
			stored = str(e.get("data", {}).get("thinking", ""))
			stored_trunc = bool(e.get("data", {}).get("thinking_truncated", true))
	if long_thought.length() > 3000 and card_full and stored == long_thought and not stored_trunc:
		passed += 1
	else:
		failed += 1
		errors.append("T18 (long thinking kept) failed: len=%d card_full=%s stored_len=%d trunc=%s" % [long_thought.length(), str(card_full), stored.length(), str(stored_trunc)])

	# 19. Boşta rozeti onay modunu tekrar etmez: mod yalnızca model çubuğundaki butonda görünür
	var dock19 = _dock()
	dock19._stream.on_state_changed(AISidebarAgentRunner.AgentState.IDLE, "Ready")
	var badge_idle = dock19.status_badge.text
	dock19._stream.on_state_changed(AISidebarAgentRunner.AgentState.COMPLETED, "Completed")
	var badge_done = dock19.status_badge.text
	var mode_btn_txt = dock19.approve_mode_btn.text
	dock19.free()
	if badge_idle == "Ready" and badge_done == "Completed" and not mode_btn_txt.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T19 (badge without mode) failed: idle='%s' done='%s' btn='%s'" % [badge_idle, badge_done, mode_btn_txt])

	return {"name": "ReasoningUITests", "passed": passed, "failed": failed, "errors": errors}
