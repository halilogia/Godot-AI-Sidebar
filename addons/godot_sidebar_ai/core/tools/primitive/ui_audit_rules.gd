@tool
extends RefCounted
class_name AISidebarUIAuditRules

## audit_ui_layout / audit_ui_touch'ın ekrana bakan kuralları (SRP): platform profili (masaüstü / mobil dokunma
## ölçüsü), görünüm dışına taşma (OUTSIDE_VIEWPORT), metin kontrastı (TEXT_LOW_CONTRAST) ve etkileşimli
## kontrolle çakışan içerik (TEXT_OVERLAPS_INTERACTIVE, INTERACTIVE_OVERLAP). Hepsi salt okunur ölçümdür.

const AISidebarUIThemeScaffold = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_theme_scaffold.gd")

## Proje başına varsayılan: Proje Ayarları'nda bu anahtar "desktop" ya da "mobile" olur.
const PLATFORM_SETTING: String = "godot_ai_sidebar/ui_audit/platform"
const DEFAULT_PLATFORM: String = "mobile"
## Masaüstü: fare imleci için 28 px yeter (Godot editörü ve çoğu strateji oyunu 24-32 px düğme kullanır).
## Mobil: Apple HIG / Material dokunma hedefi 44-48 px.
const PLATFORMS: Dictionary = {
	"desktop": {"min_touch_size": 28.0, "min_spacing": 4.0},
	"mobile": {"min_touch_size": 44.0, "min_spacing": 8.0}
}
const EDGE_TOLERANCE: float = 1.0
const MIN_OVERLAP_AREA: float = 16.0
## WCAG 2.x AA: gövde metni 4.5:1, büyük metin (>= 24 px) 3:1. 3:1'in altı okunmaz sayılır (P1), arası P2.
const CONTRAST_NORMAL: float = 4.5
const CONTRAST_LARGE: float = 3.0
const LARGE_TEXT_PX: int = 24
const MAX_TEXT_CHARS: int = 400
const TEXTURE_SAMPLES: int = 16

# --- Platform profili ---

## Geçerli platform adı; açıkça verilen ad bilinmiyorsa "" döner (araç INVALID_ARGUMENT verir).
static func resolve_platform(args: Dictionary) -> String:
	var p: String = str(args.get("platform", "")).strip_edges().to_lower()
	if not p.is_empty():
		return p if PLATFORMS.has(p) else ""
	if ProjectSettings.has_setting(PLATFORM_SETTING):
		var proj: String = str(ProjectSettings.get_setting(PLATFORM_SETTING)).strip_edges().to_lower()
		if PLATFORMS.has(proj):
			return proj
	return DEFAULT_PLATFORM

## Platform profilinden ölçüler; min_touch_size / min_spacing açıkça verildiyse onlar kazanır.
static func touch_limits(args: Dictionary, platform: String) -> Dictionary:
	var prof: Dictionary = PLATFORMS.get(platform, PLATFORMS[DEFAULT_PLATFORM])
	return {
		"platform": platform,
		"min_touch_size": float(args.get("min_touch_size", prof["min_touch_size"])),
		"min_spacing": float(args.get("min_spacing", prof["min_spacing"]))
	}

# --- Ekran dikdörtgeni ---

## Kontrolün ekran (görünüm) koordinatındaki dikdörtgeni: CanvasLayer ve tuval dönüşümü dahil.
static func screen_rect(ctrl: Control) -> Rect2:
	return ctrl.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, ctrl.size)

## Atalarda kırpan (clip_contents) kontrol varsa dikdörtgeni onunla keser; ScrollContainer da kırpar.
static func visible_screen_rect(ctrl: Control) -> Rect2:
	var r: Rect2 = screen_rect(ctrl)
	var p: Node = ctrl.get_parent()
	while p:
		if p is Control and ((p as Control).clip_contents or p is ScrollContainer):
			r = r.intersection(screen_rect(p as Control))
		p = p.get_parent()
	return r

## Dünyaya bağlı arayüz (Node2D altında ya da kamera ile kayan tuvalde) ekran dışına meşru olarak çıkar.
static func _is_world_space(ctrl: Control) -> bool:
	var p: Node = ctrl.get_parent()
	while p:
		if p is Node2D: return true
		if p is CanvasLayer or p is Viewport: break
		p = p.get_parent()
	if ctrl.get_canvas_layer_node() == null:
		var vp: Viewport = ctrl.get_viewport()
		if vp and vp.canvas_transform != Transform2D.IDENTITY: return true
	return false

static func _scrolled_or_clipped(ctrl: Control) -> bool:
	var p: Node = ctrl.get_parent()
	while p and not (p is Viewport):
		if p is ScrollContainer or (p is Control and (p as Control).clip_contents): return true
		p = p.get_parent()
	return false

# --- OUTSIDE_VIEWPORT ---

## Kontrol görünüm alanından taşıyorsa P1. Kaydırılan / kırpılan içerik (orası OUTSIDE_PARENT_RECT'in işi),
## dünyaya bağlı arayüz ve ebeveyni zaten taşan çocuk (zincir tekrarı) bildirilmez.
static func check_outside_viewport(ctrl: Control, is_audit_root: bool, issues: Array[Dictionary]) -> void:
	if not ctrl.is_inside_tree() or ctrl.size.x <= 0.0 or ctrl.size.y <= 0.0: return
	if _is_world_space(ctrl) or _scrolled_or_clipped(ctrl): return
	var vp: Rect2 = ctrl.get_viewport_rect()
	if vp.size.x <= 0.0 or vp.size.y <= 0.0: return
	var r: Rect2 = screen_rect(ctrl)
	var allowed: Rect2 = vp.grow(EDGE_TOLERANCE)
	if allowed.encloses(r): return
	var pc: Control = ctrl.get_parent() as Control
	if not is_audit_root and pc and not ctrl.top_level and pc.size.x > 0.0 and pc.size.y > 0.0 and not allowed.encloses(screen_rect(pc)):
		return
	var over: Dictionary = {
		"left": maxf(0.0, vp.position.x - r.position.x), "top": maxf(0.0, vp.position.y - r.position.y),
		"right": maxf(0.0, r.end.x - vp.end.x), "bottom": maxf(0.0, r.end.y - vp.end.y)
	}
	var fully: bool = not r.intersects(vp)
	var what: String = "tamamen ekran dışında" if fully else "ekrandan taşıyor (sol %d, üst %d, sağ %d, alt %d px)" % [int(over["left"]), int(over["top"]), int(over["right"]), int(over["bottom"])]
	issues.append({
		"rule_id": "OUTSIDE_VIEWPORT", "severity": "error", "node_path": str(ctrl.get_path()), "node_class": ctrl.get_class(),
		"message": "'%s' %s; görünüm %dx%d." % [ctrl.name, what, int(vp.size.x), int(vp.size.y)],
		"fix_action": "Anchor / offset'i görünüme göre düzelt; gizliyken ekran dışında bekleyen panel ise visible=false yap.",
		"evidence": {"screen_rect": _rect_dict(r), "viewport": _rect_dict(vp), "overflow": over, "fully_outside": fully}
	})

# --- TEXT_LOW_CONTRAST ---

static func text_of(ctrl: Control) -> String:
	if ctrl is Label: return (ctrl as Label).text
	if ctrl is Button: return (ctrl as Button).text
	if ctrl is RichTextLabel: return (ctrl as RichTextLabel).get_parsed_text()
	if ctrl is LineEdit:
		var le: LineEdit = ctrl as LineEdit
		return le.text if not le.text.is_empty() else le.placeholder_text
	return ""

static func is_text_control(ctrl: Control) -> bool:
	return ctrl is Label or ctrl is Button or ctrl is RichTextLabel or ctrl is LineEdit

static func font_color(ctrl: Control) -> Color:
	var col: Color = Color.WHITE
	if ctrl is Label and (ctrl as Label).label_settings != null:
		col = (ctrl as Label).label_settings.font_color
	elif ctrl is RichTextLabel:
		col = ctrl.get_theme_color("default_color")
	elif ctrl is LineEdit and (ctrl as LineEdit).text.is_empty():
		col = ctrl.get_theme_color("font_placeholder_color")
	else:
		col = ctrl.get_theme_color("font_color")
	return col * ctrl.self_modulate * ctrl.modulate

static func font_size(ctrl: Control) -> int:
	if ctrl is Label and (ctrl as Label).label_settings != null: return (ctrl as Label).label_settings.font_size
	if ctrl is RichTextLabel: return ctrl.get_theme_font_size("normal_font_size")
	return ctrl.get_theme_font_size("font_size")

static func _has_outline(ctrl: Control) -> bool:
	if ctrl is Label and (ctrl as Label).label_settings != null:
		return (ctrl as Label).label_settings.outline_size > 0
	return ctrl.get_theme_constant("outline_size") > 0

## Bir StyleBox'ın dolgu rengi (yarı saydam olabilir); dolgusuzsa null.
static func stylebox_fill(sb: StyleBox) -> Variant:
	if sb is StyleBoxFlat:
		var f: StyleBoxFlat = sb as StyleBoxFlat
		return f.bg_color if f.draw_center and f.bg_color.a > 0.0 else null
	if sb is StyleBoxTexture:
		var t: StyleBoxTexture = sb as StyleBoxTexture
		if not t.draw_center: return null
		var avg: Variant = texture_average(t.texture)
		return (avg as Color) * t.modulate_color if avg != null else null
	return null

## Dokunun ortalama rengi (kâğıt / parşömen gibi dokulu panel arka planı için); okunamazsa null.
static func texture_average(tex: Texture2D) -> Variant:
	if tex == null: return null
	var img: Image = tex.get_image()
	if img == null or img.is_empty(): return null
	if img.is_compressed():
		img = img.duplicate() as Image
		if img.decompress() != OK: return null
	var sum: Color = Color(0, 0, 0, 0)
	var n: int = 0
	for yi: int in TEXTURE_SAMPLES:
		for xi: int in TEXTURE_SAMPLES:
			var px: int = mini(img.get_width() - 1, int((xi + 0.5) * img.get_width() / float(TEXTURE_SAMPLES)))
			var py: int = mini(img.get_height() - 1, int((yi + 0.5) * img.get_height() / float(TEXTURE_SAMPLES)))
			var c: Color = img.get_pixel(px, py)
			sum += c
			n += 1
	return sum / float(n) if n > 0 else null

## Kontrolün kendi çizdiği dolgu: panel / ColorRect / doku. Yoksa null.
static func control_fill(ctrl: Control) -> Variant:
	var fill: Variant = null
	if ctrl is ColorRect:
		fill = (ctrl as ColorRect).color
	elif ctrl is TextureRect:
		fill = texture_average((ctrl as TextureRect).texture)
	elif ctrl is NinePatchRect:
		fill = texture_average((ctrl as NinePatchRect).texture)
	elif ctrl is Panel or ctrl is PanelContainer:
		fill = stylebox_fill(ctrl.get_theme_stylebox("panel"))
	elif ctrl is Button and not (ctrl as Button).flat:
		fill = stylebox_fill(ctrl.get_theme_stylebox("normal"))
	elif ctrl is LineEdit or ctrl is Label or ctrl is RichTextLabel:
		fill = stylebox_fill(ctrl.get_theme_stylebox("normal"))
	if fill == null: return null
	var c: Color = fill as Color
	return c * ctrl.self_modulate

## Metnin arkasında görünen renk: kendi kutusu, sonra her düzeyde önce çizilen kardeşler (metni örten),
## sonra ata panel. Yarı saydam katmanlar opak bir katmana kadar üst üste bindirilir. Bulunamazsa null.
static func background_behind(ctrl: Control) -> Variant:
	var layers: Array[Color] = []
	var target: Rect2 = screen_rect(ctrl)
	var own: Variant = control_fill(ctrl)
	if own != null: layers.append(own as Color)
	var child: Node = ctrl
	var p: Node = ctrl.get_parent()
	while p and not _opaque(layers):
		if p is Viewport or p is CanvasLayer: break
		for i: int in range(child.get_index() - 1, -1, -1):
			var sib: Node = p.get_child(i)
			if not (sib is Control) or not (sib as Control).is_visible_in_tree() or (sib as Control).top_level: continue
			var sc: Control = sib as Control
			if not screen_rect(sc).grow(EDGE_TOLERANCE).encloses(target): continue
			var f: Variant = control_fill(sc)
			if f != null:
				layers.append(f as Color)
				if _opaque(layers): break
		if _opaque(layers): break
		if p is Control:
			var pf: Variant = control_fill(p as Control)
			if pf != null: layers.append(pf as Color)
		child = p
		p = p.get_parent()
	if not _opaque(layers): return null
	var out: Color = layers[layers.size() - 1]
	out.a = 1.0
	for i: int in range(layers.size() - 2, -1, -1):
		out = out.lerp(Color(layers[i].r, layers[i].g, layers[i].b, 1.0), layers[i].a)
	return out

static func _opaque(layers: Array[Color]) -> bool:
	return not layers.is_empty() and layers[layers.size() - 1].a >= 0.99

## Metin rengi ile arkasındaki panel arasındaki WCAG oranı; < 3:1 P1, gerekli orana (4.5 / büyük metin 3) kadar P2.
## Arka plan bilinmiyorsa, kontur varsa, metin boşsa ya da düğme devre dışıysa ölçülmez (yanlış alarm yok).
static func check_text_contrast(ctrl: Control, min_ratio: float, issues: Array[Dictionary]) -> void:
	if not ctrl.is_inside_tree() or not is_text_control(ctrl): return
	if text_of(ctrl).strip_edges().is_empty(): return
	if ctrl is BaseButton and (ctrl as BaseButton).disabled: return
	if _has_outline(ctrl): return
	var bg_v: Variant = background_behind(ctrl)
	if bg_v == null: return
	var bg: Color = bg_v as Color
	var fg_raw: Color = font_color(ctrl)
	var fg: Color = bg.lerp(Color(fg_raw.r, fg_raw.g, fg_raw.b, 1.0), clampf(fg_raw.a, 0.0, 1.0))
	var ratio: float = AISidebarUIThemeScaffold.contrast_ratio(fg, bg)
	var size_px: int = font_size(ctrl)
	var needed: float = CONTRAST_LARGE if size_px >= LARGE_TEXT_PX else min_ratio
	if ratio >= needed: return
	var prio: String = "P1" if ratio < CONTRAST_LARGE else "P2"
	issues.append({
		"rule_id": "TEXT_LOW_CONTRAST", "priority": prio, "severity": "error" if prio == "P1" else "warning",
		"node_path": str(ctrl.get_path()), "node_class": ctrl.get_class(),
		"message": "'%s' metni arka planına göre %.2f:1 kontrastta (gerekli %.1f:1, %d px); okunması zor." % [ctrl.name, ratio, needed, size_px],
		"fix_action": "Yazı rengini koyulaştır / açılaştır ya da panel rengini değiştir (tema belirtecinden).",
		"evidence": {"ratio": snappedf(ratio, 0.01), "required": needed, "font_size": size_px, "text_color": "#" + fg.to_html(false), "background": "#" + bg.to_html(false)}
	})

# --- TEXT_OVERLAPS_INTERACTIVE / INTERACTIVE_OVERLAP ---

## Metnin gerçekten kapladığı ekran dikdörtgeni (Label'da karakter sınırlarından; olmazsa kutunun kendisi).
static func text_screen_rect(ctrl: Control) -> Rect2:
	var local: Rect2 = Rect2(Vector2.ZERO, ctrl.size)
	if ctrl is Label and ctrl.has_method("get_character_bounds"):
		var lbl: Label = ctrl as Label
		var n: int = mini(lbl.get_total_character_count(), MAX_TEXT_CHARS)
		var acc: Rect2 = Rect2()
		var have: bool = false
		for i: int in n:
			var cb: Rect2 = lbl.get_character_bounds(i)
			if cb.size.x <= 0.0 and cb.size.y <= 0.0: continue
			acc = cb if not have else acc.merge(cb)
			have = true
		if have: local = acc
	elif ctrl is RichTextLabel:
		var rtl: RichTextLabel = ctrl as RichTextLabel
		local = Rect2(Vector2.ZERO, Vector2(ctrl.size.x, minf(ctrl.size.y, float(rtl.get_content_height()))))
	var r: Rect2 = ctrl.get_global_transform_with_canvas() * local
	var clip: Rect2 = visible_screen_rect(ctrl)
	return r.intersection(clip)

## a, b'den sonra mı çizilir (z_index + ağaç sırası)? Biri diğerinin atasıysa false.
static func draws_above(a: Control, b: Control) -> bool:
	if a.z_index != b.z_index: return a.z_index > b.z_index
	var ca: Array[Node] = _chain(a)
	var cb: Array[Node] = _chain(b)
	var i: int = 0
	while i < ca.size() and i < cb.size() and ca[i] == cb[i]: i += 1
	if i >= ca.size() or i >= cb.size(): return false
	return ca[i].get_index() > cb[i].get_index()

static func _chain(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	var cur: Node = node
	while cur:
		out.push_front(cur)
		cur = cur.get_parent()
	return out

## Etkileşimli kontrol ile ona binen görünür metin (P1: metin düğmenin üstünde; P2: metin düğmenin altında kalıyor)
## ve birbirine binen iki etkin düğme (P1). Ata / çocuk ilişkisi (düğmenin kendi etiketi) sayılmaz.
static func check_overlaps(texts: Array[Control], interactive: Array[Control], issues: Array[Dictionary]) -> void:
	for t: Control in texts:
		if not t.is_inside_tree() or text_of(t).strip_edges().is_empty(): continue
		if _effective_alpha(t) <= 0.01: continue
		var tr: Rect2 = text_screen_rect(t)
		if tr.get_area() < MIN_OVERLAP_AREA: continue
		for b: Control in interactive:
			if b == t or not b.is_inside_tree() or b.is_ancestor_of(t) or t.is_ancestor_of(b): continue
			var hit: Rect2 = tr.intersection(visible_screen_rect(b))
			if hit.get_area() < MIN_OVERLAP_AREA: continue
			var above: bool = draws_above(t, b)
			issues.append({
				"rule_id": "TEXT_OVERLAPS_INTERACTIVE", "priority": "P1" if above else "P2", "severity": "error" if above else "warning",
				"node_path": str(t.get_path()), "node_class": t.get_class(), "other_path": str(b.get_path()),
				"message": ("'%s' metni '%s' düğmesinin üstüne biniyor (%dx%d px); düğme okunmaz / tıklanması karışır." if above else "'%s' metni '%s' düğmesinin altında kalıyor (%dx%d px); metnin bir kısmı görünmez.") % [t.name, b.name, int(hit.size.x), int(hit.size.y)],
				"fix_action": "Metni sarmala / kısalt, paneli Container ile sınırla ya da düğmeyi taşı.",
				"evidence": {"text_rect": _rect_dict(tr), "button_rect": _rect_dict(screen_rect(b)), "overlap": _rect_dict(hit)}
			})
	for i: int in interactive.size():
		var a: Control = interactive[i]
		if not a.is_inside_tree() or (a is BaseButton and (a as BaseButton).disabled): continue
		var ra: Rect2 = visible_screen_rect(a)
		for j: int in range(i + 1, interactive.size()):
			var b: Control = interactive[j]
			if not b.is_inside_tree() or a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			if b is BaseButton and (b as BaseButton).disabled: continue
			var hit: Rect2 = ra.intersection(visible_screen_rect(b))
			if hit.get_area() < MIN_OVERLAP_AREA: continue
			issues.append({
				"rule_id": "INTERACTIVE_OVERLAP", "priority": "P1", "severity": "error", "node_path": str(a.get_path()), "node_class": a.get_class(), "other_path": str(b.get_path()),
				"message": "'%s' ve '%s' düğmeleri üst üste biniyor (%dx%d px); tıklama hangisine gideceği belirsiz." % [a.name, b.name, int(hit.size.x), int(hit.size.y)],
				"fix_action": "Düğmeleri bir Container'a al ya da konumlarını ayır.",
				"evidence": {"overlap": _rect_dict(hit)}
			})

static func _effective_alpha(ctrl: CanvasItem) -> float:
	var a: float = ctrl.self_modulate.a
	var cur: Node = ctrl
	while cur:
		if cur is CanvasItem: a *= (cur as CanvasItem).modulate.a
		cur = cur.get_parent()
	return a

static func _rect_dict(r: Rect2) -> Dictionary:
	return {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y}
