@tool
extends RefCounted

## Model çubuğu (SRP): model listesi (önbellek + provider'dan gelen), seçili modelin
## kaydı ve onay modu butonu (Manuel → Otomatik → Tam otomatik döngüsü).
## Provider'ın kurulması ChatDock'ta kalır; bu sınıf yalnızca model çubuğunu yönetir.

const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

var model_selector: OptionButton = null
var approve_mode_btn: Button = null
## func(text: String, color: Color) — durum rozeti.
var set_status: Callable = func(_t, _c): pass

var current_model_list: Array = []

## Onay modu → buton metni, açıklaması, Lucide ikonu ve tonu (hap varyasyonu).
static func approve_mode_spec(mode: int) -> Dictionary:
	match mode:
		AISidebarPermissionPolicy.AutoApproveMode.AUTO:
			return {"text": "mode_auto", "desc": "mode_auto_desc", "icon": "shield-check", "tone": AISidebarThemeBuilder.TONE_SUCCESS}
		AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO:
			return {"text": "mode_full_auto", "desc": "mode_full_auto_desc", "icon": "zap", "tone": AISidebarThemeBuilder.TONE_FULL_AUTO}
	return {"text": "mode_manual", "desc": "mode_manual_desc", "icon": "hand", "tone": AISidebarThemeBuilder.TONE_WARNING}

## Mod butonu tek kaynaktır: durum rozeti modu tekrar etmez.
func update_approve_mode_ui() -> void:
	if not approve_mode_btn:
		return
	var spec = approve_mode_spec(AISidebarPermissionPolicy.get_auto_approve_mode())
	var tone: String = spec["tone"]
	var color := AISidebarThemeBuilder.tone_color(tone)
	approve_mode_btn.text = AISidebarI18n.get_text(spec["text"])
	approve_mode_btn.tooltip_text = AISidebarI18n.get_text("tooltip_approve_mode") + "\n" + AISidebarI18n.get_text(spec["desc"])
	approve_mode_btn.theme_type_variation = AISidebarThemeBuilder.pill(tone)
	AISidebarIconHelper.apply_tinted_icon(approve_mode_btn, spec["icon"], color, AISidebarTheme.ICON_SIZE_SM)

func on_approve_mode_pressed() -> void:
	var current_mode = AISidebarPermissionPolicy.get_auto_approve_mode()
	var next_mode = AISidebarPermissionPolicy.AutoApproveMode.MANUAL
	match current_mode:
		AISidebarPermissionPolicy.AutoApproveMode.MANUAL:
			next_mode = AISidebarPermissionPolicy.AutoApproveMode.AUTO
		AISidebarPermissionPolicy.AutoApproveMode.AUTO:
			next_mode = AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO
		AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO:
			next_mode = AISidebarPermissionPolicy.AutoApproveMode.MANUAL
	AISidebarPermissionPolicy.set_auto_approve_mode(next_mode)
	update_approve_mode_ui()

func load_cached_models() -> void:
	var cfg = AISidebarConfig.load_config()
	var cached: Array = cfg.get("cached_models", ["all", "free"])
	populate_model_selector(cached)

func populate_model_selector(models: Array) -> void:
	if not model_selector:
		return

	current_model_list = models
	model_selector.clear()

	var cfg = AISidebarConfig.load_config()
	var selected_model = cfg.get("selected_model", "all")
	var selected_idx = 0

	for i in range(models.size()):
		var m_name = str(models[i])
		model_selector.add_item(m_name, i)
		if m_name == selected_model:
			selected_idx = i

	if model_selector.item_count > 0:
		model_selector.selected = selected_idx

func on_models_fetched(models: Array) -> void:
	var cfg = AISidebarConfig.load_config()
	cfg["cached_models"] = models
	AISidebarConfig.save_config(cfg)

	populate_model_selector(models)
	set_status.call(AISidebarI18n.get_text("status_ready"), AISidebarTheme.COLOR_SUCCESS)

func on_model_selected(index: int) -> void:
	if index >= 0 and index < current_model_list.size():
		var chosen = current_model_list[index]
		var cfg = AISidebarConfig.load_config()
		cfg["selected_model"] = chosen
		AISidebarConfig.save_config(cfg)
