extends SceneTree

## Bir oyunun arayüz durumlarını senaryoyla PNG'ye çeker. Senaryo oyunun projesindedir (oyuna özel sınıfları
## o bilir); bekleme, kaydetme, düğüm sökme, duraklatmadan çıkma, zaman aşımı ve başlıklar bu koşucudadır.
## Yeni bir ekranı çekmek için yalnız senaryoya birkaç satır eklenir, koşucu yazılmaz.
##
##   godot --path <proje> --resolution 640x400 -s <Sidebar>/tools/ui_states.gd -- <senaryo res yolu> <çıktı klasörü> [zaman aşımı sn=180]
##
## Senaryo dosyası (örn. res://tools/capture/ui_states.gd):
##   extends RefCounted
##   func run(shot) -> void:
##       var menu := MainMenu.new()
##       shot.add(menu)
##       await shot.wait(1.2)
##       shot.save("08", "8. Ana menü")
##       await shot.drop(menu)
##
## shot: root, add(düğüm), wait(sn), frames(n), save(ad, başlık), drop(düğüm). Beklemeler duraklatılmış oyunda
## da işler. Başlıklar <çıktı>/titles.json'a kayıt sırasıyla yazılır (tools/ui_before_after.ps1 tabloyu bu
## sırayla dizer). Pencere gerekir; headless çizmez. Çıkış: 0 tamam, 2 kullanım / senaryo hatası, 3 zaman aşımı.

var out_dir := ""
var _titles := {}
var _done := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Kullanım: -- <senaryo res yolu> <çıktı klasörü> [zaman aşımı sn]")
		quit(2)
		return
	out_dir = args[1]
	var limit := float(args[2]) if args.size() > 2 else 180.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	var script := load(args[0]) as Script
	if script == null:
		printerr("[ui_states] Senaryo yüklenemedi: ", args[0])
		quit(2)
		return
	var scenario: Object = script.new()
	if not scenario.has_method("run"):
		printerr("[ui_states] Senaryoda run(shot) yok: ", args[0])
		quit(2)
		return
	create_timer(limit, true, false, true).timeout.connect(_on_timeout)
	_run.call_deferred(scenario)

func _run(scenario: Object) -> void:
	await process_frame
	@warning_ignore("unsafe_method_access")
	await scenario.run(self)
	_finish(0)

func _on_timeout() -> void:
	printerr("[ui_states] Zaman aşımı; senaryo bir beklemede takıldı. Son kayıt: ", _titles.keys().back() if not _titles.is_empty() else "yok")
	_finish(3)

func _finish(code: int) -> void:
	if _done:
		return
	_done = true
	paused = false
	var f := FileAccess.open(out_dir.path_join("titles.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_titles, "  ", false))
	f.close()
	print("[ui_states] %d görüntü -> %s" % [_titles.size(), out_dir])
	quit(code)

## Düğümü köke ekler.
func add(node: Node) -> Node:
	root.add_child(node)
	return node

## Gerçek süre bekler; oyun duraklatılmış olsa da sayar.
func wait(sec: float) -> void:
	await create_timer(sec, true).timeout

func frames(n: int = 1) -> void:
	for _i in n:
		await process_frame

## O anki viewport'u <çıktı>/<ad>.png olarak yazar. Başlık boşsa ad kullanılır.
func save(name: String, title: String = "") -> void:
	var img := root.get_texture().get_image()
	var err := img.save_png(out_dir.path_join(name + ".png"))
	if err != OK:
		printerr("[ui_states] Yazılamadı: ", name, " err=", err)
		return
	_titles[name] = title if not title.is_empty() else name
	print("[ui_states] ", name)

## Düğümü söker, duraklatmayı kaldırır ve iki kare bekler (sonraki ekran temiz başlasın).
func drop(node: Node) -> void:
	paused = false
	if is_instance_valid(node):
		node.queue_free()
	await process_frame
	await process_frame
