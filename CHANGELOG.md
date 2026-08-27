# 📝 Changelog

Tüm önemli değişiklikler bu dosyada kronolojik olarak listelenmektedir.

Biçim: [Keep a Changelog](https://keepachangelog.com/tr/1.0.0/), 
Sürümleme: [Semantic Versioning](https://semver.org/lang/tr/).

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
