extends SceneTree

## İki arayüz görüntü klasörünü karşılaştırır (tools/ui_shots.gd çıktıları; örn. ui_snapshots/<önceki>/ ile
## ui_snapshots/<sonraki>/). Aynı adlı her PNG için: birebir aynıysa "aynı" sayılır; farklıysa yan yana
## (solda önce, sağda sonra, farklı bölge kırmızı çerçeveli) bir karşılaştırma görüntüsü yazılır. Yeni ve
## kaybolan görüntüler de listelenir. Sonuç <çıktı>/report.md'dedir. Bu bir rapordur, test değildir:
## hiçbir farkı hata saymaz, yalnız neyin değiştiğini gözle bakılacak biçimde önüne koyar.
##
##   godot --headless --path . -s res://tools/ui_compare.gd -- <önce klasörü> <sonra klasörü> <çıktı klasörü>

const GAP := 16
const MARK := Color(0.95, 0.25, 0.25, 1.0)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("Kullanım: -- <önce klasörü> <sonra klasörü> <çıktı klasörü>")
		quit(2)
		return
	var before_dir: String = args[0]
	var after_dir: String = args[1]
	var out_dir: String = args[2]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var before := _pngs(before_dir)
	var after := _pngs(after_dir)
	var same: Array[String] = []
	var changed: Array[String] = []
	var added: Array[String] = []
	var removed: Array[String] = []
	for rel: String in after:
		if not before.has(rel):
			added.append(rel)
			continue
		var a := Image.load_from_file(before_dir.path_join(rel))
		var b := Image.load_from_file(after_dir.path_join(rel))
		# Hızlı yol: bayt bayt aynıysa piksel taraması yapılmaz.
		if a.get_size() == b.get_size() and a.get_format() == b.get_format() and a.get_data() == b.get_data():
			same.append(rel)
			continue
		var diff := diff_rect(a, b)
		if diff.size == Vector2i.ZERO and a.get_size() == b.get_size():
			same.append(rel)
		else:
			changed.append(rel)
			var sheet := side_by_side(a, b, diff)
			var target := out_dir.path_join(rel.replace("/", "__"))
			sheet.save_png(target)
	for rel: String in before:
		if not after.has(rel):
			removed.append(rel)
	var lines: PackedStringArray = ["# Arayüz karşılaştırması", "", "- Önce: `%s`" % before_dir, "- Sonra: `%s`" % after_dir, "", "Değişen: %d · Aynı: %d · Yeni: %d · Kaybolan: %d" % [changed.size(), same.size(), added.size(), removed.size()], ""]
	for title_and_list: Array in [["## Değişen (yan yana görüntü bu klasörde)", changed], ["## Yeni", added], ["## Kaybolan", removed]]:
		var items: Array[String] = title_and_list[1]
		if items.is_empty():
			continue
		lines.append(str(title_and_list[0]))
		for rel: String in items:
			lines.append("- `%s`" % rel)
		lines.append("")
	var f := FileAccess.open(out_dir.path_join("report.md"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("[ui_compare] changed=%d same=%d added=%d removed=%d -> %s" % [changed.size(), same.size(), added.size(), removed.size(), out_dir])
	quit()

## Klasördeki PNG'ler (alt klasörler dahil), klasöre göre göreli yollarla.
static func _pngs(dir: String, prefix: String = "") -> Array[String]:
	var out: Array[String] = []
	var full := dir.path_join(prefix) if not prefix.is_empty() else dir
	for f: String in DirAccess.get_files_at(full):
		if f.ends_with(".png"):
			out.append(prefix.path_join(f) if not prefix.is_empty() else f)
	for d: String in DirAccess.get_directories_at(full):
		out.append_array(_pngs(dir, prefix.path_join(d) if not prefix.is_empty() else d))
	return out

## İki görüntünün farklı piksellerini kapsayan dikdörtgen (aynıysa boş). Boyut farklıysa ortak alanın
## dışı da fark sayılır.
static func diff_rect(a: Image, b: Image) -> Rect2i:
	var w := maxi(a.get_width(), b.get_width())
	var h := maxi(a.get_height(), b.get_height())
	var min_p := Vector2i(w, h)
	var max_p := Vector2i(-1, -1)
	for y in h:
		for x in w:
			var in_a := x < a.get_width() and y < a.get_height()
			var in_b := x < b.get_width() and y < b.get_height()
			if in_a and in_b and a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				continue
			min_p = Vector2i(mini(min_p.x, x), mini(min_p.y, y))
			max_p = Vector2i(maxi(max_p.x, x), maxi(max_p.y, y))
	if max_p.x < 0:
		return Rect2i()
	return Rect2i(min_p, max_p - min_p + Vector2i.ONE)

## Solda önce, sağda sonra; farklı bölge iki tarafta da kırmızı çerçeveyle işaretlenir.
static func side_by_side(a: Image, b: Image, diff: Rect2i) -> Image:
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var w := a.get_width() + GAP + b.get_width()
	var h := maxi(a.get_height(), b.get_height())
	var sheet := Image.create(w, h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.3, 0.3, 0.32, 1.0))
	sheet.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	sheet.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width() + GAP, 0))
	if diff.size != Vector2i.ZERO:
		_frame(sheet, diff.grow(3))
		_frame(sheet, Rect2i(diff.position + Vector2i(a.get_width() + GAP, 0), diff.size).grow(3))
	return sheet

static func _frame(img: Image, r: Rect2i) -> void:
	var bounds := Rect2i(Vector2i.ZERO, img.get_size())
	var rr := bounds.intersection(r)
	if rr.size.x <= 0 or rr.size.y <= 0:
		return
	for t in 2:
		img.fill_rect(Rect2i(rr.position.x, rr.position.y + t, rr.size.x, 1), MARK)
		img.fill_rect(Rect2i(rr.position.x, rr.end.y - 1 - t, rr.size.x, 1), MARK)
		img.fill_rect(Rect2i(rr.position.x + t, rr.position.y, 1, rr.size.y), MARK)
		img.fill_rect(Rect2i(rr.end.x - 1 - t, rr.position.y, 1, rr.size.y), MARK)
