@tool
extends RefCounted

## Bağlam bütçesi yalnız bildirilen sayılarla çalışır: iki sağlayıcı biçimi normalleşir, bildirilmeyen /
## sıfır kullanım sayılmaz, pencere bilinmezse oran yoktur; koruma sıkıştırması araç sonucunu kendi
## çağrısından ayırmaz; SSE ayrıştırıcı akışın son parçasındaki usage'ı verir.

const AISidebarContextBudget = preload("res://addons/godot_sidebar_ai/core/agent/context_budget.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarSSEParser = preload("res://addons/godot_sidebar_ai/core/network/sse_parser.gd")

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	# T1 Normalleştirme: OpenAI uyumlu ve Antigravity CLI biçimi; sıfır / eksik → boş.
	var oa := AISidebarContextBudget.normalize({"prompt_tokens": 1200, "completion_tokens": 300, "total_tokens": 1500, "prompt_tokens_details": {"cached_tokens": 800}})
	var agy := AISidebarContextBudget.normalize({"input_tokens": 5000, "output_tokens": 40, "thinking_tokens": 12, "cache_read_tokens": 4000, "total_tokens": 5052})
	var zero := AISidebarContextBudget.normalize({"input_tokens": 0, "output_tokens": 0, "total_tokens": 0})
	if oa.get("input_tokens") == 1200 and oa.get("cached_tokens") == 800 and oa.get("output_tokens") == 300 and agy.get("input_tokens") == 5000 and agy.get("cached_tokens") == 4000 and agy.get("thinking_tokens") == 12 and zero.is_empty() and AISidebarContextBudget.normalize(null).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T1 normalize: oa=%s agy=%s zero=%s" % [oa, agy, zero])

	# T2 Doluluk ve eşikler: pencere yokken oran -1 (tahmin yok); varken son girdi + çıktı.
	var b := AISidebarContextBudget.new()
	var no_data_ratio := b.ratio()
	b.record({"prompt_tokens": 70000, "completion_tokens": 10000})
	var no_window_ratio := b.ratio()
	b.window = 100000
	var compact_at_80 := b.should_compact() and not b.should_warn()
	b.record({"prompt_tokens": 90000, "completion_tokens": 6000})
	if no_data_ratio < 0.0 and no_window_ratio < 0.0 and compact_at_80 and b.should_warn() and b.used() == 96000 and b.total_input == 160000 and b.requests == 2 and not b.record({}):
		passed += 1
	else:
		failed += 1
		errors.append("T2 budget: %s" % b.snapshot())

	# T3 Koruma sıkıştırması: kesim bir araç sonucuna denk gelse de sonuç kendi tool_calls mesajıyla kalır.
	var ctx := AISidebarAgentContext.new()
	for i in range(4):
		ctx.messages.append({"role": "user", "content": "istek %d" % i})
		ctx.messages.append({"role": "assistant", "content": "", "tool_calls": [{"id": "c%d" % i, "type": "function", "function": {"name": "read_file", "arguments": "{}"}}]})
		ctx.messages.append({"role": "tool", "tool_call_id": "c%d" % i, "content": "ok"})
	ctx.messages.append({"role": "tool", "tool_call_id": "c3b", "content": "ok"})
	# 14 mesaj: son 6'yı ayıran kesim (indeks 8) bir araç sonucuna denk gelir.
	ctx.messages.append({"role": "user", "content": "son"})
	var did := ctx.compact_now()
	var orphan := false
	for j in range(ctx.messages.size()):
		var m: Dictionary = ctx.messages[j]
		if str(m.get("role", "")) == "tool":
			var prev: Dictionary = ctx.messages[j - 1] if j > 0 else {}
			if not (prev.has("tool_calls") or str(prev.get("role", "")) == "tool"):
				orphan = true
	if did and not orphan and ctx.messages.size() < 13:
		passed += 1
	else:
		failed += 1
		errors.append("T3 compact_now: did=%s orphan=%s size=%d" % [did, orphan, ctx.messages.size()])

	# T4 SSE: include_usage ile son parçadaki usage yanıtla birlikte döner.
	var sse := "data: {\"choices\":[{\"delta\":{\"content\":\"merhaba\"}}]}\n" + "data: {\"choices\":[],\"usage\":{\"prompt_tokens\":42,\"completion_tokens\":3,\"total_tokens\":45}}\n" + "data: [DONE]\n"
	var parsed := AISidebarSSEParser.parse_response(sse)
	var u: Variant = parsed.get("usage", null)
	if str(parsed.get("content", "")) == "merhaba" and u is Dictionary and int((u as Dictionary).get("prompt_tokens", 0)) == 42:
		passed += 1
	else:
		failed += 1
		errors.append("T4 SSE usage: " + str(parsed))

	return {"name": "ContextBudgetTests", "passed": passed, "failed": failed, "errors": errors}
