# 🤖 Godot AI Core (Godot AI Sidebar v2.0)

<p align="center">
  <b>Godot Engine 4.7 için Tam Entegre Otonom Yapay Zeka Oyun Geliştirme Asistanı</b><br>
  <i>Undo/Redo (Ctrl+Z) Desteği • Clean Architecture • Progressive Tool Discovery • 9Router & Çoklu Model Desteği</i>
</p>

---

## 🌟 Temel Özellikler

* ⚡ **Doğrudan Editör Entegrasyonu:** Godot 4.7 sol dock paneline yerleşir, motoru terk etmeden AI ile sahne, kod ve oyun mantığı üretmenizi sağlar.
* ↩️ **Tam Undo / Redo (Ctrl+Z) Güvenliği:** Yapay zekanın eklediği/sildiği tüm düğümler, özellik atamaları, sinyal ve script bağlantıları Godot'nun yerel `EditorUndoRedoManager` sistemine işlenir. Hatalı bir işlem anında motordan `Ctrl + Z` ile geri alınabilir.
* 🛡️ **Path & Permission Policy (Güvenlik Kalkanı):** `project.godot`, `.git/**` ve eklenti sistem dosyalarının ezilmesini engelleyen katı güvenlik politikası.
* 🧠 **Editör Durum Yakalama (Grounding Context):** Ajan o an hangi sahnede olduğunuzu ve hangi düğümü seçtiğinizi otomatik olarak bağlamına alır.
* 🔄 **Otonom Ajan Durum Makinesi:** `IDLE → PLANNING → EXECUTING → OBSERVING → VERIFYING → COMPLETED` döngüsü ve sonsuz döngü (stagnation) koruması.
* 🌐 **Ayrık Sağlayıcı Mimarisi (Provider Abstraction):** 9Router, OpenRouter, yerel Ollama ve LM Studio ile tam uyumlu; Anthropic ve Gemini için genişletilebilir.
* 🔍 **Progressive Tool Discovery (`search_tools`):** Yüzlerce aracı tek seferde prompta yükleyip token harcamak yerine arama ile dinamik keşif.
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
│   │   └── change_set.gd             # Diff & Değişiklik Modeli
│   ├── security/
│   │   ├── path_policy.gd            # Güvenlik & Korumalı Dosya Listesi
│   │   └── permission_policy.gd      # Yetki Sınıflandırması
│   ├── config/api_config.gd          # Ayar Yönetimi & Persistence
│   ├── i18n/i18n.gd                  # TR/EN Dinamik Sözlük
│   ├── network/
│   │   ├── sse_parser.gd             # SSE Stream & Thinking Parser
│   │   └── network_manager.gd        # Saf HTTP Ağ Motoru
│   ├── providers/
│   │   ├── ai_provider.gd            # Soyut Sağlayıcı Arayüzü
│   │   └── openai_compatible_provider.gd # 9Router/OpenRouter/Ollama
│   ├── state/editor_state_snapshot.gd# Editör Aktif Sahne/Seçim Yakalayıcı
│   ├── mutations/editor_mutation_service.gd # Merkezi Undo/Redo
│   ├── agent/
│   │   ├── agent_context.gd          # Konuşma & Grounding Bağlamı
│   │   └── agent_runner.gd           # State Machine Ajan İcra Beyni
│   └── tools/
│       ├── tool_base.gd              # Temel Araç Sınıfı
│       ├── primitive/                # İlkel Araçlar (scene, script, editor)
│       ├── intent/                   # Yüksek Seviyeli Araçlar (game_intent)
│       └── tool_manager.gd           # Progressive Discovery (search_tools)
├── ui/
│   ├── icons/                        # Lucide SVG Vektörleri
│   ├── dialogs/settings_dialog.*     # Ayarlar Penceresi
│   └── docks/chat_dock.*             # Saf UI Sohbet & Thinking Dock'u
└── tests/
    ├── test_runner.gd                # Headless Test Koşucu
    └── test_*.gd (7 Test Paketi)
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
5. Sol dock panelinde AI asistanınız hazır olacaktır. Ayarlar (⚙️) butonundan 9Router veya yerel model API adresinizi girip çalışmaya başlayabilirsiniz.

---

## 🧪 Birim Testleri Çalıştırma

Eklenti bağımsız headless unit test suite içerir:

```bash
godot --headless -s res://tests/test_runner.gd
```

---

## 📄 Lisans

Bu proje **GNU General Public License v3.0 (GPL-3.0)** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakabilirsiniz.
