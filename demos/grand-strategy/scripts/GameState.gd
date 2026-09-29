class_name GameState
extends RefCounted

const TICK_SECONDS := 0.8

var gold := 400
var manpower := 150
var political_power := 100.0
var month := 1
var selected := -1
var armies: Array = []
var prov_own: Array = []
var prov_dev: Array = []
var prov_name: Array = []


func _init() -> void:
	armies = [
		{"name": "Kuzey Ordusu", "province": 45, "to": -1, "strength": 100.0, "player": true},
	]
