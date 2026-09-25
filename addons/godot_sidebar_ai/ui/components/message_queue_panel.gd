@tool
extends PanelContainer

## Queued Messages: ajan çalışırken gönderilen mesajların FIFO kuyruğu ve paneli (SRP).
## Veri ve görünüm birlikte tutulur; ne zaman dispatch edileceğine ChatDock karar verir.

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

var _items: Array[Dictionary] = []
var _title_label: Label = null
var _items_vbox: VBoxContainer = null
var _clear_btn: Button = null

func _init() -> void:
	name = "QueueContainer"
	visible = false
	add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XXS)

	var header = HBoxContainer.new()
	_title_label = Label.new()
	_title_label.text = "Queued Messages (0)"
	_title_label.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	_title_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	header.add_child(_title_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_clear_btn = Button.new()
	_clear_btn.text = "Clear All"
	_clear_btn.flat = true
	_clear_btn.focus_mode = Control.FOCUS_NONE
	_clear_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_ghost_button_style(false))
	_clear_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_ghost_button_style(true))
	_clear_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	_clear_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_ERROR)
	_clear_btn.pressed.connect(clear_all)
	header.add_child(_clear_btn)
	vbox.add_child(header)

	_items_vbox = VBoxContainer.new()
	_items_vbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XXS)
	vbox.add_child(_items_vbox)

	add_child(vbox)

## Kuyruğa ekle. vision_inputs null ise item'a hiç yazılmaz (slash komutları).
func enqueue(prompt: String, display_prompt: String, vision_inputs = null) -> void:
	var item = {
		"id": "q_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000),
		"prompt": prompt,
		"display_prompt": display_prompt,
		"created_at": Time.get_unix_time_from_system()
	}
	if vision_inputs != null:
		item["vision_inputs"] = vision_inputs
	_items.append(item)
	_refresh()

## Sıradaki item'ı çıkarır; kuyruk boşsa {} döner.
func pop_next() -> Dictionary:
	if _items.is_empty():
		return {}
	var next_item = _items.pop_front()
	_refresh()
	return next_item

func cancel(item_id: String) -> void:
	for i in range(_items.size()):
		if _items[i].get("id", "") == item_id:
			_items.remove_at(i)
			break
	_refresh()

func clear_all() -> void:
	_items.clear()
	_refresh()

func count() -> int:
	return _items.size()

func get_items() -> Array[Dictionary]:
	return _items.duplicate()

func get_title_text() -> String:
	return _title_label.text

func _refresh() -> void:
	for child in _items_vbox.get_children():
		child.queue_free()

	if _items.is_empty():
		visible = false
		return

	visible = true
	_title_label.text = "Queued Messages (%d)" % _items.size()

	for i in range(_items.size()):
		var item = _items[i]
		var item_row = HBoxContainer.new()
		item_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var num_label = Label.new()
		num_label.text = str(i + 1) + "."
		num_label.add_theme_font_size_override("font_size", 10)
		num_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		item_row.add_child(num_label)

		var prompt_label = Label.new()
		var label_text = str(item.get("display_prompt", item.get("prompt", ""))).replace("\n", " ")
		prompt_label.text = label_text
		prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prompt_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		prompt_label.clip_text = true
		prompt_label.add_theme_font_size_override("font_size", 10)
		item_row.add_child(prompt_label)

		var cancel_btn = Button.new()
		AISidebarIconHelper.apply_tinted_icon(cancel_btn, "x", Color(0.9, 0.4, 0.4), 12)
		cancel_btn.flat = true
		cancel_btn.focus_mode = Control.FOCUS_NONE
		cancel_btn.add_theme_font_size_override("font_size", 10)
		cancel_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		cancel_btn.tooltip_text = "Bu sıradaki mesajı iptal et"
		var item_id = item.get("id", "")
		cancel_btn.pressed.connect(func(): cancel(item_id))
		item_row.add_child(cancel_btn)

		_items_vbox.add_child(item_row)
