@tool
extends RefCounted

## History'den yüklenen oturumun akışa yeniden çizilmesi (replay) için DETERMINISTIK testler.
## Kapsar: yanıtlanmış ask_user kartı replay'i kesmez (regresyon: olmayan _input_container
## alanına erişim çöküyordu), kart salt-okunur görünür ve UI tek kez kurulur.

const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
const AISidebarClarificationCard = preload("res://addons/godot_sidebar_ai/ui/components/clarification_card.gd")

static func _kinds(stream: Node) -> Array:
	var out: Array = []
	for c in stream.get_children():
		out.append(c.get_script().resource_path.get_file().get_basename())
	return out

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	var dock = ChatDockScene.instantiate()
	dock._ready()
	dock._auto_scroll_enabled = false
	for c in dock.message_stream.get_children():
		c.free()

	var sess = AISidebarChatSession.new()
	sess.messages = [
		{"role": "user", "content": "Oyun yap"},
		{"role": "tool", "name": "ask_user", "content": JSON.stringify({"data": {"question": "2D mi 3D mi?", "user_answer": "3D"}})},
		{"role": "assistant", "content": "Tamam, 3D kuruyorum."},
	]
	dock._rebuild_ui_stream_from_session(sess)

	# 1. ask_user replay'i kesmez: kart ve sonraki asistan mesajı da çizilir
	var kinds = _kinds(dock.message_stream)
	if kinds == ["message_bubble", "clarification_card", "message_bubble"]:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (replay continues past ask_user) failed: " + str(kinds))

	# 2. Kart salt-okunur: ağaca girişi simüle et (_ready tek kez) -> giriş/seçenek gizli, cevap görünür
	var card = null
	for c in dock.message_stream.get_children():
		if c is AISidebarClarificationCard:
			card = c
	if card:
		card._ready()
		if card.is_answered and card.get_child_count() == 1 and not card._input_row.visible \
				and card._status_lbl.visible and card._status_lbl.text == "✓ Answered: 3D":
			passed += 1
		else:
			failed += 1
			errors.append("T2 (answered card view) failed: children=%d status='%s'" % [card.get_child_count(), card._status_lbl.text])
	else:
		failed += 1
		errors.append("T2 (answered card view) failed: no card.")

	dock.free()
	return {"name": "SessionReplayTests", "passed": passed, "failed": failed, "errors": errors}
