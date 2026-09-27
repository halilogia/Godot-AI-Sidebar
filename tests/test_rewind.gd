@tool
extends RefCounted

## "Buraya geri dön": mesajdan sonraki dosya değişikliği geri alınır, bağlam ve görev kaydı mesajdan
## öncesine kısalır, akışta balon ve sonrası kalkar, metin giriş kutusuna döner; önceki mesaj etkilenmez.

const AISidebarRewindController = preload("res://addons/godot_sidebar_ai/ui/controllers/rewind_controller.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")

const FILE := "res://tests/tmp_rewind_file.txt"

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	var ctx := AISidebarAgentContext.new()
	var rw := AISidebarRewindController.new()
	rw.context = ctx
	var restored := [""]
	rw.set_input_text = func(t: String) -> void: restored[0] = t
	var stream := VBoxContainer.new()

	# Mesaj 1 (korunacak), sonra mesaj 2 + onun dosya değişikliği.
	ctx.begin_task("birinci", "")
	ctx.add_user_message("birinci")
	var b1 := AISidebarMessageBubble.new("user", "birinci")
	stream.add_child(b1)
	rw.record(b1)
	ctx.add_assistant_message("tamam")

	ctx.begin_task("ikinci", "")
	ctx.add_user_message("ikinci")
	var b2 := AISidebarMessageBubble.new("user", "ikinci")
	stream.add_child(b2)
	rw.record(b2)
	var cs := AISidebarChangeSet.new(FILE, AISidebarChangeSet.ChangeType.CREATE_FILE, "yeni", "", "test")
	cs.apply()
	rw.on_changes_applied(cs)
	ctx.add_assistant_message("dosya yazıldı")
	var card := Label.new()
	stream.add_child(card)

	var file_before := FileAccess.file_exists(FILE)
	var res := rw.rewind(b2)
	var file_after := FileAccess.file_exists(FILE)
	var msgs_ok := ctx.messages.size() == 2 and str(ctx.messages[0].get("content", "")) == "birinci"
	var tasks_ok := ctx.get_transcript().tasks.size() == 1
	var ui_ok := b2.is_queued_for_deletion() and card.is_queued_for_deletion() and not b1.is_queued_for_deletion()
	if res.get("ok") == true and int(res.get("undone_changes", 0)) == 1 and file_before and not file_after and msgs_ok and tasks_ok and ui_ok and restored[0] == "ikinci":
		passed += 1
	else:
		failed += 1
		errors.append("T1 rewind: res=%s file=%s->%s msgs=%d tasks=%d ui=%s text=%s" % [res, file_before, file_after, ctx.messages.size(), ctx.get_transcript().tasks.size(), ui_ok, restored[0]])

	# T2 Sıkıştırmayla özete giren mesaja dönülmez.
	var ctx2 := AISidebarAgentContext.new()
	var rw2 := AISidebarRewindController.new()
	rw2.context = ctx2
	ctx2.add_user_message("eski")
	var old_bubble := AISidebarMessageBubble.new("user", "eski")
	rw2.record(old_bubble)
	ctx2.messages = [{"role": "user", "content": "[ÖNCEKİ AJAN GÖREV ÖZETİ (1 adım)]"}]
	if rw2.rewind(old_bubble).get("error") == "compacted":
		passed += 1
	else:
		failed += 1
		errors.append("T2 compacted message must not rewind")

	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	for n: Node in [b1, b2, card, old_bubble, rw, rw2, stream]:
		if is_instance_valid(n):
			n.free()
	return {"name": "RewindTests", "passed": passed, "failed": failed, "errors": errors}
