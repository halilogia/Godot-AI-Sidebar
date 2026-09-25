@tool
extends RefCounted

## Bekleyen kullanıcı kararları (SRP): onay bekleyen tool çağrısı, netleştirme sorusu (ask_user)
## ve onay bekleyen uygulama planı (propose_plan). Yalnızca saklama / tüketme / temizleme;
## durum geçişleri, context kaydı ve sinyaller AgentRunner'dadır. Runner başına ayrı örnek.

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarImplementationPlan = preload("res://addons/godot_sidebar_ai/core/types/implementation_plan.gd")

# Onay bekleyen tool çağrısı
var tool_name: String = ""
var tool_id: String = ""
var tool_args: Dictionary = {}
var change_set: AISidebarChangeSet = null
# Netleştirme sorusu
var clarification_id: String = ""
var clarification_question: String = ""
var clarification_options: Array = []
# Onay bekleyen plan
var plan: AISidebarImplementationPlan = null
var plan_id: String = ""

func request_approval(p_tool_name: String, p_tool_id: String, p_args: Dictionary, p_change_set: AISidebarChangeSet) -> void:
	tool_name = p_tool_name
	tool_id = p_tool_id
	tool_args = p_args
	change_set = p_change_set

func has_approval() -> bool:
	return not tool_name.is_empty()

## Bekleyen onayı tüketir: {"name", "id", "args", "change_set"} döner ve temizler.
func take_approval() -> Dictionary:
	var req: Dictionary = {"name": tool_name, "id": tool_id, "args": tool_args, "change_set": change_set}
	clear_approval()
	return req

func clear_approval() -> void:
	tool_name = ""
	tool_id = ""
	tool_args = {}
	change_set = null

## Seçenek dizisi kopyalanmadan saklanır; temizlikte yerinde boşaltılır.
func request_clarification(p_id: String, p_question: String, p_options: Array) -> void:
	clarification_id = p_id
	clarification_question = p_question
	clarification_options = p_options

func has_clarification() -> bool:
	return not clarification_id.is_empty()

## Bekleyen soruyu tüketir: {"id", "question"} döner ve temizler.
func take_clarification() -> Dictionary:
	var req: Dictionary = {"id": clarification_id, "question": clarification_question}
	clear_clarification()
	return req

func clear_clarification() -> void:
	clarification_id = ""
	clarification_question = ""
	clarification_options.clear()

func propose_plan(p_plan: AISidebarImplementationPlan, p_plan_id: String) -> void:
	plan = p_plan
	plan_id = p_plan_id

## Bekleyen planı tüketir: {"plan", "id"} döner ve temizler (plan yoksa null / "").
func take_plan() -> Dictionary:
	var req: Dictionary = {"plan": plan, "id": plan_id}
	clear_plan()
	return req

func clear_plan() -> void:
	plan = null
	plan_id = ""

func clear_all() -> void:
	clear_approval()
	clear_clarification()
	clear_plan()
