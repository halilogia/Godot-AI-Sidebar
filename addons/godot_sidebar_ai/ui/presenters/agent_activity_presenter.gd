@tool
extends RefCounted

## Ajanın iş adımlarının sunumu (SRP): activity grubu, tool çalıştırma / tamamlama satırları,
## doğrulama, runtime gözlemi, otomatik teşhis, adım ilerlemesi ve AI ekran görüntüsü
## önizlemesi. Her olay transcript'e de yazılır (export tek kaynaktan beslenir).
## Stream'e ekleme ve rozet ChatDock'tan callable ile; eylem özeti AgentStreamPresenter'dan.

const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarRuntimeCard = preload("res://addons/godot_sidebar_ai/ui/components/runtime_card.gd")
const AISidebarScreenshotCard = preload("res://addons/godot_sidebar_ai/ui/components/screenshot_card.gd")
const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarToolPresentation = preload("res://addons/godot_sidebar_ai/ui/presenters/tool_presentation.gd")
const AISidebarAgentStreamPresenter = preload("res://addons/godot_sidebar_ai/ui/presenters/agent_stream_presenter.gd")
const AISidebarPlanChecklistTracker = preload("res://addons/godot_sidebar_ai/ui/presenters/plan_checklist_tracker.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarMarkdownRenderer = preload("res://addons/godot_sidebar_ai/ui/presenters/markdown_renderer.gd")

## func(comp: Control) — bileşeni message stream'e ekler.
var add_component: Callable = func(_c): pass
## func(meta) — kartlardaki bağlantı tıklamaları.
var on_meta_clicked: Callable = func(_m): pass
## func(text: String, color: Color) — durum rozeti.
var set_status: Callable = func(_t, _c): pass
## func() -> bool — aktif provider görsel girdi destekliyor mu?
var supports_vision: Callable = func(): return false
## Eylem özeti ve balon ayrımı için akış sunucusu.
var stream: AISidebarAgentStreamPresenter = null
## Onaylı plan checklist'ini tool olaylarıyla ilerletir.
var checklist_tracker: AISidebarPlanChecklistTracker = null
## Transcript kaynağı olan AgentContext (headless testlerde null olabilir).
var context = null

var group: AISidebarActivityGroup = null
var runtime_card: AISidebarRuntimeCard = null
## Running satırının indeksi (tool_completed geldiğinde yerinde güncellenir, satır çoğalmaz).
var _running_idx: int = -1
var _running_tool: String = ""
var _tool_start_msec: int = 0

# --- Grup yaşam döngüsü ---

func ensure_group() -> AISidebarActivityGroup:
	if not group or not is_instance_valid(group) or not group.is_active:
		group = AISidebarActivityGroup.new(true)
		group.meta_clicked.connect(on_meta_clicked)
		add_component.call(group)
		_running_idx = -1
		_running_tool = ""
	return group

## Açık grubu tamamlar; sonraki tool yeni grup açar.
func close_group() -> void:
	if group:
		group.complete_group()
		group = null

## Tool araya kart soktu (soru / hata / task sonu): running satırı unutulur.
func clear_running() -> void:
	_running_idx = -1
	_running_tool = ""

## Yeni task: grup ve runtime kartı yeniden oluşturulur.
func begin_task() -> void:
	group = null
	runtime_card = null

## Akış temizlendi: tüm canlı durum sıfırlanır.
func reset() -> void:
	begin_task()
	clear_running()
	_tool_start_msec = 0

## Task bitti: varsa durma nedeni başlığa yazılır ve grup kapanır.
func finish_task(stop_reason: String) -> void:
	if group:
		if not stop_reason.is_empty():
			group.set_stop_reason(stop_reason)
		group.complete_group()
		group = null

## Task hata ile durdu. Limit hatasında durma satırı eklenir ve grup açık kalır.
func stop_on_error(err_msg: String) -> void:
	if group:
		if AISidebarToolPresentation.is_task_limit_error(err_msg):
			var grp = group
			grp.add_activity("✕", "Task stopped\nError: " + AISidebarActivityGroup.summarize_error(err_msg), 0, "stop_reason: " + err_msg.left(500))
			grp.set_stop_reason(err_msg)
			grp.complete_group_keep_open(true)
			# keep_open: limit satırı görünür kalsın diye grup referansı korunur,
			# sıradaki task yeni grup açar (ensure içinde is_active kontrolü yok;
			# task_completed / yeni executing yeni grup kurar).
		else:
			group.complete_group()
			group = null

# --- Tool olayları ---

func on_tool_executing(tool_name: String, args: Dictionary) -> void:
	stream.detach_bubble()
	# ask_user / propose_plan kart olarak gösterilir; activity satırı şişirmesin.
	if tool_name == "ask_user" or tool_name == "propose_plan":
		return
	var grp = ensure_group()
	grp.set_expanded(true)
	var human_title = AISidebarToolPresentation.human_title(tool_name, args)
	var details = "tool: " + tool_name + "\nargs: " + AISidebarActivityGroup.redact_secrets(JSON.stringify(args))
	if details.length() > 1500:
		details = details.left(1500) + "..."
	_running_tool = tool_name
	_tool_start_msec = Time.get_ticks_msec()
	_running_idx = grp.add_activity("▶", "Running " + human_title, -1, details)
	checklist_tracker.on_tool_start(tool_name, args)
	stream.set_action_summary(human_title)
	if context:
		context.get_transcript().record("tool_executing", {"tool": tool_name, "title": human_title.left(200), "args": AISidebarActivityGroup.redact_secrets(JSON.stringify(args)).left(800)})
		context.get_transcript().record("activity", {"icon": "▶", "title": "Running " + human_title.left(200)})

func on_tool_completed(tool_name: String, result: Dictionary) -> void:
	if tool_name == "ask_user" or tool_name == "propose_plan":
		return
	var grp = ensure_group()
	var err_code = ""
	if result.get("error") is Dictionary:
		err_code = str((result.get("error") as Dictionary).get("code", ""))
	var is_deferred = err_code.begins_with("DEFERRED")
	var outcome = AISidebarTaskTranscript.effective_tool_outcome(result)
	var is_ok = bool(outcome["success"])
	var icon = "•" if is_deferred else ("✓" if is_ok else "✕")
	var human_title = AISidebarToolPresentation.human_title(tool_name, {})
	var msg = str(result.get("message", "")).strip_edges()
	if not msg.is_empty() and msg.length() < 200 and not msg.contains("\"tool_calls\""):
		human_title = msg
	var elapsed = 100
	if _tool_start_msec > 0:
		elapsed = Time.get_ticks_msec() - _tool_start_msec
	_tool_start_msec = 0
	var err_summary = "" if is_ok else AISidebarToolPresentation.tool_error(result)
	var details = AISidebarToolPresentation.tech_details(tool_name, {}, result)
	if _running_idx >= 0 and _running_tool == tool_name and _running_idx < grp.get_item_count():
		grp.update_activity(_running_idx, icon, human_title, elapsed, details, err_summary)
	else:
		grp.add_activity(icon, human_title + ("" if is_ok else ("\nError: " + err_summary)), elapsed, details)
	_running_idx = -1
	_running_tool = ""
	var action_base = AISidebarToolPresentation.human_title(tool_name, {})
	var action_line = icon + " " + action_base
	if not msg.is_empty() and msg != action_base:
		action_line += " — " + str(msg.split("\n")[0]).left(120)
	stream.set_action_summary(action_line)
	# Ertelenen çağrı hiç çalışmadı: checklist'i kirletme, sadece activity'de göster.
	if not is_deferred:
		checklist_tracker.on_tool_done(tool_name, is_ok, err_summary)
	if context:
		var completed_data = {"tool": tool_name, "title": human_title.left(200), "success": is_ok, "error": err_summary.left(500), "duration_ms": elapsed}
		var shot_path = AISidebarToolPresentation.screenshot_image_path(tool_name, result)
		if not shot_path.is_empty():
			completed_data["has_image"] = true
			completed_data["image_path"] = shot_path.left(300)
		context.get_transcript().record("tool_completed", completed_data)
		context.get_transcript().record("activity", {"icon": icon, "title": (human_title + ("" if is_ok else (" — Error: " + err_summary))).left(300)})
	_show_screenshot_preview(tool_name, result)

## AI screenshot'u chatte thumbnail kart olarak gösterir.
func _show_screenshot_preview(tool_name: String, result: Dictionary) -> void:
	var shot_path = AISidebarToolPresentation.screenshot_image_path(tool_name, result)
	if shot_path.is_empty():
		return
	var data = result.get("data", {}) as Dictionary
	var vi = null
	if not str(data.get("base64", "")).is_empty():
		vi = AISidebarVisionInput.new(
			shot_path,
			str(data.get("base64", "")),
			int(data.get("width", 0)),
			int(data.get("height", 0))
		)
	else:
		vi = AISidebarVisionInput.from_file(shot_path)
	if vi == null or vi.image_data_base64.is_empty():
		return
	var kind = str(data.get("capture_target", ""))
	if kind.is_empty():
		if tool_name == "take_viewport_screenshot":
			kind = "editor_viewport"
		elif tool_name == "take_editor_screenshot":
			kind = "editor"
		else:
			kind = "runtime_viewport"
	var capable = bool(supports_vision.call())
	var card = AISidebarScreenshotCard.new(vi, kind, capable)
	card.meta_clicked.connect(on_meta_clicked)
	add_component.call(card)

# --- Doğrulama, runtime, teşhis, ilerleme ---

func on_verification_started(tool_name: String) -> void:
	var grp = ensure_group()
	grp.add_activity("•", "Verifying " + tool_name + "...", -1)
	stream.set_action_summary("Verifying " + tool_name)
	if context:
		context.get_transcript().record("verification_started", {"tool": tool_name})
		context.get_transcript().record("activity", {"icon": "▶", "title": "Verifying " + tool_name})

func on_verification_completed(tool_name: String, is_valid: bool, msg: String) -> void:
	var grp = ensure_group()
	var icon = "✓" if is_valid else "!"
	grp.add_activity(icon, "Verification: " + msg, 50)
	stream.set_action_summary((icon + " Verification: " + msg).split("\n")[0])
	if context:
		context.get_transcript().record("verification_completed", {"tool": tool_name, "valid": is_valid, "message": msg.left(500)})
		context.get_transcript().record("activity", {"icon": icon, "title": ("Verification: " + msg).left(300)})

func on_runtime_observation(obs: AISidebarRuntimeObservation) -> void:
	if not runtime_card:
		runtime_card = AISidebarRuntimeCard.new()
		runtime_card.meta_clicked.connect(on_meta_clicked)
		add_component.call(runtime_card)

	if obs.has_errors():
		runtime_card.add_status("✕", AISidebarMarkdownRenderer.escape_bbcode(AISidebarToolPresentation.runtime_error_summary(obs)), "#bf616a")
	else:
		runtime_card.add_status("✓", "No runtime errors detected", "#a3be8c")
	if context:
		context.get_transcript().record("runtime_observation", {"summary": obs.format_diagnostic_prompt().left(1000), "has_errors": obs.has_errors()})

func on_debugging_started(summary: String) -> void:
	var grp = ensure_group()
	grp.add_activity("•", "Auto-diagnosing runtime error: " + summary, -1)
	if context:
		context.get_transcript().record("debugging_started", {"summary": summary.left(500)})

func on_step_progress(current_step: int, max_steps: int) -> void:
	set_status.call("Step " + str(current_step) + " / " + str(max_steps), AISidebarTheme.COLOR_ACCENT)
	if group and is_instance_valid(group):
		group.set_step_progress(current_step, max_steps)
