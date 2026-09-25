@tool
extends RefCounted

## ModelBarController testleri: onay modu döngüsü + rozet kuralı, model listesi seçimi,
## seçimin ve provider'dan gelen listenin config'e yazılması.
## Kullanıcının config.json'u test başında aynen saklanır ve sonunda geri yazılır.

const AISidebarModelBarController = preload("res://addons/godot_sidebar_ai/ui/controllers/model_bar_controller.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	var had_file = FileAccess.file_exists(AISidebarConfig.CONFIG_PATH)
	var original_raw = FileAccess.get_file_as_string(AISidebarConfig.CONFIG_PATH) if had_file else ""

	var badge: Array = []
	var ctrl = AISidebarModelBarController.new()
	ctrl.model_selector = OptionButton.new()
	ctrl.approve_mode_btn = Button.new()
	ctrl.set_status = func(t, _c): badge.append(t)

	# 1. Onay modu döngüsü: Manuel → Otomatik → Tam otomatik → Manuel. Mod yalnızca butonda
	# görünür (ikon + renkli hap); durum rozeti modu tekrar etmez, mod değişimi rozete dokunmaz.
	AISidebarPermissionPolicy.set_auto_approve_mode(AISidebarPermissionPolicy.AutoApproveMode.MANUAL)
	ctrl.on_approve_mode_pressed()
	var step1 = AISidebarPermissionPolicy.get_auto_approve_mode() == AISidebarPermissionPolicy.AutoApproveMode.AUTO and ctrl.approve_mode_btn.text == AISidebarI18n.get_text("mode_auto")
	ctrl.on_approve_mode_pressed()
	var step2 = AISidebarPermissionPolicy.get_auto_approve_mode() == AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO and ctrl.approve_mode_btn.text == AISidebarI18n.get_text("mode_full_auto")
	ctrl.on_approve_mode_pressed()
	var step3 = AISidebarPermissionPolicy.get_auto_approve_mode() == AISidebarPermissionPolicy.AutoApproveMode.MANUAL and ctrl.approve_mode_btn.text == AISidebarI18n.get_text("mode_manual")
	var no_badge = badge.is_empty()
	var styled = ctrl.approve_mode_btn.icon != null and ctrl.approve_mode_btn.has_theme_stylebox_override("normal") and ctrl.approve_mode_btn.tooltip_text.contains(AISidebarI18n.get_text("mode_manual_desc"))
	if step1 and step2 and step3 and no_badge and styled:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (approve mode cycle) failed: %s %s %s no_badge=%s styled=%s badge=%s" % [str(step1), str(step2), str(step3), str(no_badge), str(styled), str(badge)])

	# 1b. Durum rozeti mod adını tekrar etmez (ekranda iki kez "Manual" yazmasın)
	var ready_txt = AISidebarI18n.get_text("status_ready")
	var mode_names_absent = true
	for key in ["mode_manual", "mode_auto", "mode_full_auto"]:
		if ready_txt.contains(AISidebarI18n.get_text(key)):
			mode_names_absent = false
	var specs_ok = true
	for m in [AISidebarPermissionPolicy.AutoApproveMode.MANUAL, AISidebarPermissionPolicy.AutoApproveMode.AUTO, AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO]:
		var spec = AISidebarModelBarController.approve_mode_spec(m)
		if not FileAccess.file_exists("res://addons/godot_sidebar_ai/assets/icons/" + str(spec["icon"]) + ".svg"):
			specs_ok = false
	if mode_names_absent and specs_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T1b (badge/mode spec) failed: absent=%s icons=%s" % [str(mode_names_absent), str(specs_ok)])

	# 2. Liste doldurma kayıtlı modeli seçer; seçim ve gelen liste config'e yazılır
	var cfg = AISidebarConfig.load_config()
	cfg["selected_model"] = "model-b"
	AISidebarConfig.save_config(cfg)
	ctrl.populate_model_selector(["model-a", "model-b", "model-c"])
	var preselected = ctrl.model_selector.item_count == 3 and ctrl.model_selector.selected == 1
	ctrl.on_model_selected(2)
	var saved_choice = str(AISidebarConfig.load_config().get("selected_model", "")) == "model-c"
	ctrl.on_model_selected(99)
	var ignored_bad_index = str(AISidebarConfig.load_config().get("selected_model", "")) == "model-c"
	badge.clear()
	ctrl.on_models_fetched(["x", "model-c"])
	var fetched = AISidebarConfig.load_config().get("cached_models", []) == ["x", "model-c"] and ctrl.model_selector.item_count == 2 and ctrl.model_selector.selected == 1 and badge == ["Ready"]
	if preselected and saved_choice and ignored_bad_index and fetched:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (model list) failed: pre=%s saved=%s bad=%s fetched=%s" % [str(preselected), str(saved_choice), str(ignored_bad_index), str(fetched)])

	ctrl.model_selector.free()
	ctrl.approve_mode_btn.free()

	# Kullanıcı config'ini aynen geri yükle
	if had_file:
		var f = FileAccess.open(AISidebarConfig.CONFIG_PATH, FileAccess.WRITE)
		f.store_string(original_raw)
		f.close()
	elif FileAccess.file_exists(AISidebarConfig.CONFIG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AISidebarConfig.CONFIG_PATH))

	return {"name": "ModelBarControllerTests", "passed": passed, "failed": failed, "errors": errors}
