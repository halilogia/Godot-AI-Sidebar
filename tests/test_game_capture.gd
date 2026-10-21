@tool
extends RefCounted

## Dock'taki "Ekran görüntüsü" / "Klip" düğmelerinin servisi (AISidebarGameCapture): komut satırları, çıktı yolu, metinler, ikonlar.

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const GameCapture = preload("res://addons/godot_sidebar_ai/core/capture/game_capture.gd")

static func run() -> Dictionary:
	var state := {"passed": 0, "failed": 0, "errors": []}   # lambdas capture locals by value, so the counters live in a Dictionary
	var check := func(ok: bool, what: String) -> void:
		if ok:
			state["passed"] += 1
		else:
			state["failed"] += 1
			(state["errors"] as Array).append(what)

	check.call(GameCapture.output_dir("C:/Users/x/Desktop/GitHub/Public/Game") == "C:/Users/x/Desktop/GitHub/Devlog/Game", "output dir is GitHub/Devlog/<project>")
	check.call(GameCapture.output_dir("C:/Users/x/Desktop/GitHub/Public/Game/") == "C:/Users/x/Desktop/GitHub/Devlog/Game", "trailing slash is ignored")
	check.call(GameCapture.file_name("shot", "20261021_200000") == "shot_20261021_200000.png", "screenshot file name")
	check.call(GameCapture.file_name("clip", "20261021_200000") == "clip_20261021_200000.avi", "clip is recorded as avi first")

	var shot := GameCapture.godot_args("shot", "C:/p", "C:/o/shot.png", false)
	check.call(shot.has("--script") and shot.has(GameCapture.SHOT_SCRIPT) and shot.has("C:/o/shot.png"), "screenshot runs the shot script with the output path")
	check.call(shot.has("1920x1080") and not shot.has("--write-movie"), "screenshot is landscape and not a movie")

	var clip := GameCapture.godot_args("clip", "C:/p", "C:/o/clip.avi", false)
	check.call(clip.has("--write-movie") and clip.has("C:/o/clip.avi") and clip.has("--fixed-fps") and clip.has("30"), "clip uses the movie maker at 30 fps")
	check.call(clip.has("1080x1920") and clip.has(GameCapture.CLIP_SCRIPT) and clip.has(str(GameCapture.CLIP_SECONDS * GameCapture.CLIP_FPS)), "fallback clip is vertical and counts frames")
	var own := GameCapture.godot_args("clip", "C:/p", "C:/o/clip.avi", true)
	check.call(own.has(GameCapture.PROJECT_CLIP_SCRIPT) and not own.has("--"), "the project's own devlog_clip.gd needs no frame argument")

	var cfg := GameCapture.override_cfg_text(GameCapture.CLIP_SIZE)
	check.call(cfg.contains("viewport_width=1080") and cfg.contains("viewport_height=1920"), "override.cfg sets the movie size")
	var ff := GameCapture.ffmpeg_args("a.avi", "a.mp4")
	check.call(ff[ff.size() - 1] == "a.mp4" and ff.has("libx264") and ff.has("a.avi"), "ffmpeg converts avi to h264 mp4")

	for lang in ["tr", "en"]:
		for key in ["capture_shot_short", "capture_clip_short", "capture_shot_tooltip", "capture_clip_tooltip", "capture_busy",
				"capture_started_shot", "capture_started_clip", "capture_done_shot", "capture_done_clip", "capture_done_clip_avi", "capture_failed"]:
			check.call(AISidebarI18n.translate(lang, key) != key, "%s has %s" % [lang, key])
	for icon in ["camera", "video"]:
		check.call(FileAccess.file_exists("res://addons/godot_sidebar_ai/assets/icons/%s.svg" % icon), "icon %s exists" % icon)

	var svc := GameCapture.new()
	check.call(not svc.is_busy(), "a fresh service is idle")
	check.call(not svc.start("bogus"), "an unknown kind does not start")
	svc.free()
	return {"name": "GameCaptureTests", "passed": state["passed"], "failed": state["failed"], "errors": state["errors"]}
