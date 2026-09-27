@tool
extends Node

## Bildirim: ajan soru sorunca, onay / plan onayı beklerken ve görev bitince ya da hatayla durunca editör
## arka plandaysa görev çubuğundaki Godot simgesini yanıp söndürür (DisplayServer.window_request_attention;
## Windows / macOS / Linux yerleşik, dış program yok). Editöre bakarken uyarmaz. Ayarlar → Genel →
## Bildirimler ile kapatılır.

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

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
	return true
