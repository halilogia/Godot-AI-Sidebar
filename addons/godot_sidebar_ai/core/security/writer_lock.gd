@tool
extends RefCounted
class_name AISidebarWriterLock

## Tek aktif yazıcı kuralı (v3.0.1): sidebar ajanı ile dış ajan (MCP) aynı anda sahne / dosya
## değiştiremez. Okuma, gözlem ve oyun kontrolü kilitlenmez.
## Sidebar kilidi görevin ilk yazma aracında alır, görev bitince bırakır. Dış ajanın kilidi
## süreli bir kiradır: her mutasyonda yenilenir, son mutasyondan EXTERNAL_LEASE_MSEC sonra kendiliğinden
## düşer (kopan / unutan istemci kilidi sonsuza kadar tutamaz); köprü kapanınca bırakılır.

const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

enum Holder { NONE, SIDEBAR, EXTERNAL }

const EXTERNAL_LEASE_MSEC := 60000

## Risk kaydında WRITE olsa da proje / sahne içeriğini değiştirmeyen araçlar.
const NON_WRITING_TOOLS: Array[String] = ["play_game", "stop_game", "restart_game", "select_node", "open_scene"]

static var _holder: Holder = Holder.NONE
static var _lease_until_msec: int = 0
## Testler kira süresini kısaltabilir.
static var external_lease_msec: int = EXTERNAL_LEASE_MSEC

static func is_write_tool(tool_name: String) -> bool:
	if NON_WRITING_TOOLS.has(tool_name):
		return false
	return AISidebarPermissionPolicy.get_tool_risk(tool_name) != AISidebarPermissionPolicy.RiskLevel.READ_ONLY

## Kilidi tutan (süresi dolmuş dış kira NONE sayılır ve temizlenir).
static func holder() -> Holder:
	if _holder == Holder.EXTERNAL and Time.get_ticks_msec() >= _lease_until_msec:
		_holder = Holder.NONE
	return _holder

## Kilit boşsa ya da zaten `who`'daysa alır (dış kirayı yeniler) ve true döner.
static func try_acquire(who: Holder) -> bool:
	var current := holder()
	if current != Holder.NONE and current != who:
		return false
	_holder = who
	if who == Holder.EXTERNAL:
		_lease_until_msec = Time.get_ticks_msec() + external_lease_msec
	return true

## Yalnız tutan bırakabilir.
static func release(who: Holder) -> void:
	if _holder == who:
		_holder = Holder.NONE

## Yazma aracı için kilidi alır. Okuma aracıysa ya da alındıysa {} döner; değilse WRITER_BUSY sonucu.
static func claim(who: Holder, tool_name: String) -> Dictionary:
	if not is_write_tool(tool_name) or try_acquire(who):
		return {}
	return busy_error()

## Bilgi `data` yerine mesajda: runner, `data` taşıyan sonuçta hata kodunu / mesajını modele iletmez.
static func busy_error() -> Dictionary:
	if holder() == Holder.EXTERNAL:
		var wait_s := ceili(maxf(0.0, float(_lease_until_msec - Time.get_ticks_msec())) / 1000.0)
		return AISidebarToolResult.err("WRITER_BUSY", "Holder: EXTERNAL. An external agent connected over MCP is changing this project; only one agent may change scenes or files at a time. Its lock expires %d s after its last change; retry after that." % wait_s)
	return AISidebarToolResult.err("WRITER_BUSY", "Holder: SIDEBAR. The Godot AI Sidebar agent is running a task that changes this project; only one agent may change scenes or files at a time. Retry after that task ends.")

## Testler ve köprü kapanışı için tam sıfırlama.
static func reset() -> void:
	_holder = Holder.NONE
	_lease_until_msec = 0
	external_lease_msec = EXTERNAL_LEASE_MSEC
