# 🤖 Godot AI Core (Godot AI Sidebar)

<p align="center">
  <b>Godot Engine 4.7 için Tam Entegre Otonom Yapay Zeka Oyun Geliştirme Asistanı</b><br>
  <i>Canlı SSE Streaming • Cerrahi Kod Düzenleme • @Mention Otomasyonu • Context Compaction • Undo/Redo (Ctrl+Z) • 9Router & Çoklu Model Desteği</i>
</p>

---

## 🌟 Temel Özellikler

* ⚡ **Doğrudan Editör Entegrasyonu:** Godot 4.7 sol/sağ dock paneline yerleşir, motoru terk etmeden AI ile sahne, kod ve oyun mantığı üretmenizi sağlar.
* 🎨 **Modern Slate & Midnight Dark Tasarım Sistemi (`AISidebarTheme`):** Cursor ve VS Code tarzı koyu slate zemin, rol bazlı konuşma balonları, kopyalanabilir/seçilebilir kod blokları, ghost butonlar ve dinamik odak stilleri.
* 📐 **AI-Native UI Layout Telemetri Motoru (`inspect_ui_layout`):** Salt-okunur (read-only) güvenlik profiliyle LLM'nin hem açık oyun sahnelerini (`@edited_scene`) hem de eklentinin kendi arayüzünü (`@sidebar`, `@sidebar/HistoryPanel`) düğüm hiyerarşisi, kümülatif taşma (`UI_CONTAINER_OVERFLOW`), görünürlük ve tema detaylarıyla denetleyebilmesi.
* 🔍 **Headless Statik Tip & Sözdizimi Kontrolcüsü (`typecheck.ps1`):** Godot editörünü açmadan 1.5 saniyede tüm GDScript ve Sahne dosyalarını derleyen TypeScript (`tsc --noEmit`) tarzı statik denetleyici. VS Code'da `Ctrl+Shift+B` kısayoluyla çalışır.
* 🌊 **Canlı Gerçek Zamanlı SSE Streaming:** Model yanıtları anında, kelime kelime sohbet baloncuğuna akar; "AI yazıyor..." göstergesi ve düşünce blokları canlı render edilir.
* ✂️ **Cerrahi Dosya Düzenleme (`replace_file_content`):** 400 satırlık scriptlerde tek bir satırı değiştirmek için tüm dosyayı baştan yazmaz; hedef kodu güvenli ve atomik şekilde değiştirir.
* 🏷️ **`@mention` Dosya & Düğüm Otomatik Tamamlama:** Sohbet kutusunda `@` yazıldığında projedeki `.gd`, `.tscn` dosyalarını ve sahne ağacındaki düğümleri listeler, seçilen bağlamı prompta güvenli limitlerle otomatik enjekte eder.
* 🗜️ **Akıllı Context Compaction:** Uzun ve çok adımlı görevlerde eski araç çıktılarını (50 dosyalık listeler, ağaç dökümleri) 1-2 satırlık özetlere dönüştürerek token patlamasını önler; aktif son 2 aracın tam detayını korur.
* ↩️ **Tam Undo / Redo (Ctrl+Z) Güvenliği:** Yapay zekanın eklediği/sildiği tüm düğümler, özellik atamaları, sinyal ve script bağlantıları Godot'nun yerel `EditorUndoRedoManager` sistemine işlenir.
* 🛡️ **Path & Permission Policy (Güvenlik Kalkanı):** `project.godot`, `.git/**` ve eklenti sistem dosyalarının ezilmesini engelleyen katı güvenlik politikası, 3 seviyeli auto-approve modu (`MANUAL`, `AUTO`, `FULL_AUTO`) ve kullanıcı onay kartları.
* 🧠 **Editör Durum Yakalama (Grounding Context):** Ajan o an hangi sahnede olduğunuzu, hangi scriptlerin açık olduğunu ve hangi düğümü seçtiğinizi otomatik olarak bağlamına alır.
* 🔄 **Otonom Ajan Durum Makinesi:** `IDLE → PLANNING → EXECUTING → OBSERVING → VERIFYING → COMPLETED` döngüsü, otomatik iyileştirme (self-healing) ve sonsuz döngü (stagnation) koruması.
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
│   ├── state/editor_state_snapshot.gd# Editör Aktif Sahne/Seçim Yakalayıcı
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
│       ├── primitive/                # İlkel Araçlar (scene, script, ui_telemetry)
│       ├── intent/                   # Yüksek Seviyeli Araçlar (game_intent)
│       └── tool_manager.gd           # Progressive Discovery & Intent Routing
├── ui/
│   ├── theme/sidebar_theme.gd        # Merkezi AISidebarTheme Tasarım Sistemi
│   ├── icons/                        # Lucide SVG Vektör Seti
│   ├── components/                   # Modüler UI Kartları (Bubble, Approval, Activity, History)
│   ├── dialogs/                      # Ayarlar ve ChangeSet Pencereleri
│   └── docks/chat_dock.*             # UI Sohbet, Streaming & @Mention Dock'u
├── tools/typecheck.gd                # Headless Statik GDScript Derleyici
├── typecheck.ps1                     # PowerShell Statik Tip Denetleyici
└── tests/
    ├── test_runner.gd                # 54 Test Paketi (291 Assertion)
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
5. Sol/sağ dock panelinde AI asistanınız hazır olacaktır. Ayarlar butonundan 9Router (`http://127.0.0.1:20128/v1`), yerel model API adresinizi veya Antigravity CLI seçip çalışmaya başlayabilirsiniz.

---

## 🧪 Test ve Doğrulama

### 1. Headless GDScript Derleme ve Sahne Doğrulama (Compilation Validator)
`typecheck.ps1` scripti, `tools/typecheck.gd` aracılığıyla eklenti (`addons/godot_sidebar_ai/`) ve test (`tests/`) dizinlerindeki tüm GDScript ve `.tscn` dosyalarını (113 script, 4 sahne) Godot motoru üzerinden statik olarak derleyip sözdizimi hatalarını yakalar:
```powershell
./typecheck.ps1
```
*(VS Code içinde `Ctrl+Shift+B` kısayolu ile derleme görevini de tetikleyebilirsiniz)*

### 2. Headless Master Test Suite (54 Test Paketi / 291 Assertion)
```bash
godot --headless -s res://tests/test_runner.gd
```

### 3. Canlı 9Router Entegrasyon Testi
```bash
godot --headless -s res://tests/integration/test_real_9router_live.gd
```

---

## 📄 Lisans

Bu proje **GNU General Public License v3.0 (GPL-3.0)** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakabilirsiniz.
