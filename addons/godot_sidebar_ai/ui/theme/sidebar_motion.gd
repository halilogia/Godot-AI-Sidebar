@tool
extends RefCounted
class_name AISidebarMotion

## Arayüz hareketi (SRP: yalnız geçişler). Bütün animasyonlar buradan geçer; ui/ altında başka yerde
## tween kurulmaz (tests/test_ui_quality.gd denetler). Ölçülü: yalnız saydamlık değişir, yerleşim oynamaz.
## Kullanıcı Ayarlar → Genel → "Arayüz animasyonları" ile kapatabilir (config "ui_animations"); kapalıyken,
## düğüm ağaçta değilken (testler) ya da görüntü araçlarında sonuç anında uygulanır.
##
## Hareketler (her biri kullanıldığı yerle):
##   fade_in / fade_children_of  yeni sohbet kartı, Ayarlar sayfası
##   reveal                      açılır bölümler (etkinlik, düşünme, görev listesi, runtime, özet)
##   pulse                       ajan çalışırken durum rozeti

# Süre ve yumuşatma belirteçleri
const DURATION_FAST := 0.12
const DURATION_BASE := 0.18
const DURATION_PULSE := 0.9
const PULSE_MIN_ALPHA := 0.55
const TRANS := Tween.TRANS_CUBIC
const EASE := Tween.EASE_OUT

const _META_TWEEN := &"_aisidebar_motion_tween"

static var enabled: bool = true

static func _animates(c: CanvasItem) -> bool:
	return enabled and c != null and c.is_inside_tree()

## Bir düğümde aynı anda tek hareket: yenisi başlarken öncekini durdurur.
static func _take_tween(c: CanvasItem) -> Tween:
	_stop(c)
	var tw := c.create_tween()
	c.set_meta(_META_TWEEN, tw)
	return tw

static func _stop(c: CanvasItem) -> void:
	if c.has_meta(_META_TWEEN):
		var old: Variant = c.get_meta(_META_TWEEN)
		if old is Tween:
			var tw: Tween = old
			if tw.is_valid():
				tw.kill()
		c.remove_meta(_META_TWEEN)

## Denetim şeffaftan tam görünüre geçer.
static func fade_in(c: CanvasItem, duration: float = DURATION_BASE) -> void:
	if not _animates(c):
		return
	c.modulate.a = 0.0
	_take_tween(c).tween_property(c, "modulate:a", 1.0, duration).set_trans(TRANS).set_ease(EASE)

## Kaptaki her yeni çocuk belirerek gelir (sohbet akışı gibi).
static func fade_children_of(container: Node) -> void:
	if not container.child_entered_tree.is_connected(_on_child_entered):
		container.child_entered_tree.connect(_on_child_entered)

static func _on_child_entered(n: Node) -> void:
	if n is Control:
		var c: Control = n
		fade_in(c)

## Açılır bölüm: açılırken görünür olup belirir, kapanırken solup gizlenir. Animasyon yoksa anında.
## Hareket sürerken tersine çevrilirse önceki durdurulur (kapanış geri çağrısı açılmış bölümü gizlemez).
static func reveal(section: CanvasItem, show: bool) -> void:
	if section == null:
		return
	if not _animates(section):
		_stop(section)
		section.visible = show
		section.modulate.a = 1.0
		return
	if show:
		if section.visible and section.modulate.a >= 1.0 and not section.has_meta(_META_TWEEN):
			return
		section.visible = true
		if section.modulate.a >= 1.0:
			section.modulate.a = 0.0
		_take_tween(section).tween_property(section, "modulate:a", 1.0, DURATION_FAST).set_trans(TRANS).set_ease(EASE)
	elif section.visible:
		var tw := _take_tween(section)
		tw.tween_property(section, "modulate:a", 0.0, DURATION_FAST).set_trans(TRANS).set_ease(EASE)
		tw.tween_callback(func() -> void:
			section.visible = false
			section.modulate.a = 1.0)

## Sürekli nabız (etkin iş göstergesi): açıkken saydamlık yavaşça iner çıkar, kapanınca tam görünüre döner.
static func pulse(c: CanvasItem, active: bool) -> void:
	if c == null:
		return
	if not active or not _animates(c):
		_stop(c)
		c.modulate.a = 1.0
		return
	if c.has_meta(_META_TWEEN):
		return
	var tw := _take_tween(c).set_loops()
	tw.tween_property(c, "modulate:a", PULSE_MIN_ALPHA, DURATION_PULSE * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "modulate:a", 1.0, DURATION_PULSE * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
