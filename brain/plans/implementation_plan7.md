# Implementation Plan: UI Layout Telemetri Motoru Red-Team Düzeltmeleri ve Entegrasyon Güçlendirmesi

ChatGPT tarafından yapılan red-team incelemesi sonucunda tespit edilen 8 mimari ve teknik açığı gidermek, aracın gerçek Godot editörü ve Sidebar UI'ı üzerinde kanıtlanabilir çalışmasını sağlamak için yapılacak mühendislik planıdır.

---

## 1. Tespit Edilen Açıklar ve Çözüm Yaklaşımı

1. **Hedef Ayrımı (Edited Scene vs. Sidebar Dock)**:
   - `EditorInterface.get_edited_scene_root()` yalnızca kullanıcının açık oyun sahnesini verir; `plugin.gd` tarafından dock'a eklenen Sidebar'ı vermez.
   - **Çözüm:** `_resolve_target_node()` iki açık semantic kökü destekleyecek:
     - `"@sidebar"` veya `"GodotAISidebar"`: Aktif Sidebar dock instance'ına (`chat_dock`) odaklanır.
     - `"@edited_scene"` veya `""` (boş): Açık oyun sahnesi köküne odaklanır (`EditorInterface.get_edited_scene_root()` veya `SceneTree.current_scene`).
     - Sub-path desteği: `"@sidebar/HistoryPanel"` veya `"@edited_scene/HUD/HealthBar"`.
   - `AISidebarUITelemetryTools.register_sidebar_dock(dock)` ve `get_sidebar_dock()` static metotları eklenerek `plugin.gd` ve `chat_dock.gd` üzerinden referans bağlanacak.

2. **`include_theme_details` Sözleşmesi**:
   - Parametre şemada olmasına rağmen fiilen theme detayları çıkarılmıyordu.
   - **Çözüm:** `include_theme_details == true` olduğunda token verimliliğini koruyan kompakt tema bilgisi çıkarılacak:
     - `font_size` (tanımlıysa int)
     - `font_color` (hex string)
     - `theme_stylebox` (`StyleBoxFlat` ise: `bg_color`, `border_width` {left, top, right, bottom}, `corner_radius` {tl, tr, bl, br}, `shadow_size`).

3. **Gerçek LLM Çağrısı Sözleşmesi ve Testler**:
   - Test 10'da kullanılan `target_node` bir internal değişkendir ve LLM JSON çağrısında var olamaz.
   - **Çözüm:** Testler doğrudan kamuya açık JSON argümanları (`{"root_path": "@sidebar"}`, `{"root_path": "@edited_scene"}`, `{"root_path": "..."}`) ile `AISidebarToolManager.execute_tool("inspect_ui_layout", ...)` çalıştırılarak uçtan uca doğrulanacak.

4. **`UI_CONTAINER_OVERFLOW` Kuralının Geliştirilmesi**:
   - Yalnızca tek çocuk boyutuna bakmak yerine `HBoxContainer` ve `VBoxContainer` için tüm çocukların toplam (aggregate) minimum boyutu hesaplanacak.
   - Somut kanıtlar (`allocated_size`, `aggregate_child_min_size`, `overflow_amount`) raporda sunulacak.

5. **`UI_NON_CONTAINER_CHILD_MISMATCH` Uyarısının Nötrleştirilmesi**:
   - "Button içine Container koymak hatadır" mutlak ifadesi yerine Radical Truth'a uygun olarak:
     - *"Button bir Container değildir; içerisindeki '%s' çocuğunun yerleşimi ve boyutu ebeveyn tarafından otomatik yönetilmeyecektir."* şeklinde uyarı/bilgilendirme üretilecek.

6. **Görünürlük (Visibility) Modelinin Düzeltilmesi**:
   - Çocuk filtreleme doğrudan `child.visible` yerine, düğüm ağaçtaysa `child.is_visible_in_tree()` kontrolüne bağlanacak. Hem `visible` hem de `visible_in_tree` ayrı alanlar olarak raporlanacak.

7. **Progressive Tool Routing Düzeltmesi**:
   - `tool_manager.gd` içindeki `ui_keywords` listesinden çıplak `"inspect"` kelimesi çıkarılacak.
   - `"/inspect Player"` veya `"inspect Player script"` gibi komutların gereksiz yere UI telemetrisi ve ekran görüntüsü açması engellenecek; yalnızca `"inspect_ui"`, `"layout"`, `"ui"` gibi bağlamlı kelimelerde devreye girecek.

8. **Metrik ve Raporlama Hassasiyeti**:
   - Test sonuçları "test paketi / assertion" ayrımıyla (örn: 54 suite / 295+ assertions) raporlanacak.

---

## 2. Değişiklik Yapılacak Dosyalar

### Core Tools & Eklenti
- **[MODIFY] [`ui_telemetry_tools.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd)**:
  - `_resolve_target_node()`: `@sidebar`, `@edited_scene`, EditorInterface doğrudan çağrısı ve subpath desteği.
  - `register_sidebar_dock()` & `get_sidebar_dock()`.
  - `include_theme_details` kompakt StyleBox, font ve renk çıkarımı.
  - `HBoxContainer` / `VBoxContainer` aggregate minimum boyut hesaplamalı `UI_CONTAINER_OVERFLOW`.
  - Nötr ve kanıta dayalı `UI_NON_CONTAINER_CHILD_MISMATCH`.
  - `is_visible_in_tree()` görünürlük filtresi.
- **[MODIFY] [`plugin.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/plugin.gd)**:
  - `chat_dock` oluşturulduğunda `AISidebarUITelemetryTools.register_sidebar_dock(chat_dock)`.
  - Çıkışta `register_sidebar_dock(null)`.
- **[MODIFY] [`chat_dock.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/docks/chat_dock.gd)**:
  - `_ready()` anında `register_sidebar_dock(self)`.
- **[MODIFY] [`tool_manager.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/tool_manager.gd)**:
  - `ui_keywords` listesinden bare `"inspect"` kelimesini kaldırma, bağlamlı kelimeler ekleme.

### Test Paketi
- **[MODIFY] [`test_ui_telemetry.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/tests/test_ui_telemetry.gd)**:
  - `@sidebar` ve `@edited_scene` çözünürlük testleri (yalnızca JSON `root_path`).
  - `include_theme_details` sözleşme doğrulaması.
  - HBoxContainer aggregate overflow doğrulaması.
  - Gizli ata düğüm altında `is_visible_in_tree()` filtreleme doğrulaması.
  - `execute_tool` uçtan uca JSON testi (`{"root_path": "@sidebar"}`).

---

## 3. Doğrulama Planı

### Otomasyon Testleri
- Komut:
  ```powershell
  godot --headless --path . -s "res://tests/test_runner.gd"
  ```
- Kriter: 54 test paketinin tamamı ve tüm iddialar 0 hata ile geçmelidir.
