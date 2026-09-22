@tool
extends SceneTree

## Freeze Teshis Probu - FAZ 2 (Editor-disi agir islemler).
##
## Faz 1 (gui_freeze_probe.gd) cekirdek mantigin toplam ~23ms oldugunu gosterdi.
## Bu prob, cekirdek mantik DISINDA kalan ve UI'i bloklayabilecek adaylari olcer:
##   A) OS.execute_with_pipe("agy")  -> motor icinden surec baslatma (SENKRON, BLOKLAYICI)
##   B) UI bilesen insasi            -> Control/StyleBox/RichTextLabel kurulumu
##   C) SVG ikon yukleme             -> Image.load_from_file + rasterizasyon
##   D) HTTPClient.connect_to_host   -> 9Router baglanti baslatma

const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

const ROUTER_HOST := "127.0.0.1"
const ROUTER_PORT := 20128

var _rows: Array = []

func _init() -> void:
	print("")
	print("##################################################################")
	print("#  FREEZE PROBE FAZ 2 - CEKIRDEK DISI BLOKAJLAR                   #")
	print("##################################################################")

	_probe_agy_spawn()
	_probe_ui_construction()
	_probe_svg_icons()
	_probe_http_connect()

	_print_summary()
	quit(0)

func _section(t: String) -> void:
	print("")
	print("-- " + t + " " + "-".repeat(maxi(0, 62 - t.length())))

func _record(label: String, us: int) -> void:
	_rows.append({"label": label, "us": us})
	var ms := us / 1000.0
	var flag := ""
	if ms >= 1000.0:
		flag = "   <== COK PAHALI"
	elif ms >= 100.0:
		flag = "   <== PAHALI"
	elif ms >= 20.0:
		flag = "   <-- dikkat"
	print("  %-44s %10.3f ms%s" % [label, ms, flag])

# ---------------------------------------------------------------- A) AGY spawn

func _probe_agy_spawn() -> void:
	_section("A) OS.execute_with_pipe('agy') - MOTOR ICINDEN SENKRON SPAWN")
	var args: PackedStringArray = [
		"--input-format", "stream-json",
		"--output-format", "stream-json",
		"--model", "gemini-3.8-flash-low"
	]

	var t0 := Time.get_ticks_usec()
	var pipe = OS.execute_with_pipe("agy", args)
	var dt := Time.get_ticks_usec() - t0
	_record("OS.execute_with_pipe('agy') [stream-json]", dt)

	if pipe.is_empty() or not pipe.has("stdio"):
		print("      !! pipe olusturulamadi (agy PATH'te yok olabilir)")
		return

	var pid = pipe.get("pid", -1)
	print("      pid=%s  keys=%s" % [str(pid), str(pipe.keys())])

	# Init event'i (handshake) ne kadar suruyor? Bu da UI thread'inde beklenirse blokaj olur.
	var stdio: FileAccess = pipe["stdio"]
	var t_handshake := Time.get_ticks_usec()
	var got_init := false
	var waited_ms := 0
	# get_line() BLOKLAYICIDIR; bu yuzden kisa bir butce ile deneriz.
	# Gercek kod (agy_cli_provider) bunu AYRI THREAD'de yapar; burada niyeti olcuyoruz.
	var deadline := Time.get_ticks_msec() + 15000
	if stdio:
		while Time.get_ticks_msec() < deadline:
			if stdio.get_length() > 0:
				got_init = true
				break
			OS.delay_msec(20)
		waited_ms = int(Time.get_ticks_usec() - t_handshake) / 1000
	if got_init:
		_record("agy 'init' event hazir olma suresi", waited_ms * 1000)
	else:
		print("  %-44s  %10d ms  (init gelmedi / timeout)" % ["agy 'init' bekleyisi", waited_ms])

	# Temizlik
	stdio.close()
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	print("      (agy sureci temizlendi)")

# ---------------------------------------------------------------- B) UI build

func _probe_ui_construction() -> void:
	_section("B) UI BILESEN INSASI (signal handler'larda senkron calisir)")
	var root_node := get_root()
	if root_node == null:
		print("      !! root yok, atlaniyor")
		return

	# MessageBubble insasi (_on_agent_text_received her mesajda yapar)
	var t0 := Time.get_ticks_usec()
	var bubble = AISidebarMessageBubble.new("assistant", "Dusunuluyor...")
	root_node.add_child(bubble)
	var dt_bubble := Time.get_ticks_usec() - t0
	_record("MessageBubble.new() + add_child() [bos]", dt_bubble)
	bubble.queue_free()

	# Gercekci: 4000 karakterlik bir yanit ile
	var big_text := ""
	for i in range(200):
		big_text += "Satir %d: res://addons/godot_sidebar_ai/core/agent/agent_runner.gd incelendi.\n" % i
	var t1 := Time.get_ticks_usec()
	var bubble2 = AISidebarMessageBubble.new("assistant", big_text)
	root_node.add_child(bubble2)
	var dt_big := Time.get_ticks_usec() - t1
	_record("MessageBubble.new() + add_child() [4K metin]", dt_big)
	bubble2.queue_free()

	# ActivityGroup
	var t2 := Time.get_ticks_usec()
	var grp = AISidebarActivityGroup.new(true)
	root_node.add_child(grp)
	var dt_grp := Time.get_ticks_usec() - t2
	_record("ActivityGroup.new() + add_child()", dt_grp)
	grp.queue_free()

	# 20 bubble + relayout (gercekci sohbet dolulugu)
	var t3 := Time.get_ticks_usec()
	var holders: Array = []
	for i in range(20):
		var b = AISidebarMessageBubble.new("user" if i % 2 == 0 else "assistant",
			"Mesaj %d: bu biraz daha uzun bir icerik parcasidir." % i)
		root_node.add_child(b)
		holders.append(b)
	var dt_20 := Time.get_ticks_usec() - t3
	_record("20 x MessageBubble.new() + add_child()", dt_20)

	# StyleBox uretimi (her bubble _setup_ui'da cagirir)
	var t4 := Time.get_ticks_usec()
	for i in range(100):
		AISidebarTheme.create_bubble_assistant_style()
		AISidebarTheme.create_ghost_button_style(false)
		AISidebarTheme.create_input_style()
	var dt_sb := Time.get_ticks_usec() - t4
	_record("300 x StyleBox uretimi", dt_sb)

	for h in holders:
		h.queue_free()

# ---------------------------------------------------------------- C) SVG icons

func _probe_svg_icons() -> void:
	_section("C) SVG IKON YUKLEME (update_ui_language her cagrida apply_icon yapar)")
	var icon_dir := "res://addons/godot_sidebar_ai/assets/icons/"
	var names: Array[String] = ["download", "history", "refresh", "settings", "trash", "send", "copy", "check", "stop"]
	for n in names:
		var path: String = icon_dir + n + ".svg"
		if not FileAccess.file_exists(path):
			continue
		var abs_path := ProjectSettings.globalize_path(path)
		var t0 := Time.get_ticks_usec()
		var img := Image.load_from_file(abs_path)
		var dt := Time.get_ticks_usec() - t0
		var ok := img != null and not img.is_empty()
		if dt >= 2000:
			_record("load SVG '%s' (ok=%s)" % [n, str(ok)], dt)
		else:
			print("  %-44s %10.3f ms  (ok=%s)" % ["load SVG '%s'" % n, dt / 1000.0, str(ok)])

# ---------------------------------------------------------------- D) HTTP

func _probe_http_connect() -> void:
	_section("D) HTTPClient.connect_to_host -> 9Router (%s:%d)" % [ROUTER_HOST, ROUTER_PORT])
	for i in range(3):
		var client := HTTPClient.new()
		var t0 := Time.get_ticks_usec()
		var err := client.connect_to_host(ROUTER_HOST, ROUTER_PORT)
		var dt := Time.get_ticks_usec() - t0
		_record("connect_to_host() deneme %d (err=%d)" % [i + 1, err], dt)

		# poll dongusu ile STATUS_CONNECTED'a kadar gecen sureyi olc
		if err == OK:
			var t1 := Time.get_ticks_usec()
			var polls := 0
			while client.get_status() != HTTPClient.STATUS_CONNECTED and polls < 500:
				client.poll()
				polls += 1
				OS.delay_msec(1)
			var dt2 := Time.get_ticks_usec() - t1
			var st := client.get_status()
			print("      -> baglanti kuruldu mu: status=%d polls=%d sure=%.3f ms"
				% [st, polls, dt2 / 1000.0])
		client.close()

# ---------------------------------------------------------------- summary

func _print_summary() -> void:
	print("")
	print("##################################################################")
	print("#  OZET - CEKIRDEK DISI (EN BUYUK 8)                              #")
	print("##################################################################")
	var s := _rows.duplicate()
	s.sort_custom(func(a, b): return a["us"] > b["us"])
	var n := mini(8, s.size())
	for i in range(n):
		print("  %2d. %-44s %10.3f ms" % [i + 1, s[i]["label"], s[i]["us"] / 1000.0])
	print("##################################################################")
