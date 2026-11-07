# Godot AI Sidebar: UI/UX Dönüşümü ve Temiz Başlangıç Planı

Kullanıcının ilettiği ekran görüntüsü ([media_1790028275883.png](file:///C:/Users/Halil%20Emre/.gemini/antigravity/brain/df971fe3-c87f-44c4-bbd5-efca3097d7ab/.user_uploaded/media_1790028275883.png)) ve talepleri doğrultusunda, dar kenar çubuğundaki (dock) görsel sıkışıklığı gideren, Cursor / Antigravity IDE seviyesinde modern bir ayarlar arayüzü sunan ve her açılışta temiz bir oturum başlatan kapsamlı UI revizyon planıdır.

---

## 1. Tespit Edilen Problemler ve Çözüm Mimarisi

### 1.1. Açılışta Eski Sohbetin Yüklenmesi
- **Mevcut Durum:** `chat_dock.gd` açılır açılmaz en son oturumu (`sessions[0]["id"]`) otomatik yüklüyor.
- **Hedef:** Godot açıldığında veya yeniden yüklendiğinde daima **temiz ve boş bir yeni sohbet** (`_start_new_chat_session()`) başlatılacak. Eski sohbetler geçmiş panelinde güvenle saklanacak.

### 1.2. Sohbet Geçmişinin (History) Ekranı "Karman Çorban" Etmesi
- **Mevcut Durum:** `history_panel` bileşeni, dikey layout içine (`$MainLayout`) mesaj alanının hemen üstüne 200px'lik sabit bir blok olarak ekleniyor. Bu durum dar bir kenar çubuğunda mesajları aşağı itip yarım yamalak gösteriyor ve iki farklı liste üst üste biniyormuş hissi veriyor.
- **Hedef (Full-View Switcher):** Geçmiş butonuna tıklandığında, sohbet mesaj kutusu ve girdi alanı geçici olarak gizlenecek; `history_panel` **tam boyutta (100% dock yüksekliği)** açılacak. Kullanıcı geçmiş sohbetleri arayıp seçtiğinde veya "✕" bastığında temiz şekilde aktif sohbete dönecek.

### 1.3. Üst Bar Sıkışıklığı ve Dil Seçimi
- **Mevcut Durum:** Üst başlık çubuğunda (`HeaderBar`) aynı anda `Godot AI Core`, `● Hazır [FULL_AUTO]`, `+ New`, `📚`, indirme ikonu ve `TR` butonu yer alıyor. 250-300px genişlikte bu butonlar taşma ve kesilmeye yol açıyor.
- **Hedef:** `TR / EN` butonu üst bardan kaldırılacak ve Ayarlar penceresi içine şık bir seçim olarak taşınacak.

### 1.4. Ayarlar Penceresi (Settings Dialog) Modernizasyonu (Cursor / Antigravity Style)
- **Mevcut Durum:** Standart gri `AcceptDialog` içinde tüm ayarlar alt alta yığılmış vaziyette.
- **Hedef:** Modern IDE'lerdeki (Cursor, Antigravity, VS Code) koyu kart (`Dark Card`) ve sekmeli (`TabContainer`) tasarıma geçilecek:
  - 🔌 **Sağlayıcı (Provider):** Antigravity CLI vs OpenAI Uyumlu, Base URL, Key, canlı durum rozeti.
  - ⚡ **Model & Parametreler:** Seçili model, 0.20 İdeal Sıcaklık (Tekerlek korumalı, tek tıkla ideale sıfırlama butonu), Maksimum Adım Sınırı.
  - 🎨 **Görünüm & Dil:** Arayüz dili (`Türkçe` / `English`), Onay Modu (`Manuel` / `Auto` / `Full Auto`).
  - 📝 **Sistem Promptu:** Cerrahi düzenleme promptu ve "Varsayılana Sıfırla" butonu.

---

## User Review Required

> [!NOTE]
> - Godot her açıldığında temiz bir sohbet açılacaktır; ancak eski tüm konuşmalarınız diske kaydedilmeye devam eder ve **📚 Geçmiş** butonundan tek tıkla geri yüklenebilir.
> - `TR / EN` butonu üst bardan kalkacağı için üst bar ferahlayacak; dil değişimi **⚙️ Ayarlar** penceresinden yapılacaktır.

---

## Proposed Changes

### Component 1: `chat_dock.gd` & `chat_dock.tscn`

#### [MODIFY] [chat_dock.tscn](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/docks/chat_dock.tscn)
- `HeaderBar` içinden `LangToggleBtn` kaldırılacak.

#### [MODIFY] [chat_dock.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/docks/chat_dock.gd)
- `_ready()` içinde `_start_new_chat_session()` varsayılan yapılacak (açılışta temiz sayfa).
- `_on_history_btn_pressed()`, `_on_history_close_requested()`, `_on_history_session_selected()`, `_on_new_chat_pressed()` metotlarında görünüm geçişi (View Switcher) uygulanacak: Geçmiş açıkken `ChatScroll` ve `InputArea` gizlenecek; geçmiş kapandığında tekrar gösterilecek.

---

### Component 2: `history_panel.gd`

#### [MODIFY] [history_panel.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/components/history_panel.gd)
- Sabit `custom_minimum_size = Vector2(0, 200)` kaldırılacak, `size_flags_vertical = SIZE_EXPAND_FILL` yapılacak.
- Kart görünümleri, arama çubuğu ve butonlar modern dark tema (`#181920`, ince kenarlık `#282c37`) ile iyileştirilecek.

---

### Component 3: `settings_dialog.gd` & `settings_dialog.tscn`

#### [MODIFY] [settings_dialog.tscn](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/dialogs/settings_dialog.tscn) & [settings_dialog.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/dialogs/settings_dialog.gd)
- Pencere modern `TabContainer` yapısına kavuşturulacak.
- Dil açılır kutusu (`Language OptionButton`) eklenecek.
- Kart panelleri (`StyleBoxFlat` koyu arka plan, yuvarlatılmış köşeler, ferah marginler) ile giydirilecek.
- Fare tekerleği koruması ve ideal 0.20 rozeti entegre korunacak.

---

### Component 4: `i18n.gd`

#### [MODIFY] [i18n.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/i18n/i18n.gd)
- Yeni ayarlar sekmeleri (`tab_provider`, `tab_parameters`, `tab_appearance`, `tab_prompt`) ve etiketler eklenecek.

---

## Verification Plan

### Automated Tests
- Test koşucusu ile tüm 275 birim testinin çalıştığının doğrulanması:
  ```powershell
  godot --headless --path . -s "res://tests/test_runner.gd"
  ```

### Manual Verification
- Godot projesini yeniden yükleyip temiz sohbet açıldığını gözlemlemek.
- 📚 Geçmiş butonuna basıldığında sohbet alanının yerini ferah tam sayfa geçmiş listesinin aldığını ve bir sohbete tıklandığında geri döndüğünü doğrulamak.
- ⚙️ Ayarlar açıldığında sekmeli modern Cursor/Antigravity dark temasının çalıştığını ve dil değiştirildiğinde arayüzün anında güncellendiğini doğrulamak.
