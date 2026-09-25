extends SceneTree

## README görsellerini eklentinin GERÇEK arayüz bileşenlerinden üretir (SRP: yalnızca görsel).
## Dock sahnesi gerçek AgentRunner sinyalleriyle sürülür; modele bağlanılmaz, konuşma içeriği
## senaryoludur. Arayüz değiştiğinde görselleri yeniden üretmek için tekrar çalıştırın.
##
## Windows / macOS (pencere açılır, birkaç saniye sonra kapanır):
##   godot --path . -s res://tools/readme_shots.gd -- docs/media en
## Linux headless sunucu (sanal ekran gerekir):
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/readme_shots.gd -- docs/media en
##
## Argümanlar: <çıktı klasörü> <dil: en|tr>. config.json dili geçici değiştirilir ve
## bitince dosya birebir geri yazılır.

const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentHost = preload("res://addons/godot_sidebar_ai/core/agent/agent_host.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarImplementationPlan = preload("res://addons/godot_sidebar_ai/core/types/implementation_plan.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")

const WIDTH := 460

class SilentProvider extends AISidebarAIProvider:
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		pass

var _out_dir := "docs/media"
var _lang := "en"
var _sessions: Array = []

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	if args.size() > 1:
		_lang = args[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out_dir))
	_run.call_deferred()

func _run() -> void:
	# Tool süreleri geriye tarihlenir; işlem sayacı en uzun süreyi geçene kadar bekle.
	while Time.get_ticks_msec() < 4000:
		await process_frame
	var had_cfg = FileAccess.file_exists(AISidebarConfig.CONFIG_PATH)
	var raw_cfg = FileAccess.get_file_as_string(AISidebarConfig.CONFIG_PATH) if had_cfg else ""
	var cfg = AISidebarConfig.load_config()
	cfg["language"] = _lang
	cfg["auto_approve_mode"] = "MANUAL"
	AISidebarConfig.save_config(cfg)

	await _shot("hero", 740, true, _scenario_hero)
	await _shot("clarification", 0, false, _scenario_clarification)
	await _shot("approval", 0, false, _scenario_approval)
	await _shot("plan", 0, false, _scenario_plan)
	await _shot("runtime", 0, false, _scenario_runtime)

	if had_cfg:
		var f = FileAccess.open(AISidebarConfig.CONFIG_PATH, FileAccess.WRITE)
		f.store_string(raw_cfg)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AISidebarConfig.CONFIG_PATH))
	for id in _sessions:
		AISidebarChatManager.delete_session(id)
	quit()

## Bir senaryoyu yeni bir dock'ta oynatır ve PNG kaydeder. full=true tüm dock'u, false yalnızca
## sohbet akışının içeriğini kırpar.
func _shot(name: String, height: int, full: bool, scenario: Callable) -> void:
	root.size = Vector2i(WIDTH, height if height > 0 else 1400)
	var dock = ChatDockScene.instantiate()
	dock.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dock)
	await process_frame
	for c in dock.message_stream.get_children():
		c.free()
	var host = AISidebarAgentHost.new()
	host.set_provider(SilentProvider.new())
	dock.attach_agent_host(host)
	var ctx = host.context
	var runner = host.runner
	dock.sessions.start_new()
	dock.model_bar_controller.populate_model_selector(["deepseek/deepseek-v4-flash"])
	dock.update_ui_language()
	ctx.begin_task("", "")
	scenario.call(dock, runner)
	dock.stream.stop_thinking_timer()
	for i in 12:
		await process_frame
	var img = root.get_texture().get_image()
	if not full:
		var top = dock.message_stream.get_global_rect().position.y
		var bottom = top
		for c in dock.message_stream.get_children():
			if c is Control and c.visible and not c.is_queued_for_deletion():
				bottom = maxf(bottom, c.get_global_rect().end.y)
		img = img.get_region(Rect2i(0, int(top) - 4, WIDTH, int(bottom - top) + 12))
	var path = ProjectSettings.globalize_path("res://" + _out_dir.path_join(name + "_" + _lang + ".png"))
	img.save_png(path)
	print("saved ", path)
	_sessions.append(dock.sessions.current_id())
	dock.free()
	host.free()

func _t(en: String, tr: String) -> String:
	return tr if _lang == "tr" else en

# --- Senaryolar ---

func _scenario_hero(dock, r) -> void:
	r.text_received.emit("user", _t("Create a hexagon map system", "Hexagon harita sistemi oluştur"))
	r.state_changed.emit(AISidebarAgentRunner.AgentState.PLANNING, "")
	r.chunk_received.emit("", _t("\"Hexagon\" could mean a single mesh, a playable grid or a generator. That changes the architecture, so I should ask.", "\"Hexagon\" tek bir mesh, oynanabilir bir grid ya da üretici olabilir. Mimariyi değiştirir, sormalıyım."))
	r.clarification_requested.emit(_t("Before I build this, which did you mean?", "Başlamadan önce hangisini kastettin?"), [_t("Single hexagon object", "Tek hexagon nesnesi"), _t("Playable hex grid / map", "Oynanabilir hex grid / harita"), _t("Procedural map generator", "Prosedürel harita üretici")], "c1")
	_answer_last_clarification(dock, _t("Playable hex grid / map", "Oynanabilir hex grid / harita"))
	_tool(dock, r, "create_scene", {"scene_path": "res://maps/hex_map.tscn"}, _t("Created scene hex_map.tscn", "hex_map.tscn sahnesi oluşturuldu"), 380)
	_tool(dock, r, "create_or_update_script", {"file_path": "res://maps/hex_grid.gd"}, _t("Wrote hex_grid.gd (axial coordinates)", "hex_grid.gd yazıldı (axial koordinatlar)"), 1240)
	_tool(dock, r, "validate_script", {"file_path": "res://maps/hex_grid.gd"}, _t("GDScript is valid", "GDScript geçerli"), 210)
	_tool(dock, r, "play_game", {}, _t("Game ran with no runtime errors", "Oyun çalıştı, runtime hatası yok"), 2860)
	var answer = _t("Done. **hex_map.tscn** now builds a 12×12 axial hex grid from **hex_grid.gd**. Tiles highlight on hover; Ctrl+Z reverts every step.", "Tamam. **hex_map.tscn**, **hex_grid.gd** ile 12×12 axial hex grid kuruyor. Üzerine gelince kareler vurgulanıyor; Ctrl+Z her adımı geri alır.")
	r.chunk_received.emit(answer, "")
	r.text_received.emit("assistant", answer)
	r.task_completed.emit({"success": true, "elapsed_seconds": 41.6, "used_steps": 6, "max_steps": 20, "tools_sent": 12, "total_tools": 34, "tool_calls": 4, "file_ops": 2})
	# AgentRunner görev sonunda IDLE'a geçer (rozet "Hazır" olur).
	r.state_changed.emit(AISidebarAgentRunner.AgentState.IDLE, AISidebarI18n.get_text("status_ready"))
	_expand_activity(dock)

func _scenario_clarification(dock, r) -> void:
	r.text_received.emit("user", _t("Create a hexagon map system", "Hexagon harita sistemi oluştur"))
	r.clarification_requested.emit(_t("Before I build this, which did you mean?", "Başlamadan önce hangisini kastettin?"), [_t("Single hexagon object", "Tek hexagon nesnesi"), _t("Playable hex grid / map", "Oynanabilir hex grid / harita"), _t("Procedural map generator", "Prosedürel harita üretici")], "c1")

func _scenario_approval(dock, r) -> void:
	var old_src = "func _physics_process(delta):\n\tvelocity.x = Input.get_axis(\"left\", \"right\") * SPEED\n\tmove_and_slide()\n"
	var new_src = "func _physics_process(delta):\n\tvelocity.x = Input.get_axis(\"left\", \"right\") * SPEED\n\tif is_on_floor() and Input.is_action_just_pressed(\"jump\"):\n\t\tvelocity.y = JUMP_VELOCITY\n\tvelocity.y += gravity * delta\n\tmove_and_slide()\n"
	r.text_received.emit("user", _t("Add jumping to the player", "Oyuncuya zıplama ekle"))
	var cs = AISidebarChangeSet.new("res://player/player.gd", AISidebarChangeSet.ChangeType.MODIFY_FILE, new_src, old_src, _t("Add jump", "Zıplama ekle"))
	r.approval_requested.emit("replace_file_content", {"file_path": "res://player/player.gd"}, cs)
	dock.interaction._on_approve_pressed()
	r.changes_applied.emit(cs)
	r.approval_requested.emit("delete_file", {"file_path": "res://player/old_controller.gd"}, null)

func _scenario_plan(dock, r) -> void:
	r.text_received.emit("user", _t("Build an inventory system with a grid UI", "Grid arayüzlü bir envanter sistemi kur"))
	r.plan_proposed.emit(AISidebarImplementationPlan.new({
		"goal": _t("Grid inventory with drag & drop", "Sürükle-bırak destekli grid envanter"),
		"affected_files": ["res://inventory/inventory.gd", "res://inventory/inventory_ui.tscn", "res://inventory/slot.gd"],
		"steps": [_t("Create the Inventory resource and item data", "Inventory kaynağını ve eşya verisini oluştur"), _t("Build the grid UI scene with slots", "Slotlu grid arayüz sahnesini kur"), _t("Add drag & drop between slots", "Slotlar arası sürükle-bırak ekle")],
		"verification": [_t("Validate scripts, run the game, move an item", "Scriptleri doğrula, oyunu çalıştır, bir eşyayı taşı")],
	}))

func _scenario_runtime(dock, r) -> void:
	r.text_received.emit("user", _t("The player isn't moving.", "Oyuncu hareket etmiyor."))
	_tool(dock, r, "inspect_runtime_tree", {}, _t("Live tree: Main › Player (CharacterBody2D)", "Canlı ağaç: Main › Player (CharacterBody2D)"), 640)
	_tool(dock, r, "inspect_runtime_node", {"node_path": "Main/Player"}, _t("Player.velocity = (0, 0) while input is held", "Tuş basılıyken Player.velocity = (0, 0)"), 520)
	_tool(dock, r, "get_runtime_errors", {}, _t("1 runtime error found", "1 runtime hatası bulundu"), 330)
	var obs = AISidebarRuntimeObservation.new()
	obs.add_error("Invalid access to property 'SPEED' on a base object of type 'null instance'.", "res://player/player.gd", 14, "_physics_process")
	r.runtime_observation_received.emit(obs)
	var answer = _t("**player.gd:14** reads `SPEED` from `stats`, but `stats` is never assigned, so the movement line fails every frame. I'll export `stats` and assign it in **player.tscn**.", "**player.gd:14** `SPEED` değerini `stats` üzerinden okuyor ama `stats` hiç atanmamış; hareket satırı her karede hata veriyor. `stats`'ı export edip **player.tscn** içinde atayacağım.")
	r.text_received.emit("assistant", answer)
	_expand_activity(dock)

## Kullanıcının tıklayarak açtığı gibi activity adımlarını görünür yapar.
func _expand_activity(dock) -> void:
	for c in dock.message_stream.get_children():
		if c is AISidebarActivityGroup:
			c.set_expanded(true)

## Tool çalıştırma / tamamlama; süre (ms) önizleme için geriye tarihlenir.
func _tool(dock, r, tool: String, args: Dictionary, message: String, ms: int) -> void:
	r.tool_executing.emit(tool, args)
	dock.activity._tool_start_msec = Time.get_ticks_msec() - ms
	r.tool_completed.emit(tool, {"success": true, "data": {}, "message": message})

func _answer_last_clarification(dock, answer: String) -> void:
	var cards = dock.message_stream.get_children().filter(func(c): return c.has_method("show_as_answered"))
	if not cards.is_empty():
		cards[-1].show_as_answered(answer)
