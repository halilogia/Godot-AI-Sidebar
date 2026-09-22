@tool
extends SceneTree

## FAZ A - GERCEK FONKSIYON MALIYET PROBU (Simulasyon DEGIL)
##
## AMAC:
##   LLM_REQUEST_START oncesinde ana thread'i bekletebilecek HER gercek fonksiyonu
##   tek tek olcup hangisinin 10s mertebesinde oldugunu bulmak.
##
## ONCEKI PROBLARIN HATASI:
##   gui_freeze_probe.gd "update_ui_language (simulated)" gibi yaklasik degerler olctu.
##   Bu prob ise GERCEK siniflari cagirir: gercek config okuma, gercek i18n,
##   gercek SVG yukleme, gercek proje taramasi, gercek araç semasi uretimi.
##
## NOT: Engine.is_editor_hint() headless'te false oldugu icin EditorInterface'e
##      bagli yollar (mention node scan, settings dialog) erken doner. Bu,
##      editor ortamina gore DAHA IYIMSER (daha hizli) bir sonuc verir.

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarMentionManager = preload("res://addons/godot_sidebar_ai/core/chat/mention_manager.gd")
const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")

const SAMPLE_PROMPT := "dusman sistemi kur ve oyuncuya saldiran 3 tane slime ekle @res://project.godot"
const SAMPLE_TOOLS_COUNT := 12

var _t0: int = 0
var _section_start: int = 0

func _stamp() -> int:
	return Time.get_ticks_usec()

func _mark(label: String) -> void:
	var now = _stamp()
	print("  %-50s : %9.3f ms" % [label, (now - _t0) / 1000.0])
	_t0 = now

func _reset() -> void:
	_t0 = _stamp()

func _section(title: String) -> void:
	print("")
	print("-- %s %s" % [title, "-".repeat(maxi(1, 62 - title.length()))])
	_section_start = _stamp()
	_t0 = _section_start

func _section_end() -> void:
	print("  %-50s : %9.3f ms  <= BOLUM TOPLAMI" % ["", (_stamp() - _section_start) / 1000.0])

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  FAZ A - GERCEK FONKSIYON MALIYET PROBU                          #")
	print("#  (LLM_REQUEST_START ONCESI ANA THREAD YOLU)                    #")
	print("##################################################################")

	_test_config_io()
	_test_i18n_real()
	_test_icon_real()
	_test_mention_scan_real()
	_test_slash_real()
	_test_schemas_real()
	_test_permission_real()
	_test_full_phase_a_chain()

	_print_verdict()
	quit(0)

# ---------------------------------------------------------------- 1. Config I/O

func _test_config_io() -> void:
	_section("1. CONFIG DISK I/O (load_config her cagride dosya okur)")
	# Soguk okuma
	_reset()
	var cfg = AISidebarConfig.load_config()
	_mark("load_config() [COLD]")
	print("      -> provider_type=%s selected_model=%s" % [str(cfg.get("provider_type", "?")), str(cfg.get("selected_model", "?"))])

	# Sicak 1
	_reset()
	cfg = AISidebarConfig.load_config()
	_mark("load_config() [WARM #1]")

	# Ardisik 12 okuma = update_ui_language() maliyetinin gercek bileşeni
	_reset()
	for i in range(12):
		cfg = AISidebarConfig.load_config()
	_mark("load_config() x12 (ardisik, sicak)")
	_section_end()

# ---------------------------------------------------------------- 2. i18n GERCEK

func _test_i18n_real() -> void:
	_section("2. i18n get_text() GERCEK (her cagri load_config yapar)")
	var keys: Array[String] = [
		"app_title", "history_title", "history_btn_new", "tooltip_model",
		"tooltip_refresh", "tooltip_settings", "input_placeholder",
		"btn_clear", "tooltip_approve_mode", "mode_manual",
		"tooltip_lang", "status_ready"
	]

	_reset()
	var first = AISidebarI18n.get_text(keys[0])
	_mark("get_text('%s') [COLD]" % keys[0])
	print("      -> \"%s\"" % first)

	# update_ui_language() gercekte ~12 get_text cagirir
	_reset()
	for k in keys:
		var _v = AISidebarI18n.get_text(k)
	_mark("get_text() x12 (update_ui_language esdegeri)")

	# 100 cagri -> dogrusal mi?
	_reset()
	for i in range(100):
		var _v = AISidebarI18n.get_text(keys[i % keys.size()])
	_mark("get_text() x100")
	_section_end()

# ---------------------------------------------------------------- 3. Ikon GERCEK

func _test_icon_real() -> void:
	_section("3. SVG IKON YUKLEME GERCEK (icon_helper)")
	var names: Array[String] = ["download", "history", "refresh", "settings", "trash", "send", "stop", "plus", "menu"]
	var btn := Button.new()

	_reset()
	var total_cold := 0
	for n in names:
		total_cold += 1
		AISidebarIconHelper.apply_icon(btn, n)
	_mark("apply_icon() x%d [COLD, gercek SVG]" % names.size())

	_reset()
	for n in names:
		AISidebarIconHelper.apply_icon(btn, n)
	_mark("apply_icon() x%d [WARM, cache'ten]" % names.size())

	btn.free()
	_section_end()

# ---------------------------------------------------------------- 4. Mention GERCEK

func _test_mention_scan_real() -> void:
	_section("4. MENTION PROJE TARAMASI GERCEK (her '@' tusunda calisir)")

	_reset()
	var sug = AISidebarMentionManager.get_suggestions("")
	_mark("get_suggestions('') [COLD - TUM PROJE TARAMASI]")
	print("      -> %d sonuc (max_results=10 sinirina takilir)" % sug.size())

	_reset()
	sug = AISidebarMentionManager.get_suggestions("")
	_mark("get_suggestions('') [WARM #1]")

	_reset()
	sug = AISidebarMentionManager.get_suggestions("")
	_mark("get_suggestions('') [WARM #2]")

	# 10 ardisik = kullanicinin '@' yazip 10 karakter yazmasi senaryosu
	_reset()
	for i in range(10):
		var _s = AISidebarMentionManager.get_suggestions("a")
	_mark("get_suggestions('a') x10 (yazarken)")

	# resolve_prompt_context (gorev baslatilirken 1 kez)
	_reset()
	var r_no = AISidebarMentionManager.resolve_prompt_context("dusman sistemi kur")
	_mark("resolve_prompt_context() [mention YOK]")

	_reset()
	var r_yes = AISidebarMentionManager.resolve_prompt_context(SAMPLE_PROMPT)
	_mark("resolve_prompt_context() [mention VAR]")
	_section_end()

# ---------------------------------------------------------------- 5. Slash GERCEK

func _test_slash_real() -> void:
	_section("5. SLASH COMMAND GERCEK (her tus vurusunda)")
	_reset()
	var q = AISidebarSlashCommandManager.detect_slash_query("dusman sistemi kur", 17)
	_mark("detect_slash_query() [slash YOK]")

	_reset()
	q = AISidebarSlashCommandManager.detect_slash_query("/he", 3)
	_mark("detect_slash_query() [slash VAR]")

	_reset()
	var s = AISidebarSlashCommandManager.get_suggestions("he")
	_mark("get_suggestions('he')  -> %d adet" % s.size())

	_reset()
	for i in range(20):
		var _q = AISidebarSlashCommandManager.detect_slash_query("merhaba dunya test " + str(i), 20)
	_mark("detect_slash_query() x20 (yazarken)")
	_section_end()

# ---------------------------------------------------------------- 6. Tool Semalari

func _test_schemas_real() -> void:
	_section("6. ARAC SEMA URETIMI GERCEK (her LLM adiminda)")
	_reset()
	var all = AISidebarToolManager.get_all_schemas()
	_mark("get_all_schemas() [COLD] -> %d sema" % all.size())

	_reset()
	all = AISidebarToolManager.get_all_schemas()
	_mark("get_all_schemas() [WARM #1] -> %d sema" % all.size())

	_reset()
	for i in range(5):
		var _a = AISidebarToolManager.get_all_schemas()
	_mark("get_all_schemas() x5")

	var ctx_text = " dusman sistemi kur ve oyuncuya saldiran 3 tane slime ekle"
	_reset()
	var rel = AISidebarToolManager.get_relevant_schemas(ctx_text, [])
	_mark("get_relevant_schemas() -> %d/%d" % [rel.size(), all.size()])

	# JSON.stringify gercek maliyeti (LLM_REQUEST_START'tan hemen once)
	_reset()
	var js = JSON.stringify(rel)
	_mark("JSON.stringify(semalar) -> %d karakter" % js.length())
	_section_end()

# ---------------------------------------------------------------- 7. Permission

func _test_permission_real() -> void:
	_section("7. PERMISSION POLICY GERCEK")
	_reset()
	var m = AISidebarPermissionPolicy.get_auto_approve_mode()
	_mark("get_auto_approve_mode() -> %s" % str(m))

	_reset()
	var a = AISidebarPermissionPolicy.requires_user_approval("create_or_update_script")
	_mark("requires_user_approval('create_or_update_script') -> %s" % str(a))

	_reset()
	var a2 = AISidebarPermissionPolicy.requires_user_approval("delete_file")
	_mark("requires_user_approval('delete_file') -> %s" % str(a2))
	_section_end()

# ---------------------------------------------------------------- 8. TAM ZINCIR

func _test_full_phase_a_chain() -> void:
	_section("8. TAM FAZ-A ZINCIRI (gercek fonksiyonlarla, tek seferde)")
	print("  Olculen: _hide_welcome -> save -> resolve_ctx -> start_task ->")
	print("           get_relevant_schemas -> JSON.stringify -> (LLM_REQUEST_START oncesi)")

	var grand_start := _stamp()
	_t0 = grand_start

	# 1) update_ui_language benzeri (state_changed sinyalinde cagrilir)
	var keys: Array[String] = ["app_title", "history_title", "history_btn_new", "tooltip_model", "tooltip_refresh", "tooltip_settings", "input_placeholder", "btn_clear", "tooltip_approve_mode", "mode_manual", "tooltip_lang", "status_ready"]
	var btn := Button.new()
	for k in keys:
		var _v = AISidebarI18n.get_text(k)
	var icons: Array[String] = ["download", "history", "refresh", "settings", "trash", "send"]
	for n in icons:
		AISidebarIconHelper.apply_icon(btn, n)
	btn.free()
	_mark("update_ui_language() esdegeri (gercek)")

	# 2) _save_current_session benzeri
	var cfg = AISidebarConfig.load_config()
	_mark("load_config() (session/save icin)")

	# 3) resolve_prompt_context
	var r = AISidebarMentionManager.resolve_prompt_context(SAMPLE_PROMPT)
	_mark("resolve_prompt_context()")

	# 4) _run_next_step icindeki context_text dongusu
	var ctx_text = ""
	var msgs: Array = []
	for i in range(40):
		msgs.append({"role": "user" if i % 2 == 0 else "assistant", "content": "ornek mesaj icerigi " + str(i)})
	for msg in msgs:
		if msg.get("role", "") == "user":
			var c = msg.get("content", "")
			if c is String:
				ctx_text += " " + c
	_mark("context_text insasi (40 mesaj)")

	# 5) get_relevant_schemas
	var tools = AISidebarToolManager.get_relevant_schemas(ctx_text, [])
	_mark("get_relevant_schemas() -> %d sema" % tools.size())

	# 6) performans metrigi icin get_all_schemas
	var all = AISidebarToolManager.get_all_schemas()
	_mark("get_all_schemas() (log satiri icin)")

	# 7) JSON.stringify (provider.send_chat icinde, START logundan HEMEN once)
	var body = {"model": cfg.get("selected_model", "a"), "messages": msgs, "tools": tools}
	var js = JSON.stringify(body)
	_mark("JSON.stringify(govde) -> %d karakter" % js.length())

	var total_ms = (_stamp() - grand_start) / 1000.0
	print("")
	print("  %-50s : %9.3f ms  <=== FAZ-A GERCEK TOPLAM" % ["", total_ms])
	print("  %-50s : %9.3f ms  <=== (hedef: ~10000 ms)" % ["", 10000.0])
	if total_ms < 500.0:
		print("  >>> SONUC: Faz-A zincirinin TAMAMI %.1f ms. 10s'lik bir blokaj YOK." % total_ms)
	elif total_ms < 3000.0:
		print("  >>> SONUC: Faz-A orta maliyetli (%.1f ms) ama 10s'yi aciklamiyor." % total_ms)
	else:
		print("  >>> SONUC: DIKKAT - Faz-A zinciri %.1f ms surdu, ana supheli!" % total_ms)
	_section_end()

# ---------------------------------------------------------------- verdict

func _print_verdict() -> void:
	print("")
	print("##################################################################")
	print("#  YORUM                                                         #")
	print("##################################################################")
	print("  Bu prob GERCEK fonksiyonlari cagirdi (simulasyon degil).")
	print("  Asagidaki iki sayiyi karsilastir:")
	print("    - BOLUM 8 'FAZ-A GERCEK TOPLAM'")
	print("    - Hedef: kullanicinin gozlemledigi ~10.000 ms freeze")
	print("  Eger Faz-A toplami ~10s'nin cok altindaysa, LLM_REQUEST_START")
	print("  oncesinde ana thread'i bekreten bir KOD YOLU YOKTUR;")
	print("  donma baska bir katmanda (editor render, disk/AV, ya da")
	print("  log sirasinin yanlis okunmasi) olusuyor demektir.")
	print("##################################################################")
