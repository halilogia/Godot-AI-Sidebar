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
        ChatDock["chat_dock.gd / .tscn (Streaming & @Mention UI)"]
        SettingsDialog["settings_dialog.gd / .tscn"]
        UIComponents["MessageBubble / ApprovalCard / ActivityGroup"]
    end

    subgraph Application ["🤖 Application Layer (agent/ & chat/)"]
        AgentRunner["agent_runner.gd (State Machine & Streaming Forwarder)"]
        AgentContext["agent_context.gd (Context Window)"]
        ContextCompactor["context_compactor.gd (Token Optimization)"]
        MentionManager["mention_manager.gd (@mention Autocomplete)"]
    end

    subgraph Domain ["🛠️ Domain Layer (tools/ & mutations/ & security/ & verification/)"]
        ToolManager["tool_manager.gd (Progressive Intent Routing)"]
        PrimitiveTools["scene_tools / script_tools (replace_file_content)"]
        IntentTools["game_intent_tools"]
        MutationService["editor_mutation_service.gd (Undo/Redo)"]
        VerificationPipeline["verification_pipeline.gd (Atomic Syntax Check)"]
        PathPolicy["path_policy.gd (Security Sandbox)"]
        ChangeSet["change_set.gd (Diff Engine)"]
    end

    subgraph Infrastructure ["🌐 Infrastructure (network/ & providers/ & config/)"]
        AIProvider["ai_provider.gd (Soyut Arayüz)"]
        OpenAIProvider["openai_compatible_provider.gd (SSE Streaming)"]
        NetworkManager["network_manager.gd (HTTPClient & Socket Recovery)"]
        SSEParser["sse_parser.gd"]
        Config["api_config.gd (Persistence)"]
    end

    ChatDock --> AgentRunner
    ChatDock --> MentionManager
    ChatDock --> UIComponents
    SettingsDialog --> Config
    AgentRunner --> AgentContext
    AgentRunner --> ToolManager
    AgentRunner --> AIProvider
    AgentContext --> ContextCompactor
    ToolManager --> PrimitiveTools
    ToolManager --> IntentTools
    PrimitiveTools --> MutationService
    PrimitiveTools --> PathPolicy
    PrimitiveTools --> VerificationPipeline
    OpenAIProvider --|> AIProvider
    OpenAIProvider --> NetworkManager
    OpenAIProvider --> SSEParser
```

---

## 🧩 Katmanlar ve Sorumlulukları

### 1. 🎨 Presentation Katmanı (`ui/`)
* **[`chat_dock.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/docks/chat_dock.gd):** Sol/sağ dock paneline yerleşen sohbet arayüzüdür. Canlı SSE token akışını sohbet baloncuğuna iletir, `@mention` açılır penceresini yönetir.
* **[`message_bubble.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/components/message_bubble.gd):** Metin seçimi (`selection_enabled`), `Ctrl+C` kısayolu ve akıcı BBCode link formatı sunan modüler mesaj baloncuğu.
* **[`approval_card.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/components/approval_card.gd):** Dosya yazma/silme gibi kritik işlemlerde kullanıcıdan onay isteyen tek yüzeyli interaktif kart.

### 2. 🤖 Application Katmanı (`core/agent/` & `core/chat/`)
* **[`agent_runner.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/agent/agent_runner.gd):** Ajan durum makinesini (State Machine) yönetir (`IDLE ➔ PLANNING ➔ EXECUTING ➔ OBSERVING ➔ VERIFYING ➔ COMPLETED`).
* **[`context_compactor.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/agent/context_compactor.gd):** Eski araç çıktılarını 1-2 satırlık özetlere dönüştürerek token tasarrufu sağlar.
* **[`mention_manager.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/chat/mention_manager.gd):** `@` yazıldığında dosya ve sahne düğümlerini tarayıp güvenli context limitiyle prompta enjekte eder.

### 3. 🛠️ Domain Katmanı (`core/tools/`, `core/mutations/`, `core/security/`)
* **[`script_tools.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd):** Cerrahi kod düzenleme (`replace_file_content`), toplu dosya yazma (`write_files`) ve silme (`delete_file`).
* **[`editor_mutation_service.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/mutations/editor_mutation_service.gd):** Düğüm ekleme/silme ve özellik değişikliklerini `EditorUndoRedoManager`'a kaydeder.
* **[`verification_pipeline.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/verification/verification_pipeline.gd):** Diske yazılmadan önce GDScript sözdizimini derleme motoruyla doğrular.

### 4. 🌐 Infrastructure Katmanı (`core/network/`, `core/providers/`)
* **[`network_manager.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/network/network_manager.gd):** Canlı SSE akışı ve soket kapanışı (`Status: 8`) kurtarma motoru. Windows loopback için `localhost` $\rightarrow$ `127.0.0.1` normalizasyonu ve `Connection: close` yönetimi.
* **[`openai_compatible_provider.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd):** 9Router, OpenRouter, yerel Ollama ve LM Studio ile iletişim kuran sağlayıcı.

---

## 🧪 Test Mimarisi

Birim ve entegrasyon testleri iki ayrı seviyede koşulur:

1. **Headless Master Suite (45 Test Paketi / 192 Assertion):**
```bash
godot --headless -s res://tests/test_runner.gd
```
2. **Canlı 9Router Entegrasyon Testi (Canlı Socket + ag/gemini-3.7-flash-low):**
```bash
godot --headless -s res://tests/integration/test_real_9router_live.gd
```ant ve string dönüşümleri)
2. `test_path_policy.gd` (Traversal engelleme ve korumalı dosya kalkanı)
3. `test_change_set.gd` (Diff motoru doğrulaması)
4. `test_sse_parser.gd` (SSE ve thinking blok ayrıştırma)
5. `test_tool_manager.gd` (Progressive discovery `search_tools`)
6. `test_agent_context.gd` (Bağlam ve zemin durumu)
7. `test_agent_runner_state.gd` (Ajan durum geçişleri)
