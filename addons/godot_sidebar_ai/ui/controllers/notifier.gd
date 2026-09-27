@tool
extends Node

## Bildirim: ajan soru sorunca, onay / plan onayı beklerken ve görev bitince ya da hatayla durunca editör
## arka plandaysa görev çubuğundaki Godot simgesini yanıp söndürür (DisplayServer.window_request_attention;
## Windows / macOS / Linux yerleşik, dış program yok). Editöre bakarken uyarmaz. Ayarlar → Genel →
## Bildirimler ile kapatılır.

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

## Kısa, yumuşak "ding" (kodla üretilir; ses dosyası yok). Ayarlar → Genel → Bildirim sesi (varsayılan kapalı).
const TONE_HZ := 880.0
const TONE_SEC := 0.18
const MIX_RATE := 22050

var _player: AudioStreamPlayer = null

## Son bildirim (testler ve ileride kısa metin gösterimi için): {"kind": String}.
var last: Dictionary = {}
## Pencere odakta mı (testler yerine koyar).
var is_focused: Callable = func() -> bool:
	var w := get_window()
	return w != null and w.has_focus()

func _init() -> void:
	name = "Notifier"

static func is_enabled() -> bool:
	return AISidebarConfig.load_config().get("notifications", true) == true

## kind: "question", "approval", "plan", "done", "error". Dönüş: bildirim verildi mi.
func notify(kind: String) -> bool:
	if not is_enabled() or is_focused.call():
		return false
	last = {"kind": kind}
	DisplayServer.window_request_attention()
	if AISidebarConfig.load_config().get("notification_sound", false) == true:
		_play_tone()
	return true

static func make_tone() -> AudioStreamWAV:
	var n := int(MIX_RATE * TONE_SEC)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := minf(1.0, t * 80.0) * (1.0 - float(i) / n)
		var v := int(sin(TAU * TONE_HZ * t) * env * 0.35 * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav

func _play_tone() -> void:
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.stream = make_tone()
		add_child(_player)
	if _player.is_inside_tree():
		_player.play()
