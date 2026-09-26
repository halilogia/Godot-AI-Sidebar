@tool
extends RefCounted
class_name AISidebarMotion

## Arayüz hareketi (SRP: yalnız geçişler). Kısa ve ölçülü: yeni kart / sayfa yumuşakça belirir.
## Kullanıcı Ayarlar → Genel → "Arayüz animasyonları" ile kapatabilir (config "ui_animations").
## Düğüm ağaçta değilse ya da animasyon kapalıysa hiçbir şey yapmaz (testler ve headless güvenli).

const DURATION_FAST := 0.12
const DURATION_BASE := 0.18

static var enabled: bool = true

## Denetim şeffaftan tam görünüre geçer (yalnız saydamlık; yerleşim bozulmaz).
static func fade_in(c: CanvasItem, duration: float = DURATION_BASE) -> void:
	if not enabled or c == null or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Kaptaki her yeni çocuk belirerek gelir (sohbet akışı gibi).
static func fade_children_of(container: Node) -> void:
	if not container.child_entered_tree.is_connected(_on_child_entered):
		container.child_entered_tree.connect(_on_child_entered)

static func _on_child_entered(n: Node) -> void:
	if n is Control:
		var c: Control = n
		fade_in(c)
