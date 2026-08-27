# 🤖 Godot AI Core (Godot AI Sidebar)

<p align="center">
  <b>Godot Engine 4.7 için Tam Entegre Otonom Yapay Zeka Oyun Geliştirme Asistanı</b><br>
  <i>Canlı SSE Streaming • Cerrahi Kod Düzenleme • @Mention Otomasyonu • Context Compaction • Undo/Redo (Ctrl+Z) • 9Router & Çoklu Model Desteği</i>
</p>

---

## 🌟 Temel Özellikler

* ⚡ **Doğrudan Editör Entegrasyonu:** Godot 4.7 sol/sağ dock paneline yerleşir, motoru terk etmeden AI ile sahne, kod ve oyun mantığı üretmenizi sağlar.
* 🌊 **Canlı Gerçek Zamanlı SSE Streaming:** Model yanıtları anında, kelime kelime sohbet baloncuğuna akar; "AI yazıyor..." göstergesi ve düşünce blokları canlı render edilir.
* ✂️ **Cerrahi Dosya Düzenleme (`replace_file_content`):** 400 satırlık scriptlerde tek bir satırı değiştirmek için tüm dosyayı baştan yazmaz; hedef kodu güvenli ve atomik şekilde değiştirir.
* 🏷️ **`@mention` Dosya & Düğüm Otomatik Tamamlama:** Sohbet kutusunda `@` yazıldığında projedeki `.gd`, `.tscn` dosyalarını ve sahne ağacındaki düğümleri listeler, seçilen bağlamı prompta güvenli limitlerle otomatik enjekte eder.
* 🗜️ **Akıllı Context Compaction:** Uzun ve çok adımlı görevlerde eski araç çıktılarını (50 dosyalık listeler, ağaç dökümleri) 1-2 satırlık özetlere dönüştürerek token patlamasını önler; aktif son 2 aracın tam detayını korur.
* ↩️ **Tam Undo / Redo (Ctrl+Z) Güvenliği:** Yapay zekanın eklediği/sildiği tüm düğümler, özellik atamaları, sinyal ve script bağlantıları Godot'nun yerel `EditorUndoRedoManager` sistemine işlenir.
* 🛡️ **Path & Permission Policy (Güvenlik Kalkanı):** `project.godot`, `.git/**` ve eklenti sistem dosyalarının ezilmesini engelleyen katı güvenlik politikası ve kullanıcı onay kartları.
* 🧠 **Editör Durum Yakalama (Grounding Context):** Ajan o an hangi sahnede olduğunuzu, hangi scriptlerin açık olduğunu ve hangi düğümü seçtiğinizi otomatik olarak bağlamına alır.
* 🔄 **Otonom Ajan Durum Makinesi:** `IDLE → PLANNING → EXECUTING → OBSERVING → VERIFYING → COMPLETED` döngüsü, otomatik iyileştirme (self-healing) ve sonsuz döngü (stagnation) koruması.
* 🌐 **Gerçek 9Router & OpenAI Uyumluluğu:** `127.0.0.1:20128` üzerinden 9Router, OpenRouter, yerel Ollama ve LM Studio ile tam uyumlu; `finish_reason: "stop"` ve soket kapanışlarını kusursuz karşılar.
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
│   │   └── openai_compatible_provider.gd # 9Router / OpenRouter / Ollama
│   ├── state/editor_state_snapshot.gd# Editör Aktif Sahne/Seçim Yakalayıcı
│   ├── chat/mention_manager.gd       # @mention Dosya & Düğüm Tarama Servisi
│   ├── mutations/editor_mutation_service.gd # Merkezi Undo/Redo Mutasyonları
│   ├── verification/verification_pipeline.gd # GDScript & Sahne Doğrulama
│   ├── agent/
│   │   ├── agent_context.gd          # Konuşma & Grounding Bağlamı
│   │   ├── context_compactor.gd      # Tarihsel Araç Çıktısı Sıkıştırıcı
│   │   └── agent_runner.gd           # State Machine Ajan İcra Beyni
│   └── tools/
│       ├── tool_base.gd              # Temel Araç Sınıfı
│       ├── primitive/                # İlkel Araçlar (scene, script, editor)
│       ├── intent/                   # Yüksek Seviyeli Araçlar (game_intent)
│       └── tool_manager.gd           # Progressive Discovery & Intent Routing
├── ui/
│   ├── icons/                        # Lucide SVG Vektör Seti
│   ├── components/                   # Modüler UI Kartları (Bubble, Approval, Activity)
│   ├── dialogs/settings_dialog.*     # Ayarlar Penceresi
│   └── docks/chat_dock.*             # UI Sohbet, Streaming & @Mention Dock'u
└── tests/
    ├── test_runner.gd                # 45 Test Paketi (192 Assertion)
    └── integration/test_real_9router_live.gd # Gerçek Canlı 9Router Test Aracı
```

---

## 🚀 Kurulum

1. [Releases](https://github.com/halilogia/Godot-AI-Sidebar/releases) sayfasından en son `godot-ai-sidebar-v1.0.0.zip` paketini indirin (veya bu depoyu klonlayın).
2. Paket içindeki `addons/godot_sidebar_ai` klasörünü Godot projenizin `addons/` dizinine kopyalayın:
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
5. Sol/sağ dock panelinde AI asistanınız hazır olacaktır. Ayarlar (⚙️) butonundan 9Router (`http://127.0.0.1:20128/v1`) veya yerel model API adresinizi girip çalışmaya başlayabilirsiniz.

---

## 🧪 Test Çalıştırma

### 1. Headless Master Test Suite (45 Test Paketi / 192 Assertion)
```bash
godot --headless -s res://tests/test_runner.gd
```

### 2. Canlı 9Router Entegrasyon Testi
```bash
godot --headless -s res://tests/integration/test_real_9router_live.gd
```

---

## 📄 Lisans

Bu proje **GNU General Public License v3.0 (GPL-3.0)** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakabilirsiniz.
