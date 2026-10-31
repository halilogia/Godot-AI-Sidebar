@tool
extends RefCounted
class_name AISidebarUIComponentBuilder

## scaffold_ui_component çekirdeği: Healthbar, DialogueBox, InventoryGrid, PauseMenu için
## yalnız Container düzeniyle (elle position / offset yok) düğüm ağacı + küçük bir betik API'si üretir.
## Ağaç bellekte kurulur; kaydetmeden önce audit_ui_layout / audit_ui_touch kurallarından geçirilir.

const COMPONENTS: Array[String] = ["healthbar", "dialogue_box", "inventory_grid", "pause_menu", "framed_panel", "resource_strip", "list_row", "event_popup"]
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
""",
	"framed_panel": """extends PanelContainer
## scaffold_ui_component (framed_panel). set_title(başlık), content() ve close_requested sinyali.

signal close_requested

@onready var _title: Label = %TitleLabel
@onready var _close: Button = %CloseButton
@onready var _body: VBoxContainer = %Body

func _ready() -> void:
	_close.pressed.connect(func() -> void: close_requested.emit())

func set_title(text: String) -> void:
	_title.text = text

func content() -> VBoxContainer:
	return _body
""",
	"resource_strip": """extends PanelContainer
## scaffold_ui_component (resource_strip). set_value(anahtar, metin) ile üst kaynak şeridini günceller.

@onready var _row: HBoxContainer = %Row

func set_value(key: String, value_text: String) -> void:
	var item: Node = _row.get_node_or_null(key)
	if item == null:
		return
	var val: Label = item.get_node_or_null("Value") as Label
	if val:
		val.text = value_text
""",
	"list_row": """extends PanelContainer
## scaffold_ui_component (list_row). setup(başlık, alt_yazı, eylem_metni) ve action_pressed sinyali.

signal action_pressed

@onready var _title: Label = %TitleLabel
@onready var _sub: Label = %SubLabel
@onready var _btn: Button = %ActionButton

func _ready() -> void:
	_btn.pressed.connect(func() -> void: action_pressed.emit())

func setup(title: String, subtitle: String = "", action_text: String = "") -> void:
	_title.text = title
	_sub.text = subtitle
	_sub.visible = not subtitle.is_empty()
	if not action_text.is_empty():
		_btn.text = action_text
""",
	"event_popup": """extends Control
## scaffold_ui_component (event_popup). show_event(başlık, gövde, seçenekler) ve choice_made(indeks) sinyali.

signal choice_made(index: int)

@onready var _title: Label = %TitleLabel
@onready var _body: RichTextLabel = %BodyLabel
@onready var _choices: VBoxContainer = %Choices

func _ready() -> void:
	for i: int in _choices.get_child_count():
		var b: Button = _choices.get_child(i) as Button
		if b:
			b.pressed.connect(func() -> void: choice_made.emit(i))

func show_event(title: String, body: String, options: Array = []) -> void:
	_title.text = title
	_body.text = body
	for i: int in _choices.get_child_count():
		var b: Button = _choices.get_child(i) as Button
		if b == null:
			continue
		if i < options.size():
			b.text = str(options[i])
			b.visible = true
		elif not options.is_empty():
			b.visible = false
	visible = true
"""
}

const API: Dictionary = {
	"healthbar": ["set_health(value, max_value = -1)", "signal changed(value, max_value)", "signal depleted"],
	"dialogue_box": ["show_line(speaker, text)", "skip()", "signal line_finished", "signal advance_requested"],
	"inventory_grid": ["set_item(index, icon, count = 1)", "clear_slot(index)", "slot_count()", "signal slot_pressed(index)"],
	"pause_menu": ["open()", "close()", "signal action_selected(action)"],
	"framed_panel": ["set_title(text)", "content() -> VBoxContainer", "signal close_requested"],
	"resource_strip": ["set_value(key, value_text)"],
	"list_row": ["setup(title, subtitle = '', action_text = '')", "signal action_pressed"],
	"event_popup": ["show_event(title, body, options = [])", "signal choice_made(index)"]
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
		"framed_panel": root = _framed_panel(opts, parts)
		"resource_strip": root = _resource_strip(opts, parts)
		"list_row": root = _list_row(opts, parts)
		"event_popup": root = _event_popup(opts, parts)
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

static func _framed_panel(opts: Dictionary, parts: Dictionary) -> Node:
	var root: PanelContainer = PanelContainer.new()
	root.name = str(opts.get("name", "FramedPanel"))
	root.theme_type_variation = "Card"
	root.custom_minimum_size = Vector2(360, 220)
	var col: BoxContainer = _box(_margin(root, parts), VBoxContainer.new(), "Column", parts)
	var header: BoxContainer = _box(col, HBoxContainer.new(), "Header", parts)
	var title: Label = _label(header, "TitleLabel", str(opts.get("title", "Panel")), "HeaderMedium", true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "CloseButton", "X", Vector2(TOUCH_MIN, TOUCH_MIN), "GhostButton", true)
	_add(col, HSeparator.new(), "Divider")
	var body: BoxContainer = _box(col, VBoxContainer.new(), "Body", parts, true)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return root

static func _resource_strip(opts: Dictionary, parts: Dictionary) -> Node:
	var root: PanelContainer = PanelContainer.new()
	root.name = str(opts.get("name", "ResourceStrip"))
	var row: BoxContainer = _box(_margin(root, parts), HBoxContainer.new(), "Row", parts, true)
	var items: Array = opts.get("resources", ["gold", "manpower", "stability"]) as Array if opts.get("resources") is Array else ["gold", "manpower", "stability"]
	if items.is_empty():
		items = ["gold"]
	for i: int in mini(items.size(), 8):
		var key: String = str(items[i]).strip_edges()
		if key.is_empty():
			continue
		var cell: BoxContainer = _box(row, HBoxContainer.new(), key, parts)
		_label(cell, "Caption", key.capitalize() + ":", "Caption")
		_label(cell, "Value", "0", "AccentLabel")
		if i < items.size() - 1:
			_add(row, VSeparator.new(), "Sep_%d" % i)
	return root

static func _list_row(opts: Dictionary, parts: Dictionary) -> Node:
	var root: PanelContainer = PanelContainer.new()
	root.name = str(opts.get("name", "ListRow"))
	var row: BoxContainer = _box(_margin(root, parts), HBoxContainer.new(), "Row", parts)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var info: BoxContainer = _box(row, VBoxContainer.new(), "Info", parts)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(info, "TitleLabel", str(opts.get("title", "Item")), "HeaderMedium", true)
	_label(info, "SubLabel", str(opts.get("sample_text", "Details")), "Caption", true)
	_button(row, "ActionButton", str(opts.get("next_text", "Select")), Vector2(96, TOUCH_MIN), "PrimaryButton", true)
	return root

static func _event_popup(opts: Dictionary, parts: Dictionary) -> Node:
	var root: Control = Control.new()
	root.name = str(opts.get("name", "EventPopup"))
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = _add(root, ColorRect.new(), "Dim") as ColorRect
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var center: CenterContainer = _add(root, CenterContainer.new(), "Center") as CenterContainer
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card: PanelContainer = _add(center, PanelContainer.new(), "Card") as PanelContainer
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(420, 260)
	var col: BoxContainer = _box(_margin(card, parts), VBoxContainer.new(), "Column", parts)
	_label(col, "TitleLabel", str(opts.get("title", "Event")), "HeaderLarge", true)
	_add(col, HSeparator.new(), "Divider")
	var body: RichTextLabel = _add(col, RichTextLabel.new(), "BodyLabel", true) as RichTextLabel
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.text = str(opts.get("sample_text", "An unexpected event has occurred."))
	body.custom_minimum_size = Vector2(360, 80)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var choices: BoxContainer = _box(col, VBoxContainer.new(), "Choices", parts, true)
	var labels: Array = opts.get("buttons", ["Accept", "Decline"]) as Array if opts.get("buttons") is Array else ["Accept", "Decline"]
	if labels.is_empty():
		labels = ["Accept"]
	for i: int in mini(labels.size(), 6):
		_button(choices, "Choice_%d" % i, str(labels[i]), Vector2(360, TOUCH_MIN), "PrimaryButton" if i == 0 else "")
	return root
