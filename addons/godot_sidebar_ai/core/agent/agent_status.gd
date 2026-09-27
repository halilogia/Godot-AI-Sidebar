@tool
extends RefCounted
class_name AISidebarAgentStatus

## Görev durma nedenleri makine kodudur (SRP). Kararlar (görev devam ettirilebilir mi, adım sınırında mı
## durdu) bu koda bakar; ekrandaki metin koddan i18n ile iki dilde üretilir. Metin değişse ya da çevrilse
## davranış değişmez. Kod ajan tarafından AgentRunner.last_stop_code ve bitiş ölçütlerinde ("stop_code")
## verilir, transcript'teki görev kaydında saklanır (task["stop_code"]).

const USER_STOPPED := "user_stopped"
const STEP_LIMIT := "step_limit"
const HEAL_LIMIT := "heal_limit"
const REPEATED_TOOL := "repeated_tool"
const EMPTY_RESPONSE := "empty_response"
const PROVIDER_ERROR := "provider_error"
const COMPLETION_GATE := "completion_gate"

## Aynı istemle devam etmek anlamsız olan durmalar (sınır, döngü): devam önerilmez.
const TERMINAL: Array[String] = [STEP_LIMIT, HEAL_LIMIT, REPEATED_TOOL]

static func is_terminal(code: String) -> bool:
	return TERMINAL.has(code)

## Koddan önce kaydedilmiş eski oturumlar için (task["stop_code"] yok): metinden tahmin. Yeni kayıtlarda
## kullanılmaz; kod varsa karar yalnız koda bakar.
static func legacy_is_terminal(stop_reason: String) -> bool:
	var s := stop_reason.strip_edges().to_lower()
	if s.is_empty():
		return false
	return "limit" in s or "tekrarlad" in s or "iyileştirme limiti" in s or "stagnation" in s

## Görev kaydı için karar: kod varsa kod, yoksa eski metin tahmini.
static func task_is_terminal(code: String, stop_reason: String) -> bool:
	if not code.is_empty():
		return is_terminal(code)
	return legacy_is_terminal(stop_reason)
