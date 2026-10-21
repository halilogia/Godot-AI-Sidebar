@tool
extends Node
class_name AISidebarGameCapture

## Dock'taki "Ekran görüntüsü" ve "Klip" düğmelerinin arkasındaki servis. Oyunu editörden bağımsız, pencereli ayrı bir Godot
## sürecinde açar: ekran görüntüsü için capture_shot.gd, klip için Godot'nun film modu (--write-movie, dikey 1080x1920, 30 fps)
## ve ffmpeg ile MP4. Projede tools/devlog_clip.gd varsa klibin kamera koreografisi odur (yoksa ana sahne CLIP_SECONDS sn).
## Çıktı repo dışına gider: <proje>/../../Devlog/<proje adı>/ (tools/game_shot.ps1 / game_clip.ps1 ile aynı yer).
## Tek iş aynı anda; bitince `finished` sinyali gelir.

signal finished(kind: String, path: String, ok: bool, detail: String)

const KIND_SHOT := "shot"
const KIND_CLIP := "clip"
const SHOT_SCRIPT := "res://addons/godot_sidebar_ai/core/capture/capture_shot.gd"
const CLIP_SCRIPT := "res://addons/godot_sidebar_ai/core/capture/capture_clip.gd"
const PROJECT_CLIP_SCRIPT := "res://tools/devlog_clip.gd"
const SHOT_SIZE := Vector2i(1920, 1080)
const CLIP_SIZE := Vector2i(1080, 1920)
const CLIP_FPS := 30
const CLIP_SECONDS := 10
const SHOT_WAIT_SEC := 3.0
const MIN_BYTES := 1000

var _kind := ""
var _pid := -1
var _phase := ""   # "godot" | "ffmpeg" | ""
var _out := ""
var _avi := ""
var _had_override := false
var _override_backup := ""
var _override_path := ""


# ------------------------------------------------------------------ saf yardımcılar (testlenir) ----

## Projenin dizini (mutlak, sonda eğik çizgi yok).
static func project_dir() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")

## <proje>/../../Devlog/<proje adı>: GitHub\Public\Oyun -> GitHub\Devlog\Oyun.
static func output_dir(proj_dir: String) -> String:
	var clean := proj_dir.trim_suffix("/")
	return clean.get_base_dir().get_base_dir().path_join("Devlog").path_join(clean.get_file())

static func file_name(kind: String, stamp: String) -> String:
	return "%s_%s.%s" % [kind, stamp, "png" if kind == KIND_SHOT else "avi"]

static func stamp_now() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [t["year"], t["month"], t["day"], t["hour"], t["minute"], t["second"]]

static func size_text(size: Vector2i) -> String:
	return "%dx%d" % [size.x, size.y]

## Godot komut satırı. `project_clip`: projede kendi klip betiği var mı.
static func godot_args(kind: String, proj_dir: String, out_path: String, project_clip: bool) -> PackedStringArray:
	if kind == KIND_SHOT:
		return PackedStringArray(["--path", proj_dir, "--resolution", size_text(SHOT_SIZE), "--script", SHOT_SCRIPT, "--", out_path, str(SHOT_WAIT_SEC)])
	var script := PROJECT_CLIP_SCRIPT if project_clip else CLIP_SCRIPT
	var args := PackedStringArray(["--path", proj_dir, "--resolution", size_text(CLIP_SIZE), "--write-movie", out_path,
			"--fixed-fps", str(CLIP_FPS), "--script", script])
	if not project_clip:
		args.append_array(PackedStringArray(["--", str(CLIP_SECONDS * CLIP_FPS)]))
	return args

## Film modu çıktı boyutunu pencereden değil projenin temel çözünürlüğünden alır; geçici override.cfg bunu istenen boyuta çeker.
static func override_cfg_text(size: Vector2i) -> String:
	return "[display]\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\nwindow/size/window_width_override=%d\nwindow/size/window_height_override=%d\n" % [size.x, size.y, size.x, size.y]

static func ffmpeg_args(avi: String, mp4: String) -> PackedStringArray:
	return PackedStringArray(["-y", "-loglevel", "error", "-i", avi, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
			"-preset", "medium", "-movflags", "+faststart", "-an", mp4])


# ------------------------------------------------------------------------------------- çalışma ----

func is_busy() -> bool:
	return _phase != ""

## Çekimi başlatır; zaten bir iş varsa ya da süreç açılamazsa false.
func start(kind: String) -> bool:
	if is_busy() or (kind != KIND_SHOT and kind != KIND_CLIP):
		return false
	var proj := project_dir()
	var dir := output_dir(proj)
	DirAccess.make_dir_recursive_absolute(dir)
	_kind = kind
	_out = dir.path_join(file_name(kind, stamp_now()))
	_avi = _out
	var project_clip := FileAccess.file_exists(PROJECT_CLIP_SCRIPT)
	if kind == KIND_CLIP:
		_write_override(proj)
	_pid = OS.create_process(OS.get_executable_path(), godot_args(kind, proj, _out, project_clip))
	if _pid <= 0:
		_restore_override()
		_phase = ""
		return false
	_phase = "godot"
	set_process(true)
	return true

func _process(_delta: float) -> void:
	if _phase == "" or OS.is_process_running(_pid):
		return
	if _phase == "godot":
		_restore_override()
		if not _file_ok(_out):
			_end(false, _out, "no_output")
			return
		if _kind == KIND_SHOT:
			_end(true, _out, "")
			return
		if not _has_ffmpeg():
			_end(true, _out, "no_ffmpeg")
			return
		var mp4 := _out.get_basename() + ".mp4"
		_pid = OS.create_process("ffmpeg", ffmpeg_args(_out, mp4))
		if _pid <= 0:
			_end(true, _out, "no_ffmpeg")
			return
		_out = mp4
		_phase = "ffmpeg"
	elif _phase == "ffmpeg":
		if _file_ok(_out):
			DirAccess.remove_absolute(_avi)
			_end(true, _out, "")
		else:
			_end(true, _avi, "no_ffmpeg")

func _end(ok: bool, path: String, detail: String) -> void:
	var kind := _kind
	_phase = ""
	_pid = -1
	set_process(false)
	finished.emit(kind, path, ok, detail)

func _file_ok(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	return f != null and f.get_length() > MIN_BYTES

func _has_ffmpeg() -> bool:
	var out: Array = []
	return OS.execute("ffmpeg", ["-version"], out) == 0

func _write_override(proj: String) -> void:
	_override_path = proj.path_join("override.cfg")
	_had_override = FileAccess.file_exists(_override_path)
	_override_backup = FileAccess.get_file_as_string(_override_path) if _had_override else ""
	var f := FileAccess.open(_override_path, FileAccess.WRITE)
	if f != null:
		f.store_string((_override_backup + "\n" if _had_override else "") + override_cfg_text(CLIP_SIZE))
		f.close()

func _restore_override() -> void:
	if _override_path == "":
		return
	if _had_override:
		var f := FileAccess.open(_override_path, FileAccess.WRITE)
		if f != null:
			f.store_string(_override_backup)
			f.close()
	else:
		DirAccess.remove_absolute(_override_path)
	_override_path = ""


# ------------------------------------------------------------- sürüm kancası (Ayarlar → Devlog) ----

const HOOK_MARKER := "sidebar-devlog-hook"
const RELEASE_SCRIPT := "res://addons/godot_sidebar_ai/core/capture/game_clip.ps1"

## Projenin git kancaları klasörü ("" = proje bir git deposu değil). Worktree'de `.git` bir dosyadır ("gitdir: ...").
static func git_hooks_dir(proj_dir: String) -> String:
	var dot_git := proj_dir.trim_suffix("/").path_join(".git")
	if DirAccess.dir_exists_absolute(dot_git):
		return dot_git.path_join("hooks")
	if FileAccess.file_exists(dot_git):
		var line := FileAccess.get_file_as_string(dot_git).strip_edges()
		if line.begins_with("gitdir:"):
			var gitdir := line.trim_prefix("gitdir:").strip_edges()
			if gitdir.contains("/worktrees/"):
				gitdir = gitdir.get_base_dir().get_base_dir()   # ortak git dizini
			return gitdir.path_join("hooks")
	return ""

## `reference-transaction` kancası: refs/tags/v* yazılınca devlog klibi ayrı pencerede başlar (git'te etiket sonrası kancası yok).
static func release_hook_text(proj: String, script: String, godot: String, log: String) -> String:
	var lines := PackedStringArray([
		"#!/bin/sh",
		"# %s: refs/tags/v* yazilinca devlog klibini baslatir (Godot AI Sidebar > Ayarlar > Devlog)" % HOOK_MARKER,
		"[ \"$1\" = \"committed\" ] || exit 0",
		"[ \"${DEVLOG_AUTO:-1}\" = \"0\" ] && exit 0",
		"[ -f \"%s/tools/devlog/clips.json\" ] || exit 0" % proj,
		"while read old new ref; do",
		"  case \"$ref\" in",
		"    refs/tags/v*)",
		"      case \"$new\" in 0000000000000000000000000000000000000000) continue ;; esac",
		"      tag=\"${ref#refs/tags/}\"",
		"      echo \"$(date '+%%F %%T') START $tag\" >> \"%s\"" % log,
		"      ( nohup powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%s\" -Project \"%s\" -Release \"$tag\" -GodotPath \"%s\" >> \"%s\" 2>&1 & ) >/dev/null 2>&1" % [script, proj, godot, log],
		"      ;;",
		"  esac",
		"done",
		"exit 0",
		""])
	return "\n".join(lines)

static func hook_installed(proj_dir: String) -> bool:
	var dir := git_hooks_dir(proj_dir)
	if dir == "":
		return false
	var path := dir.path_join("reference-transaction")
	return FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).contains(HOOK_MARKER)

## "" = kuruldu; "no_git" = proje git deposu değil; "foreign_hook" = aynı adlı başka bir kanca var (üzerine yazılmaz).
static func install_release_hook(proj_dir: String, godot_path: String) -> String:
	var dir := git_hooks_dir(proj_dir)
	if dir == "":
		return "no_git"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("reference-transaction")
	if FileAccess.file_exists(path) and not FileAccess.get_file_as_string(path).contains(HOOK_MARKER):
		return "foreign_hook"
	var proj := proj_dir.trim_suffix("/")
	var script := ProjectSettings.globalize_path(RELEASE_SCRIPT)
	var log := dir.get_base_dir().path_join("devlog_hook.log")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "write_failed"
	f.store_string(release_hook_text(proj, script, godot_path, log))
	f.close()
	return ""

static func remove_release_hook(proj_dir: String) -> void:
	if hook_installed(proj_dir):
		DirAccess.remove_absolute(git_hooks_dir(proj_dir).path_join("reference-transaction"))

## Projede klip manifesti (tools/devlog/clips.json) var mı: yoksa kanca çalışmaz.
static func has_manifest(proj_dir: String) -> bool:
	return FileAccess.file_exists(proj_dir.trim_suffix("/").path_join("tools/devlog/clips.json"))
