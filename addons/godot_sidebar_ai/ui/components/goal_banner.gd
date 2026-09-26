@tool
extends PanelContainer
class_name AISidebarGoalBanner

## Etkin hedefin (/goal) giriş alanının üstündeki şeridi: hedef metni (tek satır, üç noktayla kesilir,
## tamamı ipucunda), tur sayacı ve Durdur düğmesi. Hedef yokken gizlidir.

signal stop_requested()

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarStatusIcon = preload("res://addons/godot_sidebar_ai/ui/components/status_icon.gd")

var _goal_lbl: Label
var _round_lbl: Label
var _stop_btn: Button

func _init() -> void:
	name = "GoalBanner"
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theme_type_variation = AISidebarThemeBuilder.CARD_INFO
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	add_child(row)
	var icon := AISidebarStatusIcon.new(AISidebarTheme.ICON_SIZE_MD)
	icon.set_icon("target", AISidebarTheme.COLOR_TONE_INFO_TEXT)
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_XXS))
	row.add_child(texts)
	_goal_lbl = Label.new()
	_goal_lbl.theme_type_variation = AISidebarThemeBuilder.BODY
	_goal_lbl.clip_text = true
	_goal_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_goal_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	texts.add_child(_goal_lbl)
	_round_lbl = Label.new()
	_round_lbl.theme_type_variation = AISidebarThemeBuilder.MICRO
	texts.add_child(_round_lbl)
	_stop_btn = Button.new()
	_stop_btn.theme_type_variation = AISidebarThemeBuilder.GHOST_BUTTON
	_stop_btn.focus_mode = Control.FOCUS_NONE
	_stop_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	AISidebarIconHelper.apply_tinted_icon(_stop_btn, "stop", AISidebarTheme.COLOR_TEXT_SECONDARY, AISidebarTheme.ICON_SIZE_SM)
	_stop_btn.pressed.connect(func() -> void: stop_requested.emit())
	row.add_child(_stop_btn)

## Hedef etkinse gösterir; objective boşsa gizler.
func show_goal(objective: String, current_round: int, max_rounds: int) -> void:
	visible = not objective.is_empty()
	if not visible:
		return
	_goal_lbl.text = AISidebarI18n.get_text("goal_banner_goal", {"objective": objective.replace("\n", " ")})
	_goal_lbl.tooltip_text = objective
	_round_lbl.text = AISidebarI18n.get_text("goal_banner_round", {"round": current_round, "max": max_rounds})
	_stop_btn.text = AISidebarI18n.get_text("goal_banner_stop")
	_stop_btn.tooltip_text = AISidebarI18n.get_text("goal_banner_stop_tooltip")

func get_goal_text() -> String:
	return _goal_lbl.text

func get_round_text() -> String:
	return _round_lbl.text
