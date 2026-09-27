@tool
extends RefCounted
class_name AISidebarContextBudget

## Bağlam bütçesi: yalnız sağlayıcının BİLDİRDİĞİ token sayılarıyla çalışır, tahmin yapmaz.
##   - Her yanıtın `usage` bilgisi normalleştirilir (OpenAI uyumlu: prompt_tokens / completion_tokens /
##     prompt_tokens_details.cached_tokens; Antigravity CLI: input_tokens / output_tokens /
##     thinking_tokens / cache_read_tokens). Sağlayıcı bildirmezse hiçbir sayı gösterilmez.
##   - Bağlamdaki doluluk = son isteğin girdi + çıktı token'ı (çıktı bir sonraki turun girdisine girer).
##   - Pencere boyu yalnız iki kaynaktan: Ayarlar'daki değer ya da sağlayıcının model listesindeki
##     değer. Bilinmiyorsa oran yoktur (çubuk yerine yalnız sayı).
##   - Koruma: gerçek doluluk COMPACT_RATIO'yu geçince bir sonraki istekten önce bağlam sıkıştırılır,
##     WARN_RATIO'yu geçince kullanıcı uyarılır.

const COMPACT_RATIO := 0.8
const WARN_RATIO := 0.95

## Son yanıtın normalleştirilmiş kullanımı ({} = henüz bildirilmedi).
var last: Dictionary = {}
## Oturum toplamları (bildirilen yanıtların toplamı).
var total_input: int = 0
var total_output: int = 0
var total_cached: int = 0
var requests: int = 0
## Modelin bağlam penceresi (token); 0 = bilinmiyor.
var window: int = 0

## Sağlayıcının ham `usage` sözlüğünden ortak biçim: {input_tokens, output_tokens, cached_tokens,
## thinking_tokens, total_tokens}. Bildirilmemişse (ya da hepsi sıfırsa: hata yanıtı) boş sözlük.
static func normalize(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var u: Dictionary = raw
	var input := _int(u, ["prompt_tokens", "input_tokens"])
	var output := _int(u, ["completion_tokens", "output_tokens"])
	var thinking := _int(u, ["thinking_tokens", "reasoning_tokens"])
	var cached := _int(u, ["cache_read_tokens", "cache_read_input_tokens", "cached_tokens"])
	for details_key: String in ["prompt_tokens_details", "input_tokens_details"]:
		if cached == 0:
			cached = _int(_dict(u, details_key), ["cached_tokens"])
	if thinking == 0:
		thinking = _int(_dict(u, "completion_tokens_details"), ["reasoning_tokens"])
	if input <= 0 and output <= 0:
		return {}
	var total := _int(u, ["total_tokens"])
	if total <= 0:
		total = input + output
	return {"input_tokens": input, "output_tokens": output, "cached_tokens": cached, "thinking_tokens": thinking, "total_tokens": total}

static func _int(d: Dictionary, keys: Array) -> int:
	for k: String in keys:
		var v: Variant = d.get(k, null)
		if v is int:
			var i: int = v
			return i
		if v is float:
			var f: float = v
			return int(f)
	return 0

static func _dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, null)
	if v is Dictionary:
		var out: Dictionary = v
		return out
	return {}

## Bir yanıtın kullanımını işler; bildirilmemişse false (sayılar değişmez).
func record(raw: Variant) -> bool:
	var u := normalize(raw)
	if u.is_empty():
		return false
	last = u
	var i: int = u["input_tokens"]
	var o: int = u["output_tokens"]
	var c: int = u["cached_tokens"]
	total_input += i
	total_output += o
	total_cached += c
	requests += 1
	return true

func has_data() -> bool:
	return not last.is_empty()

## Bağlamdaki doluluk: son isteğin girdi + çıktısı (bildirilmediyse 0).
func used() -> int:
	if last.is_empty():
		return 0
	var i: int = last["input_tokens"]
	var o: int = last["output_tokens"]
	return i + o

## Doluluk oranı; pencere bilinmiyorsa ya da veri yoksa -1.
func ratio() -> float:
	if window <= 0 or last.is_empty():
		return -1.0
	return float(used()) / float(window)

func should_compact() -> bool:
	return ratio() >= COMPACT_RATIO

func should_warn() -> bool:
	return ratio() >= WARN_RATIO

## Yeni sohbet: sayılar sıfırlanır (pencere boyu modele bağlı olduğu için korunur).
func reset() -> void:
	last = {}
	total_input = 0
	total_output = 0
	total_cached = 0
	requests = 0

## Arayüz için anlık görüntü.
func snapshot() -> Dictionary:
	return {
		"has_data": has_data(), "used": used(), "window": window, "ratio": ratio(),
		"last": last.duplicate(), "total_input": total_input, "total_output": total_output,
		"total_cached": total_cached, "requests": requests,
	}

## 1234 → "1.2k", 1000000 → "1.0M" (kısa sayı; ekranda token sayıları için).
static func short(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (float(n) / 1000000.0)
	if n >= 1000:
		return "%.1fk" % (float(n) / 1000.0)
	return str(n)
