@tool
extends RefCounted
class_name AISidebarContextCompactor

## Context Window Optimizasyonu ve Tool Sonucu Sıkıştırıcı (SRP).
## Uzun görevlerde eski tool result ve gözlem verilerini yapılandırılmış 1-2 satırlık
## özetlere dönüştürerek token şişmesini önler; aktif adımdaki güncel veriyi korur.
## Girdi AISidebarToolResult biçimidir: {success, data, error}.
## Korunanlar: başarısız sonuçların hata metni (yazım gerçekleşmedi bilgisi kaybolmasın) ve her
## dosyanın en son okunan içeriği (ajan aynı dosyayı tekrar tekrar okumasın).

const MAX_UNCOMPACTED_CHARS: int = 350
const MAX_ERROR_CHARS: int = 400
## Tam detayda kalan son araç sonucu sayısı.
const KEEP_RECENT_TOOLS: int = 12
const READ_TOOLS := ["read_script", "read_files", "read_file"]

## Mesaj listesindeki eski tool sonuçlarını sıkıştırır.
static func compact_messages(raw_messages: Array, keep_recent_tools: int = KEEP_RECENT_TOOLS) -> Array:
	var compacted: Array = []

	# Tool mesajlarının indekslerini ve her dosyanın son okunduğu mesajı belirle
	var tool_indices: Array[int] = []
	var last_read: Dictionary = {}
	for i in range(raw_messages.size()):
		var m = raw_messages[i]
		if m is Dictionary and m.get("role") == "tool":
			tool_indices.append(i)
			if READ_TOOLS.has(str(m.get("name", ""))):
				var p := _read_path(str(m.get("content", "")))
				if not p.is_empty():
					last_read[p] = i

	var cutoff_index = -1
	if tool_indices.size() > keep_recent_tools:
		var cutoff_pos = tool_indices.size() - keep_recent_tools
		cutoff_index = tool_indices[cutoff_pos]

	for i in range(raw_messages.size()):
		var msg = raw_messages[i].duplicate(true)
		# Eski asistan mesajlarında yazma araçlarının dosya içerikleri kısa nota iner: reddedilen denemeler
		# dahil her yazılan dosya her istekte yeniden gidiyordu (grand strateji: asistan mesajları 192 KB).
		if cutoff_index != -1 and i < cutoff_index and msg is Dictionary:
			var md: Dictionary = msg
			_slim_assistant_writes(md)
		if msg is Dictionary and msg.get("role") == "tool":
			# Eğer bu tool sonucu son keep_recent_tools içinde değilse sıkıştır
			if cutoff_index != -1 and i < cutoff_index:
				var tool_name: String = str(msg.get("name", ""))
				var content_str: String = str(msg.get("content", ""))
				# Skill talimatları kalıcı yönergedir: sıkıştırılmaz (sessizce kaybolursa ajan yöntemi unutur).
				var keep_full: bool = tool_name == "activate_skill"
				if READ_TOOLS.has(tool_name):
					var p := _read_path(content_str)
					keep_full = not p.is_empty() and int(last_read.get(p, -1)) == i
				if not keep_full:
					msg["content"] = compact_tool_content(tool_name, content_str)
		compacted.append(msg)

	return compacted

const WRITE_CONTENT_KEYS := ["content", "tscn_content", "replacement_code", "target_code"]
const WRITE_CONTENT_KEEP := 200

static func _slim_assistant_writes(msg: Dictionary) -> void:
	if msg.get("role") != "assistant":
		return
	var calls_v: Variant = msg.get("tool_calls", null)
	if not (calls_v is Array):
		return
	var calls: Array = calls_v
	for tc_v: Variant in calls:
		if not (tc_v is Dictionary):
			continue
		var tc: Dictionary = tc_v
		var fn_v: Variant = tc.get("function", null)
		if fn_v is Dictionary:
			var fn: Dictionary = fn_v
			fn["arguments"] = compact_write_arguments(str(fn.get("name", "")), str(fn.get("arguments", "")))

## Yazma aracının argümanlarındaki büyük içerik alanlarını kısa nota çevirir (yol ve boyut kalır).
static func compact_write_arguments(tool_name: String, args_json: String) -> String:
	if not tool_name in ["write_files", "create_or_update_script", "replace_file_content", "create_scene"]:
		return args_json
	var json := JSON.new()
	if json.parse(args_json) != OK or not (json.data is Dictionary):
		return args_json
	var args: Dictionary = json.data
	_slim_content(args)
	var files_v: Variant = args.get("files", null)
	if files_v is Array:
		var files: Array = files_v
		for f: Variant in files:
			if f is Dictionary:
				var fd: Dictionary = f
				_slim_content(fd)
	return JSON.stringify(args)

static func _slim_content(d: Dictionary) -> void:
	var path := str(d.get("file_path", d.get("scene_path", "")))
	for key: String in WRITE_CONTENT_KEYS:
		var v: Variant = d.get(key, null)
		if v is String:
			var s: String = v
			if s.length() > WRITE_CONTENT_KEEP:
				d[key] = "[%d chars for %s; omitted from history, read_script shows the file on disk]" % [s.length(), path]

## Okuma sonucunun dosya yolu (başarısızsa ya da yoksa "").
static func _read_path(content_str: String) -> String:
	# JSON.new().parse hata basmaz (parse_string JSON olmayan içerikte konsolu kirletir).
	var json := JSON.new()
	if json.parse(content_str) != OK:
		return ""
	if not (json.data is Dictionary):
		return ""
	var parsed: Dictionary = json.data
	var data_v: Variant = parsed.get("data", null)
	if not bool(parsed.get("success", false)) or not (data_v is Dictionary):
		return ""
	var data: Dictionary = data_v
	return str(data.get("file_path", data.get("path", "")))

## Belirli bir aracın çıktı metnini analiz edip yapılandırılmış özete dönüştürür.
static func compact_tool_content(tool_name: String, content_str: String) -> String:
	if content_str.is_empty():
		return content_str

	var json = JSON.new()
	var parse_err = json.parse(content_str)
	if parse_err != OK or not (json.data is Dictionary):
		if content_str.length() > MAX_UNCOMPACTED_CHARS:
			return content_str.left(MAX_UNCOMPACTED_CHARS) + "... [Truncated]"
		return content_str

	var data: Dictionary = json.data
	if data.get("is_compacted", false):
		return content_str

	var success: bool = bool(data.get("success", false))
	if not success:
		var err_v: Variant = data.get("error", null)
		var code := ""
		var message := ""
		if err_v is Dictionary:
			var err: Dictionary = err_v
			code = str(err.get("code", ""))
			message = str(err.get("message", ""))
		elif err_v != null:
			message = str(err_v)
		return JSON.stringify({
			"success": false,
			"is_compacted": true,
			"summary": "BAŞARISIZ (%s): %s" % [code, message.left(MAX_ERROR_CHARS)]
		})

	var res: Dictionary = {}
	var res_v: Variant = data.get("data", null)
	if res_v is Dictionary:
		res = res_v
	var summary = ""

	match tool_name:
		"analyze_project":
			var p_name = res.get("project_name", "Godot Project")
			var main_s = res.get("main_scene", "")
			var total_f = res.get("total_files", 0)
			var sc_cnt = res.get("scenes_count", 0)
			var scr_cnt = res.get("scripts_count", 0)
			summary = "Proje: '%s', Ana Sahne: '%s', Toplam Dosya: %d (%d sahne, %d script)" % [p_name, main_s, total_f, sc_cnt, scr_cnt]

		"get_project_files":
			var count = res.get("count", 0)
			var path = res.get("path", "res://")
			var files: Array = res.get("files", [])
			summary = "'%s' altında %d dosya: %s" % [path, count, _path_list(files)]

		"search_project_assets":
			var q = res.get("query", "")
			var assets: Array = res.get("assets", [])
			summary = "'%s' araması için %d asset: %s" % [q, assets.size(), _path_list(assets)]

		"get_scene_tree", "inspect_node":
			var root_name = res.get("root_name", res.get("node_name", "Node"))
			var node_type = res.get("node_type", res.get("type", "Node"))
			var node_count = res.get("node_count", 1)
			summary = "Sahne Ağacı: '%s' (%s), %d düğüm incelendi" % [root_name, node_type, node_count]

		"read_script", "read_files", "read_file", "get_node_info":
			var f_path = res.get("file_path", res.get("path", ""))
			var lines_cnt = res.get("line_count", 0)
			if lines_cnt == 0 and res.has("content"):
				lines_cnt = str(res["content"]).split("\n").size()
			summary = "Dosya okundu: '%s' (%d satır; aynı dosya daha sonra yeniden okunduğu için içerik burada kısaltıldı)" % [f_path, lines_cnt]

		"get_runtime_errors":
			var err_count = res.get("error_count", 0)
			var errors = res.get("errors", [])
			var first_err = ""
			if errors.size() > 0:
				var e0 = errors[0]
				var f = str(e0.get("file", ""))
				var msg = str(e0.get("message", ""))
				first_err = (f + ": " if not f.is_empty() else "") + msg
			summary = "Runtime Hatası: %d adet tespit edildi (%s)" % [err_count, first_err.left(60)]

		"create_or_update_script", "replace_file_content", "write_files", "create_scene":
			var listed: Variant = res.get("written_files", [])
			var paths: Array = listed if listed is Array else []
			var f_path = str(res.get("file_path", ""))
			if not f_path.is_empty() and not paths.has(f_path):
				paths.append(f_path)
			summary = "Diske yazıldı: %s" % [_path_list(paths)]

		_:
			if content_str.length() > MAX_UNCOMPACTED_CHARS:
				summary = content_str.left(MAX_UNCOMPACTED_CHARS) + "..."
			else:
				return content_str

	var compacted_dict = {
		"success": true,
		"is_compacted": true,
		"summary": summary
	}
	return JSON.stringify(compacted_dict)

## Yol listesi özeti: tam yollar (klasör bilgisi kaybolmasın), çok uzunsa ilk 40.
static func _path_list(paths: Array) -> String:
	var shown := PackedStringArray()
	for p: Variant in paths.slice(0, 40):
		shown.append(str(p))
	var text := ", ".join(shown)
	if paths.size() > shown.size():
		text += " … (+%d)" % (paths.size() - shown.size())
	return text
