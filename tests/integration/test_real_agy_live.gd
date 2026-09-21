@tool
extends SceneTree

const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")

func _init() -> void:
	print("--- LIVE AGY 2-TURN INTEGRATION TEST START ---")
	var prov = AISidebarAGYProvider.new()

	var state = {
		"done": false,
		"text": "",
		"chunks": 0
	}

	prov.chunk_received.connect(func(text_delta: String, _thinking: String):
		state["chunks"] += 1
		print("  [STREAM DELTA]: ", text_delta.strip_edges())
	)

	prov.response_received.connect(func(text_content: String, _thinking: String, _tools: Array):
		state["text"] = text_content.strip_edges()
		state["done"] = true
	)

	prov.error_occurred.connect(func(err: String):
		print("  [ERROR]: ", err)
		state["done"] = true
	)

	# --- TURN 1 (Cold Start) ---
	print(">>> Starting Turn 1 (Cold Start)...")
	var t0 = Time.get_ticks_msec()
	prov.send_chat([{"role": "user", "content": "Reply: READY"}], [])

	while not state["done"]:
		await create_timer(0.05).timeout

	var dur1 = (Time.get_ticks_msec() - t0) / 1000.0
	print("<<< Turn 1 Finished in: %.2fs, Text: '%s', Chunks: %d" % [dur1, state["text"], state["chunks"]])

	# --- TURN 2 (Warm Turn on SAME persistent process) ---
	print("\n>>> Starting Turn 2 (Warm Turn on persistent session)...")
	state["done"] = false
	state["text"] = ""
	state["chunks"] = 0
	var t1 = Time.get_ticks_msec()
	prov.send_chat([{"role": "user", "content": "Reply: 42"}], [])

	while not state["done"]:
		await create_timer(0.05).timeout

	var dur2 = (Time.get_ticks_msec() - t1) / 1000.0
	print("<<< Turn 2 Finished in: %.2fs, Text: '%s', Chunks: %d" % [dur2, state["text"], state["chunks"]])

	prov.stop_process()
	print("--- LIVE AGY 2-TURN INTEGRATION TEST END ---")

	var success = (state["text"] == "42" or "42" in state["text"]) and dur2 < 5.0
	quit(0 if success else 1)
