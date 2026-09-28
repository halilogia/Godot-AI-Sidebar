@tool
extends RefCounted
class_name AISidebarOutputTools

## `get_output`: Godot'nun Output (terminal) çıktısını okur; salt okunur gözlem aracı.
##   editor: editör sürecinin çıktısı (autoload / içe aktarma / eklenti / betik yükleme hataları, editördeki print)
##   game  : çalışan oyunun çıktısı (print satırları ve hatalar), oyundaki köprünün arabelleğinden
## Sırlar (API anahtarı biçimleri) maskelenir.

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarDebuggerPlugin = preload("res://addons/godot_sidebar_ai/core/runtime/debugger_plugin.gd")

const TOOL_NAME := "get_output"
const DEFAULT_LIMIT := 40
const MAX_LIMIT := 200

static func get_schemas() -> Array:
	return [{
		"type": "function",
		"function": {
			"name": TOOL_NAME,
			"description": "Reads Godot's Output (terminal) log. source 'editor': what the editor itself printed (autoload, import, plugin and script-loading errors, editor prints); source 'game': the running game's print() lines and errors (needs play_game first); 'both' (default) returns both. Use it when something fails without a clear error in another tool, to read print() debugging output from the game, or to check what the editor complained about after a change. level 'errors' keeps only errors and warnings. contains filters by text. Newest lines last. Secrets are masked.",
			"parameters": {
				"type": "object",
				"properties": {
					"source": {"type": "string", "enum": ["editor", "game", "both"], "description": "Which output to read (default both)."},
					"level": {"type": "string", "enum": ["all", "errors"], "description": "all lines, or only errors and warnings (default all)."},
					"contains": {"type": "string", "description": "Only lines containing this text (case-insensitive)."},
					"limit": {"type": "integer", "description": "Maximum lines per source (default 40, max 200)."},
				},
				"required": [],
			},
		},
	}]

static func normalize_args(args: Dictionary) -> Dictionary:
	var source := str(args.get("source", "both"))
	if not source in ["editor", "game", "both"]:
		source = "both"
	var level := str(args.get("level", "all"))
	if level != "errors":
		level = "all"
	return {"source": source, "level": level, "contains": str(args.get("contains", "")),
		"limit": clampi(int(str(args.get("limit", DEFAULT_LIMIT)).to_float()), 1, MAX_LIMIT)}

## Satırları modele küçük ve düz biçimde verir: "[hata] metin".
static func format_lines(entries: Array) -> Array:
	var out: Array = []
	for e_v: Variant in entries:
		var e: Dictionary = e_v
		var kind := str(e.get("kind", ""))
		var tag := kind if kind in ["error", "warning"] else "log"
		out.append("[%s] %s" % [tag, str(e.get("text", ""))])
	return out

static func execute_async(args: Dictionary) -> Dictionary:
	var a := normalize_args(args)
	var source: String = a["source"]
	var level: String = a["level"]
	var contains: String = a["contains"]
	var limit: int = a["limit"]
	var out := {"source": source, "level": level}
	var notes: Array = []
	if source in ["editor", "both"]:
		var sink: AISidebarEditorOutput.Sink = AISidebarEditorOutput.sink
		if sink == null:
			out["editor"] = []
			notes.append("The editor output logger is not running (only active in a normal editor session).")
		else:
			out["editor"] = format_lines(sink.recent(level, limit, contains))
	if source in ["game", "both"]:
		var dbg := AISidebarDebuggerPlugin.instance
		if dbg == null or not dbg.has_active_session():
			out["game"] = []
			notes.append("The game is not running (call play_game to read its output).")
		else:
			var resp: Dictionary = await dbg.query_async("output", [{"level": level, "contains": contains, "limit": limit}], 3.0)
			if resp.get("success", false) != true:
				out["game"] = []
				notes.append("The game did not answer: " + str(resp.get("message", resp.get("error", ""))))
			else:
				var raw: Array = resp["lines"] if resp.get("lines") is Array else []
				var masked: Array = []
				for e_v: Variant in raw:
					var e: Dictionary = e_v
					var raw_text := str(e.get("text", ""))
					e["text"] = AISidebarEditorOutput.mask_secrets(raw_text)
					masked.append(e)
				out["game"] = format_lines(masked)
	if not notes.is_empty():
		out["notes"] = notes
	var counts := PackedStringArray()
	for k: String in ["editor", "game"]:
		if out.has(k):
			var lines: Array = out[k]
			counts.append("%s %d" % [k, lines.size()])
	return AISidebarToolResult.ok(out, "Output: " + ", ".join(counts))
