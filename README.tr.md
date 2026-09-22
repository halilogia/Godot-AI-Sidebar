# 🤖 Godot AI Core (Godot AI Sidebar)

<p align="center">
  <b>Godot Engine 4.7 için Tam Entegre Otonom Yapay Zeka Oyun Geliştirme Asistanı</b><br>
  <i>Canlı SSE Streaming • Cerrahi Kod Düzenleme • @Mention Otomasyonu • Context Compaction • Undo/Redo (Ctrl+Z) • 9Router & Çoklu Model Desteği</i>
</p>

[English](README.md) · **Türkçe**

---

> **Not:** Bu dosya projenin Türkçe dokümantasyonudur. Uluslararası keşfedilebilirlik
> için ana `README.md` İngilizce olarak yeniden düzenlendi; içerik kaybı olmaması
> adına Türkçe sürüm burada korunmaktadır.

---

## 🌟 Temel Özellikler

* ⚡ **Doğrudan Editör Entegrasyonu:** Godot 4.7 sağ dock paneline yerleşir, motoru terk etmeden AI ile sahne, kod ve oyun mantığı üretmenizi sağlar.
* 🤔 **Ajan Netleştirme (`ask_user`):** Sonucu kökten değiştirecek bir belirsizlik olduğunda AI tahmin yürütmek yerine duraklayıp soru sorar. Örneğin "hexagon oluştur" isteğinde tek obje mi, oynanabilir ızgara mı, prosedürel sistem mi olduğunu sorar. `WAITING_FOR_CLARIFICATION` ayrı bir ajan durumudur.
* 🐞 **Çalışma Zamanı Denetimi (`inspect_runtime_tree`, `inspect_runtime_node`):** `EditorDebuggerPlugin` ve autoload köprüsü ile **çalışan oyunun** canlı sahne ağacını ve düğüm değerlerini sorgular; stack trace'i gerçek kaynak dosyaya eşler.
* 🎨 **Modern Slate & Midnight Dark Tasarım Sistemi (`AISidebarTheme`):** Cursor ve VS Code tarzı koyu slate zemin, rol bazlı konuşma balonları, kopyalanabilir/seçilebilir kod blokları, ghost butonlar ve dinamik odak stilleri.
* 📐 **AI-Native UI Layout Telemetri Motoru (`inspect_ui_layout`):** Salt-okunur (read-only) güvenlik profiliyle LLM'nin hem açık oyun sahnelerini (`@edited_scene`) hem de eklentinin kendi arayüzünü (`@sidebar`, `@sidebar/HistoryPanel`) düğüm hiyerarşisi, kümülatif taşma (`UI_CONTAINER_OVERFLOW`), görünürlük ve tema detaylarıyla denetleyebilmesi.
* 🔍 **Headless GDScript Derleme ve Sahne Doğrulayıcı (`typecheck.ps1`):** Godot editörünü açmadan 1.5 saniyede eklenti (`addons/godot_sidebar_ai/`) ve test (`tests/`) altındaki tüm GDScript ve Sahne dosyalarını (129 script, 4 sahne) statik olarak derleyip yükleyen sözdizimi doğrulayıcı. VS Code'da `Ctrl+Shift+B` kısayoluyla çalışır.
* 🌊 **Canlı Gerçek Zamanlı SSE Streaming:** Model yanıtları anında, kelime kelime sohbet baloncuğuna akar; "AI yazıyor..." göstergesi ve düşünce blokları canlı render edilir.
* ✂️ **Cerrahi Dosya Düzenleme (`replace_file_content`):** 400 satırlık scriptlerde tek bir satırı değiştirmek için tüm dosyayı baştan yazmaz; hedef kodu güvenli ve atomik şekilde değiştirir.
* 🏷️ **`@mention` Dosya & Düğüm Otomatik Tamamlama:** Sohbet kutusunda `@` yazıldığında projedeki `.gd`, `.tscn` dosyalarını ve sahne ağacındaki düğümleri listeler, seçilen bağlamı prompta güvenli limitlerle otomatik enjekte eder.
* 💬 **Mesaj Kuyruğu (Queued Messages):** AI çalışırken yeni görev gönderebilirsiniz; mesajlar FIFO sırasıyla otomatik yürütülür.
* 🗜️ **Akıllı Context Compaction:** Uzun ve çok adımlı görevlerde eski araç çıktılarını (50 dosyalık listeler, ağaç dökümleri) 1-2 satırlık özetlere dönüştürerek token patlamasını önler; aktif son 2 aracın tam detayını korur.
* ↩️ **Tam Undo / Redo (Ctrl+Z) Güvenliği:** Yapay zekanın eklediği/sildiği tüm düğümler, özellik atamaları, sinyal ve script bağlantıları Godot'nun yerel `EditorUndoRedoManager` sistemine işlenir.
* 🛡️ **Path & Permission Policy (Güvenlik Kalkanı):** `project.godot`, `.git/**` ve eklenti sistem dosyalarının ezilmesini engelleyen katı güvenlik politikası, 3 seviyeli auto-approve modu (`MANUAL`, `AUTO`, `FULL_AUTO`) ve kullanıcı onay kartları.
* 🧠 **Editör Durum Yakalama (Grounding Context):** Ajan o an hangi sahnede olduğunuzu, hangi scriptlerin açık olduğunu ve hangi düğümü seçtiğinizi otomatik olarak bağlamına alır.
* 🔄 **Otonom Ajan Durum Makinesi:** `IDLE → PLANNING → EXECUTING → OBSERVING → VERIFYING → COMPLETED` döngüsü, otomatik iyileştirme (self-healing) ve sonsuz döngü (stagnation) koruması.
* 📚 **Sohbet Kalıcılığı & Geçmiş:** `user://sidebar_ai_chats/` altında JSON oturum deposu; arama, yeniden adlandırma ve silme. API anahtarı asla diske yazılmaz.
* 🌐 **Gerçek 9Router, OpenAI & Antigravity CLI Uyumluluğu:** 9Router (`127.0.0.1:20128`), OpenRouter, yerel Ollama, LM Studio ve resmi Google Antigravity CLI ile doğrudan oturum desteği.
* 🇹🇷 🇬🇧 **Çift Dil Desteği:** Tek tıkla Türkçe ve İngilizce arayüz geçişi.

---

## 📁 Mimari Yapı (Clean Architecture & SRP)

```text
addons/godot_sidebar_ai/
├── plugin.cfg & plugin.gd
├── core/
│   ├── types/
│   │   ├── type_parser.gd            # Smart Variant & string parse
│   │   ├── tool_result.gd            # Standart Sonuç Modeli (ok/err)
│   │   ├── change_set.gd             # Diff & Değişiklik Modeli
│   │   ├── vision_input.gd           # Multimodal Görsel Veri Modeli
│   │   └── runtime_observation.gd    # Çalışma Zamanı Hata Gözlemi
│   ├── security/
│   │   ├── path_policy.gd            # Güvenlik & Korumalı Dosya Listesi
│   │   └── permission_policy.gd      # Yetki Sınıflandırması & Onay Kuralları
│   ├── config/api_config.gd          # Ayar Yönetimi & Persistence
│   ├── i18n/i18n.gd                  # TR/EN Dinamik Sözlük
│   ├── network/
│   │   ├── sse_parser.gd             # SSE Stream, Reasoning & Tool Parser
│   │   └── network_manager.gd        # HTTPClient Ağ Motoru (Status 8 & Stream Recovery)
│   ├── providers/
│   │   ├── ai_provider.gd            # Soyut Sağlayıcı Arayüzü
│   │   ├── openai_compatible_provider.gd # 9Router / OpenRouter / Ollama
│   │   └── agy_cli_provider.gd       # Google Antigravity CLI Sağlayıcısı
│   ├── runtime/
│   │   ├── debugger_plugin.gd        # EditorDebuggerPlugin Köprüsü
│   │   ├── runtime_bridge.gd         # Oyun Tarafı Autoload
│   │   ├── runtime_observer.gd       # Çalışma Zamanı Gözlemci
│   │   └── source_mapper.gd          # Stack Trace -> Kaynak Eşleyici
│   ├── state/
│   │   ├── editor_state_snapshot.gd  # Editör Aktif Sahne/Seçim Yakalayıcı
│   │   ├── context_collector.gd      # Bağlam Toplayıcı
│   │   └── diagnosis_context.gd      # Teşhis Bağlamı
│   ├── commands/slash_command_manager.gd # /slash komutları
│   ├── chat/
│   │   ├── chat_manager.gd           # Oturum Persistence & JSON Deposu
│   │   ├── chat_session.gd           # Konuşma Oturum Modeli
│   │   ├── chat_exporter.gd          # Markdown / JSON Dışa Aktarma
│   │   └── mention_manager.gd        # @mention Dosya & Düğüm Tarama Servisi
│   ├── mutations/editor_mutation_service.gd # Merkezi Undo/Redo Mutasyonları
│   ├── verification/verification_pipeline.gd # GDScript & Sahne Doğrulama
│   ├── agent/
│   │   ├── agent_context.gd          # Konuşma & Grounding Bağlamı
│   │   ├── context_compactor.gd      # Tarihsel Araç Çıktısı Sıkıştırıcı
│   │   └── agent_runner.gd           # State Machine Ajan İcra Beyni
│   └── tools/
│       ├── tool_base.gd              # Temel Araç Sınıfı
│       ├── primitive/                # İlkel Araçlar (scene, script, editor, ui_telemetry)
│       ├── intent/                   # Yüksek Seviyeli Araçlar (game_intent)
│       └── tool_manager.gd           # Progressive Discovery & Intent Routing
├── ui/
│   ├── theme/sidebar_theme.gd        # Merkezi AISidebarTheme Tasarım Sistemi
│   ├── icons/                        # Lucide SVG Vektör Seti
│   ├── components/                   # Modüler UI Kartları (Bubble, Approval, Clarification, Activity, History, Welcome)
│   ├── dialogs/                      # Ayarlar ve ChangeSet Pencereleri
│   └── docks/chat_dock.*             # UI Sohbet, Streaming & @Mention Dock'u
├── tools/typecheck.gd                # Headless Statik GDScript Derleyici
├── typecheck.ps1                     # PowerShell Statik Tip Denetleyici
└── tests/
    ├── test_runner.gd                # 55 Test Paketi (331 Assertion)
    └── integration/test_real_9router_live.gd # Gerçek Canlı 9Router Test Aracı
```

---

## 🚀 Kurulum

1. Bu depoyu klonlayın (`git clone https://github.com/halilogia/Godot-AI-Sidebar.git`) veya [Releases](https://github.com/halilogia/Godot-AI-Sidebar/releases) sayfasından en son yayınlanan sürüm arşivini indirin.
2. Depo içindeki `addons/godot_sidebar_ai` klasörünü Godot projenizin `addons/` dizinine kopyalayın:
   ```text
   senin_godot_projen/
   └── addons/
       └── godot_sidebar_ai/
           ├── plugin.cfg
           ├── plugin.gd
           └── ...
   ```
3. Godot Editöründe **Project -> Project Settings -> Plugins** sekmesine gidin.
4. **Godot AI Sidebar** eklentisinin yanındaki **Enable (Etkin)** kutucuğunu işaretleyin.
5. Sağ dock panelinde AI asistanınız hazır olacaktır. Ayarlar butonundan 9Router (`http://127.0.0.1:20128/v1`), yerel model API adresinizi veya Antigravity CLI seçip çalışmaya başlayabilirsiniz.

> **AI nereden geliyor?** İki sağlayıcı ailesi var:
> **OpenAI-uyumlu** (9Router, OpenRouter, Ollama, LM Studio — base URL + API key gerekir, görsel destekler)
> ve **Antigravity CLI** (`agy` PATH'te ve oturum açılmış olmalı, görsel desteklemez).
> Detaylı karşılaştırma için İngilizce [README.md](README.md#providers) dosyasına bakın.

---

## 🧪 Test ve Doğrulama

### 1. Headless GDScript Derleme ve Sahne Doğrulama (Compilation Validator)
`typecheck.ps1` scripti, `tools/typecheck.gd` aracılığıyla eklenti (`addons/godot_sidebar_ai/`) ve test (`tests/`) dizinlerindeki tüm GDScript ve `.tscn` dosyalarını (129 script, 4 sahne) Godot motoru üzerinden statik olarak derleyip sözdizimi hatalarını yakalar:
```powershell
./typecheck.ps1
```
*(VS Code içinde `Ctrl+Shift+B` kısayolu ile derleme görevini de tetikleyebilirsiniz)*

### 2. Headless Master Test Suite (55 Test Paketi / 331 Assertion)
```bash
godot --headless -s res://tests/test_runner.gd
```

> **Önemli:** Test paketi **temiz bir klonda**, yani `config.json` yokken %100
> geçmelidir. Hiçbir test kullanıcının yerel sağlayıcı ayarlarına bağımlı
> olmamalıdır; yalnızca yazarın makinesinde geçen bir test, testsizlikten
> daha kötüdür.

### 3. Canlı 9Router Entegrasyon Testi
```bash
godot --headless -s res://tests/integration/test_real_9router_live.gd
```

---

## ⚠️ Bilinen Sınırlamalar

Dürüstçe, çünkü zaten karşılaşacaksınız:

* **AGY CLI ilk açılış gecikmesi:** `agy` oturumu başlatılırken alt süreç stdio
  borularını hazırlayana kadar editör kısa süre bloke olabilir. Bir ön-ısıtma
  (pre-warm) adımı bunu hafifletir, ancak alt sürece yazma işlemi hâlâ ana
  thread üzerinde gerçekleşir. Aktif olarak incelenmektedir.
* **AGY CLI ile görsel (Vision) desteği yok:** `agy` stream-json arayüzü görsel
  veri kabul etmez. Görsel analiz için OpenAI-uyumlu sağlayıcı kullanın.
* **Yalnızca Godot 4.7+:** Eklenti `EditorInterface` singleton API'lerini
  kullanır; 4.2 ve öncesinde çalışması beklenmez.
* **Yalnızca GDScript:** C# scripting desteklenmemektedir.

---

## 📄 Lisans

Bu proje **GNU General Public License v3.0 (GPL-3.0)** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakabilirsiniz.

Telif Hakkı (C) 2026 Halil Emre.
