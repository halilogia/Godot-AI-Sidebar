@tool
extends RefCounted
class_name AISidebarPlanningPolicy

## Uygulama Planlama Katmanı — Kapsam Sınıflandırıcı ve Mutation Guard (SRP).
##
## AMAC:
##   Her mesajı zorla planlamaya sokmadan, yalnızca orta/büyük kapsamlı
##   isteklerde plan onayı istemek ve plan aşamasında mutation'ı
##   DETERMINISTIK olarak engellemek.
##
## NEDEN DETERMINISTIK (LLM'SIZ):
##   Sınıflandırma ve guard, modelin davranışına bırakılırsa test edilemez ve
##   güvenilmez olur. Bu yüzden karar tamamen yerel ve tekrarlanabilirdir.
##
## RISK LİSTESİ TEKRAR YAZILMAZ:
##   Mutation tespiti AISidebarPermissionPolicy risk kayıt defterini kullanır;
##   böylece tek bir doğruluk kaynağı (single source of truth) korunur.

const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")

## Plan aşamasında daima erişilebilen, mutation ÜRETMEYEN araçlar.
## (Okuma/inceleme + netleştirme + plan sunumu)
const PLANNING_SAFE_TOOLS: Array = [
	"search_tools", "ask_user", "propose_plan",
	"analyze_project", "read_script", "get_project_files", "list_dir",
	"get_scene_tree", "get_active_scene_tree", "get_selected_nodes",
	"get_open_scripts", "get_node_properties", "get_editor_errors",
	"search_project_assets", "take_editor_screenshot", "take_viewport_screenshot",
	"inspect_ui_layout"
]

## "Üretme / kurma" fiil kökleri (token ÖNEKİ olarak eşleşir; Türkçe ekleri kapsar).
const BUILD_VERB_STEMS: Array = [
	"oluştur", "olustur", "create", "yap", "ekle", "add", "kur", "build",
	"generate", "implement", "geliştir", "gelistir", "tasarla", "design",
	"kurgula", "setup", "entegre"
]

## Sistem ölçeğinde kapsam isimleri (token ÖNEKİ olarak eşleşir).
const SYSTEM_NOUN_STEMS: Array = [
	"sistem", "system", "manager", "yönetici", "yonetici", "inventory", "envanter",
	"quest", "menü", "menu", "save", "load", "kaydet", "generat",
	"grid", "hex", "harita", "dungeon", "zindan", "düşman", "dusman", "enemy",
	"hud", "seviye", "level", "oyuncu", "player", "karakter", "character", "arayüz"
]

## Tekil özellik/değer ayarı göstergeleri. Bunlardan biri varsa istek
## büyük olasılıkla basit bir tweak'tir -> plan gereksizdir.
## NOT: İngilizce "can" modal fiili ile çakışmaması için Türkçe "can"
## (sağlık) yerine "sağlık"/"saglik"/"hp" kullanılır.
const TWEAK_NOUN_STEMS: Array = [
	"speed", "hız", "hiz", "health", "sağlık", "saglik", "hp",
	"renk", "color", "boyut", "size", "position", "pozisyon",
	"değer", "deger", "value", "damage", "hasar", "isim",
	"opacity", "scale", "volume", "ses", "gravity", "yerçekimi"
]

## Soru/okuma niyeti belirten kökler. Bunlardan biri varsa plan YAPILMAZ.
const QUERY_VERB_STEMS: Array = [
	"söyle", "soyle", "göster", "goster", "listele", "açıkla", "acikla",
	"nedir", "nasıl", "nasil", "explain", "what", "how", "where"
]

## Bu istek için implementation plan gerekiyor mu?
##
## Muhafazakâr tasarım tercihi: yanlış pozitif (gereksiz plan ekranı) kötü UX,
## yanlış negatif ise kullanıcının istediği korumayı atlar. Bu nedenle kural
## "fiil VE sistem ölçeği VE tweak değil" üçlüsünün TAMAMINI arar.
static func should_plan(prompt: String) -> bool:
	var text: String = prompt.strip_edges()
	if text.is_empty():
		return false

	var tokens: Array = _tokenize(text)

	# 1. Soru/okuma isteği plan gerektirmez.
	if _starts_with_any(tokens, QUERY_VERB_STEMS):
		return false

	# 2. Bir "üretme/kurma" fiili yoksa plan gereksizdir.
	if not _starts_with_any(tokens, BUILD_VERB_STEMS):
		return false

	# 3. Tekil özellik ayarı ise (ör. "speed değerini 300 yap") plan gereksizdir.
	if _starts_with_any(tokens, TWEAK_NOUN_STEMS):
		return false

	# 4. Sistem ölçeğinde bir kapsam yoksa plan gereksizdir.
	if not _starts_with_any(tokens, SYSTEM_NOUN_STEMS):
		return false

	return true

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
	return ("PLANLAMA MODU (SISTEM TALIMATI): Bu istek orta/buyuk kapsamli bir uretim istegidir. " +
		"Su anda HICBIR degistirici arac (dosya yazma/degistirme/silme, sahne veya dugum mutasyonu) CAGRILAMAZ. " +
		"1) Once yalnizca okuma ve inceleme araclarini kullanarak mevcut projeyi incele. " +
		"2) Sonucu kokten degistirecek kritik bir mimari belirsizlik varsa 'ask_user' ile netlestir. " +
		"3) Ardindan 'propose_plan' aracini cagirarak kullaniciya uygulanabilir bir plan sun. " +
		"Plan somut olmali: goal, affected_files (gercek dosya yollari), steps (sirali ve uygulanabilir adimlar; " +
		"'sistem olustur, test et' gibi genel ifadeler yetersizdir), dependencies, verification (nasil dogrulanacak) " +
		"ve varsa risks alanlarini doldur. Plan onaylanana kadar yalnizca okuma yapabilirsin.")

## Metni token'lara ayırır. Noktalama karakterleri token ayirici olarak kullanılır;
## böylece "Player'ın speed" -> ["player", "ın", "speed"] olur ve önek eşleşmesi bozulmaz.
static func _tokenize(text: String) -> Array:
	var cleaned: String = text.to_lower()
	var separators: Array = [
		",", ".", ";", ":", "!", "?", "(", ")", "[", "]", "{", "}",
		"\"", "'", "`", "/", "\\", "*", "\n", "\r", "\t", "|", "+",
		"&", "%", "#", "@", "$", "=", "<", ">", "~", "^", "’", "‘", "“", "”", "-", "_"
	]
	for sep: Variant in separators:
		cleaned = cleaned.replace(str(sep), " ")

	var tokens: Array = []
	for raw in cleaned.split(" ", false):
		var tok: String = str(raw).strip_edges()
		if not tok.is_empty():
			tokens.append(tok)
	return tokens

## Token'lardan herhangi biri verilen köklerden biriyle BAŞLIYOR mu?
## (Türkçe eklerini ayrı ayrı listelememek için önek eşleşmesi kullanılır.)
static func _starts_with_any(tokens: Array, stems: Array) -> bool:
	for raw_tok: Variant in tokens:
		var tok: String = str(raw_tok)
		for raw_stem: Variant in stems:
			var stem: String = str(raw_stem)
			if not stem.is_empty() and tok.begins_with(stem):
				return true
	return false
