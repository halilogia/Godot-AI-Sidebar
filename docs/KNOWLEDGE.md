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
