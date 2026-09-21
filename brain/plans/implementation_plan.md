# Godot AI Sidebar (Clean Architecture & Autonomous Agent) Yeniden İnşa Planı

Bu plan, **Godot AI Sidebar** eklentisini en son Godot 4.7 standartlarına uygun, sektör standardı katmanlı mimari (**Clean Architecture**), katı **SRP (1 Dosya = 1 İş)** ve otonom ajan yetenekleriyle sıfırdan ve sağlam temellerle yeniden yapılandırır.

---

## 🏗️ 1. Mimari Katmanları ve Klasör Yapısı

```text
addons/godot_sidebar_ai/
├── plugin.cfg                           # Eklenti kimlik ve sürüm tanımı (v2.0)
├── plugin.gd                            # Sadece dock slot ve lifecycle yönetimi
│
├── core/
│   ├── config/
│   │   └── api_config.gd               # 9Router Base URL, Nexus API key, model & ayar yönetimi
│   ├── i18n/
│   │   └── i18n.gd                     # Dinamik TR/EN çeviri motoru
│   ├── network/
│   │   ├── sse_parser.gd               # Server-Sent Events akış ve Thinking ayrıştırıcısı
│   │   └── ai_client.gd                # Dual-channel HTTP istemcisi (Modeller + Chat)
│   ├── agent/
│   │   ├── agent_context.gd            # Sohbet ve işlem geçmişi (Context Window)
│   │   └── agent_runner.gd             # Otonom Ajan İcra Döngüsü (UI'dan bağımsız karar beyni)
│   └── tools/
│       ├── tool_base.gd                # Tüm araçların soyut temel sınıfı
│       ├── scene_tools.gd              # Sahne ve Node işlemleri (Tam EditorUndoRedoManager / Ctrl+Z)
│       ├── script_tools.gd             # Kod okuma, oluşturma, patch ve syntax doğrulama
│       ├── editor_tools.gd             # Selection, play/stop, hata logları, viewport ekran görüntüsü
│       ├── game_intent_tools.gd        # Yüksek seviyeli bileşik oyun üretim araçları (create_character vb.)
│       └── tool_manager.gd             # Progressive Discovery (search_tools, dinamik şema üretimi)
│
└── ui/
    ├── icons/                          # Lucide SVG vektör ikonları (bot, send, settings, refresh, trash, globe)
    ├── components/
    │   ├── thinking_block.gd / .tscn   # Gemini tarzı çerçeveli Thinking kutusu bileşeni
    │   └── chat_bubble.gd / .tscn      # Kullanıcı, Asistan, Araç ve Hata mesaj kutuları
    ├── docks/
    │   ├── chat_dock.gd                # Sadece kullanıcı etkileşimini dinleyen saf UI paneli
    │   └── chat_dock.tscn              # Sol panel dock arayüzü
    └── dialogs/
        ├── settings_dialog.gd          # 9Router ve API ayarları modal penceresi
        └── settings_dialog.tscn        # Ayarlar sahnesi
```

---

## 🧩 2. Temel Teknolojiler ve Yenilikler

1. **Otonom Ajan Çekirdeği (`AgentRunner`):**
   * UI ile Ajan mantığı birbirinden tamamen ayrılır.
   * Ajan kendi adımlarını planlar, araçları çalıştırır, sonuçları analiz eder ve döngüyü sürdürür.
2. **Editor Undo/Redo Entegrasyonu (`scene_tools.gd`):**
   * AI'ın oluşturduğu veya sildiği her düğüm Godot'nun yerel `EditorUndoRedoManager`'ına işlenir. Yanlış bir işlemde motor içinden **`Ctrl + Z`** ile anında geri alınabilir.
3. **Progressive Tool Discovery (`tool_manager.gd`):**
   * Modelin bağlamını (context) 100+ araçla kirletip yavaşlatmamak için **`search_tools`** ve kategori filtreleme mekanizması.
4. **Yüksek Seviyeli Oyun Araçları (`game_intent_tools.gd`):**
   * 10 ayrı API çağrısı yerine tek komutla çalışan bileşik fonksiyonlar: `create_character_scene(type, name, speed, health)`, `setup_camera_follow(target)`.
5. **SSE Streaming & Gemini Tarzı Thinking Blokları:**
   * 9Router üzerinden gelen düşünce zincirini (`reasoning_content`) canlı ve estetik olarak biçimlendirir.
6. **Sıfır Port / Çift Kanallı Ağ Mimarisi:**
   * Node.js veya harici port çakışması olmadan motor içi saf HTTP ile çalışır.

---

## 📋 3. Yapılacak Değişiklikler ve Dosya Listesi

### [Core - Config & i18n]
- [NEW] [api_config.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/config/api_config.gd)
- [NEW] [i18n.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/i18n/i18n.gd)

### [Core - Network & Parsing]
- [NEW] [sse_parser.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/network/sse_parser.gd)
- [NEW] [ai_client.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/network/ai_client.gd)

### [Core - Agent Orchestrator]
- [NEW] [agent_context.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/agent/agent_context.gd)
- [NEW] [agent_runner.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/agent/agent_runner.gd)

### [Core - Modular Tools]
- [NEW] [tool_base.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/tool_base.gd)
- [NEW] [scene_tools.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/scene_tools.gd)
- [NEW] [script_tools.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/script_tools.gd)
- [NEW] [editor_tools.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/editor_tools.gd)
- [NEW] [game_intent_tools.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/game_intent_tools.gd)
- [NEW] [tool_manager.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/tool_manager.gd)

### [UI & Lifecycle]
- [MODIFY] [plugin.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/plugin.gd)
- [MODIFY] [chat_dock.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/docks/chat_dock.gd)
- [MODIFY] [chat_dock.tscn](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/docks/chat_dock.tscn)
- [MODIFY] [settings_dialog.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/dialogs/settings_dialog.gd)
- [MODIFY] [settings_dialog.tscn](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/dialogs/settings_dialog.tscn)

---

## 🧪 4. Doğrulama Planı

1. **Headless Engine Derleme Kontrolü:**
   * `Godot_v4.7.2-stable_win64.exe --headless --path "<local_path> AI Sidebar" --check-only` çalıştırılarak 0 hata ile derlendiği doğrulanacak.
2. **9Router Bağlantı ve Model Çekme Testi:**
   * Canlı 9Router API'sine bağlanıp model listesinin çekildiği ve SSE akışının ayrıştırıldığı doğrulanacak.
3. **Undo/Redo & Sahne Testi:**
   * AI'ın oluşturduğu bir düğümün Godot Editor UndoRedo yöneticisine başarıyla kaydedildiği test edilecek.
