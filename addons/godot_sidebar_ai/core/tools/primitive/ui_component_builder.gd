@tool
extends RefCounted
class_name AISidebarUIComponentBuilder

## scaffold_ui_component çekirdeği: Healthbar, DialogueBox, InventoryGrid, PauseMenu için
## yalnız Container düzeniyle (elle position / offset yok) düğüm ağacı + küçük bir betik API'si üretir.
## Ağaç bellekte kurulur; kaydetmeden önce audit_ui_layout / audit_ui_touch kurallarından geçirilir.

const COMPONENTS: Array[String] = ["healthbar", "dialogue_box", "inventory_grid", "pause_menu"]
const TOUCH_MIN: float = 44.0

const SCRIPTS: Dictionary = {
	"healthbar": """extends PanelContainer
## scaffold_ui_component (healthbar). set_health(değer, en_çok) çağır; görünüm temadan gelir.

signal changed(value: float, max_value: float)
signal depleted

@export var low_threshold: float = 0.25

@onready var _bar: ProgressBar = %Bar
@onready var _value_label: Label = %ValueLabel

func _ready() -> void:
	set_health(_bar.value, _bar.max_value)

func set_health(value: float, max_value: float = -1.0) -> void:
	if max_value > 0.0:
		_bar.max_value = max_value
	_bar.value = clampf(value, 0.0, _bar.max_value)
	_value_label.text = "%d / %d" % [int(_bar.value), int(_bar.max_value)]
	var low: bool = _bar.max_value > 0.0 and _bar.value / _bar.max_value <= low_threshold
	_bar.theme_type_variation = &"DangerBar" if low else &"HealthBar"
	changed.emit(_bar.value, _bar.max_value)
	if _bar.value <= 0.0:
		depleted.emit()
""",
	"dialogue_box": """extends PanelContainer
## scaffold_ui_component (dialogue_box). show_line(konuşmacı, metin) ile satır göster.

signal line_finished
signal advance_requested

@export var chars_per_second: float = 40.0

@onready var _speaker: Label = %SpeakerLabel
@onready var _text: RichTextLabel = %TextLabel
@onready var _next: Button = %NextButton

var _typing: bool = false
var _progress: float = 0.0

func _ready() -> void:
	_next.pressed.connect(_on_next_pressed)
	set_process(false)

func show_line(speaker: String, text: String) -> void:
	_speaker.text = speaker
	_speaker.visible = not speaker.is_empty()
	_text.text = text
	_progress = 0.0
	_typing = chars_per_second > 0.0
	if _typing:
		_text.visible_characters = 0
		set_process(true)
	else:
		_finish()

func skip() -> void:
	_finish()

func _process(delta: float) -> void:
	_progress += delta * chars_per_second
	_text.visible_characters = int(_progress)
	if int(_progress) >= _text.get_total_character_count():
		_finish()

func _finish() -> void:
	_typing = false
	set_process(false)
	_text.visible_characters = -1
	line_finished.emit()

func _on_next_pressed() -> void:
	if _typing:
		_finish()
	else:
		advance_requested.emit()
""",
	"inventory_grid": """extends PanelContainer
## scaffold_ui_component (inventory_grid). set_item(indeks, ikon, adet) ile yuvaları doldur.

signal slot_pressed(index: int)

@onready var _grid: GridContainer = %Grid

func _ready() -> void:
	for i: int in _grid.get_child_count():
		var slot: Button = _grid.get_child(i) as Button
		if slot:
			slot.pressed.connect(func() -> void: slot_pressed.emit(i))

func slot_count() -> int:
	return _grid.get_child_count()

func set_item(index: int, icon: Texture2D, count: int = 1) -> void:
	if index < 0 or index >= _grid.get_child_count():
		return
	var slot: Button = _grid.get_child(index) as Button
	slot.icon = icon
	slot.text = str(count) if icon != null and count > 1 else ""

func clear_slot(index: int) -> void:
	set_item(index, null, 0)
""",
	"pause_menu": """extends Control
## scaffold_ui_component (pause_menu). open() / close(); düğmeler action_selected(eylem) sinyali verir.

signal action_selected(action: StringName)

@onready var _buttons: Control = %Buttons

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for node: Node in _buttons.get_children():
		var button: Button = node as Button
		if button:
			var action: String = str(button.get_meta("action", button.name))
			button.pressed.connect(_on_pressed.bind(StringName(action)))

func open() -> void:
	visible = true
	get_tree().paused = true
	var first: Button = _buttons.get_child(0) as Button
	if first:
		first.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

func _on_pressed(action: StringName) -> void:
	if action == &"resume":
		close()
	action_selected.emit(action)
"""
}

const API: Dictionary = {
	"healthbar": ["set_health(value, max_value = -1)", "signal changed(value, max_value)", "signal depleted"],
	"dialogue_box": ["show_line(speaker, text)", "skip()", "signal line_finished", "signal advance_requested"],
	"inventory_grid": ["set_item(index, icon, count = 1)", "clear_slot(index)", "slot_count()", "signal slot_pressed(index)"],
	"pause_menu": ["open()", "close()", "signal action_selected(action)"]
}

## Dönen: {root: Node, script_source: String, api: Array, margin_nodes, box_nodes}
static func build(component: String, opts: Dictionary) -> Dictionary:
	var parts: Dictionary = {"margins": [], "boxes": []}
	var root: Node = null
	match component:
		"healthbar": root = _healthbar(opts, parts)
		"dialogue_box": root = _dialogue_box(opts, parts)
		"inventory_grid": root = _inventory_grid(opts, parts)
		"pause_menu": root = _pause_menu(opts, parts)
	return {"root": root, "script_source": str(SCRIPTS.get(component, "")), "api": API.get(component, []), "parts": parts}

## Tüm torunlara owner ver (PackedScene.pack için gerekli).
static func own_all(root: Node, node: Node) -> void:
	for ch: Node in node.get_children():
		ch.owner = root
		own_all(root, ch)

## Tema yoksa boşluk sıfır kalır; yalnız o durumda yedek boşluk değeri ver.
static func apply_fallback_spacing(parts: Dictionary) -> void:
	for m: MarginContainer in parts["margins"]:
		for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			m.add_theme_constant_override(side, 12)
	for b: BoxContainer in parts["boxes"]:
		b.add_theme_constant_override("separation", 8)

static func _add(parent: Node, child: Node, node_name: String, unique: bool = false) -> Node:
	child.name = node_name
	parent.add_child(child)
	child.unique_name_in_owner = unique
	return child

static func _margin(parent: Node, parts: Dictionary) -> MarginContainer:
	var m: MarginContainer = _add(parent, MarginContainer.new(), "Margin") as MarginContainer
	(parts["margins"] as Array).append(m)
	return m

static func _box(parent: Node, box: BoxContainer, node_name: String, parts: Dictionary, unique: bool = false) -> BoxContainer:
	(parts["boxes"] as Array).append(box)
	return _add(parent, box, node_name, unique) as BoxContainer

static func _label(parent: Node, node_name: String, text: String, variation: String = "", unique: bool = false) -> Label:
	var lb: Label = _add(parent, Label.new(), node_name, unique) as Label
	lb.text = text
	if not variation.is_empty():
		lb.theme_type_variation = variation
	return lb

static func _button(parent: Node, node_name: String, text: String, min_size: Vector2, variation: String = "", unique: bool = false) -> Button:
	var b: Button = _add(parent, Button.new(), node_name, unique) as Button
	b.text = text
	b.custom_minimum_size = Vector2(maxf(min_size.x, TOUCH_MIN), maxf(min_size.y, TOUCH_MIN))
	b.focus_mode = Control.FOCUS_ALL
	if not variation.is_empty():
		b.theme_type_variation = variation
	return b

static func _healthbar(opts: Dictionary, parts: Dictionary) -> Node:
	var root: PanelContainer = PanelContainer.new()
	root.name = str(opts.get("name", "HealthBar"))
	var hb: BoxContainer = _box(_margin(root, parts), HBoxContainer.new(), "Row", parts)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var caption: String = str(opts.get("caption", "HP"))
	if not caption.is_empty():
		_label(hb, "Caption", caption, "Caption")
	var bar: ProgressBar = _add(hb, ProgressBar.new(), "Bar", true) as ProgressBar
	var max_value: float = maxf(float(opts.get("max_value", 100.0)), 1.0)
	bar.max_value = max_value
	bar.value = max_value
	bar.show_percentage = false
	bar.theme_type_variation = "HealthBar"
	bar.custom_minimum_size = Vector2(160, 20)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label: Label = _label(hb, "ValueLabel", "%d / %d" % [int(max_value), int(max_value)], "", true)
	value_label.visible = bool(opts.get("show_value_text", true))
	return root

static func _dialogue_box(opts: Dictionary, parts: Dictionary) -> Node:
	var root: PanelContainer = PanelContainer.new()
	root.name = str(opts.get("name", "DialogueBox"))
	root.custom_minimum_size = Vector2(320, 140)
	var col: BoxContainer = _box(_margin(root, parts), VBoxContainer.new(), "Column", parts)
	_label(col, "SpeakerLabel", str(opts.get("speaker", "Speaker")), "HeaderMedium", true)
	var text: RichTextLabel = _add(col, RichTextLabel.new(), "TextLabel", true) as RichTextLabel
	text.bbcode_enabled = true
	text.fit_content = false
	text.scroll_active = false
	text.text = str(opts.get("sample_text", "..."))
	text.custom_minimum_size = Vector2(0, 64)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var footer: BoxContainer = _box(col, HBoxContainer.new(), "Footer", parts)
	var spacer: Control = _add(footer, Control.new(), "Spacer") as Control
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(footer, "NextButton", str(opts.get("next_text", "Next")), Vector2(96, TOUCH_MIN), "PrimaryButton", true)
	return root

static func _inventory_grid(opts: Dictionary, parts: Dictionary) -> Node:
	var root: PanelContainer = PanelContainer.new()
	root.name = str(opts.get("name", "InventoryGrid"))
	var col: BoxContainer = _box(_margin(root, parts), VBoxContainer.new(), "Column", parts)
	var title: String = str(opts.get("title", "Inventory"))
	if not title.is_empty():
		_label(col, "TitleLabel", title, "HeaderMedium")
	var scroll: ScrollContainer = _add(col, ScrollContainer.new(), "Scroll") as ScrollContainer
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid: GridContainer = _add(scroll, GridContainer.new(), "Grid", true) as GridContainer
	grid.columns = clampi(int(opts.get("columns", 5)), 1, 12)
	var slot_size: float = clampf(float(opts.get("slot_size", 72.0)), TOUCH_MIN, 256.0)
	for i: int in clampi(int(opts.get("slot_count", 20)), 1, 200):
		var slot: Button = _button(grid, "Slot_%d" % i, "", Vector2(slot_size, slot_size))
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	return root

static func _pause_menu(opts: Dictionary, parts: Dictionary) -> Node:
	var root: Control = Control.new()
	root.name = str(opts.get("name", "PauseMenu"))
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = _add(root, ColorRect.new(), "Dim") as ColorRect
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var center: CenterContainer = _add(root, CenterContainer.new(), "Center") as CenterContainer
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card: PanelContainer = _add(center, PanelContainer.new(), "Card") as PanelContainer
	card.theme_type_variation = "Card"
	var col: BoxContainer = _box(_margin(card, parts), VBoxContainer.new(), "Column", parts)
	var title: Label = _label(col, "TitleLabel", str(opts.get("title", "Paused")), "HeaderLarge")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons: BoxContainer = _box(col, VBoxContainer.new(), "Buttons", parts, true)
	var labels: Array = opts.get("buttons", ["Resume", "Settings", "Quit"]) as Array if opts.get("buttons") is Array else ["Resume", "Settings", "Quit"]
	if labels.is_empty():
		labels = ["Resume"]
	for i: int in mini(labels.size(), 8):
		var text: String = str(labels[i])
		var b: Button = _button(buttons, "Button_%d" % i, text, Vector2(220, 48), "PrimaryButton" if i == 0 else "")
		b.set_meta("action", text.to_lower().strip_edges().replace(" ", "_"))
	return root
