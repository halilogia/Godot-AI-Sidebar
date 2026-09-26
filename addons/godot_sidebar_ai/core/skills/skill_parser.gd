@tool
extends RefCounted
class_name AISidebarSkillParser

## Agent Skills (agentskills.io) `SKILL.md` ayrıştırıcısı: YAML ön bilgi (frontmatter) + Markdown
## gövde. Standardın uygulayıcı rehberine göre hoşgörülü: kozmetik sorunlarda uyarı verip yükler,
## açıklama yoksa ya da ön bilgi hiç okunamıyorsa skill'i atlar. Tam YAML değil; skill'lerde
## kullanılan alt küme: `anahtar: değer`, tırnaklı değer, `>` / `|` blok metin, iç içe haritalar
## (ör. `metadata:`) — iç içe olanlar yalnız düz metin olarak saklanır.

const NAME_MAX := 64
const DESCRIPTION_MAX := 1024

## Dönüş: {"ok": bool, "name", "description", "body", "fields": Dictionary, "warnings": Array[String], "error": String}
static func parse(text: String, dir_name: String = "") -> Dictionary:
	var result := {"ok": false, "name": "", "description": "", "body": "", "fields": {}, "warnings": [] as Array[String], "error": ""}
	var src := text.replace("\r\n", "\n").trim_prefix("﻿")
	if not src.begins_with("---"):
		result["error"] = "SKILL.md must start with YAML frontmatter (---)."
		return result
	var close := src.find("\n---", 3)
	if close == -1:
		result["error"] = "Frontmatter is not closed with ---."
		return result
	var yaml := src.substr(3, close - 3)
	var after := src.substr(close + 4)
	var nl := after.find("\n")
	var body := after.substr(nl + 1) if nl != -1 else ""
	var fields := parse_frontmatter(yaml)
	var warnings: Array[String] = []
	var name := str(fields.get("name", "")).strip_edges()
	var description := str(fields.get("description", "")).strip_edges()
	if description.is_empty():
		result["error"] = "description is missing or empty."
		return result
	if name.is_empty():
		name = dir_name
		warnings.append("name is missing; using the folder name.")
	if not dir_name.is_empty() and name != dir_name:
		warnings.append("name '%s' does not match the folder name '%s'." % [name, dir_name])
	if name.length() > NAME_MAX:
		warnings.append("name is longer than %d characters." % NAME_MAX)
	if not is_valid_name(name):
		warnings.append("name should use lowercase letters, digits and single hyphens.")
	if description.length() > DESCRIPTION_MAX:
		warnings.append("description is longer than %d characters." % DESCRIPTION_MAX)
	result["ok"] = true
	result["name"] = name
	result["description"] = description
	result["body"] = body.strip_edges()
	result["fields"] = fields
	result["warnings"] = warnings
	return result

static func is_valid_name(name: String) -> bool:
	if name.is_empty() or name.begins_with("-") or name.ends_with("-") or name.contains("--"):
		return false
	for i in name.length():
		var c := name.unicode_at(i)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 45
		if not ok:
			return false
	return true

## Üst düzey `anahtar: değer` çiftleri. Blok (`>` katlanan, `|` satır koruyan) ve girintili iç
## içe değerler desteklenir; iç içe haritalar ham metin olarak döner.
static func parse_frontmatter(yaml: String) -> Dictionary:
	var out := {}
	var lines := yaml.split("\n")
	var i := 0
	while i < lines.size():
		var line: String = lines[i]
		if line.strip_edges().is_empty() or line.strip_edges().begins_with("#") or line.begins_with(" ") or line.begins_with("\t"):
			i += 1
			continue
		var colon := line.find(":")
		if colon <= 0:
			i += 1
			continue
		var key := line.substr(0, colon).strip_edges()
		var value := line.substr(colon + 1).strip_edges()
		# Girintili devam satırları (blok metin ya da iç içe harita)
		var nested: PackedStringArray = []
		var j := i + 1
		while j < lines.size() and (lines[j].begins_with(" ") or lines[j].begins_with("\t") or lines[j].strip_edges().is_empty()):
			nested.append(lines[j].strip_edges())
			j += 1
		if value == ">" or value == ">-" or value == "|" or value == "|-":
			var sep := " " if value.begins_with(">") else "\n"
			out[key] = sep.join(nested).strip_edges()
		elif value.is_empty() and nested.size() > 0:
			out[key] = "\n".join(nested).strip_edges()
		else:
			out[key] = _unquote(value)
		i = j
	return out

static func _unquote(v: String) -> String:
	if v.length() >= 2 and ((v.begins_with("\"") and v.ends_with("\"")) or (v.begins_with("'") and v.ends_with("'"))):
		var inner := v.substr(1, v.length() - 2)
		return inner.replace("\\\"", "\"") if v.begins_with("\"") else inner.replace("''", "'")
	return v
