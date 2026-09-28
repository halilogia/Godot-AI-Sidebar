@tool
extends RefCounted

## Sağlayıcı yeniden denemesi: geçici hata (5xx, 429, bağlantı zaman aşımı) yanıt akmadan gelirse sohbet
## isteği yeniden gönderilir ve ajana hata iletilmez; kalıcı hata (401), akış başladıktan sonraki hata ve
## denemeler tükenince hata iletilir. (Benchmark: tek bir 502 / 529 uzun görevleri öldürüyordu.)

const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")

class CountingNet extends AISidebarNetworkManager:
	var posts: int = 0
	func post_request(_url: String, _headers: PackedStringArray, _body_json: String) -> Error:
		posts += 1
		return OK

static func _setup() -> Array:
	var net := CountingNet.new()
	var provider = AISidebarOpenAICompatibleProvider.new(net)
	var errors: Array = []
	provider.error_occurred.connect(func(m: String) -> void: errors.append(m))
	provider.send_chat([{"role": "user", "content": "x"}], [])
	return [net, provider, errors]

static func run() -> Dictionary:
	var checks: Array = []
	var saved: Array = AISidebarOpenAICompatibleProvider.retry_delays.duplicate()
	AISidebarOpenAICompatibleProvider.retry_delays = [60.0]
	# Zamanlayıcı yerine kayıt: geri çağrı elle tetiklenir (yeniden gönderim de doğrulanır).
	var pending: Array = []
	AISidebarOpenAICompatibleProvider.schedule_hook = func(_d: float, cb: Callable) -> void: pending.append(cb)

	# T1 sınıflandırma
	var t := AISidebarOpenAICompatibleProvider.is_transient_error
	checks.append(["T1 transient classification", t.call("HTTP 502: fetch failed") and t.call("HTTP 529: Endpoint is unavailable") and t.call("HTTP 429: rate limit") and t.call("Connect Timeout Error") and not t.call("HTTP 401: invalid key") and not t.call("HTTP 400: bad request")])

	# T2 geçici hata: ajana iletilmez, yeniden deneme zamanlanır
	var s2 := _setup()
	var net2: CountingNet = s2[0]
	net2.request_failed.emit("chat", "HTTP 502: fetch failed (UND_ERR_CONNECT_TIMEOUT)")
	var held: bool = (s2[2] as Array).is_empty() and net2.posts == 1 and pending.size() == 1
	if not pending.is_empty():
		(pending[0] as Callable).call()
	checks.append(["T2 transient error held, request re-sent (errors=%s posts=%d)" % [str(s2[2]), net2.posts], held and net2.posts == 2])

	# T6 iptal edilen görev yeniden göndermez
	pending.clear()
	var s6 := _setup()
	var net6: CountingNet = s6[0]
	net6.request_failed.emit("chat", "HTTP 529: Endpoint is unavailable")
	(s6[1]).cancel()
	if not pending.is_empty():
		(pending[0] as Callable).call()
	checks.append(["T6 cancel stops pending retry", net6.posts == 1 and pending.size() == 1])

	# T3 kalıcı hata hemen iletilir
	var s3 := _setup()
	(s3[0] as CountingNet).request_failed.emit("chat", "HTTP 401: invalid key")
	checks.append(["T3 permanent error reported", (s3[2] as Array).size() == 1])

	# T4 akış başladıktan sonra yeniden gönderilmez (çift metin olurdu)
	var s4 := _setup()
	var net4: CountingNet = s4[0]
	net4.response_chunk_received.emit("chat", "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n")
	net4.request_failed.emit("chat", "HTTP 502: upstream reset")
	checks.append(["T4 no retry after streaming", (s4[2] as Array).size() == 1])

	# T5 denemeler tükenince iletilir
	AISidebarOpenAICompatibleProvider.retry_delays = []
	var s5 := _setup()
	(s5[0] as CountingNet).request_failed.emit("chat", "HTTP 529: Endpoint is unavailable")
	checks.append(["T5 reported when retries exhausted", (s5[2] as Array).size() == 1])

	AISidebarOpenAICompatibleProvider.retry_delays = saved
	AISidebarOpenAICompatibleProvider.schedule_hook = Callable()
	var passed := 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "ProviderRetryTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
