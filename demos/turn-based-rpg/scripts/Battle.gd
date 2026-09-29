class_name Battle
extends Node

enum State { PLAYER_TURN, ANIM, ENEMY_TURN, OVER }

signal log_line(text: String)
signal state_changed(s: State)
signal stats_changed
signal battle_over(win: bool)
signal damage_shown(world_pos: Vector2, amount: int, is_enemy: bool)

var combatants: Array[Combatant] = []
var order: Array[Combatant] = []
var turn_index: int = 0
var state: int = State.PLAYER_TURN

func start() -> void:
	turn_index = 0
	state = State.PLAYER_TURN
	_begin_turn()

func living(players: bool) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in combatants:
		if c.is_player == players and c.is_alive():
			out.append(c)
	return out

func current() -> Combatant:
	if order.is_empty():
		return null
	return order[turn_index]

func _begin_turn() -> void:
	for c in order:
		c.is_shielded = false
	var c := current()
	if c == null:
		return
	log_line.emit("%s sırası." % c.cname)
	state_changed.emit(state)

## player action: kind = attack | skill | guard
func player_action(c: Combatant, target: Combatant, kind: String, skill_index: int) -> void:
	if state != State.PLAYER_TURN or c != current() or not c.is_alive():
		return
	state = State.ANIM
	state_changed.emit(state)
	var dmg := 0
	match kind:
		"attack":
			dmg = _hit(c, target)
			log_line.emit("%s → %s  %d hasar." % [c.cname, target.cname, dmg])
		"skill":
			dmg = _hit(c, target, true)
			log_line.emit("%s beceriyle %s'a %d hasar." % [c.cname, target.cname, dmg])
		"guard":
			c.is_shielded = true
			log_line.emit("%s kalkan aldı." % c.cname)
	damage_shown.emit(target.position, dmg, not target.is_player)
	_check_end()
	if state != State.OVER:
		_advance(true)

func _hit(c: Combatant, target: Combatant, skill: bool = false) -> int:
	var power := c.attack
	if skill:
		power += 10
		c.spend_mp(6)
	if target.is_shielded:
		power = int(power * 0.5)
	power = maxi(1, power - target.defense)
	if c.mp <= 0:
		power = int(power * 0.75)
		c.mp = 2
	target.receive(power)
	stats_changed.emit()
	return power

func _advance(skip_current: bool) -> void:
	for i in range(order.size()):
		if skip_current:
			turn_index = (turn_index + 1) % order.size()
		if order[turn_index].is_alive():
			break
		if skip_current:
			turn_index = (turn_index + 1) % order.size()
	if not skip_current:
		while not order[turn_index].is_alive():
			turn_index = (turn_index + 1) % order.size()
	_begin_turn()

func run_enemy_turn() -> void:
	if state == State.OVER:
		return
	state = State.ENEMY_TURN
	state_changed.emit(state)
	var c := current()
	if c == null or not c.is_alive() or c.is_player:
		state = State.PLAYER_TURN
		_begin_turn()
		return
	var targets := living(true)
	if targets.is_empty():
		_check_end()
		return
	var target: Combatant = targets[randi() % targets.size()]
	var dmg := _hit(c, target)
	damage_shown.emit(target.position, dmg, not target.is_player)
	log_line.emit("%s → %s  %d hasar." % [c.cname, target.cname, dmg])
	_check_end()
	if state != State.OVER:
		state = State.PLAYER_TURN
		_advance(false)

func _check_end() -> void:
	if living(false).is_empty():
		state = State.OVER
		battle_over.emit(false)
	elif living(true).is_empty():
		state = State.OVER
		battle_over.emit(true)
