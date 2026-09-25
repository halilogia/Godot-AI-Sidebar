@tool
extends Node

## Ajan cevap akışının sunumu (SRP): streaming asistan balonu, tool-call zarfı süzme,
## thinking / reasoning (eylem özeti) kartları, bekleme sayacı ve durum rozeti metni.
## Stream'e ekleme, rozet yazma ve kaydırma ChatDock'tan callable ile gelir.

signal answer_text_started

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarReasoningCard = preload("res://addons/godot_sidebar_ai/ui/components/reasoning_card.gd")
const AISidebarThinkingCard = preload("res://addons/godot_sidebar_ai/ui/components/thinking_card.gd")
const AISidebarPendingIndicator = preload("res://addons/godot_sidebar_ai/ui/components/pending_indicator.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

## func(comp: Control) — bileşeni message stream'e ekler.
var add_component: Callable = func(_c): pass
## func(meta) — kartlardaki bağlantı tıklamaları.
var on_meta_clicked: Callable = func(_m): pass
## func(text: String, color: Color) — durum rozeti.
var set_status: Callable = func(_t, _c): pass
## func() — kullanıcı en alttaysa akışı aşağı kaydırır.
var scroll_if_following: Callable = func(): pass

var assistant_bubble: AISidebarMessageBubble = null
var reasoning_card: AISidebarReasoningCard = null
var thinking_card: AISidebarThinkingCard = null
## Model yanıtı beklenirken akışın sonundaki canlı gösterge (ilk hayat belirtisinde kalkar).
var pending_indicator: AISidebarPendingIndicator = null
## Bir sonraki user balonuna eklenecek görseller (task başlatılırken doldurulur).
var user_vision_inputs: Array = []
## AGY alt sureci 'init' handshake'ini tamamlayana kadar true kalir.
## Yalnizca status rozeti metnini bilgilendirici yapar; thinking timer'i BOZMAZ.
var agy_preparing: bool = false

var _thinking_seen_this_turn: bool = false
var _stream_buffer: String = ""
var _thinking_timer: Timer = null
var _thinking_elapsed_sec: int = 0

func _init() -> void:
	name = "AgentStreamPresenter"

func _exit_tree() -> void:
	stop_thinking_timer()
	if _thinking_timer and is_instance_valid(_thinking_timer):
		_thinking_timer.queue_free()
		_thinking_timer = null

# --- Durum rozeti + bekleme sayacı ---

func on_state_changed(new_state: AISidebarAgentRunner.AgentState, state_desc: String) -> void:
	match new_state:
		AISidebarAgentRunner.AgentState.IDLE, AISidebarAgentRunner.AgentState.COMPLETED:
			stop_thinking_timer()
			set_status.call(state_desc, AISidebarTheme.COLOR_SUCCESS)
		AISidebarAgentRunner.AgentState.PLANNING:
			# Yeni LLM turu: thinking kartı sıfırlanır (sonraki thinking yeni kart açar),
			# rozet yanıt gelene kadar "Waiting" gösterir (thinking varsayılmaz).
			# Akışa yer tutucu balon eklenmez: gerçek thinking kartı cevabın üstünde kalmalı.
			_thinking_seen_this_turn = false
			thinking_card = null
			start_thinking_timer()
			set_status.call("Waiting...", AISidebarTheme.COLOR_WARNING)
			_show_pending()
		AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL:
			stop_thinking_timer()
			set_status.call("Waiting Approval", AISidebarTheme.COLOR_WARNING)
		AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL:
			stop_thinking_timer()
			set_status.call(AISidebarI18n.get_text("status_waiting_plan"), AISidebarTheme.COLOR_WARNING)
		AISidebarAgentRunner.AgentState.RUNNING_GAME:
			stop_thinking_timer()
			set_status.call("Running Game", AISidebarTheme.COLOR_ACCENT)
		AISidebarAgentRunner.AgentState.DEBUGGING:
			stop_thinking_timer()
			set_status.call("Debugging", AISidebarTheme.COLOR_ERROR)
		AISidebarAgentRunner.AgentState.ERROR:
			stop_thinking_timer()
			set_status.call(state_desc, AISidebarTheme.COLOR_ERROR)
		AISidebarAgentRunner.AgentState.RECOVERING:
			# Yeniden deneme: bekleyiş sürüyor, gösterge nedeni yazar.
			set_status.call(state_desc, AISidebarTheme.COLOR_WARNING)
			if _has_pending():
				pending_indicator.set_phase(state_desc, _thinking_elapsed_sec)
		_:
			_hide_pending()
			set_status.call(state_desc, AISidebarTheme.COLOR_WARNING)

func _setup_thinking_timer() -> void:
	if _thinking_timer != null:
		return
	_thinking_timer = Timer.new()
	_thinking_timer.wait_time = 1.0
	_thinking_timer.one_shot = false
	_thinking_timer.timeout.connect(_on_thinking_tick)
	add_child(_thinking_timer)

func start_thinking_timer() -> void:
	_setup_thinking_timer()
	_thinking_elapsed_sec = 0
	_thinking_timer.start()

func stop_thinking_timer() -> void:
	if _thinking_timer and is_instance_valid(_thinking_timer):
		_thinking_timer.stop()
	_thinking_elapsed_sec = 0
	_hide_pending()

func _on_thinking_tick() -> void:
	_thinking_elapsed_sec += 1
	# AGY 'init' handshake'i surerken durum rozetinde hazirlik bilgisi gosterilir.
	# Thinking timer DURDURULMAZ; yalnizca rozet metni degisir.
	if agy_preparing:
		set_status.call(AISidebarI18n.get_text("status_agy_preparing"), AISidebarTheme.COLOR_WARNING)
	elif _thinking_seen_this_turn:
		set_status.call("Thinking (%ds)..." % _thinking_elapsed_sec, AISidebarTheme.COLOR_WARNING)
	else:
		set_status.call("Waiting... (%ds)..." % _thinking_elapsed_sec, AISidebarTheme.COLOR_WARNING)
	if _has_pending():
		var phase_key = "pending_agy_preparing" if agy_preparing else "pending_waiting"
		pending_indicator.set_phase(AISidebarI18n.get_text(phase_key), _thinking_elapsed_sec)

# --- Bekleme göstergesi ---

func _has_pending() -> bool:
	return pending_indicator != null and is_instance_valid(pending_indicator)

func _show_pending() -> void:
	if _has_pending():
		return
	pending_indicator = AISidebarPendingIndicator.new()
	if agy_preparing:
		pending_indicator.set_phase(AISidebarI18n.get_text("pending_agy_preparing"), 0)
	add_component.call(pending_indicator)

func _hide_pending() -> void:
	if _has_pending():
		pending_indicator.queue_free()
	pending_indicator = null

## Akışa başka bir bileşen eklendi (thinking, cevap, activity, kart): bekleyiş bitti.
func on_component_added(comp: Control) -> void:
	if comp != pending_indicator:
		_hide_pending()

# --- Reasoning (eylem özeti) ve thinking kartları ---

## Canlı reasoning kartı (task başına tek; thinking yoksa oluşmaz).
func ensure_reasoning_card() -> AISidebarReasoningCard:
	if reasoning_card == null or not is_instance_valid(reasoning_card):
		reasoning_card = AISidebarReasoningCard.new()
		reasoning_card.meta_clicked.connect(on_meta_clicked)
		add_component.call(reasoning_card)
	return reasoning_card

## Eylem özeti yaz (ham reasoning asla karta girmez).
func set_action_summary(line: String) -> void:
	if line == null or line.strip_edges().is_empty():
		return
	ensure_reasoning_card().set_action(line.strip_edges().left(300))

## İsteğe bağlı thinking kartı (LLM turu başına bir; thinking yoksa oluşmaz).
func ensure_thinking_card() -> AISidebarThinkingCard:
	if thinking_card == null or not is_instance_valid(thinking_card):
		thinking_card = AISidebarThinkingCard.new()
		thinking_card.meta_clicked.connect(on_meta_clicked)
		add_component.call(thinking_card)
	return thinking_card

func on_thinking_received(thinking: String) -> void:
	if thinking == null or thinking.strip_edges().is_empty():
		return
	_hide_pending()
	_thinking_seen_this_turn = true
	set_status.call("Thinking...", AISidebarTheme.COLOR_WARNING)
	# Stream dışı final thinking: kart boşsa doldur (delta'larla duplicate olmaz).
	ensure_thinking_card().set_thinking_final(thinking)

# --- Cevap akışı ---

func on_chunk_received(text_delta: String, thinking_delta: String) -> void:
	stop_thinking_timer()
	if thinking_delta != null and not thinking_delta.strip_edges().is_empty():
		_thinking_seen_this_turn = true
		set_status.call("Thinking...", AISidebarTheme.COLOR_WARNING)
		ensure_thinking_card().append_thinking(thinking_delta)
	if text_delta.is_empty():
		return

	answer_text_started.emit()

	_stream_buffer += text_delta
	_render_stream_buffer()

## Tampondaki metinden tool-call zarflarini cikarip gorunur kismi balona yazar.
## Gorunur metin yoksa (saf zarf veya henuz yarim JSON) balon hic gosterilmez.
func _render_stream_buffer() -> void:
	var visible := AISidebarMessageBubble.strip_tool_call_envelopes(_stream_buffer, true).strip_edges()
	if visible.is_empty():
		# Saf zarf / yarim JSON: kullaniciya hicbir sey gosterme.
		if assistant_bubble != null and is_instance_valid(assistant_bubble):
			assistant_bubble.queue_free()
			assistant_bubble = null
		return
	if assistant_bubble != null and is_instance_valid(assistant_bubble):
		assistant_bubble.set_message("assistant", visible)
	else:
		assistant_bubble = AISidebarMessageBubble.new("assistant", visible)
		assistant_bubble.meta_clicked.connect(on_meta_clicked)
		add_component.call(assistant_bubble)
	set_status.call("AI Typing...", AISidebarTheme.COLOR_WARNING)
	scroll_if_following.call()

## Akış tamponunu sıfırla (yeni metin turu / temizleme).
func reset_stream_buffer() -> void:
	_stream_buffer = ""

func on_text_received(role: String, text: String) -> void:
	_hide_pending()
	answer_text_started.emit()

	if role == "assistant":
		# Ham tool-call zarflari metinden cikarilir; kullanici yalnizca gercek
		# asistan metnini gorur. Zarf hic yoksa metin aynen korunur.
		var clean_text := AISidebarMessageBubble.strip_tool_call_envelopes(text, false).strip_edges()
		if clean_text.is_empty():
			# Metnin tamami zarf (veya yarim JSON): hicbir sey gosterme.
			if assistant_bubble != null and is_instance_valid(assistant_bubble):
				assistant_bubble.queue_free()
			assistant_bubble = null
			reset_stream_buffer()
			return
		if assistant_bubble != null and is_instance_valid(assistant_bubble):
			assistant_bubble.finalize_stream(clean_text)
			assistant_bubble = null
		else:
			var bubble = AISidebarMessageBubble.new(role, clean_text)
			bubble.meta_clicked.connect(on_meta_clicked)
			add_component.call(bubble)
		reset_stream_buffer()
	else:
		assistant_bubble = null
		reset_stream_buffer()
		var bubble_role = role
		if bubble_role == "user" and text.begins_with("/"):
			bubble_role = "command"
		var vi_for_bubble = user_vision_inputs.duplicate() if bubble_role == "user" else []
		user_vision_inputs.clear()
		var bubble = AISidebarMessageBubble.new(bubble_role, text, vi_for_bubble)
		bubble.meta_clicked.connect(on_meta_clicked)
		add_component.call(bubble)

# --- Yaşam döngüsü ---

## Tool / kart araya girdi: sonraki metin yeni balon açar.
func detach_bubble() -> void:
	assistant_bubble = null
	_hide_pending()

## Yeni task: eylem özeti ve thinking kartı yeniden oluşturulur.
func begin_task() -> void:
	reasoning_card = null
	thinking_card = null

## Task bitti / hata: canlı kart referansları bırakılır (kartlar akışta kalır).
func end_task() -> void:
	assistant_bubble = null
	reasoning_card = null
	thinking_card = null
	_hide_pending()

## Akış temizlendi: tüm canlı durum sıfırlanır.
func reset() -> void:
	end_task()
	_thinking_seen_this_turn = false
	reset_stream_buffer()
