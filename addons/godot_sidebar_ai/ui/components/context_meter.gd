@tool
extends VBoxContainer
class_name AISidebarContextMeter

## Giriş kutusunun üstündeki bağlam göstergesi. Yalnız sağlayıcının bildirdiği token sayılarını gösterir
## (AISidebarContextBudget; tahmin yok): bağlamdaki doluluk / pencere boyu, çubuk ve oturum toplamları
## (giden, önbellekten, gelen). Pencere boyu bilinmiyorsa çubuk yerine yalnız sayı. Sağlayıcı hiç
## bildirmediyse görünmez. Koruma bağlamı sıkıştırdıysa ya da pencere dolmak üzereyse bir satır uyarı.

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarContextBudget = preload("res://addons/godot_sidebar_ai/core/agent/context_budget.gd")

var bar: ProgressBar
var used_label: Label
var totals_label: Label
var notice_label: Label
var _snapshot: Dictionary = {}
var _compacted: bool = false

func _init() -> void:
	name = "ContextMeter"
	visible = false
	add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_XXS))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	add_child(row)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, AISidebarTheme.px(AISidebarTheme.SPACE_XS + 1))
	bar.max_value = 1.0
	bar.step = 0.0
	bar.theme_type_variation = AISidebarThemeBuilder.METER
	row.add_child(bar)
	used_label = Label.new()
	used_label.theme_type_variation = AISidebarThemeBuilder.HINT_MUTED
	used_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(used_label)
	totals_label = Label.new()
	totals_label.theme_type_variation = AISidebarThemeBuilder.HINT_MUTED
	totals_label.clip_text = true
	totals_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(totals_label)
	notice_label = Label.new()
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.visible = false
	add_child(notice_label)

## AgentHost.budget_changed: bütçe anlık görüntüsü; `compacted` bu yanıtta sıkıştırma yapıldıysa true.
func update_budget(snapshot: Dictionary, compacted: bool = false) -> void:
	_snapshot = snapshot
	_compacted = compacted
	refresh_texts()

## Metinleri seçili dilde yeniden yazar (dil değişince dock çağırır).
func refresh_texts() -> void:
	visible = _snapshot.get("has_data", false) == true
	if not visible:
		return
	var used: int = _snapshot.get("used", 0)
	var window: int = _snapshot.get("window", 0)
	var ratio: float = _snapshot.get("ratio", -1.0)
	bar.visible = window > 0
	if window > 0:
		bar.value = clampf(ratio, 0.0, 1.0)
		bar.theme_type_variation = AISidebarThemeBuilder.METER_DANGER if ratio >= AISidebarContextBudget.WARN_RATIO else (AISidebarThemeBuilder.METER_WARNING if ratio >= AISidebarContextBudget.COMPACT_RATIO else AISidebarThemeBuilder.METER)
		used_label.text = AISidebarI18n.get_text("context_used_of", {"used": AISidebarContextBudget.short(used), "window": AISidebarContextBudget.short(window), "pct": roundi(ratio * 100.0)})
	else:
		used_label.text = AISidebarI18n.get_text("context_used_only", {"used": AISidebarContextBudget.short(used)})
	used_label.size_flags_horizontal = Control.SIZE_SHRINK_END if window > 0 else Control.SIZE_EXPAND_FILL
	var t_in: int = _snapshot.get("total_input", 0)
	var t_cached: int = _snapshot.get("total_cached", 0)
	var t_out: int = _snapshot.get("total_output", 0)
	var reqs: int = _snapshot.get("requests", 0)
	totals_label.text = AISidebarI18n.get_text("context_totals", {
		"input": AISidebarContextBudget.short(t_in),
		"cached": AISidebarContextBudget.short(t_cached),
		"output": AISidebarContextBudget.short(t_out),
		"requests": reqs,
	})
	tooltip_text = AISidebarI18n.get_text("context_tooltip" if window > 0 else "context_tooltip_no_window")
	var notice := ""
	if window > 0 and ratio >= AISidebarContextBudget.WARN_RATIO:
		notice = AISidebarI18n.get_text("context_near_limit", {"pct": roundi(ratio * 100.0)})
		notice_label.theme_type_variation = AISidebarThemeBuilder.TEXT_ERROR
	elif _compacted:
		notice = AISidebarI18n.get_text("context_compacted", {"pct": roundi(ratio * 100.0)})
		notice_label.theme_type_variation = AISidebarThemeBuilder.HINT
	notice_label.text = notice
	notice_label.visible = not notice.is_empty()
