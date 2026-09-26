@tool
extends RefCounted

## Dış ajan (MCP) `ask` modu onaylarının sunumu (SRP): köprünün onay kaydından gelen her istek
## için dock'ta onay kartı açar, kullanıcı kararını kayda iletir, süre dolması / kopma /
## köprü kapanışında kartı kapatır.
## Transcript'e yazılmaz (bilinçli): bu istekler bir sidebar görevinin parçası değildir; iz dış
## ajanın kendi kaydında (araç sonucu: USER_DENIED / APPROVAL_TIMEOUT …) ve editör konsolundadır.

const AISidebarApprovalCard = preload("res://addons/godot_sidebar_ai/ui/components/approval_card.gd")
const AISidebarExternalApprovals = preload("res://addons/godot_sidebar_ai/core/bridge/external_approvals.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

## func(comp: Control) — bileşeni message stream'e ekler.
var add_component: Callable = func(_c: Control) -> void: pass
## func() — kullanıcı en alttaysa akışı aşağı kaydırır.
var scroll_if_following: Callable = func() -> void: pass

var approvals: AISidebarExternalApprovals = null
## request_id -> kart
var _cards: Dictionary = {}

func bind(p_approvals: AISidebarExternalApprovals) -> void:
	approvals = p_approvals
	approvals.requested.connect(on_requested)
	approvals.resolved.connect(on_resolved)

func on_requested(request_id: int, tool_name: String, args: Dictionary, scene_path: String) -> void:
	var card := AISidebarApprovalCard.new(tool_name, args, null)
	card.title_text = AISidebarI18n.get_text("mcp_approval_title")
	card.description_text = AISidebarI18n.get_text("mcp_approval_desc", {
		"tool": tool_name,
		"scene": scene_path,
		"args": JSON.stringify(args).left(400).replace("[", "[lb]"),
	})
	card.action_approved.connect(func() -> void: approvals.resolve(request_id, true))
	card.action_rejected.connect(func() -> void: approvals.resolve(request_id, false))
	_cards[request_id] = card
	add_component.call(card)
	scroll_if_following.call()

func on_resolved(request_id: int, outcome: String) -> void:
	var card: AISidebarApprovalCard = _cards.get(request_id, null)
	_cards.erase(request_id)
	if card == null or not is_instance_valid(card) or card.is_resolved:
		return
	match outcome:
		AISidebarExternalApprovals.APPROVED:
			card.mark_approved()
		AISidebarExternalApprovals.DENIED:
			card.mark_rejected()
		AISidebarExternalApprovals.TIMEOUT:
			card.mark_cancelled(AISidebarI18n.get_text("mcp_approval_timeout"))
		AISidebarExternalApprovals.DISCONNECTED:
			card.mark_cancelled(AISidebarI18n.get_text("mcp_approval_disconnected"))
		_:
			card.mark_cancelled(AISidebarI18n.get_text("mcp_approval_stopped"))
