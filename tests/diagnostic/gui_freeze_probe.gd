@tool
extends SceneTree

## GUI'siz (Headless) Freeze Teshis Probu.
##
## AMAC: 'LLM_REQUEST_START' logundan ONCE gerceklesen ve Godot UI'i
## bloklayan senkron cagrilari tek tek olcup suclu fonksiyonu tespit etmek.
##
## Kullanim:
##   godot --headless --path . -s "res://tests/diagnostic/gui_freeze_probe.gd"
##
## NOT: Bu prob EditorInterface gerektirmez; editor-dock UI maliyetini OLCMEZ.
##      Olctugu sey: TASK_START -> LLM_REQUEST_START arasindaki
##      motor-tarafi (config/i18n/sema/persist/compaction) senkron maliyettir.

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
const AISidebarMentionManager = preload("res://addons/godot_sidebar_ai/core/chat/mention_manager.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarContextCompactor = preload("res://addons/godot_sidebar_ai/core/agent/context_compactor.gd")
const AISidebarEditorStateSnapshot = preload("res://addons/godot_sidebar_ai/core/state/editor_state_snapshot.gd")

const ITERS := 20

var _rows: Array = []

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  GUI-FREEZE DIAGNOSTIC PROBE (HEADLESS)                        #")
	print("#  Hedef: LLM_REQUEST_START ONCESI senkron blokaj suclusu         #")
	print("##################################################################")
	print("")

	_phase_config()
	_phase_i18n()
	_phase_session_persist()
	_phase_mention()
	_phase_schemas()
	_phase_context()
	_phase_permission()

	_print_summary()
	quit(0)

# ------------------------------------------------------------------ helpers

func _bench(label: String, f: Callable, iters: int = ITERS) -> int:
	# Isinma (warm-up): ilk cagri disk/cache etkisini yaniltici sekilde buyutur
	f.call()

	var best := -1
	var total := 0
	for i in range(iters):
		var t0 := Time.get_ticks_usec()
		f.call()
		var dt := Time.get_ticks_usec() - t0
		total += dt
		if best < 0 or dt < best:
			best = dt

	var avg := total / iters
	_rows.append({"label": label, "avg_us": avg, "best_us": best})
	var avg_ms := avg / 1000.0
	var flag := ""
	if avg_ms >= 100.0:
		flag = "   <== PAHALI"
	elif avg_ms >= 20.0:
		flag = "   <-- dikkat"
	print("  %-46s avg=%8.3f ms  best=%8.3f ms  (x%d)%s"
		% [label, avg_ms, best / 1000.0, iters, flag])
	return avg

func _section(title: String) -> void:
	print("")
	print("-- " + title + " " + "-".repeat(maxi(0, 62 - title.length())))

# ------------------------------------------------------------------ phases

func _phase_config() -> void:
	_section("1. CONFIG (AISidebarConfig.load_config -> dosya oku + JSON parse)")
	_bench("AISidebarConfig.load_config()", func(): AISidebarConfig.load_config())
	# Config icindeki system_prompt buyuk; save maliyetini de gorelim
	var cfg := AISidebarConfig.load_config()
	print("      system_prompt uzunlugu: %d karakter" % str(cfg.get("system_prompt", "")).length())
	print("      provider_type: %s | selected_model: %s"
		% [str(cfg.get("provider_type", "")), str(cfg.get("selected_model", ""))])

func _phase_i18n() -> void:
	_section("2. i18n (update_ui_language HER state degisiminde cagriliyor)")
	_bench("AISidebarI18n.get_current_language()", func(): AISidebarI18n.get_current_language())
	_bench("AISidebarI18n.get_text('app_title')", func(): AISidebarI18n.get_text("app_title"))

	# update_ui_language() icinde gerceklesen cagri sayisini taklit et.
	# chat_dock.gd update_ui_language() ~20 farkli anahtar okuyor.
	var keys := [
		"history_title", "history_btn_new", "app_title", "tooltip_model",
		"tooltip_refresh", "tooltip_settings", "input_placeholder", "btn_clear",
		"mode_manual", "tooltip_approve_mode", "mode_auto", "status_ready"
	]
	_bench("update_ui_language() ~12 get_text (taklit)", func():
		for k in keys:
			AISidebarI18n.get_text(k)
	, ITERS)

func _phase_session_persist() -> void:
	_section("3. OTURUM KAYDI (_start_task_prompt -> _save_current_session)")
	var sess = AISidebarChatSession.new()
	# Gercekci bir gecmis: 20 mesaj (agent_context tipik doluluk)
	for i in range(20):
		sess.messages.append({"role": "user", "content": "mesaj %d - biraz daha uzun icerik testi" % i})
		sess.messages.append({"role": "assistant", "content": "yanit %d - biraz daha uzun icerik testi" % i})
	_bench("auto_title_from_first_message()", func(): sess.auto_title_from_first_message())
	_bench("ChatManager.save_session(40 mesaj)", func(): AISidebarChatManager.save_session(sess))
	_bench("ChatManager.list_sessions()", func(): AISidebarChatManager.list_sessions())

func _phase_mention() -> void:
	_section("4. MENTION (resolve_prompt_context)")
	_bench("resolve_prompt_context(mention YOK)", func():
		AISidebarMentionManager.resolve_prompt_context("Bir dusman sistemi kur ve test et")
	, ITERS)
	_bench("detect_mention_query()", func():
		AISidebarMentionManager.detect_mention_query("@pl", 3)
	, ITERS)
	# @mention VAR ise: proje taramasi + dosya okuma tetiklenir (agir olabilir)
	var probe_target := ""
	if FileAccess.file_exists("res://project.godot"):
		probe_target = "@project.godot dosyasini ozetle"
	if not probe_target.is_empty():
		_bench("resolve_prompt_context(mention VAR)", func():
			AISidebarMentionManager.resolve_prompt_context(probe_target)
		, 5)

func _phase_schemas() -> void:
	_section("5. ARAC SEMALARI (_run_next_step -> get_relevant_schemas)")
	_bench("ToolManager.get_all_schemas()", func(): AISidebarToolManager.get_all_schemas())
	_bench("get_relevant_schemas('dusman sistemi kur')", func():
		AISidebarToolManager.get_relevant_schemas("Bir dusman sistemi kur ve test et")
	)
	_bench("get_relevant_schemas('script yaz kod')", func():
		AISidebarToolManager.get_relevant_schemas("script yaz kod olustur")
	)
	var all_s := AISidebarToolManager.get_all_schemas()
	var rel_s := AISidebarToolManager.get_relevant_schemas("Bir dusman sistemi kur")
	print("      toplam sema: %d | filtrelenen: %d" % [all_s.size(), rel_s.size()])

func _phase_context() -> void:
	_section("6. BAGLAM (add_user_message + get_messages_for_api)")
	var ctx = AISidebarAgentContext.new()
	_bench("context.add_user_message()", func(): ctx.add_user_message("test", false, "test", []))
	# Gercekci doluluk + grounding + compaction yolu
	var ctx2 = AISidebarAgentContext.new()
	for i in range(18):
		ctx2.messages.append({"role": "assistant", "content": "x".repeat(400)})
		ctx2.messages.append({"role": "tool", "name": "read_script", "tool_call_id": "c%d" % i, "content": "{\"status\":\"ok\",\"result\":{\"file_path\":\"res://a.gd\",\"line_count\":42}}"})
	_bench("EditorStateSnapshot.get_grounding_prompt_text()", func():
		AISidebarEditorStateSnapshot.get_grounding_prompt_text()
	)
	_bench("context.get_messages_for_api()", func(): ctx2.get_messages_for_api())
	_bench("ContextCompactor.compact_messages()", func():
		AISidebarContextCompactor.compact_messages(ctx2.messages, 2)
	)

func _phase_permission() -> void:
	_section("7. YETKI (PermissionPolicy)")
	_bench("PermissionPolicy.get_auto_approve_mode()", func():
		AISidebarPermissionPolicy.get_auto_approve_mode()
	)
	_bench("requires_user_approval('create_or_update_script')", func():
		AISidebarPermissionPolicy.requires_user_approval("create_or_update_script", {"file_path": "res://yeni_dosya.gd"})
	)

# ------------------------------------------------------------------ summary

func _print_summary() -> void:
	print("")
	print("##################################################################")
	print("#  OZET - EN PAHALI 10 SENKRON CAGRILAR (LLM oncesi yol)           #")
	print("##################################################################")
	var sorted_rows := _rows.duplicate()
	sorted_rows.sort_custom(func(a, b): return a["avg_us"] > b["avg_us"])
	var n := mini(10, sorted_rows.size())
	for i in range(n):
		var r: Dictionary = sorted_rows[i]
		print("  %2d. %-46s %10.3f ms" % [i + 1, r["label"], r["avg_us"] / 1000.0])
	print("")
	var budget_us := 0
	for r in _rows:
		budget_us += r["avg_us"]
	print("  Tek seferlik toplam (tum olculen cagrilar): %.2f ms" % (budget_us / 1000.0))
	print("  NOT: Bu toplam, gercek akista BAZI cagrilarin birden fazla")
	print("       tetiklenmesini (state_changed -> update_ui_language) ICERMEZ.")
	print("##################################################################")
