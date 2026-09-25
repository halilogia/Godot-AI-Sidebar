@tool
extends RefCounted

## Provider kompozisyonu (AgentHost + ChatDock, Refactor Faz 2.0): config'e göre provider seçimi ve
## NetworkManager bağı, ayar kaydında runner'ın yeni provider'a geçmesi (eski provider'ın bağı
## kopar), model listesi ve AGY hazırlık rozeti aktarımı, görsel desteği, Refresh ve kapanışta alt
## sürecin durdurulması. AGY dalı config ile kurulmaz: pre_warm gerçek 'agy' sürecini başlatır.
## Kullanıcının config.json'u test başında aynen saklanır ve sonunda geri yazılır.

const ChatDockScene = preload("res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentHost = preload("res://addons/godot_sidebar_ai/core/agent/agent_host.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarAGYProvider = preload("res://addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

## is_ready / readiness_changed / stop_process taşıyan (AGY benzeri) sahte provider.
class FakeAgyProvider extends AISidebarAIProvider:
	signal readiness_changed(state: int, message: String)
	var ready_flag: bool = false
	var vision: bool = false
	var fetch_calls: int = 0
	var stop_calls: int = 0
	func is_ready() -> bool:
		return ready_flag
	func supports_vision() -> bool:
		return vision
	func fetch_models() -> void:
		fetch_calls += 1
	func stop_process() -> void:
		stop_calls += 1
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		pass

## Hazırlık durumu ve alt süreci olmayan provider.
class PlainProvider extends AISidebarAIProvider:
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		pass

## Editör yolundaki bağlama ile aynı (host plugin.gd yerine burada kurulur); provider
## başlangıçta PlainProvider'dır.
static func _make_dock() -> Dictionary:
	var dock = ChatDockScene.instantiate()
	dock._ready()
	dock.auto_scroll_enabled = false
	for child in dock.message_stream.get_children():
		child.free()
	var host = AISidebarAgentHost.new()
	host.set_provider(PlainProvider.new())
	dock.attach_agent_host(host)
	return {"dock": dock, "host": host, "runner": host.runner}

## Testin kullandığı provider'ı host üzerinden bağlar (runner ve hazırlık aktarımı dahil).
static func _use_provider(dock, p) -> void:
	dock.agent_host.set_provider(p)

static func _dispose(dock) -> void:
	var host = dock.agent_host
	if dock.agent_runner.is_running():
		dock.agent_runner.stop()
	dock.stream.stop_thinking_timer()
	for child in dock.message_stream.get_children():
		child.free()
	dock.free()
	host.free()

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	var had_file = FileAccess.file_exists(AISidebarConfig.CONFIG_PATH)
	var original_raw = FileAccess.get_file_as_string(AISidebarConfig.CONFIG_PATH) if had_file else ""
	var cfg = AISidebarConfig.load_config()
	cfg["provider_type"] = "openai_compatible"
	AISidebarConfig.save_config(cfg)

	var made = _make_dock()
	var dock = made["dock"]
	var host = made["host"]
	var runner = made["runner"]

	# 1. openai_compatible: OpenAI provider host'un NetworkManager'ı ile kurulur, runner ona geçer
	dock._rebuild_provider()
	var p1 = host.provider
	var nm = host.network_manager
	var is_openai = p1 is AISidebarOpenAICompatibleProvider
	var nm_shared = is_openai and nm != null and p1.network_manager == nm and nm.get_parent() == host
	var runner_on_p1 = runner.provider == p1 and p1.response_received.is_connected(runner._on_provider_response)
	if is_openai and nm_shared and runner_on_p1:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (openai provider + network manager) failed: openai=%s nm=%s runner=%s" % [str(is_openai), str(nm_shared), str(runner_on_p1)])

	# 2. Ayar kaydı: yeni provider kurulur, aynı NetworkManager kullanılır, eski provider'ın
	# hiçbir sinyali runner'a veya model çubuğuna ulaşmaz; yenisinin model listesi ulaşır.
	# Eski provider'dan kalan "AGY hazırlanıyor" durumu sıfırlanır.
	dock.stream.agy_preparing = true
	# Ayar kaydı sırasında görev çalışıyor ve eski provider'ın isteği sürüyor: görev kullanıcı
	# adına durdurulur (Paused, "devam et" ile sürer) ve eski istek iptal edilir; aksi halde eski
	# yanıt yeni provider'a gelir ya da (AGY'ye geçişte) runner sonsuza kadar bekler.
	runner.current_state = AISidebarAgentRunner.AgentState.EXECUTING
	nm._is_request_active = true
	dock._rebuild_provider()
	var inflight_closed = not runner.is_running() and not nm._is_request_active and dock.tasks.is_user_stopped
	var p2 = host.provider
	var switched = p2 != p1 and p2 is AISidebarOpenAICompatibleProvider and runner.provider == p2 and not dock.stream.agy_preparing
	var same_nm = host.network_manager == nm and p2.network_manager == nm
	# Emekli provider hâlâ bir yerde tutulsa bile ortak NetworkManager'ı dinlemez (tek alıcı)
	var nm_single = nm.request_completed.get_connections().size() == 1 and nm.response_chunk_received.get_connections().size() == 1 and nm.request_failed.get_connections().size() == 1
	var old_detached = p1.response_received.get_connections().is_empty() and p1.chunk_received.get_connections().is_empty() and p1.error_occurred.get_connections().is_empty() and p1.models_fetched.get_connections().is_empty()
	p1.models_fetched.emit(["stale-a", "stale-b", "stale-c"])
	var stale_ignored = dock.model_selector.item_count != 3
	p2.models_fetched.emit(["m1", "m2"])
	var fresh_shown = dock.model_selector.item_count == 2 and dock.model_selector.get_item_text(0) == "m1"
	if switched and same_nm and nm_single and inflight_closed and old_detached and stale_ignored and fresh_shown:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (provider switch) failed: switched=%s nm=%s nm_single=%s inflight_closed=%s detached=%s stale=%s fresh=%s" % [str(switched), str(same_nm), str(nm_single), str(inflight_closed), str(old_detached), str(stale_ignored), str(fresh_shown)])

	# 3. AGY hazırlık rozeti: hazır değil -> "hazırlanıyor"; hazır + boşta -> "Hazır";
	# hazır + ajan çalışıyor -> "Thinking..."; hazırlık durumu olmayan provider rozete dokunmaz.
	var fake = FakeAgyProvider.new()
	_use_provider(dock, fake)
	fake.readiness_changed.emit(1, "")
	var preparing = dock.stream.agy_preparing and dock.status_badge.text == AISidebarI18n.get_text("status_agy_preparing")
	fake.ready_flag = true
	fake.readiness_changed.emit(2, "")
	var ready_idle = not dock.stream.agy_preparing and dock.status_badge.text == AISidebarI18n.get_text("status_ready")
	# Çalışan ajan: durum doğrudan yazılır (start_task'ın UI zamanlayıcısı bu testin konusu değil)
	runner.current_state = AISidebarAgentRunner.AgentState.EXECUTING
	fake.readiness_changed.emit(2, "")
	var ready_running = runner.is_running() and dock.status_badge.text == "Thinking..."
	runner.current_state = AISidebarAgentRunner.AgentState.IDLE
	var plain = PlainProvider.new()
	_use_provider(dock, plain)
	dock.stream.agy_preparing = true
	dock.status_badge.text = "badge"
	dock._on_provider_readiness_changed(2, "")
	var plain_ignored = dock.stream.agy_preparing and dock.status_badge.text == "badge"
	dock.stream.agy_preparing = false
	if preparing and ready_idle and ready_running and plain_ignored:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (readiness badge) failed: preparing=%s idle=%s running=%s plain=%s" % [str(preparing), str(ready_idle), str(ready_running), str(plain_ignored)])

	# 4. Görsel desteği aktif provider'a sorulur; provider yoksa false
	_use_provider(dock, fake)
	fake.vision = true
	var vision_on = dock.activity.supports_vision.call() == true
	fake.vision = false
	var vision_off = dock.activity.supports_vision.call() == false
	_use_provider(dock, null)
	var vision_none = dock.activity.supports_vision.call() == false
	if vision_on and vision_off and vision_none:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (supports_vision) failed: on=%s off=%s none=%s" % [str(vision_on), str(vision_off), str(vision_none)])

	# 5. Refresh: provider varsa rozet + fetch_models; yoksa hiçbir şey olmaz
	_use_provider(dock, fake)
	dock._on_refresh_models_pressed()
	var refreshed = fake.fetch_calls == 1 and dock.status_badge.text == "Refreshing..."
	_use_provider(dock, null)
	dock.status_badge.text = "badge"
	dock._on_refresh_models_pressed()
	var refresh_noop = fake.fetch_calls == 1 and dock.status_badge.text == "badge"
	if refreshed and refresh_noop:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (refresh models) failed: refreshed=%s noop=%s" % [str(refreshed), str(refresh_noop)])

	# 6. Dock ağaçtan çıkınca alt süreçli provider durdurulur; süreçsiz provider'da sorun çıkmaz
	_use_provider(dock, fake)
	dock._exit_tree()
	var stopped = fake.stop_calls == 1
	_use_provider(dock, plain)
	dock._exit_tree()
	if stopped:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (exit_tree stops provider process) failed: stop_calls=%d" % fake.stop_calls)

	_dispose(dock)

	# 7. Provider seçimi: openai_compatible -> OpenAI (verilen NetworkManager ile), diğer her şey
	# -> AGY. Seçim alt süreç başlatmaz (ısıtma yalnızca rebuild_provider'da).
	var sel_nm = AISidebarAgentHost.AISidebarNetworkManager.new()
	var sel_openai = AISidebarAgentHost.create_provider("openai_compatible", sel_nm)
	var sel_agy = AISidebarAgentHost.create_provider("antigravity_cli", sel_nm)
	var sel_unknown = AISidebarAgentHost.create_provider("unknown", null)
	var openai_ok = sel_openai is AISidebarOpenAICompatibleProvider and sel_openai.network_manager == sel_nm
	var agy_ok = sel_agy is AISidebarAGYProvider and sel_unknown is AISidebarAGYProvider and sel_agy._pid == -1 and not sel_agy.is_ready()
	sel_nm.free()
	if openai_ok and agy_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T7 (create_provider) failed: openai=%s agy=%s" % [str(openai_ok), str(agy_ok)])

	# Kullanıcı config'ini aynen geri yükle
	if had_file:
		var f = FileAccess.open(AISidebarConfig.CONFIG_PATH, FileAccess.WRITE)
		f.store_string(original_raw)
		f.close()
	elif FileAccess.file_exists(AISidebarConfig.CONFIG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AISidebarConfig.CONFIG_PATH))

	return {"name": "ProviderCompositionTests", "passed": passed, "failed": failed, "errors": errors}
