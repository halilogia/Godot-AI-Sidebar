@tool
extends RefCounted

## Sohbet metni için küçük Markdown → RichTextLabel BBCode dönüştürücüsü (SRP, saf fonksiyon).
## Desteklenen: başlıklar (#), kalın (**x** / __x__), italik (*x* / _x_), satır içi kod (`x`),
## çitli kod blokları (```), madde listeleri (- * +), alıntı (>), yatay çizgi (---).
## Metindeki köşeli parantezler önce kaçırılır: model/kullanıcı metni BBCode enjekte edemez.
## Kaynak metin değişmez; dışa aktarma ve kopyalama ham Markdown'ı kullanmaya devam eder.

const COLOR_CODE_INLINE := "#e5c07b"
const COLOR_CODE_BLOCK := "#a9b1d6"
const COLOR_CODE_BG := "#151922"
const COLOR_QUOTE := "#8a93a6"
const COLOR_RULE := "#3b4252"
const HEADER_FONT_SIZE := 13

static var _re_header: RegEx = null
static var _re_bullet: RegEx = null
static var _re_quote: RegEx = null
static var _re_rule: RegEx = null
static var _re_code: RegEx = null
static var _re_bold_star: RegEx = null
static var _re_bold_under: RegEx = null
static var _re_italic_star: RegEx = null
static var _re_italic_under: RegEx = null

static func _compile() -> void:
	if _re_header != null:
		return
	_re_header = RegEx.create_from_string("^(#{1,6})\\s+(.*)$")
	_re_bullet = RegEx.create_from_string("^(\\s*)[-*+]\\s+(.*)$")
	_re_quote = RegEx.create_from_string("^>\\s?(.*)$")
	_re_rule = RegEx.create_from_string("^\\s*(-{3,}|\\*{3,}|_{3,})\\s*$")
	_re_code = RegEx.create_from_string("`([^`\\n]+)`")
	_re_bold_star = RegEx.create_from_string("\\*\\*(?=\\S)(.+?)(?<=\\S)\\*\\*")
	_re_bold_under = RegEx.create_from_string("(?<![A-Za-z0-9_])__(?=\\S)(.+?)(?<=\\S)__(?![A-Za-z0-9_])")
	_re_italic_star = RegEx.create_from_string("(?<![*\\w])\\*(?=\\S)([^*\\n]+?)(?<=\\S)\\*(?![*\\w])")
	_re_italic_under = RegEx.create_from_string("(?<![A-Za-z0-9_])_(?=\\S)([^_\\n]+?)(?<=\\S)_(?![A-Za-z0-9_])")

## Köşeli parantezleri RichTextLabel kaçış etiketlerine çevirir.
static func escape_bbcode(text: String) -> String:
	return text.replace("[", "\u0001").replace("]", "[rb]").replace("\u0001", "[lb]")

static func to_bbcode(markdown: String) -> String:
	_compile()
	var out: PackedStringArray = []
	var in_fence := false
	var fence_lines: PackedStringArray = []
	for raw_line in markdown.replace("\r\n", "\n").split("\n"):
		var line: String = raw_line
		if line.strip_edges().begins_with("```"):
			if in_fence:
				out.append(_code_block(fence_lines))
				fence_lines.clear()
				in_fence = false
			else:
				in_fence = true
			continue
		if in_fence:
			fence_lines.append(line)
			continue
		out.append(_block_line(line))
	# Kapanmamış çit (akış yarıda): içeriği yine kod olarak göster.
	if in_fence:
		out.append(_code_block(fence_lines))
	return "\n".join(out)

static func _code_block(lines: PackedStringArray) -> String:
	var body = escape_bbcode("\n".join(lines))
	return "[bgcolor=%s][code][color=%s]%s[/color][/code][/bgcolor]" % [COLOR_CODE_BG, COLOR_CODE_BLOCK, body]

static func _block_line(line: String) -> String:
	if _re_rule.search(line):
		return "[color=%s]────────────────[/color]" % COLOR_RULE
	var m = _re_header.search(line)
	if m:
		var level = m.get_string(1).length()
		var title = _inline(m.get_string(2))
		if level <= 2:
			return "[font_size=%d][b]%s[/b][/font_size]" % [HEADER_FONT_SIZE, title]
		return "[b]%s[/b]" % title
	m = _re_bullet.search(line)
	if m:
		var depth = m.get_string(1).replace("\t", "  ").length() / 2
		return "  ".repeat(depth) + "• " + _inline(m.get_string(2))
	m = _re_quote.search(line)
	if m:
		return "[color=%s]│ %s[/color]" % [COLOR_QUOTE, _inline(m.get_string(1))]
	return _inline(line)

## Satır içi biçimler. Kod parçaları önce yer tutucuya alınır ki içleri biçimlenmesin.
static func _inline(text: String) -> String:
	var codes: PackedStringArray = []
	var result := ""
	var last := 0
	for m in _re_code.search_all(text):
		result += text.substr(last, m.get_start() - last)
		result += "\u0002%d\u0003" % codes.size()
		codes.append(m.get_string(1))
		last = m.get_end()
	result += text.substr(last)

	result = escape_bbcode(result)
	result = _re_bold_star.sub(result, "[b]$1[/b]", true)
	result = _re_bold_under.sub(result, "[b]$1[/b]", true)
	result = _re_italic_star.sub(result, "[i]$1[/i]", true)
	result = _re_italic_under.sub(result, "[i]$1[/i]", true)

	for i in codes.size():
		var code_bb = "[code][color=%s]%s[/color][/code]" % [COLOR_CODE_INLINE, escape_bbcode(codes[i])]
		result = result.replace("\u0002%d\u0003" % i, code_bb)
	return result
