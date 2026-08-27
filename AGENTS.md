# 🤖 AGENTS.md — Godot AI Core Shared Agent Context & Memory

> **Evrensel Ajan Kılavuzu & Ortak Proje Hafızası**  
> Bu dosya, projede yeni açılan her yapay zekâ sohbetinde (Antigravity, Claude Code, Cursor, Codex, Aider vb.) ajanların projeyi sıfırdan ve eksiksiz anlamasını sağlayan birincil hafıza kaynağıdır.

---

## 🎯 1. Proje Kimliği ve Temel Amaç

* **Proje Adı:** Godot AI Core (Godot AI Sidebar)
* **Hedef Motor:** Godot Engine 4.7+ (GDScript 2.0)
* **Temel Misyon:** Godot Editörüne doğrudan yerleşen, tam Undo/Redo (Ctrl+Z) güvenliğine sahip, canlı SSE streaming destekli, otonom ve genişletilebilir bir yapay zekâ oyun geliştirme asistanı.

---

## 🧭 2. Epistemik Dürüstlük & Gerçeklik Kuralları (Radical Truth)

1. **Kanıt Yoksa İddia Yok:** Bir özelliğin veya testin çalıştığı iddia edilmeden önce somut kanıt aranmalıdır.
2. **Mock ile Gerçek Ağ Ayrımı:**
   * In-memory / MockFastProvider testleri yalnızca iç GDScript mantığını ve durum geçişlerini kanıtlar.
   * Gerçek 9Router / LLM ağ davranışını **sadece `tests/integration/test_real_9router_live.gd`** kanıtlar.
3. **Mümkün vs Gerçekçi:** Bir çözümün teorik olarak mümkün olması ile pratikte hatasız çalışması asla karıştırılmamalıdır.
4. **Hataları Açıkça Kabul Et:** Teşhis hatası yapıldığında savunmaya geçilmemeli, gerçek kök neden açıkça raporlanmalıdır.

---

## 🏛️ 3. Mimari Kurallar ve Katı Standartlar

1. **Clean Architecture & Katı SRP (1 Dosya = 1 İş):**
   * `Presentation (ui/)` asla doğrudan `Infrastructure (network/, providers/)` ile konuşmaz.
   * `ChatDock` içinde hiçbir HTTP düğümü veya ağ mantığı bulunmaz; sadece `AgentRunner` sinyallerini dinler.
2. **Motor Güvenliği & Merkezi Undo/Redo:**
   * Tüm sahne ve düğüm mutasyonları `AISidebarMutationService` üzerinden `EditorUndoRedoManager`'a kaydedilir (`add_do_reference` zorunludur).
3. **Headless CLI Preload Kuralı:**
   * Godot CLI ortamında global `class_name` dizini belleğe yüklenmediği için tüm scriptler birbirini **`const MyClass = preload("res://...")`** ile bağlar.
4. **Cerrahi Dosya Düzenleme (`replace_file_content`):**
   * Büyük dosyalarda gereksiz tam dosya yazımı yerine hedef blok cerrahi olarak değiştirilir ve diske yazılmadan önce `VerificationPipeline` ile doğrulanır.
5. **Context Compaction:**
   * Çok adımlı görevlerde 2 adımdan eski araç çıktıları `AISidebarContextCompactor` ile 1-2 satırlık özetlere dönüştürülür; son 2 araç (`keep_recent_tools: 2`) tam korunur.

---

## 🌐 4. Ağ ve 9Router SSE Protokolü Hafızası

1. **Canlı Akış ve Bitiş Belirteci:**
   * 9Router / Gemini 3.7 Flash akış bitiminde ayrı bir `[DONE]` satırı göndermek yerine 3. chunk'ta `finish_reason: "stop"` gönderir ve TCP soketini kapatır.
   * Bu soket kapanışı (`Status: 8 / DISCONNECT: ResponseAborted`) bir hata değildir; tamponda geçerli içerik veya `finish_reason` varsa `NetworkManager` tarafından başarıyla karşılanır (`_finalize_success`).
2. **Windows Localhost Normalizasyonu:**
   * Windows IPv6 DNS gecikmesini (30 sn) engellemek için tüm URL'ler `127.0.0.1` formatına normalize edilmeli ve `Connection: close` başlığı korunmalıdır.

---

## 🧪 5. Doğrulama ve Test Komutları

Yeni bir özellik veya düzeltme yapıldığında sırasıyla şu komutlar koşulmalıdır:

```bash
# 1. Tüm Birim ve Mantık Testleri (45 Test Paketi / 192 Assertion)
& "C:\Users\Halil Emre\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\Halil Emre\Desktop\GitHub\Private\Godot AI Sidebar" -s "res://tests/test_runner.gd"

# 2. GDScript Derleme / Sözdizimi Kontrolü
& "C:\Users\Halil Emre\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\Halil Emre\Desktop\GitHub\Private\Godot AI Sidebar" --check-only

# 3. Canlı 9Router & Model Entegrasyon Testi (127.0.0.1:20128)
& "C:\Users\Halil Emre\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\Users\Halil Emre\Desktop\GitHub\Private\Godot AI Sidebar" -s "res://tests/integration/test_real_9router_live.gd"
```

---

## 🔒 6. Güvenlik ve Gizlilik Politikası

* API anahtarları asla kodun içine, commit mesajlarına veya git geçmişine yazılmaz.
* Anahtarlar `$env:GODOT_AI_TEST_API_KEY` veya git-ignored `.env` dosyasından okunur.
* `res://project.godot`, `.git/**` ve `addons/godot_sidebar_ai/**` dosyaları `PathPolicy` kalkanıyla korunur.
