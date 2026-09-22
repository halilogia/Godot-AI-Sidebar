# 🏛️ Godot AI Core Architecture

Bu belge, **Godot AI Core (Godot AI Sidebar)** eklentisinin yazılım mimarisini, katmanlar arası bağımlılık kurallarını, veri akışını, soket yaşam döngüsünü ve güvenlik tasarımını detaylandırmaktadır.

---

## 🎯 Mimari İlkeler (Design Principles)

1. **Clean Architecture (Temiz Mimari):**
   * Bağımlılık yönü daima dıştan içe doğrudur.
   * `Presentation` (UI) asla doğrudan `Infrastructure` (ağ soketleri, HTTP istemcileri) ile konuşmaz.
   * `Domain` katmanı dış dünyadan tamamen izoledir.
2. **Single Responsibility Principle (1 Dosya = 1 İş):**
   * Her dosya yalnızca tek bir sorumluluğa sahiptir (`context_compactor.gd` sadece özetleme yapar; `mention_manager.gd` sadece `@mention` listesi tarar).
3. **Engine Safety & Complete Undo/Redo:**
   * Yapay zekanın yaptığı tüm sahne ve düğüm mutasyonları Godot'nun yerel `EditorUndoRedoManager` sistemine kayıtlıdır (**Ctrl + Z** desteği).
4. **Resilient Network & Graceful Socket Recovery:**
   * 9Router / OpenAI SSE akışlarında `finish_reason: "stop"` ve soket kapanışları (`Status: 8`) kayıpsız karşılanır ve kurtarılır.

---

## 📐 Katmanlı Mimari Şeması (Layer Diagram)

```mermaid
graph TD
    subgraph UI ["🎨 Presentation (ui/)"]
        ChatDock["chat_dock.gd / .tscn (Streaming, @Mention & Queue UI)"]
        SettingsDialog["settings_dialog.gd / .tscn"]
        UIComponents["MessageBubble / ApprovalCard / ClarificationCard / ActivityGroup / WelcomeCard / RuntimeCard"]
        HistoryPanel["history_panel.gd (Session Drawer)"]
        Theme["sidebar_theme.gd (AISidebarTheme Design System)"]
    end

    subgraph Application ["🤖 Application Layer (core/agent/ & core/chat/ & core/commands/)"]
        AgentRunner["agent_runner.gd (State Machine & Streaming Forwarder)"]
        AgentContext["agent_context.gd (Context Window)"]
        ContextCompactor["context_compactor.gd (Token Optimization)"]
        ChatManager["chat_manager.gd / chat_session.gd (Persistence)"]
        MentionManager["mention_manager.gd (@mention Autocomplete)"]
        SlashCommands["slash_command_manager.gd"]
    end

    subgraph Domain ["🛠️ Domain Layer (tools/ & mutations/ & security/ & verification/)"]
        ToolManager["tool_manager.gd (Progressive Intent Routing)"]
        PrimitiveTools["scene_tools / script_tools / editor_tools"]
        IntentTools["game_intent_tools"]
        UITelemetry["ui_telemetry_tools.gd (Layout Inspection)"]
        MutationService["editor_mutation_service.gd (Undo/Redo)"]
        VerificationPipeline["verification_pipeline.gd (Atomic Syntax Check)"]
        PathPolicy["path_policy.gd (Security Sandbox)"]
        PermissionPolicy["permission_policy.gd (Approval Classification)"]
        ChangeSet["change_set.gd (Diff Engine)"]
    end

    subgraph Runtime ["🐞 Runtime Inspection (core/runtime/)"]
        DebuggerPlugin["debugger_plugin.gd (EditorDebuggerPlugin)"]
        RuntimeBridge["runtime_bridge.gd (Game-side Autoload)"]
        RuntimeObserver["runtime_observer.gd"]
        SourceMapper["source_mapper.gd (Stack-trace Mapping)"]
    end

    subgraph Infrastructure ["🌐 Infrastructure (network/ & providers/ & config/ & state/)"]
        AIProvider["ai_provider.gd (Soyut Arayüz)"]
        OpenAIProvider["openai_compatible_provider.gd (SSE Streaming)"]
        AGYProvider["agy_cli_provider.gd (Antigravity CLI Subprocess)"]
        NetworkManager["network_manager.gd (HTTPClient & Socket Recovery)"]
        SSEParser["sse_parser.gd"]
        Config["api_config.gd (Persistence)"]
        EditorSnapshot["editor_state_snapshot.gd / context_collector.gd (Grounding)"]
    end

    ChatDock --> AgentRunner
    ChatDock --> MentionManager
    ChatDock --> ChatManager
    ChatDock --> SlashCommands
    ChatDock --> UIComponents
    ChatDock --> HistoryPanel
    ChatDock -.->|"AISidebarTheme tokens"| Theme
    SettingsDialog --> Config
    AgentRunner --> AgentContext
    AgentRunner --> ToolManager
    AgentRunner --> AIProvider
    AgentRunner --> VerificationPipeline
    AgentContext --> ContextCompactor
    AgentContext --> EditorSnapshot
    ToolManager --> PrimitiveTools
    ToolManager --> IntentTools
    ToolManager --> UITelemetry
    PrimitiveTools --> MutationService
    PrimitiveTools --> PathPolicy
    PrimitiveTools --> PermissionPolicy
    PrimitiveTools --> VerificationPipeline
    OpenAIProvider --|> AIProvider
    AGYProvider --|> AIProvider
    OpenAIProvider --> NetworkManager
    OpenAIProvider --> SSEParser
    DebuggerPlugin --> RuntimeBridge
    RuntimeBridge --> RuntimeObserver
    RuntimeObserver --> SourceMapper
    SourceMapper --> AgentContext
```

---

## 🧩 Katmanlar ve Sorumlulukları

### 1. 🎨 Presentation Katmanı (`ui/`)
* **[`chat_dock.gd`](addons/godot_sidebar_ai/ui/docks/chat_dock.gd):** Sol/sağ dock paneline yerleşen ana sohbet arayüzüdür. Canlı SSE token akışını sohbet baloncuğuna iletir, `@mention` açılır penceresini, mesaj kuyruğunu ve görsel önizleme çipini yönetir.
* **[`sidebar_theme.gd`](addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd):** Merkezi tema motoru (`AISidebarTheme`). Semantik renk tokenları, tipografi ve tutarlı StyleBox tanımlarını barındırır.
* **[`message_bubble.gd`](addons/godot_sidebar_ai/ui/components/message_bubble.gd):** Metin seçimi (`selection_enabled`), `Ctrl+C` kısayolu ve akıcı BBCode link formatı sunan modüler mesaj baloncuğu.
* **[`approval_card.gd`](addons/godot_sidebar_ai/ui/components/approval_card.gd):** Dosya yazma/silme gibi kritik işlemlerde kullanıcıdan onay isteyen tek yüzeyli interaktif kart.
* **[`clarification_card.gd`](addons/godot_sidebar_ai/ui/components/clarification_card.gd):** Ajan kritik bir belirsizlikte durduğunda (`WAITING_FOR_CLARIFICATION`) gösterilen soru kartı; tek tık seçenek butonları ve serbest metin girişi sunar.
* **[`activity_group.gd`](addons/godot_sidebar_ai/ui/components/activity_group.gd):** Ajanın arka plan araç çağrılarını ve doğrulama adımlarını katlanabilir grupta toplayan bileşen.
* **[`history_panel.gd`](addons/godot_sidebar_ai/ui/components/history_panel.gd):** Geçmiş sohbet oturumlarını listeleme, arama ve yükleme paneli.
* **[`welcome_card.gd`](addons/godot_sidebar_ai/ui/components/welcome_card.gd):** Boş sohbet durumunda hızlı başlangıç önerileri sunan karşılama kartı.

### 2. 🤖 Application Katmanı (`core/agent/`, `core/chat/`, `core/commands/`)
* **[`agent_runner.gd`](addons/godot_sidebar_ai/core/agent/agent_runner.gd):** Ajan durum makinesini (State Machine) yönetir (`IDLE ➔ PLANNING ➔ EXECUTING ➔ OBSERVING ➔ VERIFYING ➔ COMPLETED`, ayrıca `WAITING_FOR_APPROVAL` ve `WAITING_FOR_CLARIFICATION`).
* **[`context_compactor.gd`](addons/godot_sidebar_ai/core/agent/context_compactor.gd):** Eski araç çıktılarını 1-2 satırlık özetlere dönüştürerek token tasarrufu sağlar.
* **[`chat_manager.gd`](addons/godot_sidebar_ai/core/chat/chat_manager.gd) / [`chat_session.gd`](addons/godot_sidebar_ai/core/chat/chat_session.gd):** Oturum kalıcılığı. Konuşmalar projeye bağlı `user://sidebar_ai_chats/` dizininde izole JSON dosyaları olarak saklanır; API anahtarı veya token asla diske yazılmaz.
* **[`mention_manager.gd`](addons/godot_sidebar_ai/core/chat/mention_manager.gd):** `@` yazıldığında dosya ve sahne düğümlerini tarayıp güvenli context limitiyle prompta enjekte eder.
* **[`slash_command_manager.gd`](addons/godot_sidebar_ai/core/commands/slash_command_manager.gd):** `/` ile başlayan hızlı komutları çözümler.

### 3. 🛠️ Domain Katmanı (`core/tools/`, `core/mutations/`, `core/security/`, `core/verification/`)
* **[`script_tools.gd`](addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd):** Cerrahi kod düzenleme (`replace_file_content`), toplu dosya yazma (`write_files`) ve silme (`delete_file`).
* **[`editor_mutation_service.gd`](addons/godot_sidebar_ai/core/mutations/editor_mutation_service.gd):** Düğüm ekleme/silme ve özellik değişikliklerini `EditorUndoRedoManager`'a kaydeder.
* **[`verification_pipeline.gd`](addons/godot_sidebar_ai/core/verification/verification_pipeline.gd):** Diske yazılmadan önce GDScript sözdizimini derleme motoruyla doğrular.
* **[`permission_policy.gd`](addons/godot_sidebar_ai/core/security/permission_policy.gd):** İşlemleri yetki sınıflarına ayırır ve `MANUAL` / `AUTO` / `FULL_AUTO` onay moduna göre kullanıcı onayı gerekip gerekmediğine karar verir.
* **[`ui_telemetry_tools.gd`](addons/godot_sidebar_ai/core/tools/telemetry/ui_telemetry_tools.gd):** Godot Control/Container hiyerarşisini, taşma ve tema detaylarını denetleyen telemetri motoru.

### 4. 🐞 Runtime Inspection Katmanı (`core/runtime/`)
* **[`debugger_plugin.gd`](addons/godot_sidebar_ai/core/runtime/debugger_plugin.gd):** `EditorDebuggerPlugin` tabanlı köprü; editör ile çalışan oyun arasında mesaj kanalı kurar.
* **[`runtime_bridge.gd`](addons/godot_sidebar_ai/core/runtime/runtime_bridge.gd):** Oyun tarafına autoload olarak eklenen karşı taraf; canlı sahne ağacı ve düğüm özelliklerini sorgulanabilir kılar (`inspect_runtime_tree`, `inspect_runtime_node`).
* **[`runtime_observer.gd`](addons/godot_sidebar_ai/core/runtime/runtime_observer.gd):** Çalışma zamanı hatalarını gözlemler ve `RuntimeObservation` modeline dönüştürür.
* **[`source_mapper.gd`](addons/godot_sidebar_ai/core/runtime/source_mapper.gd):** Stack trace girdilerini projedeki gerçek kaynak dosya ve satırlara eşler; self-healing döngüsünün doğru scripti bulmasını sağlar.

### 5. 🌐 Infrastructure Katmanı (`core/network/`, `core/providers/`, `core/state/`)
* **[`network_manager.gd`](addons/godot_sidebar_ai/core/network/network_manager.gd):** Canlı SSE akışı ve soket kapanışı (`Status: 8`) kurtarma motoru. Windows loopback için `localhost` $\rightarrow$ `127.0.0.1` normalizasyonu ve `Connection: close` yönetimi.
* **[`openai_compatible_provider.gd`](addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd):** 9Router, OpenRouter, yerel Ollama ve LM Studio ile iletişim kuran sağlayıcı. Vision yeteneği, diskten bağımsız çalışan saf `model_supports_vision()` fonksiyonu ile belirlenir ve `vision_capable` ayarıyla geçersiz kılınabilir.
* **[`agy_cli_provider.gd`](addons/godot_sidebar_ai/core/providers/agy_cli_provider.gd):** Resmi Google Antigravity CLI'ını (`agy`) kalıcı alt süreç olarak çalıştırır; çift yönlü NDJSON akışıyla HTTP katmanı olmadan doğrudan oturum açar. Görsel (Vision) girdisini desteklemez.
* **[`editor_state_snapshot.gd`](addons/godot_sidebar_ai/core/state/editor_state_snapshot.gd) / [`context_collector.gd`](addons/godot_sidebar_ai/core/state/context_collector.gd):** Aktif sahne, seçili düğüm ve açık script gibi editör durumunu toplayıp prompt bağlamına (grounding) ekler.

---

## 🧪 Test Mimarisi

Birim, mantık ve entegrasyon testleri üç ayrı seviyede koşulur:

1. **Headless GDScript Compilation & Scene Load Validation:**
```bash
powershell -ExecutionPolicy Bypass -File .\typecheck.ps1
```
*Tüm eklenti (`addons/godot_sidebar_ai/`) ve test (`tests/`) scriptlerini (129 GDScript, 4 Sahne) statik olarak yükleyip derleme hatalarını doğrular.*

2. **Headless Master Test Suite (55 Test Paketi / 331 Assertion):**
```bash
godot --headless --path . -s res://tests/test_runner.gd
```

3. **Canlı 9Router Entegrasyon Testi (Canlı Socket + Model Çağrısı):**
```bash
godot --headless --path . -s res://tests/integration/test_real_9router_live.gd
```
