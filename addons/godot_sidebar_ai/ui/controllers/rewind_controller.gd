@tool
extends Node

## "Buraya geri dön": kullanıcı mesajının balonundaki düğme sohbeti o mesajdan önceki haline döndürür.
##   1. O mesajdan sonra ajanın uyguladığı dosya değişiklikleri (ChangeSet) sondan başa geri alınır.
##   2. Mesaj ve sonrası ajanın bağlamından, görev kaydından ve oturumdan silinir; akıştaki kartlar kalkar.
##   3. Mesajın metni giriş kutusuna döner; düzeltip yeniden gönderilir.
## Kayıt yalnız bu oturumda gönderilen mesajlar için tutulur (geçmişten yüklenen sohbette düğme çıkmaz).
## Sahne düzenlemeleri (düğüm ekleme vb.) ChangeSet değil, editörün Undo'sundadır: Ctrl+Z ile geri alınır.

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarChatSessionStore = preload("res://addons/godot_sidebar_ai/ui/controllers/chat_session_store.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

var context: AISidebarAgentContext = null
var sessions: AISidebarChatSessionStore = null
## Ajan çalışıyor mu (çalışırken geri dönülmez).
var is_busy: Callable = func() -> bool: return false
## Mesaj metnini giriş kutusuna koyar.
var set_input_text: Callable = func(_t: String) -> void: pass

var _applied: Array[AISidebarChangeSet] = []
var _checkpoints: Array[Dictionary] = []
var _confirm: ConfirmationDialog = null
var _pending_bubble: Control = null

func _init() -> void:
	name = "RewindController"

## Yeni sohbet / temizleme / geçmişten yükleme: kayıtlar sıfırlanır.
func reset() -> void:
	_applied.clear()
	_checkpoints.clear()

## AgentRunner.changes_applied: uygulanan her dosya değişikliği sırayla tutulur.
func on_changes_applied(cs: AISidebarChangeSet) -> void:
	if cs:
		_applied.append(cs)

## Kullanıcı mesajının balonu akışa eklendi (mesaj bağlama az önce eklendi, son mesaj odur).
func record(bubble: Control) -> void:
	if context == null or context.messages.is_empty():
		return
	_checkpoints.append({
		"bubble": bubble,
		"message": context.messages.back(),
		"change_count": _applied.size(),
		"task_count": maxi(0, context.get_transcript().tasks.size() - 1),
	})
	if bubble.has_method("enable_rewind"):
		bubble.call("enable_rewind", true)
	if bubble.has_signal("rewind_requested"):
		bubble.connect("rewind_requested", request)

## Balondaki düğme: onay ister (kaç dosya değişikliğinin geri alınacağını söyler).
func request(bubble: Control) -> void:
	var cp := _checkpoint_of(bubble)
	if cp.is_empty():
		return
	if is_busy.call():
		_notify(AISidebarI18n.get_text("rewind_busy"))
		return
	if _message_index(cp) < 0:
		_notify(AISidebarI18n.get_text("rewind_compacted"))
		return
	_pending_bubble = bubble
	var kept: int = cp["change_count"]
	if _confirm == null:
		_confirm = ConfirmationDialog.new()
		_confirm.theme = AISidebarSettingsUi.form_theme()
		_confirm.get_ok_button().theme_type_variation = AISidebarThemeBuilder.PRIMARY_BUTTON
		_confirm.get_cancel_button().theme_type_variation = AISidebarThemeBuilder.BUTTON
		_confirm.confirmed.connect(func() -> void:
			if is_instance_valid(_pending_bubble):
				rewind(_pending_bubble))
		add_child(_confirm)
	_confirm.title = AISidebarI18n.get_text("rewind_confirm_title")
	_confirm.ok_button_text = AISidebarI18n.get_text("rewind_confirm_ok")
	_confirm.cancel_button_text = AISidebarI18n.get_text("rewind_cancel")
	_confirm.dialog_text = AISidebarI18n.get_text("rewind_confirm_text", {"changes": _applied.size() - kept})
	_confirm.dialog_autowrap = true
	_confirm.popup_centered(Vector2i(AISidebarTheme.px(460), 0))

## Geri dönüşü uygular (onaysız; testler ve onay penceresi çağırır). Dönüş: {ok, undone_changes, error}.
func rewind(bubble: Control) -> Dictionary:
	var cp := _checkpoint_of(bubble)
	if cp.is_empty():
		return {"ok": false, "error": "no_checkpoint"}
	var idx := _message_index(cp)
	if idx < 0:
		return {"ok": false, "error": "compacted"}
	# 1. Dosya değişiklikleri: bu mesajdan sonrakiler, sondan başa.
	var keep_changes: int = cp["change_count"]
	var undone := 0
	while _applied.size() > keep_changes:
		var cs: AISidebarChangeSet = _applied.pop_back()
		cs.rollback()
		undone += 1
	# 2. Bağlam, görev kaydı, oturum.
	context.messages.resize(idx)
	var tasks: Array = context.get_transcript().tasks
	var keep_tasks: int = cp["task_count"]
	if tasks.size() > keep_tasks:
		tasks.resize(keep_tasks)
	if sessions:
		sessions.truncate_local_entries(idx)
		if sessions.current:
			sessions.current.checkpoint = {}
		sessions.save()
	# 3. Akış: balon ve sonrasındaki her şey; sonraki kayıtlar da düşer.
	var text: String = bubble.get("text_content")
	var parent := bubble.get_parent()
	if parent:
		var from := bubble.get_index()
		for i in range(parent.get_child_count() - 1, from - 1, -1):
			parent.get_child(i).queue_free()
	var pos := _checkpoints.find(cp)
	if pos >= 0:
		_checkpoints.resize(pos)
	set_input_text.call(text)
	return {"ok": true, "undone_changes": undone}

func _checkpoint_of(bubble: Control) -> Dictionary:
	for cp: Dictionary in _checkpoints:
		if is_same(cp["bubble"], bubble):
			return cp
	return {}

## Mesajın bağlamdaki yeri; sıkıştırmayla özete girdiyse -1.
func _message_index(cp: Dictionary) -> int:
	for i in context.messages.size():
		if is_same(context.messages[i], cp["message"]):
			return i
	return -1

func _notify(text: String) -> void:
	var d := AcceptDialog.new()
	d.theme = AISidebarSettingsUi.form_theme()
	d.dialog_text = text
	d.dialog_autowrap = true
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered(Vector2i(AISidebarTheme.px(420), 0))
