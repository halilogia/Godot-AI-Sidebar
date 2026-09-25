@tool
extends RefCounted

## Markdown → BBCode dönüştürücü testleri: biçimler, BBCode enjeksiyonu, dosya yolları,
## kod içinin korunması ve balon / plan kartı entegrasyonu.

const R = preload("res://addons/godot_sidebar_ai/ui/presenters/markdown_renderer.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarPlanCard = preload("res://addons/godot_sidebar_ai/ui/components/plan_card.gd")
const AISidebarImplementationPlan = preload("res://addons/godot_sidebar_ai/core/types/implementation_plan.gd")

static func _plain(bb: String) -> String:
	var l = RichTextLabel.new()
	l.bbcode_enabled = true
	l.text = bb
	var t = l.get_parsed_text()
	l.free()
	return t

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Satır içi biçimler
	var b1 = R.to_bbcode("Use **bold**, *italic*, _also_ and `code_here`.")
	if "[b]bold[/b]" in b1 and "[i]italic[/i]" in b1 and "[i]also[/i]" in b1 and "code_here[/color][/code]" in b1:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (inline) failed: " + b1)

	# 2. Blok biçimleri: başlık, madde, alıntı, çizgi; görünen metinde işaretler kalmaz
	var b2 = R.to_bbcode("## Plan\n- first\n  - nested\n> note\n---\n1. step")
	var p2 = _plain(b2)
	if "[b]Plan[/b]" in b2 and "• first" in p2 and "  • nested" in p2 and "│ note" in p2 and not "##" in p2 and "1. step" in p2:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (blocks) failed: " + p2)

	# 3. BBCode enjeksiyonu yok; köşeli parantez metin olarak görünür
	var p3 = _plain(R.to_bbcode("Array[int] and [url=x]click[/url] [b]raw[/b]"))
	if p3 == "Array[int] and [url=x]click[/url] [b]raw[/b]":
		passed += 1
	else:
		failed += 1
		errors.append("T3 (escape) failed: " + p3)

	# 4. Dosya yolları ve snake_case bozulmaz; kod içi biçimlenmez; çitli blok korunur
	var b4 = R.to_bbcode("Edit old_player_controller.gd and `**not bold**`\n```gdscript\nvar a = [1, 2]\n**x**\n```")
	var p4 = _plain(b4)
	if "old_player_controller.gd" in p4 and "**not bold**" in p4 and "var a = [1, 2]" in p4 and "**x**" in p4 and not "```" in p4:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (paths/code) failed: " + p4)

	# 5. Balon: asistan Markdown işler ve res:// bağlantısını korur; kullanıcı metni düz kalır
	var a = AISidebarMessageBubble.new("assistant", "Done. **player.gd** at res://player.gd")
	a._ready()
	var u = AISidebarMessageBubble.new("user", "Make **this** [b]x[/b]")
	u._ready()
	var ok_a = "[b]player.gd[/b]" in a._content_label.text and "[url=file:res://player.gd]" in a._content_label.text
	var ok_u = u._content_label.get_parsed_text() == "Make **this** [b]x[/b]"
	a.free()
	u.free()
	if ok_a and ok_u:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (bubble roles) failed: a=%s u=%s" % [str(ok_a), str(ok_u)])

	# 6. Plan kartı Markdown'ı işler (ham ** / ## görünmez)
	var card = AISidebarPlanCard.new(AISidebarImplementationPlan.new({"goal": "Jump", "steps": ["Add code"], "verification": ["Run"]}))
	card._ready()
	var plan_txt = card._plan_lbl.get_parsed_text()
	card.free()
	if not "**" in plan_txt and not "##" in plan_txt and "Jump" in plan_txt:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (plan card) failed: " + plan_txt)

	# 7. Kalın / italik / kod gövde metniyle aynı boyutta (tema varsayılanına düşmez)
	var bb = AISidebarMessageBubble.new("assistant", "**a** `b`")
	bb._ready()
	var lbl = bb._content_label
	var same = true
	for key in ["bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		if not lbl.has_theme_font_size_override(key) or lbl.get_theme_font_size(key) != lbl.get_theme_font_size("normal_font_size"):
			same = false
	bb.free()
	var card7 = AISidebarPlanCard.new(AISidebarImplementationPlan.new({"goal": "G", "steps": ["s"], "verification": ["v"]}))
	card7._ready()
	var same_plan = card7._plan_lbl.get_theme_font_size("bold_font_size") == card7._plan_lbl.get_theme_font_size("normal_font_size")
	card7.free()
	if same and same_plan:
		passed += 1
	else:
		failed += 1
		errors.append("T7 (font sizes) failed: bubble=%s plan=%s" % [str(same), str(same_plan)])

	# 8. Çitli kod bloğu glif başına arka plan ([bgcolor]) kullanmaz: tek kutulu tablo hücresi.
	# ([bgcolor] komşu satırlara taşıp başlığı ve alt çizgileri örtüyordu.) Kod yazı tipi eş genişlikli.
	var b8 = R.to_bbcode("### Tree\n```\nMain3D (Node3D)\n├── Ground\n```")
	var bub8 = AISidebarMessageBubble.new("assistant", "x")
	bub8._ready()
	var mono_ok = bub8._content_label.has_theme_font_override("mono_font") and bub8._content_label.get_theme_font("mono_font") is SystemFont
	bub8.free()
	if not "[bgcolor" in b8 and "[table=1][cell bg=" in b8 and "Main3D (Node3D)" in _plain(b8) and mono_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T8 (code block box + mono font) failed: " + b8)

	return {"name": "MarkdownRendererTests", "passed": passed, "failed": failed, "errors": errors}
