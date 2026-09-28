@tool
extends RefCounted

## Model çubuğu (SRP): sağlayıcı profili seçici (iki ya da daha çok profil varken görünür), model listesi
## (önbellek + provider'dan gelen), seçili modelin kaydı ve onay modu butonu (Manuel → Otomatik → Tam otomatik).
## Provider'ın kurulması ChatDock'ta kalır; bu sınıf yalnızca model çubuğunu yönetir.

const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

var model_selector: OptionButton = null
var provider_selector: OptionButton = null
## func() — etkin profil değişti: ChatDock sağlayıcıyı yeniden kurar ve model listesini çeker.
var on_provider_switched: Callable = func() -> void: pass
var _profile_ids: Array[String] = []
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

## Eylem / Plan modu hapı: Eylem = ajan işi kendi içinde aşamalara bölüp doğrudan yürütür; Plan = önce görünür
## plan ve onay. Ayar: planning_mode (Ayarlar → Genel → Planlama ile aynı). /plan tek istek için Plan.
var plan_mode_btn: Button = null

func update_plan_mode_ui() -> void:
	if not plan_mode_btn:
		return
	var on: bool = AISidebarConfig.load_config().get("planning_mode", false) == true
	plan_mode_btn.text = AISidebarI18n.get_text("mode_plan") if on else AISidebarI18n.get_text("mode_build")
	plan_mode_btn.tooltip_text = AISidebarI18n.get_text("mode_plan_desc") if on else AISidebarI18n.get_text("mode_build_desc")
	plan_mode_btn.theme_type_variation = AISidebarThemeBuilder.pill(AISidebarThemeBuilder.TONE_ACCENT if on else AISidebarThemeBuilder.TONE_MUTED)

func on_plan_mode_pressed() -> void:
	var cfg: Dictionary = AISidebarConfig.load_config()
	cfg["planning_mode"] = not (cfg.get("planning_mode", false) == true)
	AISidebarConfig.save_config(cfg)
	update_plan_mode_ui()

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

## Profil seçici config'teki profillerle doldurulur; tek profil varken gizlidir (çubuk değişmez).
func load_profiles() -> void:
	if not provider_selector:
		return
	var cfg := AISidebarConfig.load_config()
	var active := str(cfg.get("active_provider_id", ""))
	provider_selector.clear()
	_profile_ids.clear()
	for prof: Dictionary in AISidebarConfig.profiles(cfg):
		_profile_ids.append(str(prof.get("id", "")))
		provider_selector.add_item(str(prof.get("name", "?")))
		if _profile_ids[-1] == active:
			provider_selector.selected = _profile_ids.size() - 1
	provider_selector.visible = _profile_ids.size() >= 2

func on_provider_selected(index: int) -> void:
	if index < 0 or index >= _profile_ids.size():
		return
	var cfg := AISidebarConfig.load_config()
	if str(cfg.get("active_provider_id", "")) == _profile_ids[index]:
		return
	if AISidebarConfig.activate_profile(cfg, _profile_ids[index]):
		AISidebarConfig.save_config(cfg)
		load_cached_models()
		on_provider_switched.call()

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
		if not models.has(selected_model):
			cfg["selected_model"] = str(models[0])
			AISidebarConfig.save_config(cfg)

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
