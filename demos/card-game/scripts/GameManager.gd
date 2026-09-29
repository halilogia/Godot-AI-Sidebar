class_name GameManager
extends Control

const CARD_UI_SCENE = preload("res://scenes/CardUI.tscn")

# Stats
var player_max_hp: int = 50
var player_hp: int = 50
var player_block: int = 0
var player_max_mana: int = 3
var player_mana: int = 3

var enemy_max_hp: int = 40
var enemy_hp: int = 40
var enemy_block: int = 0
var enemy_next_intent: Dictionary = {"type": "attack", "value": 8} # or shield

var deck: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand: Array[CardData] = []

@onready var player_hp_label: Label = $BattleArea/PlayerSide/VBox/HPLabel
@onready var player_hp_bar: ProgressBar = $BattleArea/PlayerSide/VBox/HPBar
@onready var player_block_label: Label = $BattleArea/PlayerSide/VBox/BlockLabel
@onready var player_mana_label: Label = $BattleArea/PlayerSide/VBox/ManaLabel

@onready var enemy_hp_label: Label = $BattleArea/EnemySide/VBox/HPLabel
@onready var enemy_hp_bar: ProgressBar = $BattleArea/EnemySide/VBox/HPBar
@onready var enemy_block_label: Label = $BattleArea/EnemySide/VBox/BlockLabel
@onready var enemy_intent_label: Label = $BattleArea/EnemySide/VBox/IntentLabel
@onready var enemy_sprite_panel: Panel = $BattleArea/EnemySide/VBox/EnemyVisual

@onready var hand_container: HBoxContainer = $HandArea/HandContainer
@onready var end_turn_btn: Button = $ActionArea/EndTurnButton
@onready var combat_log_label: Label = $LogArea/LogLabel
@onready var restart_btn: Button = $GameOverOverlay/Panel/VBox/RestartBtn
@onready var game_over_overlay: Control = $GameOverOverlay
@onready var game_over_title: Label = $GameOverOverlay/Panel/VBox/Title

var is_player_turn: bool = true

func _ready() -> void:
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	restart_btn.pressed.connect(restart_game)
	init_game()

func init_game() -> void:
	player_hp = player_max_hp
	player_block = 0
	player_mana = player_max_mana
	
	enemy_hp = enemy_max_hp
	enemy_block = 0
	
	game_over_overlay.visible = false
	is_player_turn = true
	
	build_starter_deck()
	deck.shuffle()
	pick_enemy_intent()
	update_all_ui()
	start_player_turn()

func build_starter_deck() -> void:
	deck.clear()
	discard_pile.clear()
	hand.clear()
	
	# 4 Vuruş (1 Mana, 6 Hasar)
	for i in range(4):
		deck.append(CardData.new("Kılıç Darbesi", 1, 6, CardData.Type.ATTACK, "Düşmana 6 hasar verir."))
	# 3 Savunma (1 Mana, 5 Kalkan)
	for i in range(3):
		deck.append(CardData.new("Kalkan", 1, 5, CardData.Type.DEFEND, "5 Kalkan kazan."))
	# 2 İksir (2 Mana, 7 İyileşme)
	for i in range(2):
		deck.append(CardData.new("Şifa İksiri", 2, 7, CardData.Type.HEAL, "7 Can yeniler."))
	# 1 Ağır Darbe (2 Mana, 14 Hasar)
	deck.append(CardData.new("Ağır Darbe", 2, 14, CardData.Type.ATTACK, "Düşmana 14 ezici hasar verir."))

func start_player_turn() -> void:
	is_player_turn = true
	player_block = 0
	player_mana = player_max_mana
	end_turn_btn.disabled = false
	log_message("Sıra sizde! Mana yenilendi.")
	draw_cards(4)
	update_all_ui()

func draw_cards(count: int) -> void:
	for i in range(count):
		if deck.is_empty():
			if discard_pile.is_empty():
				break
			deck = discard_pile.duplicate()
			discard_pile.clear()
			deck.shuffle()
			log_message("Deste karıştırıldı.")
		if not deck.is_empty():
			var card: CardData = deck.pop_back()
			hand.append(card)
	rebuild_hand_ui()

func rebuild_hand_ui() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	
	for card in hand:
		var c_ui: CardUI = CARD_UI_SCENE.instantiate()
		hand_container.add_child(c_ui)
		c_ui.setup(card)
		c_ui.card_clicked.connect(_on_card_played)

func _on_card_played(c_ui: CardUI) -> void:
	if not is_player_turn:
		return
	var card: CardData = c_ui.data
	if player_mana < card.cost:
		log_message("Yetersiz Mana! (" + str(player_mana) + "/" + str(card.cost) + ")")
		_flash_node(player_mana_label, Color.RED)
		return
	
	player_mana -= card.cost
	hand.erase(card)
	discard_pile.append(card)
	
	# Execute effect
	match card.type:
		CardData.Type.ATTACK:
			apply_damage_to_enemy(card.value)
			log_message("Kullandın: " + card.title + " -> " + str(card.value) + " hasar!")
			_flash_node(enemy_sprite_panel, Color.RED)
		CardData.Type.DEFEND:
			player_block += card.value
			log_message("Kullandın: " + card.title + " -> +" + str(card.value) + " kalkan.")
			_flash_node(player_block_label, Color.SKY_BLUE)
		CardData.Type.HEAL:
			player_hp = mini(player_max_hp, player_hp + card.value)
			log_message("Kullandın: " + card.title + " -> +" + str(card.value) + " can.")
			_flash_node(player_hp_bar, Color.GREEN)
	
	rebuild_hand_ui()
	update_all_ui()
	
	if enemy_hp <= 0:
		handle_victory()

func apply_damage_to_enemy(amount: int) -> void:
	if enemy_block >= amount:
		enemy_block -= amount
	else:
		var remaining := amount - enemy_block
		enemy_block = 0
		enemy_hp = maxi(0, enemy_hp - remaining)

func apply_damage_to_player(amount: int) -> void:
	if player_block >= amount:
		player_block -= amount
	else:
		var remaining := amount - player_block
		player_block = 0
		player_hp = maxi(0, player_hp - remaining)

func _on_end_turn_pressed() -> void:
	if not is_player_turn:
		return
	is_player_turn = false
	end_turn_btn.disabled = true
	# Discard hand
	for c in hand:
		discard_pile.append(c)
	hand.clear()
	rebuild_hand_ui()
	
	log_message("Sıra düşmanda...")
	update_all_ui()
	
	# Enemy action delayed
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(execute_enemy_turn)

func execute_enemy_turn() -> void:
	enemy_block = 0
	if enemy_next_intent["type"] == "attack":
		var dmg: int = enemy_next_intent["value"]
		apply_damage_to_player(dmg)
		log_message("Düşman saldırdı: " + str(dmg) + " hasar!")
		_flash_node(player_hp_bar, Color.RED)
	elif enemy_next_intent["type"] == "defend":
		var shld: int = enemy_next_intent["value"]
		enemy_block += shld
		log_message("Düşman kalkan kullandı: +" + str(shld) + " kalkan.")
		_flash_node(enemy_block_label, Color.SKY_BLUE)
		
	update_all_ui()
	
	if player_hp <= 0:
		handle_defeat()
		return
	
	pick_enemy_intent()
	
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(start_player_turn)

func pick_enemy_intent() -> void:
	var roll := randf()
	if roll < 0.65:
		var dmg := randi_range(6, 10)
		enemy_next_intent = {"type": "attack", "value": dmg}
	else:
		var blk := randi_range(5, 8)
		enemy_next_intent = {"type": "defend", "value": blk}

func update_all_ui() -> void:
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	player_hp_label.text = "Can: %d / %d" % [player_hp, player_max_hp]
	player_block_label.text = "Kalkan: %d" % player_block
	player_mana_label.text = "Mana: %d / %d" % [player_mana, player_max_mana]
	
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp
	enemy_hp_label.text = "Can: %d / %d" % [enemy_hp, enemy_max_hp]
	enemy_block_label.text = "Kalkan: %d" % enemy_block
	
	if enemy_next_intent["type"] == "attack":
		enemy_intent_label.text = "Niyet: Saldırı (%d Hasar)" % enemy_next_intent["value"]
		enemy_intent_label.modulate = Color("#ef4444")
	else:
		enemy_intent_label.text = "Niyet: Savunma (%d Kalkan)" % enemy_next_intent["value"]
		enemy_intent_label.modulate = Color("#3b82f6")

func log_message(msg: String) -> void:
	combat_log_label.text = msg

func _flash_node(node: CanvasItem, color: Color) -> void:
	if not node:
		return
	var orig_mod: Color = node.modulate
	var tw := create_tween()
	tw.tween_property(node, "modulate", color, 0.08)
	tw.tween_property(node, "modulate", orig_mod, 0.12)

func handle_victory() -> void:
	game_over_title.text = "ZAFER!"
	game_over_title.modulate = Color("#f59e0b")
	game_over_overlay.visible = true
	log_message("Düşmanı mağlup ettin!")

func handle_defeat() -> void:
	game_over_title.text = "BOZGUNA UĞRADIN"
	game_over_title.modulate = Color("#ef4444")
	game_over_overlay.visible = true
	log_message("Yenildin...")

func restart_game() -> void:
	init_game()
