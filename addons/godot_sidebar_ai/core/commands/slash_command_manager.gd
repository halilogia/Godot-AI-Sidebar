@tool
extends RefCounted
class_name AISidebarSlashCommandManager

## Slash Command (/) Yöneticisi, Ayrıştırıcısı ve Kayıt Defteri (SRP).
## Claude Code tarzı hızlı ajan işlemlerini (/help, /clear, /analyze, /inspect, /test, /run, /debug, /fix, /review, /explain)
## merkezi bir kayıt defteri üzerinden yönetir.

const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")

## Komut Tanım Modeli
static var _commands: Dictionary = {}
static var _is_initializing: bool = false

static func get_commands() -> Dictionary:
	if _commands.is_empty() and not _is_initializing:
		_is_initializing = true
		_init_default_commands()
		_is_initializing = false
	return _commands

static func register_command(name: String, description: String, usage: String, risk: int, execute_fn: Callable) -> void:
	var key = name.strip_edges().to_lower().trim_prefix("/")
	_commands[key] = {
		"name": key,
		"description": description,
		"usage": usage,
		"risk": risk,
		"execute_fn": execute_fn
	}

static func get_command(name: String) -> Dictionary:
	var key = name.strip_edges().to_lower().trim_prefix("/")
	var cmds = get_commands()
	if cmds.has(key):
		return cmds[key]
	return {}

## Metnin bir slash command olup olmadığını ayrıştırır
static func parse(text: String) -> Dictionary:
	var trimmed = text.strip_edges()
	if not trimmed.begins_with("/"):
		return {"is_command": false, "name": "", "args": "", "command": {}}
		
	var space_idx = trimmed.find(" ")
	var cmd_name = ""
	var args_str = ""
	
	if space_idx == -1:
		cmd_name = trimmed.substr(1).to_lower()
		args_str = ""
	else:
		cmd_name = trimmed.substr(1, space_idx - 1).to_lower()
		args_str = trimmed.substr(space_idx + 1).strip_edges()
		
	var cmds = get_commands()
	if cmds.has(cmd_name):
		return {
			"is_command": true,
			"name": cmd_name,
			"args": args_str,
			"command": cmds[cmd_name],
			"raw": trimmed
		}
		
	return {
		"is_command": true,
		"name": cmd_name,
		"args": args_str,
		"command": {},
		"error": "Bilinmeyen slash komutu: /" + cmd_name,
		"raw": trimmed
	}

## Komutu çalıştırır ve eylem sonucunu döndürür
static func execute_command(name: String, args: String, context: Dictionary = {}) -> Dictionary:
	var cmd = get_command(name)
	if cmd.is_empty():
		return {
			"action": "error",
			"message": "Bilinmeyen slash komutu: /" + name
		}
	var fn = cmd.get("execute_fn")
	if fn is Callable:
		return fn.call(args, context)
	return {
		"action": "error",
		"message": "Komut yürütücüsü bulunamadı: /" + name
	}

## İmleç konumunda aktif slash komut sorgusu olup olmadığını tespit eder
static func detect_slash_query(text: String, caret_pos: int) -> Dictionary:
	var invalid_result = {"active": false, "query": "", "start_pos": -1, "end_pos": -1}
	if text.is_empty() or caret_pos <= 0 or caret_pos > text.length():
		return invalid_result
		
	var text_before_caret = text.substr(0, caret_pos)
	var slash_idx = text_before_caret.rfind("/")
	if slash_idx == -1:
		return invalid_result
		
	# Slash işaretinden önce satır başı veya boşluk olmalı (örn: dosya yolları res:// ile karışmasın)
	if slash_idx > 0:
		var char_before = text_before_caret[slash_idx - 1]
		if char_before != "\n" and char_before != " " and char_before != "\t":
			return invalid_result
			
	var query_part = text_before_caret.substr(slash_idx + 1)
	# Boşluk girildiyse komut tamamlanmış ve argüman aşamasına geçilmiştir
	if " " in query_part or "\n" in query_part or "\t" in query_part:
		return invalid_result
		
	return {
		"active": true,
		"query": query_part.to_lower(),
		"start_pos": slash_idx,
		"end_pos": caret_pos
	}

## Sorguya uyan slash komut önerilerini döndürür
static func get_suggestions(query: String, max_results: int = 10) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var q = query.to_lower().strip_edges()
	var cmds = get_commands()
	
	var exact_prefixes: Array[Dictionary] = []
	var contains_matches: Array[Dictionary] = []
	
	for cmd_key in cmds.keys():
		var cmd = cmds[cmd_key]
		var c_name = cmd["name"]
		var c_desc = cmd["description"]
		var c_usage = cmd["usage"]
		
		if q.is_empty():
			exact_prefixes.append({
				"type": "command",
				"type_badge": "CMD",
				"label": "/" + c_name,
				"detail": c_desc,
				"insert_text": "/" + c_name + " ",
				"usage": c_usage,
				"name": c_name
			})
		elif c_name.begins_with(q):
			exact_prefixes.append({
				"type": "command",
				"type_badge": "CMD",
				"label": "/" + c_name,
				"detail": c_desc,
				"insert_text": "/" + c_name + " ",
				"usage": c_usage,
				"name": c_name
			})
		elif q in c_name or q in c_desc.to_lower():
			contains_matches.append({
				"type": "command",
				"type_badge": "CMD",
				"label": "/" + c_name,
				"detail": c_desc,
				"insert_text": "/" + c_name + " ",
				"usage": c_usage,
				"name": c_name
			})
			
	for m in exact_prefixes:
		if results.size() >= max_results: break
		results.append(m)
	for m in contains_matches:
		if results.size() >= max_results: break
		results.append(m)
		
	return results

## 10 Çekirdek Komutun Başlatılması
static func _init_default_commands() -> void:
	# 1. /help
	register_command(
		"help",
		"Mevcut slash komutlarını, açıklamalarını ve örnek kullanımlarını gösterir.",
		"/help",
		AISidebarPermissionPolicy.RiskLevel.READ_ONLY,
		Callable(AISidebarSlashCommandManager, "_handle_help")
	)
	
	# 2. /clear
	register_command(
		"clear",
		"Mevcut agent task/context çalışma hafızasını sıfırlar (sohbet geçmişi silinmez).",
		"/clear",
		AISidebarPermissionPolicy.RiskLevel.READ_ONLY,
		Callable(AISidebarSlashCommandManager, "_handle_clear")
	)
	
	# 3. /analyze
	register_command(
		"analyze",
		"Projeyi veya sahneyi analiz eder (Read-Only, dosya değiştirmez).",
		"/analyze [opsiyonel: sahne_veya_konu]",
		AISidebarPermissionPolicy.RiskLevel.READ_ONLY,
		Callable(AISidebarSlashCommandManager, "_handle_analyze")
	)
	
	# 4. /inspect
	register_command(
		"inspect",
		"Godot bağlamını, aktif sahneyi, düğüm ağacını veya belirtilen hedefi inceler.",
		"/inspect [opsiyonel: NodeAdi veya res://yol]",
		AISidebarPermissionPolicy.RiskLevel.READ_ONLY,
		Callable(AISidebarSlashCommandManager, "_handle_inspect")
	)
	
	# 5. /test
	register_command(
		"test",
		"İlgili testleri ve kod doğrulamalarını çalıştırıp sonuçları analiz eder.",
		"/test [opsiyonel: test_adi_veya_kapsam]",
		AISidebarPermissionPolicy.RiskLevel.READ_ONLY,
		Callable(AISidebarSlashCommandManager, "_handle_test")
	)
	
	# 6. /run
	register_command(
		"run",
		"Godot projesini çalıştırır ve runtime debugger ile gözlemler.",
		"/run",
		AISidebarPermissionPolicy.RiskLevel.WRITE,
		Callable(AISidebarSlashCommandManager, "_handle_run")
	)
	
	# 7. /debug
	register_command(
		"debug",
		"Editör ve runtime logları, hataları ve stack trace'i analiz eder.",
		"/debug [opsiyonel: hata_aciklamasi]",
		AISidebarPermissionPolicy.RiskLevel.READ_ONLY,
		Callable(AISidebarSlashCommandManager, "_handle_debug")
	)
	
	# 8. /fix
	register_command(
		"fix",
		"Son tespit edilen hata üzerinde güvenli düzeltme görevi başlatır.",
		"/fix [opsiyonel: sorun_detayi]",
		AISidebarPermissionPolicy.RiskLevel.WRITE,
		Callable(AISidebarSlashCommandManager, "_handle_fix")
	)
	
	# 9. /review
	register_command(
		"review",
		"Son yapılan değişiklikleri 6 güvenlik ve kalite kriterine göre inceler.",
		"/review",
		AISidebarPermissionPolicy.RiskLevel.READ_ONLY,
		Callable(AISidebarSlashCommandManager, "_handle_review")
	)
	
	# 10. /explain
	register_command(
		"explain",
		"Belirtilen dosyayı, düğümü veya son değişiklikleri açıklar.",
		"/explain <dosya_yolu | NodeAdi | last>",
		AISidebarPermissionPolicy.RiskLevel.READ_ONLY,
		Callable(AISidebarSlashCommandManager, "_handle_explain")
	)

## --- KOMUT İŞLEYİCİLERİ (COMMAND HANDLERS) ---

static func _handle_help(_args: String, _context: Dictionary) -> Dictionary:
	var cmds = get_commands()
	var text = "### ⚡ Godot AI Slash Commands Rehberi\n\n"
	text += "Doğal dil yerine sık kullanılan ajan görevlerini tek satırda tetikleyebilirsiniz:\n\n"
	
	var sorted_keys = cmds.keys()
	sorted_keys.sort()
	
	for k in sorted_keys:
		var c = cmds[k]
		var risk_badge = "🛡️ READ_ONLY"
		if c["risk"] == AISidebarPermissionPolicy.RiskLevel.WRITE:
			risk_badge = "✏️ WRITE"
		elif c["risk"] == AISidebarPermissionPolicy.RiskLevel.DESTRUCTIVE:
			risk_badge = "⚠️ DESTRUCTIVE"
		elif c["risk"] == AISidebarPermissionPolicy.RiskLevel.EXTERNAL_SENSITIVE:
			risk_badge = "🌐 SENSITIVE"
			
		text += "* `/" + c["name"] + "` — " + c["description"] + "\n"
		text += "  * **Kullanım:** `" + c["usage"] + "` (" + risk_badge + ")\n"
		
	text += "\n> **İpucu:** Chat kutusunda `/` yazarak komut listesini açabilir, `↑/↓` ile gezinip `Enter` veya `Tab` ile tamamlayabilirsiniz."
	
	return {
		"action": "local_response",
		"message": text
	}

static func _handle_clear(_args: String, context: Dictionary) -> Dictionary:
	var agent_ctx = context.get("agent_context", null)
	if agent_ctx:
		agent_ctx.clear()
		
	return {
		"action": "local_response",
		"message": "🧹 **Agent çalışma hafızası sıfırlandı.**\nMevcut konuşma geçmişi (Chat Management) korundu. Yeni görevler için temiz bir ajan icra bağlamı başlatıldı."
	}

static func _handle_analyze(args: String, _context: Dictionary) -> Dictionary:
	var target = args.strip_edges()
	var prompt = ""
	if target.is_empty():
		prompt = "Projenin ve aktif açık sahnenin yapısını, mimarisini, ana sahnesini ve dosya hiyerarşisini detaylı analiz et. KESİNLİKLE dosya değiştirme (Read-Only)."
	else:
		prompt = "Belirtilen hedef veya konu ('" + target + "') özelinde proje ve sahne yapısını derinlemesine analiz et. KESİNLİKLE dosya değiştirme (Read-Only)."
		
	return {
		"action": "run_agent",
		"prompt": prompt,
		"display_prompt": "/analyze " + target if not target.is_empty() else "/analyze"
	}

static func _handle_inspect(args: String, _context: Dictionary) -> Dictionary:
	var target = args.strip_edges()
	var prompt = ""
	if target.is_empty():
		prompt = "Godot aktif sahnesini (get_scene_tree), kullanıcının seçtiği düğümleri (get_selected_nodes) ve bağlı script/özellikleri derinlemesine incele ve detaylı durum raporu sun. Hiçbir değişiklik yapma (Read-Only)."
	else:
		prompt = "Belirtilen hedefi ('" + target + "') detaylı olarak incele: Düğüm özellikleri, bağlı script, sinyaller ve hiyerarşi durumunu inceleyip raporla. Hiçbir değişiklik yapma (Read-Only)."
		
	return {
		"action": "run_agent",
		"prompt": prompt,
		"display_prompt": "/inspect " + target if not target.is_empty() else "/inspect"
	}

static func _handle_test(args: String, _context: Dictionary) -> Dictionary:
	var target = args.strip_edges()
	var prompt = ""
	if target.is_empty():
		prompt = "Projedeki tüm birim/mantık testlerini ve script doğrulamalarını (validate_script) incele. Başarısız veya hatalı test varsa kök nedenini belirle ve detaylı rapor sun. Kullanıcı açıkça istemediği sürece dosya değiştirme."
	else:
		prompt = "Belirtilen test veya kapsam ('" + target + "') için testleri ve script doğrulamalarını incele. Sonuçları analiz et ve açıkça istenmedikçe dosya değiştirme."
		
	return {
		"action": "run_agent",
		"prompt": prompt,
		"display_prompt": "/test " + target if not target.is_empty() else "/test"
	}

static func _handle_run(_args: String, _context: Dictionary) -> Dictionary:
	var prompt = "Godot oyun projesini play_game aracıyla çalıştır. Çalışma zamanı (runtime) gözlemlerini ve hata loglarını alıp durumu raporla."
	return {
		"action": "run_agent",
		"prompt": prompt,
		"display_prompt": "/run"
	}

static func _handle_debug(args: String, _context: Dictionary) -> Dictionary:
	var target = args.strip_edges()
	var prompt = ""
	if target.is_empty():
		prompt = "get_editor_errors ve get_runtime_errors araçlarını kullanarak editör ve runtime hata loglarını, stack trace ve uyarıları topla. Hataların kaynak kod bağlamını analiz et, kök nedeni teşhis et ve çözüm öner."
	else:
		prompt = "Belirtilen problem ('" + target + "') ve mevcut hata logları üzerinden hata analizi yap. Hatanın kaynağını bul, stack trace'i incele ve çözüm öner."
		
	return {
		"action": "run_agent",
		"prompt": prompt,
		"display_prompt": "/debug " + target if not target.is_empty() else "/debug"
	}

static func _handle_fix(args: String, _context: Dictionary) -> Dictionary:
	var target = args.strip_edges()
	var prompt = ""
	if target.is_empty():
		prompt = "Tespit edilen son hatayı ve problemleri çözmek için gerekli script veya sahne düzeltmelerini yap. Kod yazarken Verification Pipeline ve mimari güvenlik kurallarına tam uy."
	else:
		prompt = "Belirtilen hatayı ('" + target + "') çözmek için gerekli script veya sahne düzeltmelerini yap. Kod yazarken Verification Pipeline ve mimari güvenlik kurallarına tam uy."
		
	return {
		"action": "run_agent",
		"prompt": prompt,
		"display_prompt": "/fix " + target if not target.is_empty() else "/fix"
	}

static func _handle_review(_args: String, _context: Dictionary) -> Dictionary:
	var prompt = "Son yapılan değişiklikleri şu 6 kriter açısından kapsamlıca incele:\n"
	prompt += "1. Bug ve mantık riski\n"
	prompt += "2. Godot 4.7 API uyumluluğu (GDScript 2.0)\n"
	prompt += "3. Runtime ve performans riski\n"
	prompt += "4. Gereksiz karmaşıklık (overengineering)\n"
	prompt += "5. Kırılmış sahne referansları ve geçersiz node path'leri\n"
	prompt += "6. Olası sözdizimi veya resource problemleri\n"
	prompt += "Bulguları maddeler halinde raporla. Açıkça talep edilmedikçe dosya değiştirme."
	
	return {
		"action": "run_agent",
		"prompt": prompt,
		"display_prompt": "/review"
	}

static func _handle_explain(args: String, _context: Dictionary) -> Dictionary:
	var target = args.strip_edges()
	var prompt = ""
	if target.is_empty() or target == "last":
		prompt = "Son yapılan kod veya sahne değişikliklerini mimari ve işlevsel açıdan detaylı olarak açıkla. Ne değişti, neden değişti ve nasıl çalışıyor özetle."
	elif target.begins_with("res://"):
		prompt = "Belirtilen dosyayı ('" + target + "') read_script ile oku; yapısını, mimari rolünü, fonksiyonlarını ve mantığını detaylı olarak açıkla."
	else:
		prompt = "Belirtilen sahne veya düğümü ('" + target + "') get_scene_tree üzerinden incele; sahnedeki rolünü, bağlı scriptini ve işlevini açıkla."
		
	return {
		"action": "run_agent",
		"prompt": prompt,
		"display_prompt": "/explain " + target if not target.is_empty() else "/explain last"
	}
