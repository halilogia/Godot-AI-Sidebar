class_name WeaponData
extends RefCounted

## Tek bir silahın tüm tanımı: görünüm ölçeği, namlu konumu, ateş hızı,
## şarjör, isabet yayılımı ve geri tepme. Player bu veriden silahı değiştirir.
var id: String = "kar98k"
var display_name: String = "Kar98k"
var clip_size: int = 8
var reserve: int = 56
var fire_rate: float = 0.28
var reload_time: float = 1.4
var base_spread: float = 0.4
var ads_spread: float = 0.1
var sprint_spread: float = 2.4
var recoil_pitch: float = 0.022
var recoil_yaw: float = 0.008
var auto: bool = false
# Görsel: mevcut silah modelinin ölçeği ve namlu uzunluğu çarpanı.
var ads_zoom: float = 1.0
var gun_scale: float = 0.72
var barrel_length: float = 0.38
var tint: Color = Color(0.22, 0.23, 0.25)
var kick: float = 3.6


static func make_bolt() -> WeaponData:
	return WeaponData.new()


## Üç temel silah: Kar98k (tüfek), MP40 (SMG), P08 (tabanca).
static func defaults() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	var bolt := make_bolt()
	bolt.id = "kar98k"
	bolt.display_name = "KAR98K"
	bolt.clip_size = 8
	bolt.reserve = 56
	bolt.fire_rate = 0.28
	bolt.reload_time = 1.6
	bolt.base_spread = 0.4
	bolt.ads_spread = 0.08
	bolt.sprint_spread = 2.4
	bolt.recoil_pitch = 0.030
	bolt.recoil_yaw = 0.008
	bolt.auto = false
	bolt.ads_zoom = 1.0
	bolt.gun_scale = 0.72
	bolt.barrel_length = 0.38
	bolt.tint = Color(0.22, 0.23, 0.25)
	bolt.kick = 3.6
	out.append(bolt)

	var mp := make_bolt()
	mp.id = "mp40"
	mp.display_name = "MP40"
	mp.clip_size = 32
	mp.reserve = 224
	mp.fire_rate = 0.085
	mp.reload_time = 1.9
	mp.base_spread = 1.5
	mp.ads_spread = 0.7
	mp.sprint_spread = 3.0
	mp.recoil_pitch = 0.011
	mp.recoil_yaw = 0.010
	mp.auto = true
	mp.ads_zoom = 0.25
	mp.gun_scale = 0.60
	mp.barrel_length = 0.22
	mp.tint = Color(0.26, 0.24, 0.20)
	mp.kick = 2.2
	out.append(mp)

	var p08 := make_bolt()
	p08.id = "p08"
	p08.display_name = "P08"
	p08.clip_size = 8
	p08.reserve = 48
	p08.fire_rate = 0.24
	p08.reload_time = 1.2
	p08.base_spread = 0.9
	p08.ads_spread = 0.3
	p08.sprint_spread = 2.6
	p08.recoil_pitch = 0.020
	p08.recoil_yaw = 0.007
	p08.auto = false
	p08.ads_zoom = 0.6
	p08.gun_scale = 0.52
	p08.barrel_length = 0.16
	p08.tint = Color(0.20, 0.21, 0.24)
	p08.kick = 2.6
	out.append(p08)
	return out
