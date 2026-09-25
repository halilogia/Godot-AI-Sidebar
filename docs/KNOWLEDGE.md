# 🧠 Project Knowledge Base (Godot AI Core)

Bu dosya, Godot 4.7 motor özellikleri, GDScript 2.0 kuralları, 9Router/LLM protokolleri, eklenti mimarisi ve geliştirme esnasında öğrenilen kritik teknik bilgileri içerir.

---

## ⚙️ Godot 4.7 & Motor Özellikleri

1. **EditorInterface Singleton:**
   * Godot 4.3 ve sonrasında `EditorInterface` global bir singleton'dır. `EditorPlugin.get_editor_interface()` yerine doğrudan `EditorInterface.get_edited_scene_root()` veya `EditorInterface.get_selection()` çağrılabilir.
2. **EditorUndoRedoManager:**
   * Editör içindeki Undo/Redo geçmişi `EditorInterface.get_editor_undo_redo()` ile alınır (Standart `UndoRedo` değil, `EditorUndoRedoManager` kullanılır).
   * Düğüm ekleme eylemlerinde `add_do_reference(new_node)` kullanılmalıdır; aksi halde geri alma (undo) esnasında bellekten sızma veya çökme yaşanabilir.
3. **ClassDB:**
   * Bir düğüm sınıfının geçerliliği `ClassDB.class_exists(class_name)` ile kontrol edilir.
   * Örnekleme `ClassDB.instantiate(class_name)` ile yapılır.

---

## 🌐 9Router & SSE Ağ Protokolü Bilgi Tabanı

1. **9Router SSE Akış Yapısı:**
   * Gerçek 9Router + Gemini 3.7 Flash akışında 3 ana chunk gelir:
     1. `{"delta": {"role": "assistant"}}`
     2. `{"delta": {"content": "..."}}`
     3. `{"delta": {}, "finish_reason": "stop"}, "usage": {...}`
   * 9Router her zaman metinsel `data: [DONE]` satırı göndermez; `finish_reason: "stop"` chunk'ının ardından doğrudan TCP FIN ile soketi kapatır.
2. **Windows TCP Soket Kapanışı (`Status: 8` / `ResponseAborted`):**
   * Godot `HTTPClient`, sunucu soketi kapattığında `STATUS_CONNECTION_ERROR (8)` üretir.
   * Bu durum fatal hata değildir: Tamponda geçerli içerik veya `finish_reason` varsa `NetworkManager` tarafından başarıyla kurtarılmalı (`_finalize_success`) ve kullanıcıya eksiksiz teslim edilmelidir.
   * 9Router sunucu tarafında bu doğal soket kapanışını `DISCONNECT: ResponseAborted` olarak loglar; bu bir veri kaybı veya istemci hatası değildir (9Router Issue #3488).
3. **Windows Localhost DNS Çözümleme Gecikmesi:**
   * Windows üzerinde `http://localhost:20128` çağrıları IPv6 (`::1`) öncelikli DNS denemesi yüzünden 30 saniye gecikebilir.
   * Bu sebeple URL'ler `http://127.0.0.1:20128` formatına normalize edilmeli ve `Connection: close` başlığı eklenmelidir.

---

## 🗜️ Context Window Compaction & Token Ekonomisi

1. **Tarihsel Araç Sıkıştırması:**
   * `AISidebarContextCompactor`, çok adımlı ajan görevlerinde 2 adımdan eski araç çıktılarını (ör. 50 dosyalık dizin listesi, sahne ağacı dökümü) 1-2 satırlık yapılandırılmış özetlere dönüştürür.
   * Aktif son 2 aracın (`keep_recent_tools: 2`) tam JSON çıktısı korunur; böylece modelin o an üzerinde çalıştığı kod ve dosya verisi asla kaybolmaz.
2. **Cerrahi Kod Düzenleme (`replace_file_content`):**
   * 400 satırlık scriptlerde tüm dosyayı baştan yazmak yerine sadece hedef satır aralığını değiştiren cerrahi araç kullanılır; bu da token tüketimini ve hata payını minimize eder.

---

## 🛡️ Güvenlik ve Yol Kuralları (Path Policy)

* **Normalizasyon:** Tüm yollar `res://` veya `user://` önekine normalize edilir. Backslash'lar (`\`) forward slash'a (`/`) çevrilir.
* **Traversal Koruması:** `../` dizin atlama parçaları array stack yöntemiyle temizlenir.
* **Korumalı Yollar:**
  * `res://project.godot` (Motor ayarları)
  * `res://export_presets.cfg` (Dışa aktarım ayarları)
  * `res://.git/**` (Git sürüm kontrol dosyaları)
  * `res://addons/godot_sidebar_ai/**` (Eklentinin kendi kaynak kodları)
  * Yapay zekanın bu dosyaları ezmesi veya silmesi `AISidebarPathPolicy` tarafından engellenir.

---

## 🧪 Headless CLI Test Çalıştırma Kuralı

* Godot editörü kapalıyken `godot --headless -s test_runner.gd` çalıştırıldığında, editörün global `class_name` dizini bellekte olmayabilir.
* Bu sebeple bağımsız çalışan scriptler ve test sınıfları birbirini **`const MyClass = preload("res://path/to/script.gd")`** şeklinde bağlamalıdır.
* Bu yaklaşım hem CLI ortamında hem de editör ortamında %100 deterministik ve hatasız çalışmayı garanti eder.

---

## GDScript Derleme ve Önbellek Davranışı (4.7.2, 26.09)

* `GDScript.reload()` hem parser hatasında hem de eksik `preload` / `extends "yol"` çözümlemesinde `ERR_PARSE_ERROR` (43) döner; dönüş koduyla ikisi ayırt edilemez. Parser hatası (ör. `Expected parameter name`) varsa preload çözümlemesine hiç geçilmez.
* `preload` ve `extends "res://…"` betiği `GDScriptCache` üzerinden **diskten** okur. Bellek içi bir `GDScript`'i `take_over_path()` ile o yola kaydetmek yetmez ("Could not find script"). Henüz yazılmamış bir dosyaya bağımlı betiği gerçekten derlemek için bağımlılık diske (proje dışı `user://` aynası) yazılmalıdır (`VerificationPipeline` batch aynası).
* **GDScript uyarıları headless'ta (Refactor Faz 4.A.2 araştırması):**
  * Ayar adları `debug/gdscript/warnings/<ad>` (0 = kapalı, 1 = uyarı, 2 = hata). 4.x'teki `exclude_addons` 4.7'de yoktur; yerine `debug/gdscript/warnings/directory_rules` sözlüğü gelir, varsayılan `{ "res://addons": 0 }` (addons hariç). Karar değeri 0 = hariç, 1 = dahil; 2 geçersizdir (`decision >= DECISION_MAX` hatası).
  * Seviye 1'de (uyarı) headless `reload()` **hiçbir şey basmaz** ve OK döner; uyarılar yalnızca editörün betik panelinde görünür.
  * Seviye 2'de uyarılar `SCRIPT ERROR: Parse Error: … (Warning treated as error.)` olarak satır numarasıyla basılır ve `reload()` `ERR_PARSE_ERROR` döner. Bir dosyadaki tüm uyarılar raporlanır (ilk hatada durmaz).
  * `ProjectSettings.set_setting` ile değiştirilen uyarı seviyeleri parser'a **bir kare sonra** yansır (`update_project_settings`); `_init` içinde aynı karede derlenen betik eski ayarı görür. `_initialize` + `await process_frame` gerekir.
  * Ölçüm yöntemi (`tools/warning_report.gd`): alt süreçte önce tüm betikler varsayılan ayarla yüklenir, sonra her tür tek başına seviye 2'ye çekilip betikler yerinde `reload(true)` edilir; bağımlılıklar önbellekten geldiği için hata zincirlenmez (sonuç derleme sırasından bağımsız ve deterministik, doğrulandı). Çalışan betik kendini `reload()` edemez.
  * LSP (`--lsp-port`, `publishDiagnostics`) yolu denenmedi; yukarıdaki yöntem yeterli olduğu için gerek kalmadı.
* Aynı betik içindeki `Callable(Script, "static_func")` ve iki betik arasında döngüsel `preload` (`verification_pipeline.gd` ↔ `tscn_validator.gd`) headless'ta sorunsuz çalışır.

## Yerelleştirme (i18n) — Godot 4.7.2 çeviri alanları (26.09)

* Eklentinin metinleri `AISidebarI18n` + `addons/godot_sidebar_ai/i18n/<dil>.json` üzerinden gelir (i18next düz JSON; `_one` / `_other`; seçili dil → EN → anahtar).
* Godot 4.7'de `TranslationDomain` vardır: `TranslationServer.get_or_add_domain("ad")` ile ana alandan yalıtılmış bir alan açılır (oyun projesinin çevirileriyle karışmaz; probe ile doğrulandı), `set_locale_override("en")` alanın dilini editör / işletim sistemi dilinden (`TranslationServer.get_locale()`, ör. `tr_TR`) bağımsız yapar, `translate_plural` mevcuttur. Gerekirse `AISidebarI18n.translate` tek giriş noktası olduğu için geçiş oradan yapılır.
* Headless testlerde dil config'ten okunur (`config.json` git-ignored); dil bağımsız test için beklenen metin `AISidebarI18n.get_text` / `translate` ile üretilir, sabit İngilizce metin yazılmaz.

## İkon Sistemi (Lucide) ve Emoji Yasağı

* UI'da emoji kullanılmaz; ikonlar `addons/godot_sidebar_ai/assets/icons/` altındaki Lucide SVG'leridir (ISC, `LICENSE` aynı klasörde). Yeni ikon: `lucide-static` paketinden aynı adla kopyalanır.
* `AISidebarIconHelper.get_tinted_icon(name, color, size)` SVG'yi okuyup stroke/fill renklerini (ve `currentColor`'ı) verilen renge boyar, `Image.load_svg_from_string` ile render eder ve önbelleğe alır. Import sistemine bağlı değildir (headless testlerde de çalışır).
* Durum glifleri (`✓ ✕ ▶ ! ☐ – •`) veri modelinde (activity, checklist, transcript, export) aynen kalır. Görünümde `AISidebarStatusIcon` bunları ikona çevirir; tanınmayan glif metin olarak görünür.
* `tests/test_icon_system.gd` T5, `ui/` ve `core/commands/` kaynaklarında emoji bulursa kırmızıya döner. Eski veri için girdi takma adları (❌, ✅, ⚠️) kaynakta `\u` kaçış dizisiyle yazılır.
* Kapsam dışı (bilinçli): `ChatExporter` Markdown çıktısı ve LLM'e giden prompt/araç metinleri. Kullanıcı arayüzü değil, belge/model girdisidirler.

---

## HTTPClient Döngü Tuzakları (canlı test, 25.09)

* `HTTPClient.get_status()` ile elle yazılan döngülerde **her** terminal durum ele alınmalı: `STATUS_CANT_RESOLVE`, `STATUS_CANT_CONNECT`, `STATUS_TLS_HANDSHAKE_ERROR`, `STATUS_CONNECTION_ERROR`, `STATUS_DISCONNECTED`. `CANT_CONNECT` (4) varsayılan dala düşerse sunucu kapalıyken döngü sonsuza kadar bekler.
* İstek gönderildikten sonra durum `STATUS_CONNECTED`'a dönerse yanıt bitmiştir (keep-alive); bu da döngüden çıkış koşuludur.
* Her döngüye zaman aşımı konur; ağ testleri başarıyı ancak HTTP 200 + boş olmayan içerikle kanıtlar ve açık bir başarı satırı yazar (`LIVE TEST PASSED`). `verify.ps1 -Live` hem çıkış kodunu hem bu satırı arar.
* Canlı test 9Router olmadan doğrulanabilir: `127.0.0.1:20128` üzerinde küçük bir sahte sunucu (chunked SSE + JSON, ayrıca HTTP 500) ile başarı ve başarısızlık yolları denenir.

