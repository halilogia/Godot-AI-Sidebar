@tool
extends RefCounted
class_name AISidebarProjectInstructions

## Oyun projesinin kök `AGENTS.md` dosyası (agents.md açık formatı): projenin her zaman geçerli
## kuralları. Sidebar ajanı her turda okur; Codex, Cursor, Copilot gibi araçlar aynı dosyayı kendileri
## okur (Claude Code'da `CLAUDE.md` içinden içe aktarılabilir). Ayrı biçim, şablon ya da klasör yoktur.

const PATH := "res://AGENTS.md"
const MAX_CHARS := 12000

## Modele eklenecek metin; dosya yoksa ya da boşsa "".
static func prompt_text(path: String = PATH) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var text := FileAccess.get_file_as_string(path).strip_edges()
	if text.is_empty():
		return ""
	var note := ""
	if text.length() > MAX_CHARS:
		text = text.left(MAX_CHARS)
		note = "\n[AGENTS.md truncated at %d characters]" % MAX_CHARS
	return "=== PROJECT INSTRUCTIONS (AGENTS.md at the project root; follow them) ===\n" + text + note
