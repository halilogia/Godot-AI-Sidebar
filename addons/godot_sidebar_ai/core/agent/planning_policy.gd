@tool
extends RefCounted
class_name AISidebarPlanningPolicy

## Uygulama Planlama Katmanı — Mutation Guard (SRP).
##
## Plan yalnız kullanıcı isteyince açılır (Antigravity'deki gibi): `/plan istek` ya da Ayarlar →
## Genel → "Her istekte önce plan yap". Önceden kelime listesiyle (fiil + "oyuncu", "harita" …)
## karar veriliyordu; oyun isteklerinin çoğu bu kelimeleri içerdiği için neredeyse her istek plana
## düşüyordu. Plan aşamasında değiştirici araçlar DETERMINISTIK olarak engellenir.
##
## RISK LİSTESİ TEKRAR YAZILMAZ:
##   Mutation tespiti AISidebarPermissionPolicy risk kayıt defterini kullanır;
##   böylece tek bir doğruluk kaynağı (single source of truth) korunur.

const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")

## Plan aşamasında daima erişilebilen, mutation ÜRETMEYEN araçlar.
## (Okuma/inceleme + netleştirme + plan sunumu)
const PLANNING_SAFE_TOOLS: Array = [
	"search_tools", "ask_user", "propose_plan",
	"analyze_project", "read_script", "file_info", "search_code", "get_project_files", "list_dir",
	"get_scene_tree", "get_active_scene_tree", "get_selected_nodes",
	"get_open_scripts", "get_node_properties", "get_editor_errors",
	"search_project_assets", "take_editor_screenshot", "take_viewport_screenshot",
	"inspect_ui_layout", "get_godot_class_info"
]

## Plan aşaması aktifken bu aracın çağrılması engellenmeli mi?
## Fail-closed: bilinmeyen araç (risk kaydı yok) WRITE varsayılır ve engellenir.
static func is_mutation_blocked(tool_name: String) -> bool:
	if tool_name in PLANNING_SAFE_TOOLS:
		return false
	return AISidebarPermissionPolicy.get_tool_risk(tool_name) != AISidebarPermissionPolicy.RiskLevel.READ_ONLY

## Plan aşamasında izinli araç isimleri (şema filtresi için).
static func get_planning_safe_tools() -> Array:
	return PLANNING_SAFE_TOOLS.duplicate()

## Modele enjekte edilecek planlama talimatı.
## Plan kullanıcıya gösterilen bir artifact'tır; gizli reasoning DEĞİLDİR.
static func build_plan_directive(_prompt: String) -> String:
	return ("PLANLAMA MODU (SISTEM TALIMATI): Kullanici uygulamadan once plan istedi. " +
		"Su anda HICBIR degistirici arac (dosya yazma/degistirme/silme, sahne veya dugum mutasyonu) CAGRILAMAZ. " +
		"1) Once yalnizca okuma ve inceleme araclarini kullanarak mevcut projeyi incele. " +
		"2) Sonucu kokten degistirecek kritik bir mimari belirsizlik varsa 'ask_user' ile netlestir. " +
		"3) Ardindan 'propose_plan' aracini cagirarak kullaniciya uygulanabilir bir plan sun. " +
		"Plan somut olmali: goal, affected_files (gercek dosya yollari), steps (sirali ve uygulanabilir adimlar; " +
		"'sistem olustur, test et' gibi genel ifadeler yetersizdir), dependencies, verification (nasil dogrulanacak) " +
		"ve varsa risks alanlarini doldur. Plan onaylanana kadar yalnizca okuma yapabilirsin.")
