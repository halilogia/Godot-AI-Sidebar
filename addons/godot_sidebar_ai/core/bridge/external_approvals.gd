@tool
extends RefCounted
class_name AISidebarExternalApprovals

## Dış ajan (MCP) sahne değişiklikleri için bekleyen kullanıcı onayları (v3.0.2, `ask` modu).
## Köprü `request()` ile kayıt açar ve sonucu bekler; arayüz `requested` sinyaliyle kart
## gösterir, kullanıcı kararını `resolve()` ile bildirir. Köprü süre dolunca ya da istemci
## kopunca `cancel()` çağırır. Çekirdek arayüzü tanımaz (sinyal üzerinden konuşur).

const APPROVED := "approved"
const DENIED := "denied"
const TIMEOUT := "timeout"
const DISCONNECTED := "disconnected"
const BRIDGE_STOPPED := "bridge_stopped"

## Yeni onay isteği: arayüz kart gösterir.
signal requested(request_id: int, tool_name: String, args: Dictionary, scene_path: String)
## İstek sonuçlandı (onay / ret / iptal nedeni): arayüz kartı günceller.
signal resolved(request_id: int, outcome: String)

var _next_id: int = 1
## id -> {"tool", "outcome"} ("" = bekliyor)
var _requests: Dictionary = {}

func request(tool_name: String, args: Dictionary, scene_path: String) -> int:
	var id := _next_id
	_next_id += 1
	_requests[id] = {"tool": tool_name, "outcome": ""}
	requested.emit(id, tool_name, args.duplicate(true), scene_path)
	return id

## Bekleyen isteğin sonucu; bekliyorsa "" (bilinmeyen id de "").
func outcome(request_id: int) -> String:
	var entry: Dictionary = _requests.get(request_id, {})
	return str(entry.get("outcome", ""))

func is_pending(request_id: int) -> bool:
	return _requests.has(request_id) and outcome(request_id).is_empty()

## Kullanıcı kararı. Yalnız bekleyen istek sonuçlanır (geç tıklama etkisizdir).
func resolve(request_id: int, approved: bool) -> void:
	_finish(request_id, APPROVED if approved else DENIED)

## Köprü tarafı iptal: süre doldu, istemci koptu, köprü kapandı.
func cancel(request_id: int, reason: String) -> void:
	_finish(request_id, reason)

func cancel_all(reason: String) -> void:
	for id: Variant in _requests.keys():
		_finish(int(id), reason)

## Sonuçlanan kaydı siler (köprü sonucu okuduktan sonra çağırır).
func forget(request_id: int) -> void:
	_requests.erase(request_id)

func pending_count() -> int:
	var n := 0
	for id: Variant in _requests.keys():
		if is_pending(int(id)):
			n += 1
	return n

func _finish(request_id: int, result: String) -> void:
	if not is_pending(request_id):
		return
	var entry: Dictionary = _requests[request_id]
	entry["outcome"] = result
	resolved.emit(request_id, result)
