@tool
extends RefCounted
class_name AISidebarRuntimeUiAudit

## Çalışan oyunun arayüzünü ölçer (oyun tarafı, saf ölçüm): ekran dışına taşan, kutusundan geniş, üst üste binen ve
## arka planda okunmayan (WCAG kontrastı) metin düğümleri. Ajanın kendi ekran görüntüsünde gözle yakalayamadığı
## hataları sayıya çevirir. Çıktı: {"checked": int, "issues": [{code, node, message}], "summary": String}.

const MAX_NODES := 80
const MAX_ISSUES := 20
const MIN_CONTRAST := 3.0
const OVERLAP_RATIO := 0.3

static func audit(tree: SceneTree) -> Dictionary:
	var root := tree.root
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var nodes: Array[Control] = []
	_collect(root, nodes)
	var img := root.get_texture().get_image() if root.get_texture() != null else null
	var scale := Vector2.ONE
	if img != null and view.size.x > 0.0 and view.size.y > 0.0:
		scale = Vector2(img.get_width() / view.size.x, img.get_height() / view.size.y)
	var issues: Array[Dictionary] = []
	for c in nodes:
		var rect := c.get_global_rect()
		var name_path := str(root.get_path_to(c))
		var inside := rect.intersection(view)
		if inside.get_area() < rect.get_area() * 0.9:
			issues.append({"code": "OFF_SCREEN", "node": name_path, "message": "text %s is partly outside the screen" % _quote(c)})
		if not _wraps(c) and c.get_minimum_size().x > rect.size.x + 2.0 and rect.size.x > 0.0:
			issues.append({"code": "TEXT_OVERFLOW", "node": name_path, "message": "text %s is wider (%d px) than its box (%d px)" % [_quote(c), int(c.get_minimum_size().x), int(rect.size.x)]})
		if img != null:
			var ratio := contrast(_font_color(c), _background_luminance(img, rect, scale))
			if ratio >= 0.0 and ratio < MIN_CONTRAST:
				issues.append({"code": "LOW_CONTRAST", "node": name_path, "message": "text %s has contrast %.1f:1 against the background (needs %.1f:1)" % [_quote(c), ratio, MIN_CONTRAST]})
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			var a := nodes[i]
			var b := nodes[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var ra := a.get_global_rect()
			var rb := b.get_global_rect()
			var overlap := ra.intersection(rb).get_area()
			var smaller := minf(ra.get_area(), rb.get_area())
			if smaller > 0.0 and overlap / smaller > OVERLAP_RATIO:
				issues.append({"code": "OVERLAP", "node": "%s | %s" % [root.get_path_to(a), root.get_path_to(b)], "message": "texts %s and %s overlap" % [_quote(a), _quote(b)]})
	if issues.size() > MAX_ISSUES:
		issues.resize(MAX_ISSUES)
	var summary := "%d text node(s) checked, %d issue(s)" % [nodes.size(), issues.size()]
	return {"checked": nodes.size(), "issues": issues, "summary": summary}

## Görünür, metni olan Label / Button / RichTextLabel / LineEdit düğümleri (ilk MAX_NODES tane).
static func _collect(node: Node, out: Array[Control]) -> void:
	if out.size() >= MAX_NODES:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Control and _has_text(node as Control) and (node as Control).is_visible_in_tree():
		var r := (node as Control).get_global_rect()
		if r.size.x > 0.0 and r.size.y > 0.0:
			out.append(node as Control)
	for child in node.get_children():
		_collect(child, out)

static func _has_text(c: Control) -> bool:
	if c is Label:
		return not (c as Label).text.strip_edges().is_empty()
	if c is Button:
		return not (c as Button).text.strip_edges().is_empty()
	if c is RichTextLabel:
		return not (c as RichTextLabel).get_parsed_text().strip_edges().is_empty()
	if c is LineEdit:
		return not (c as LineEdit).text.strip_edges().is_empty()
	return false

static func _wraps(c: Control) -> bool:
	if c is Label:
		return (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF or (c as Label).clip_text
	if c is Button:
		return (c as Button).clip_text
	return c is RichTextLabel or c is LineEdit

static func _text_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	return (c as LineEdit).text

static func _quote(c: Control) -> String:
	var t := _text_of(c).strip_edges().replace("\n", " ")
	return "'%s'" % (t.left(28) + ("…" if t.length() > 28 else ""))

static func _font_color(c: Control) -> Color:
	var col := c.get_theme_color("font_color") if c.has_theme_color("font_color") else Color.WHITE
	if c is Label and (c as Label).label_settings != null:
		col = (c as Label).label_settings.font_color
	return Color(col.r, col.g, col.b, 1.0) * Color(c.self_modulate.r, c.self_modulate.g, c.self_modulate.b, 1.0)

## Kutunun kenarlarından ve köşelerinden örneklenen piksellerin (metin ortada olduğu için arka plana yakın) ortanca renk parlaklığı.
static func _background_luminance(img: Image, rect: Rect2, scale: Vector2) -> float:
	var lums: Array[float] = []
	var px := Rect2(rect.position * scale, rect.size * scale).intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
	if px.size.x < 4.0 or px.size.y < 4.0:
		return -1.0
	var pts := [Vector2(1, 1), Vector2(px.size.x - 2, 1), Vector2(1, px.size.y - 2), Vector2(px.size.x - 2, px.size.y - 2),
		Vector2(px.size.x * 0.5, 1), Vector2(px.size.x * 0.5, px.size.y - 2), Vector2(1, px.size.y * 0.5), Vector2(px.size.x - 2, px.size.y * 0.5)]
	for p: Vector2 in pts:
		var at := px.position + p
		lums.append(_luminance(img.get_pixel(clampi(int(at.x), 0, img.get_width() - 1), clampi(int(at.y), 0, img.get_height() - 1))))
	lums.sort()
	return lums[lums.size() / 2]

static func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)

static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)

## WCAG kontrast oranı (1..21); arka plan ölçülemediyse -1.
static func contrast(fg: Color, bg_luminance: float) -> float:
	if bg_luminance < 0.0:
		return -1.0
	var l1 := _luminance(fg)
	return (maxf(l1, bg_luminance) + 0.05) / (minf(l1, bg_luminance) + 0.05)
