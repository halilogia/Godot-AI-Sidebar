# 📝 Changelog

Tüm önemli değişiklikler bu dosyada kronolojik olarak listelenmektedir.

Biçim: [Keep a Changelog](https://keepachangelog.com/tr/1.0.0/), 
Sürümleme: [Semantic Versioning](https://semver.org/lang/tr/).

---

## [Unreleased]

### Düzeltilenler
* **Oyunu ikinci kez çalıştırınca runtime araçlarının çalışmayı bırakması:** İlk durdurmadan sonra çalışan oyunun ekran görüntüsü ve canlı sahne ağacı okunamıyordu ("debugger bağlı değil"); editör aynı hata ayıklama oturumunu yeniden kullanıyor, eklenti ise onu ilk durdurmada unutuyordu.
* **`class_name` içeren geçerli script'lerin doğrulamada "hata 43" alması:** Script kontrolü, kendi dosyasına kayıtlı sınıf adını "global sınıfı gölgeliyor" diye reddediyordu; oyun bu script'lerle sorunsuz çalışsa da hem sidebar ajanının dosya yazımı hem `validate_script` bunları hatalı sayıyordu.
* **Çalışan oyunun log'unun (print'ler ve başlangıç hataları) görülmemesi:** Oyun her açılışta yeni bir log dosyası başlatıyor; eklenti eski dosyanın uzunluğundan okumaya devam ettiği için yeni dosyanın başını kaçırıyordu. Başlangıçtaki hatalar da gözden kaçabiliyordu.

### Eklenenler
* **Skill'ler (v3.1, Agent Skills standardı):** Başlıktaki **Skills** düğmesiyle skill'leri görebilir, açıp kapatabilir, yenisini oluşturabilir, başka bir yerden klasör içe aktarabilir ve silebilirsiniz. Ajan açık skill'lerin adını ve açıklamasını görür, görev uyduğunda ilgili skill'in talimatlarını kendisi yükler; `/skill ad istek` ile siz de başlatabilirsiniz. Eklentiyle beş yerleşik Godot skill'i gelir (özellik geliştirme, sahne yazımı, hata ayıklama ve onarım, runtime doğrulama, refactor). Skill'ler standart `SKILL.md` klasörleridir: `~/.agents/skills` (kullanıcı) ve projede `.agents/skills` / `.claude/skills` taranır; aynı skill'ler Claude Code, Cursor, Codex gibi araçlarda da çalışır. Proje skill'leri depodan geldiği için siz açana kadar kapalıdır.
* **Proje kuralları (`AGENTS.md`):** Oyun projesinin kökünde `AGENTS.md` varsa ajan her görevde onu okur ve kurallarına uyar. Aynı dosyayı Codex, Cursor, Copilot gibi araçlar kendileri okur; köprüye bağlanan ajana da okuması söylenir.
* **Dış ajan köprüsü (MCP, v3.0 ilk sürüm):** Claude Code gibi ajanlar artık açık Godot editörünü kullanabilir. Sidebar'da `/mcp on` yazın; Claude Code bağlantı komutu panoya kopyalanır, oyun projenizin klasöründe terminale yapıştırın. Ajan sahne ağacını ve düğümleri okuyabilir, scriptleri doğrulayabilir, dosya yazdıktan sonra editöre taratabilir (`sync_project`), oyunu başlatıp durdurabilir, runtime hatalarını ve canlı ağacı görebilir, ekran görüntüsü alabilir. Köprü yalnız bu bilgisayardan erişilebilir (127.0.0.1 + gizli token) ve eklentinin güvenlik politikalarından geçer; sahne / dosya değiştiren araçlar bu sürümde dışarı açık değildir. Kapatmak için `/mcp off`.
* **Dış ajan sahne değişiklikleri (v3.0.1):** Köprü açıkken dış ajan açık sahneye düğüm ekleyebilir, özellik değiştirebilir, sahne örnekleyebilir, script bağlayabilir ve sahneyi kaydedebilir; her değişiklik Ctrl+Z ile geri alınır. Ajan her değişiklikte hangi sahneyi değiştirdiğini belirtmek zorundadır; editörde başka bir sahne açıksa değişiklik yapılmaz. (Kısa süre var olan ayrı `/mcp write off | ask | auto` modu ve onay kartı kaldırıldı: izin `/mcp on` ile verilir, onay dış ajanın kendi izin sisteminde kalır.)
* **Dış ajana dosya-öncelikli çalışma kuralı:** Köprü, bağlanan ajana sahneleri ve scriptleri dosya olarak yazmasını, tek tek düğüm araçlarını yalnız açık sahnedeki küçük düzenlemeler için kullanmasını söyler. `sync_project`, ajanın yazdığı ve editörde açık olan sahneyi diskten yeniden yükler; böylece sonraki kayıt ajanın dosyasını eski kopyayla ezmez.
* **Grand strateji benchmark'ı (v3.2 altyapı):** `benchmarks/grand-strategy-slice/` tek istemlik bir grand strateji dikey kesiti, kanıt türüyle kabul kriterleri ve boş benchmark projesi kuran bir script içerir. (Kısa süre `integrations/claude-code/skills/` altında duran Claude Code'a özgü skill paketi kaldırıldı; skill'ler eklentinin kendi özelliği olarak tasarlanacak.)
* **Tek aktif yazıcı:** Sidebar ajanı ile dış ajan aynı anda sahne / dosya değiştiremez; sonra gelen taraf "başka bir ajan yazıyor" hatası alır. Okuma, oyunu çalıştırma ve ekran görüntüsü etkilenmez.

---

## [2.8.0] - 2026-09-26 (Refactor Faz 1–5: ChatDock / AgentRunner bölünmesi, test ve tip denetimi altyapısı, i18n, düzeltmeler)

### Yeniden yapılanma (davranış değişmeden)
* `ui/docks/chat_dock.gd` 2349 satırdan ~600 satıra indi; sorumluluklar ayrı birimlere taşındı: `ChatDockTheme`, `ToolPresentation`, `PlanChecklistTracker`, `MessageQueuePanel`, `InputComposer`, `ChatExportActions`, `ChatSessionStore`, `SessionReplayRenderer`, `AgentStreamPresenter`, `AgentActivityPresenter`, `AgentInteractionPresenter`, `ModelBarController`, `TaskController`. Plan ve kararlar: `docs/REFACTOR_PLAN.md`.
* Daha önce testsiz olan alanlar teste bağlandı: AgentRunner ↔ dock sinyal bağlantıları, gönder / kuyruk / durdur / devam et hattı, model çubuğu.
* Provider ve `NetworkManager` artık arayüz tarafından değil, `plugin.gd`'nin kurduğu `AgentHost` (`core/agent/agent_host.gd`) tarafından oluşturuluyor; ChatDock bu birimi enjekte olarak alıyor. Provider seçimi, ayar kaydında provider değişimi, AGY hazırlık rozeti ve Refresh ilk kez test altında.
* AgentRunner'ın telemetri sayaçları, süre dağılımı ve task sonu metrikleri `AgentTelemetry` (`core/agent/agent_telemetry.gd`) birimine taşındı; bekleme / LLM süresi muhasebesi ve metrik sözlüğünün tamamı ilk kez test altında.
* Bekleyen kullanıcı kararları (tool onayı, netleştirme sorusu, plan) `PendingInteraction` (`core/agent/pending_interaction.gd`) birimine taşındı; karar fonksiyonlarının koruma koşulları ve temizlik kuralları test altında.
* Model yanıtını işleyen 201 satırlık `_on_provider_response` adımlara bölündü (boş yanıt, tool dağıtımı, çağrı başına korumalar, icra, tamamlama kapısı); her dal önce 13 senaryoluk birebir iz testiyle sabitlendi.
* Aynı süreçte iki bağımsız `AgentRunner` / `AgentHost` testi: context, telemetri, bekleyen kararlar, tekrar koruması, açılan araçlar ve Stop birbirine karışmıyor (alt ajanlar ve CLI / MCP köprüsü için önkoşul).
* Arayüz metinleri koddan `addons/godot_sidebar_ai/i18n/tr.json` ve `en.json` dosyalarına taşındı (i18next biçimi, `_one` / `_other` çoğul ekleri, seçili dil → İngilizce → anahtar yedek zinciri); yeni `ui/` kodunda sabit görünür metin testle engelleniyor.
* TSCN/TRES yapısal doğrulayıcısı `VerificationPipeline`'dan ayrı bir birime (`core/verification/tscn_validator.gd`) taşındı; her hata kodu ve sonuç metni önce sabitleme testiyle kilitlendi. `chat_exporter.gd`, `editor_tools.gd` ve `scene_tools.gd` değerlendirildi ve gerekçesiyle bölünmedi.

### Düzeltilenler
* `/clear` sohbeti gerçekten temizliyor (Clear butonuyla aynı yol).
* Stop sonrası "Paused" rozeti artık hemen "Hazır" ile ezilmiyor.
* Sahte "Düşünülüyor" balonu kaldırıldı; thinking kartı cevabın üstünde kalıyor.
* Mesajdaki `[b]`, `[url=…]` gibi metinler BBCode olarak yorumlanıp silinmiyor.
* Runtime kartı modele giden uzun teşhis metni yerine kısa hata satırı gösteriyor.
* Normal kod blokları Output'a "Parse JSON failed" hatası bastırmıyor.
* Hata kartındaki Retry, görevi normal hattan yeniden başlatıyor: slash komutlarında modele doğru istem gidiyor, yeni transcript görevi açılıyor, görsel eki korunuyor.
* `/help` gibi yerel komutlar sohbet kaydında kalıyor ve History'den yüklenince görünüyor; modele gönderilmiyor.
* Uzun model düşünceleri (thinking) kesilmiyor: kart 3000 yerine 20.000 karaktere kadar gösteriyor, transcript / export 1000 yerine 16.000 karaktere kadar saklıyor.
* Kod blokları komşu satırları örtmüyor; kalın / kod metni gövdeyle aynı boyutta.
* Onay modu ekranda iki kez yazmıyor: durum rozeti yalnızca "Hazır" gösteriyor, mod model çubuğundaki butonda.
* Ajan çalışırken ayarlar kaydedilirse görev "Paused" olarak durduruluyor ("devam et" ile yeni provider'da sürüyor); eski isteğin cevabı yeni provider'a karışmıyor, AGY'ye geçişte ajan asılı kalmıyor.
* `/analyze`, `/fix` gibi ajanı başlatan slash komutları ekli görseli artık modele gönderiyor (ajan meşgulse kuyruğa görselle alınıyor); `/help` gibi yerel komutlar eki silmiyor.
* Eski sürümlerde `/clear` kullanılmış oturumlar History'den yüklenince `/clear`'ın yerel yanıtı artık modele gönderilmiyor.
* Kuyrukta birden fazla mesaj varken görev hatayla bitince (veya hatadan hemen sonra Retry'a basılınca) kuyruktaki bir mesaj kaybolmuyor ve çalışan görevin kaydı "iptal" görünmüyor.
* Ajanı durdurmak (Stop) artık kullanıcının F5 ile açtığı oyunu kapatmıyor; yalnızca ajanın kendi başlattığı oyun durduruluyor.
* Telemetri kartı ve export'taki dosya süresi (`file_time`) artık cerrahi düzenleme (`replace_file_content`) ve dosya silme (`delete_file`) sürelerini de içeriyor.
* History replay'de yanıtlanmış `ask_user` kartı akışı durdurmuyor; uzun başlıklar header butonlarını taşırmıyor.
* `write_files` ile aynı pakette birbirini kullanan betikler yazılırken sözdizimi hatalı bir betik artık "doğrulandı" sayılıp diske yazılmıyor; paket içi bağımlılık gerçekten derlenerek kontrol ediliyor.
* Ekran görüntüsü araçları (`take_viewport_screenshot`, `take_editor_screenshot`, `take_runtime_screenshot`) artık korumalı dosyalara (`project.godot`, eklenti klasörü, `.git`) veya proje dışına kaydedemiyor.
* `create_scene` / `add_node` Node olmayan bir tipte (`Resource` gibi) sessizce boş sonuç döndürmek yerine anlaşılır bir `INVALID_CLASS` hatası veriyor.
* Tam `.tscn` içeriğiyle oluşturulan sahnede sonuç mesajı artık varsayılan "Root (Node2D)" değil, sahnenin gerçek kök düğümünü gösteriyor.
* Sohbet export'unda mesaj alanı boş (`null`) olan bir tool sonucu, Markdown'daki tool bölümünü yarıda kesmiyor.
* Türkçe arayüzde kalan İngilizce metinler çevrildi: onay / netleştirme / plan / hata kartları, değişiklik kartı, kuyruk paneli, telemetri başlığı, etkinlik grubu, görev listesi, History paneli, ayar ipuçları ve üst çubuk. İngilizce arayüz aynı kaldı; yalnızca daha önce İngilizce modda da Türkçe görünen karşılama kartı, ek görseli, ipuçları ve onay diyaloğu artık İngilizce. "Changes (1 files)" gibi tekil/çoğul hataları düzeldi. README görselleri güncellendi.
* Kuyruk panelindeki satır numarası ve iptal butonu tema renklerini kullanıyor.
* Dar dock'ta arayüz sağdan taşmıyor: uzun netleştirme seçenekleri ve hızlı başlangıç önerileri satır kaydırıyor (seçenekler artık alt alta, tam genişlikte), görev listesi ve telemetri başlıkları "…" ile kısalıyor ve tam metin ipucunda görünüyor.
* Ayarlardan dil değiştirilince karşılama kartı da yeni dile geçiyor; hızlı başlangıç önerileri artık çevriliyor (İngilizce arayüzde Türkçe kalıyordu).

### Eklenenler
* Asistan cevaplarında ve plan kartında Markdown (başlık, kalın, italik, kod, liste, alıntı).
* Model yanıtı beklenirken akışta canlı bekleme göstergesi (aşama + süre, uzun bekleyişte iptal ipucu).
* Emoji yerine tek renkli Lucide ikonları (`AISidebarStatusIcon`, boyanabilir SVG'ler).
* Onay modu butonu ikonlu renkli hap: Manuel (el, sarı), Auto (kalkan, yeşil), Full Auto (şimşek, mor); ipucu modu açıklıyor (TR/EN).
* README için gerçek arayüz bileşenlerinden ekran görüntüsü üreten `tools/readme_shots.gd`.

---

## [2.7.0] - 2026-09-22 (AI UI Telemetry, Headless Static Typecheck & Centralized Design System)

### 🌟 Eklenenler & İyileştirmeler
* **Merkezi Tasarım Sistemi & Semantik Tokenlar (`AISidebarTheme`):**
  - Modern VS Code ve Cursor tarzı derin slate ve midnight dark (`#07080b`, `#111317`, `#181d28`) arayüz teması.
  - Rol bazlı (`user`, `assistant`, `command`) dinamik mesaj kartları ve StyleBoxFlat factory metotları.
  - Ghost buton stili (`create_ghost_button_style`), odak bordürleri (`create_input_focus_style`) ve dinamik Send/Stop aksan butonu.
  - Tüketici emojileri (`⏳`, `▶`, `🐞`, `❌`, `⚡`) temizlendi; profesyonel minimalist durum göstergeleri semantik durum tokenlarına bağlandı (`COLOR_SUCCESS`, `COLOR_WARNING`, `COLOR_ERROR`, `COLOR_ACCENT`).
* **AI-Native UI Layout Telemetri Motoru (`inspect_ui_layout`):**
  - Salt-okunur (read-only) güvenlik profiliyle LLM'nin hem açık sahneyi (`@edited_scene`) hem de kendi arayüzünü (`@sidebar`, `@sidebar/HistoryPanel`, `@sidebar/QueueContainer`) denetleyebilmesi sağlandı.
  - Konteyner kümülatif taşma kontrolü (`UI_CONTAINER_OVERFLOW` aggregate min dimensions).
  - Efektif görünürlük kontrolü (`_is_node_effectively_visible`) ve StyleBoxFlat / font boyutu tema analizi (`include_theme_details`).
* **Headless GDScript Derleme ve Sahne Doğrulayıcı (`typecheck.ps1` & `tools/typecheck.gd`):**
  - Godot editörünü açmadan eklenti (`addons/godot_sidebar_ai/`) ve test (`tests/`) altındaki tüm 113 GDScript ve 4 Sahne dosyasını statik olarak yükleyip derleyen sözdizimi doğrulayıcı.
  - Dinamik binary çözümleme (PATH, `$env:GODOT_BIN`, dinamik masaüstü araması) ve VS Code `Ctrl+Shift+B` derleme entegrasyonu.
* **Birim & Entegrasyon Test Güvencesi:**
  - `tests/test_ui_telemetry.gd` ve `tests/test_ui_components.gd` genişletildi; 54 test paketi ve 291 assertion %100 yeşil (`ALL PASS`).

---

## [2.6.0] - 2026-08-27 (Chat Management, Persistence & History Drawer)

### 🌟 Eklenenler & İyileştirmeler
* **Chat Management & Oturum Kalıcılığı (`AISidebarChatManager` & `AISidebarChatSession`):**
  - Tüm konuşmalar Godot projesine bağlı `user://sidebar_ai_chats/` dizininde izole JSON dosyaları halinde saklanır.
  - Asla API key, token veya hassas veri diske yazılmaz.
  - Mesajlar, araç çağrıları, araç sonuçları, netleştirmeler ve seans telemetrisi eksiksiz kaydedilir.
* **`+ New Chat` (Yeni Sohbet Başlatma):**
  - Aktif konuşmayı otomatik kaydeder, çalışan ajan varsa durdurur, girdi/kuyruk state'ini temizler ve temiz bir oturum başlatır.
* **`📚 History` (Geçmiş Sohbetler Çekmecesi):**
  - Başlık çubuğundaki `📚` butonuyla açılıp kapanabilen `AISidebarHistoryPanel` eklendi.
  - Gerçek zamanlı arama filtresi (`LineEdit`), oluşturulma/güncellenme zamanı ve mesaj sayısı göstergesi.
  - Aktif konuşma yeşil rozet ve vurgu çerçevesiyle öne çıkarılır.
* **Sohbet Değiştirme (Chat Switching & State Restoration):**
  - Geçmişten bir sohbet seçildiğinde mesaj balonları, araç geçmişi ve telemetri kartı hatasız olarak UI'da yeniden oluşturulur.
  - Eski approval, clarification veya runtime hata döngüleri kesinlikle yeniden tetiklenmez (`isolated context`).
* **Sohbet Yeniden Adlandırma & Silme:**
  - `✏️` butonu ile başlık değiştirme, ilk kullanıcı mesajından otomatik başlık türetme (`35 karaktere kadar`).
  - `🗑️` butonu ve `ConfirmationDialog` ile güvenli kalıcı silme.
* **Birim Testleri:**
  - `tests/test_chat_management.gd` eklendi (13 test); toplam test paketi 49'a ve doğrulama sayısı 233'e yükseldi (`%100 ALL PASS`).

---

## [2.5.0] - 2026-08-27 (Agent Clarification & Ask User Interactive Flow)

### 🌟 Eklenenler & İyileştirmeler
* **Ajan Netleştirme / Soru Sorma Sistemi (`ask_user`):**
  - Sonucu kökten değiştirecek ve aktif editör bağlamından çıkarılamayan bir belirsizlik olduğunda AI tahmin yürütmek yerine görevi duraklatıp (`WAITING_FOR_CLARIFICATION`) kullanıcıya soru sorar (Örn: "Sahne oluştur ve slime yap" $\rightarrow$ "2D mi 3D mi?").
  - Önemsiz detaylarda (hız, renk, boyut vb.) veya tek makul seçenek olduğunda soru sormadan makul varsayımla devam eden net karar politikası uygulandı.
* **Dinamik Clarification UI Kartı (`AISidebarClarificationCard`):**
  - Soru metni, tek tıkla seçilebilir hızlı seçenek butonları (`[2D] [3D]`), serbest metin giriş alanı (`LineEdit`) ve `Send` butonu.
  - Yanıt verildiğinde kart kontrolleri kilitlenir ve `✓ Answered: {answer}` geri bildirimi gösterilir.
* **Kesintisiz Görev Devamı (No Task Duplication):**
  - Kullanıcı yanıt verdiğinde yeni bağımsız bir görev başlatılmaz; mevcut ajan görevi kaldığı adımdan (`step`), telemetri ve bağlam bütünlüğüyle devam eder.
* **Durum & Kuyruk Güvenliği:**
  - `WAITING_FOR_CLARIFICATION` ve `WAITING_FOR_APPROVAL` durumları birbirinden tamamen izole edilmiştir.
  - Soru bekleyen görev varken kuyruktaki (`_message_queue`) sonraki görevler yanlışlıkla tetiklenmez.
  - `Stop` / `Clear` komutları netleştirme bekleyen görevi güvenli şekilde iptal eder.
* **Birim Testleri:**
  - `tests/test_agent_clarification.gd` eklendi; toplam test paketi 48'e ve doğrulama sayısı 220'ye yükseldi (`%100 ALL PASS`).

---

## [2.4.0] - 2026-08-27 (Enter=Send, Queued Messages FIFO & Chat Export 2.0)

### 🌟 Eklenenler & İyileştirmeler
* **Enter = Send UX Standardı:**
  - `Enter` ve `Ctrl+Enter` mesajı gönderir (veya kuyruğa alır).
  - `Shift+Enter` çok satırlı (multiline) metin girişi için yeni satır ekler.
  - `@mention` popup açıkken `Enter` ve `Tab` öneriyi seçer; `Esc` kapatır; `Yukarı/Aşağı` gezinir.
* **Queued Messages (FIFO Sıralı Mesaj Kuyruğu):**
  - AI bir görev üzerinde çalışırken (veya onay beklerken) kullanıcı yeni mesajlar gönderebilir.
  - Yeni mesajlar `_message_queue` kuyruğuna alınır ve girdi kutusunun üstünde `📋 Queued Messages (X)` kartında listelenir.
  - Kullanıcı istediği sırada bekleyen mesajı `✕` butonuyla iptal edebilir veya `Clear All` ile tümünü temizleyebilir.
  - Aktif görev tamamlandığında kuyruktaki sıradaki mesaj otomatik olarak başlatılır.
  - Kullanıcı `Stop` veya `Clear` yaptığında kuyruk güvenli şekilde duraklatılır veya temizlenir.
* **Gelişmiş Chat Export 2.0 (`chat_exporter.gd`):**
  - İnsan ve AI tarafından kolayca ayrıştırılabilen zengin Markdown ve JSON dışa aktarım desteği.
  - Hiyerarşik başlıklar: `## 👤 User` (multimodal görsel rozetleri dahil), `## 🤖 Godot AI` (Reasoning/Planning blokları dahil), `#### ⚡ Tool Executed` (girintili JSON argümanları), `### ⚙️ Tool Result` (dosya hedefleri, runtime teşhis hataları, durum rozetleri) ve `## 📊 Session Telemetry`.
  - Hatalı veya eksik veri girişlerine karşı %100 Null-Safe yapı.
* **Kapsamlı Test Paketi:**
  - `tests/test_ui_ux_queue_and_input.gd` ve genişletilmiş `tests/test_chat_exporter.gd` ile toplam test paketi 47'ye ve doğrulama sayısı 210'a ulaştı (`%100 ALL PASS`).

---

## [2.3.0] - 2026-08-27 (Viewport Screenshot & Multimodal Vision Loop)

### 🌟 Eklenenler
* **`take_viewport_screenshot` Aracı:** Godot editörünün aktif 2D veya 3D sahne viewport ekran görüntüsünü alan, token tasarrufu için ölçeklendiren ve diske kaydeden araç eklendi.
* **Otomatik Multimodal Vision Pipeline:** Viewport görüntüsü alındığında görsel otomatik olarak `AISidebarVisionInput` nesnesine dönüştürülüp modelin bir sonraki promptuna `image_url` parçası olarak enjekte edilir ("sahneyi gör ve düzelt" döngüsü).
* **Vision Intent Routing:** "gör", "viewport", "hiza", "screenshot" gibi görsel niyet anahtar kelimeleriyle dinamik araç eşleşmesi sağlandı.
* **Headless & Birim Testleri:** `tests/test_viewport_screenshot.gd` eklendi; toplam test paketi 46'ya ve assertion sayısı 198'e yükseldi (`%100 ALL PASS`).

---

## [2.2.0] - 2026-08-27 (Real 9Router Protocol Alignment & Live Diagnostics)

### 🌟 Eklenenler & Düzeltmeler
* **Gerçek 9Router SSE Protokol Uyumu:** 9Router / Gemini 3.7 Flash'ın akış bitiminde `finish_reason: "stop"` / `"tool_calls"` gönderip soketi kapatması (`Status: 8 / ResponseAborted`) durumunda veriyi kayıpsız kurtaran `is_buffer_complete` mimarisi uygulandı.
* **Canlı Entegrasyon & Teşhis Aracı (`tests/integration/test_real_9router_live.gd`):** Gerçek 9Router (`http://127.0.0.1:20128/v1`) ve `ag/gemini-3.7-flash-low` ile çalışan canlı TTFT, chunk sayısı ve kapanış durumu ölçüm aracı eklendi.
* **Test Paketi Genişletmesi:** 45 test paketi ve 192 assertion'a ulaşıldı (`%100 ALL PASS`).
* **Gizli API Anahtarı Koruması:** `.env` ve ortam değişkeni (`GODOT_AI_TEST_API_KEY`) desteği eklendi; `.gitignore` güncellendi.

---

## [2.1.0] - 2026-08-27 (Surgical Editing, Streaming, @Mention & Context Compactor)

### 🌟 Eklenenler
* **Cerrahi Dosya Düzenleme (`replace_file_content`):** Büyük scriptlerde küçük değişiklikleri satır satır diff ve atomik syntax doğrulaması ile yapabilen cerrahi araç eklendi.
* **Canlı LLM SSE Streaming:** Gelen token chunk'larını anında sohbet baloncuğuna akıtan ve "AI yazıyor..." göstergesi sunan streaming motoru entegre edildi.
* **`@mention` Dosya & Düğüm Otomatik Tamamlama:** Sohbet kutusuna `@` yazıldığında proje dosyalarını ve sahne ağacı düğümlerini listeyen `AISidebarMentionManager` eklendi.
* **Akıllı Context Compactor (`AISidebarContextCompactor`):** Uzun görevlerde eski araç çıktılarını 1-2 satırlık yapılandırılmış özetlere indirgeyerek %70+ token tasarrufu sağlayan sıkıştırma motoru eklendi (aktif son 2 araç tam korunur).
* **UI Metin Seçimi & Kopyalama:** Chat panellerinde fareyle metin seçimi, `Ctrl+C` kısayolu ve sağ tık kopyalama menüsü aktifleştirildi.

---

## [2.0.0] - 2026-08-26 (Godot AI Core Architecture Overhaul)

### 🌟 Eklenenler
* **Clean Architecture & Katı SRP:** Proje katmanlara ayrıldı (`types`, `security`, `state`, `mutations`, `agent`, `providers`, `network`, `tools`, `ui`, `tests`).
* **Merkezi Undo/Redo Servisi (`AISidebarMutationService`):** `add_node`, `delete_node`, `set_property`, `connect_signal`, `attach_script` ve `reparent_node` işlemlerine tam `EditorUndoRedoManager` desteği eklendi.
* **Güvenlik Kalkanı (`AISidebarPathPolicy`):** Path traversal (`../`) engellendi, `project.godot`, `.git/**` ve eklenti sistem dosyaları korumaya alındı.
* **Sağlayıcı Soyutlaması (`AISidebarAIProvider`):** OpenAI uyumlu modeller (`OpenAICompatibleProvider`), 9Router, OpenRouter, yerel Ollama ve LM Studio ile çalışacak şekilde ayrıştırıldı.
* **Bağımsız Ağ Motoru (`AISidebarNetworkManager`):** `HTTPRequest` düğümleri Presentation katmanından çıkarıldı, altyapı servisine taşındı.
* **Editör Zemin Bilgisi (`AISidebarEditorStateSnapshot`):** Aktif sahne adı, dosyası ve seçili düğümler prompt bağlamına otomatik eklendi.
* **Ajan Durum Makinesi (`AISidebarAgentRunner`):** `IDLE`, `PLANNING`, `EXECUTING`, `OBSERVING`, `VERIFYING`, `COMPLETED`, `ERROR`, `RECOVERING`, `CANCELLED` durumları ve Stagnation koruması eklendi.
* **Diff & ChangeSet Modeli (`AISidebarChangeSet`):** Kod değişiklikleri için satır satır diff üreten domain modeli eklendi.
* **Headless Birim Test Paketi (`tests/test_runner.gd`):** Godot 4.7 CLI üzerinden çalışan 45 test paketi ve 192 assertion eklendi.
* **GNU GPL-3.0 Lisansı:** Açık kaynak lisans dosyası (`LICENSE`) eklendi.

---

## [1.0.0] - 2026-08-26 (Official v1.0.0 Release)

### 🌟 Eklenenler
* Godot AI Sidebar resmi v1.0.0 sürümü GitHub üzerinden yayınlandı ve temiz ZIP paketi hazırlandı.
* Temiz kurulum ve README dokümantasyonu tamamlandı.
