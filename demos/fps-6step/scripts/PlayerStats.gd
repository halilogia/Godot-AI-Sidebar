class_name PlayerStats
extends RefCounted

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal ammo_changed(clip: int, reserve: int)
signal weapon_fired()
signal weapon_reloaded()
signal hit_confirmed(is_headshot: bool)

const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0

const STAMINA_DRAIN := 22.0
const STAMINA_REGEN := 14.0
const SPRINT_MIN := 12.0

var health: float = MAX_HEALTH
var stamina: float = MAX_STAMINA

# Silahlar: her biri kendi şarjör/yedek mermisini tutar, sadece biri aktiftir.
var weapons: Array[WeaponData] = []
var ammo: Array[Vector2i] = []  # x = şarjördeki, y = yedek
var active_index: int = 0


func _init() -> void:
	weapons = WeaponData.defaults()
	for w in weapons:
		ammo.append(Vector2i(w.clip_size, w.reserve))


func weapon() -> WeaponData:
	return weapons[active_index]


func clip() -> int:
	return ammo[active_index].x


func reserve() -> int:
	return ammo[active_index].y


func clip_size() -> int:
	return weapon().clip_size


func select(index: int) -> bool:
	if index < 0 or index >= weapons.size() or index == active_index:
		return false
	active_index = index
	ammo_changed.emit(clip(), reserve())
	return true


func cycle(delta: int) -> bool:
	return select(posmod(active_index + delta, weapons.size()))


func can_sprint(on_floor: bool) -> bool:
	return on_floor and stamina > SPRINT_MIN


func spend_stamina(delta: float) -> void:
	stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
	stamina_changed.emit(stamina, MAX_STAMINA)


func regen_stamina(delta: float) -> void:
	if stamina >= MAX_STAMINA:
		return
	stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN * delta)
	stamina_changed.emit(stamina, MAX_STAMINA)


func damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	health_changed.emit(health, MAX_HEALTH)


## Oyuncu öldüğünde yeniden doğuş: sağlık, nefes ve TÜM mermiler dolu.
func respawn() -> void:
	health = MAX_HEALTH
	stamina = MAX_STAMINA
	for i in weapons.size():
		ammo[i] = Vector2i(weapons[i].clip_size, weapons[i].reserve)
	health_changed.emit(health, MAX_HEALTH)
	stamina_changed.emit(stamina, MAX_STAMINA)
	ammo_changed.emit(clip(), reserve())


func has_ammo() -> bool:
	return clip() > 0


func consume_round() -> void:
	var a := ammo[active_index]
	a.x = maxi(0, a.x - 1)
	ammo[active_index] = a
	ammo_changed.emit(a.x, a.y)
	weapon_fired.emit()


func reload() -> void:
	var a := ammo[active_index]
	var size := clip_size()
	if a.x >= size or a.y <= 0:
		return
	var taken: int = mini(size - a.x, a.y)
	a.x += taken
	a.y -= taken
	ammo[active_index] = a
	ammo_changed.emit(a.x, a.y)
	weapon_reloaded.emit()
