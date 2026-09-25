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

## Aktif provider'ın model listesi geldi.
signal models_fetched(models: Array)
## Aktif provider'ın hazırlık durumu değişti (yalnızca AGY gibi alt süreçli provider'lar yayar).
signal readiness_changed(state: int, message: String)

var network_manager: AISidebarNetworkManager
var provider: AISidebarAIProvider = null
var context: AISidebarAgentContext
var runner: AISidebarAgentRunner

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
		if provider.has_signal("readiness_changed") and provider.readiness_changed.is_connected(_relay_readiness_changed):
			provider.readiness_changed.disconnect(_relay_readiness_changed)
	provider = p_provider
	if provider:
		provider.models_fetched.connect(_relay_models_fetched)
		if provider.has_signal("readiness_changed"):
			provider.readiness_changed.connect(_relay_readiness_changed)
		if warm and provider.has_method("pre_warm"):
			provider.pre_warm()
	runner.set_provider(provider)

func _relay_models_fetched(models: Array) -> void:
	models_fetched.emit(models)

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
