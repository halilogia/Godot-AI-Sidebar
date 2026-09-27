@tool
extends Node

## Ajan katmanının kompozisyon birimi (SRP): NetworkManager, provider, AgentContext ve
## AgentRunner'ın sahibidir. Provider config'e göre kurulur ve ayar değişince yenilenir.
## UI provider'a doğrudan dokunmaz; model listesini ve hazırlık durumunu bu birimden dinler.
## Kompozisyon kökü plugin.gd'dir: host'u kurar ve ChatDock'a enjekte eder.

const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarContextBudget = preload("res://addons/godot_sidebar_ai/core/agent/context_budget.gd")

## Aktif provider'ın model listesi geldi.
signal models_fetched(models: Array)
## Aktif provider'ın hazırlık durumu değişti (yalnızca AGY gibi alt süreçli provider'lar yayar).
signal readiness_changed(state: int, message: String)
## Bağlam bütçesi değişti (sağlayıcı token kullanımı bildirdi ya da sıfırlandı). `compacted`: koruma
## bu yanıtta bağlamı sıkıştırdı.
signal budget_changed(snapshot: Dictionary, compacted: bool)

var network_manager: AISidebarNetworkManager
var provider: AISidebarAIProvider = null
var context: AISidebarAgentContext
var runner: AISidebarAgentRunner
## Yalnız sağlayıcının bildirdiği token sayıları (tahmin yok).
var budget: AISidebarContextBudget = AISidebarContextBudget.new()

func _init() -> void:
	network_manager = AISidebarNetworkManager.new()
	add_child(network_manager)
	context = AISidebarAgentContext.new()
	runner = AISidebarAgentRunner.new(null, context)

## Provider tipine göre yeni provider (ısıtma yok; alt süreç başlatılmaz).
static func create_provider(provider_type: String, p_network_manager: AISidebarNetworkManager) -> AISidebarAIProvider:
	if provider_type == "openai_compatible":
		return AISidebarOpenAICompatibleProvider.new(p_network_manager)
	return AISidebarAGYProvider.new()

## Config'e göre provider'ı (yeniden) kurar: eskisinin süren isteğini iptal eder ve alt sürecini durdurur, yenisini bağlar,
## ısıtır (pre_warm) ve runner'ı ona geçirir.
func rebuild_provider() -> void:
	var cfg = AISidebarConfig.load_config()
	var prov_type = cfg.get("provider_type", "antigravity_cli")
	# Süren istek kapatılır: yanıtı ortak NetworkManager üzerinden yeni provider'a gelmesin.
	if provider:
		provider.cancel()
	if provider and provider.has_method("stop_process"):
		provider.stop_process()
	_bind_provider(create_provider(prov_type, network_manager), true)

## Hazır bir provider'ı bağlar (config dışı kompozisyon ve testler için); ısıtma yapılmaz.
func set_provider(p_provider: AISidebarAIProvider) -> void:
	_bind_provider(p_provider, false)

## Eski provider'ı emekliye ayırır (dispose) ve aktarım bağlarını koparır, yenisininkileri kurar. Isıtma, runner yeni
## provider'a geçmeden önce yapılır (ısıtma sırasındaki provider hatası runner'a gitmez).
func _bind_provider(p_provider: AISidebarAIProvider, warm: bool) -> void:
	if provider and provider != p_provider:
		provider.dispose()
	if provider:
		if provider.models_fetched.is_connected(_relay_models_fetched):
			provider.models_fetched.disconnect(_relay_models_fetched)
		if provider.usage_reported.is_connected(_on_usage_reported):
			provider.usage_reported.disconnect(_on_usage_reported)
		if provider.has_signal("readiness_changed") and provider.readiness_changed.is_connected(_relay_readiness_changed):
			provider.readiness_changed.disconnect(_relay_readiness_changed)
	provider = p_provider
	if provider:
		provider.models_fetched.connect(_relay_models_fetched)
		provider.usage_reported.connect(_on_usage_reported)
		if provider.has_signal("readiness_changed"):
			provider.readiness_changed.connect(_relay_readiness_changed)
		if warm and provider.has_method("pre_warm"):
			provider.pre_warm()
	runner.set_provider(provider)

func _relay_models_fetched(models: Array) -> void:
	models_fetched.emit(models)
	# Model listesi pencere boyunu da getirmiş olabilir.
	refresh_budget_window()

## Pencere boyu: Ayarlar'daki değer, yoksa sağlayıcının model listesindeki değer, yoksa 0 (bilinmiyor).
func refresh_budget_window() -> void:
	var cfg := AISidebarConfig.load_config()
	var configured := int(str(cfg.get("context_window", 0)).to_float())
	var from_provider := provider.context_window_for(str(cfg.get("selected_model", ""))) if provider else 0
	budget.window = configured if configured > 0 else from_provider
	budget_changed.emit(budget.snapshot(), false)

## Sağlayıcı token kullanımını bildirdi: bütçe güncellenir; gerçek doluluk sınırı geçtiyse bağlam, runner
## bir sonraki isteği kurmadan önce sıkıştırılır (kullanım yanıttan önce yayılır).
func _on_usage_reported(usage: Dictionary) -> void:
	if not budget.record(usage):
		return
	var compacted := false
	if budget.should_compact() and context != null:
		compacted = context.compact_now()
	budget_changed.emit(budget.snapshot(), compacted)

## Yeni sohbet: sayılar sıfırlanır.
func reset_budget() -> void:
	budget.reset()
	budget_changed.emit(budget.snapshot(), false)

func _relay_readiness_changed(state: int, message: String) -> void:
	readiness_changed.emit(state, message)

func has_provider() -> bool:
	return provider != null

func fetch_models() -> void:
	if provider:
		provider.fetch_models()

## Aktif provider görsel girdi destekliyor mu? Provider yoksa false.
func supports_vision() -> bool:
	return provider != null and provider.has_method("supports_vision") and provider.supports_vision()

## Aktif provider'ın hazırlık durumu var mı (AGY)? Yoksa hazırlık olayları yok sayılır.
func has_readiness_state() -> bool:
	return provider != null and provider.has_method("is_ready")

func is_provider_ready() -> bool:
	return has_readiness_state() and provider.is_ready()

## Alt süreçli provider'ı (AGY) durdurur; diğerlerinde etkisizdir.
func stop_provider_process() -> void:
	if provider and provider.has_method("stop_process"):
		provider.stop_process()
