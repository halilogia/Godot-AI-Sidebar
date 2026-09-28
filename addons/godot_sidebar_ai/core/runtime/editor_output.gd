@tool
extends RefCounted
class_name AISidebarEditorOutput

## Editörün Output (terminal) çıktısı için gözlem katmanı: editör sürecinde bir Logger kaydedilir, son satırlar
## (hata, uyarı, print / mesaj) bir halka arabellekte tutulur. `get_output` aracı bunu okur; autoload,
## içe aktarma, eklenti ve betik yükleme hataları gibi yalnız Output panelinde görünen şeyler ajana böyle ulaşır.
## Oyun sürecinin çıktısı ayrıdır (oyundaki köprünün ErrorSink'i, "output" komutu).

const MAX_LINES := 300
const MAX_LINE_CHARS := 400

## Sırlar modele gitmesin: API anahtarı biçimleri ve Authorization başlığı maskelenir.
static func mask_secrets(text: String) -> String:
	var out := text
	for pattern: String in ["sk-[A-Za-z0-9_\\-]{8,}", "(?i)bearer\\s+[A-Za-z0-9_\\-\\.]{8,}", "(?i)(api[_-]?key|token|secret|password)(\"?\\s*[:=]\\s*\"?)[^\\s\",}]{6,}"]:
		var rx := RegEx.create_from_string(pattern)
		if rx == null:
			continue
		if pattern.begins_with("(?i)(api"):
			out = rx.sub(out, "$1$2***", true)
		else:
			out = rx.sub(out, "***", true)
	return out

## Kayıt (Logger). Başka iş parçacığından da çağrılır: kilitle korunur.
class Sink extends Logger:
	var lines: Array[Dictionary] = []
	var total: int = 0
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		# Doğrulamanın bellek içi derlemeleri (gdscript://) beklenen gürültüdür.
		if file.begins_with("gdscript://") or file.contains("ai_sidebar_verify"):
			return
		var text := rationale if not rationale.is_empty() else code
		var where := "%s:%d" % [file, line] if not file.is_empty() else function
		_add("warning" if error_type == Logger.ERROR_TYPE_WARNING else "error", "%s (%s)" % [text, where], file, line)

	func _log_message(message: String, error: bool) -> void:
		var text := message.strip_edges()
		# Eklentinin kendi zamanlama günlüğü Output'u boğar; modele değeri yok.
		if text.is_empty() or text.begins_with("[TIMING]"):
			return
		_add("error" if error else "message", text, "", 0)

	func _add(kind: String, text: String, file: String, line: int) -> void:
		var clean := AISidebarEditorOutput.mask_secrets(text)
		if clean.length() > AISidebarEditorOutput.MAX_LINE_CHARS:
			clean = clean.left(AISidebarEditorOutput.MAX_LINE_CHARS) + "..."
		_mutex.lock()
		total += 1
		lines.append({"n": total, "t_ms": Time.get_ticks_msec(), "kind": kind, "text": clean, "file": file, "line": line})
		if lines.size() > AISidebarEditorOutput.MAX_LINES:
			lines.pop_front()
		_mutex.unlock()

	## level: "all" | "errors" (hata + uyarı). contains: büyük-küçük harf duyarsız süzgeç. En yeni sonda.
	func recent(level: String, limit: int, contains: String) -> Array:
		var needle := contains.to_lower()
		_mutex.lock()
		var snapshot: Array[Dictionary] = lines.duplicate()
		_mutex.unlock()
		var out: Array = []
		for entry: Dictionary in snapshot:
			if level == "errors" and str(entry["kind"]) == "message":
				continue
			if not needle.is_empty() and not str(entry["text"]).to_lower().contains(needle):
				continue
			out.append(entry)
		return out.slice(maxi(0, out.size() - limit))

static var sink: Sink = null

## plugin.gd açılışta / kapanışta çağırır.
static func start() -> void:
	if sink == null:
		sink = Sink.new()
		OS.add_logger(sink)

static func stop() -> void:
	if sink != null:
		OS.remove_logger(sink)
		sink = null
