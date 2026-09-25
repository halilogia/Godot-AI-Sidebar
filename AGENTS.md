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
   * UI katmanında (`ui/`) hiçbir HTTP düğümü veya ağ mantığı bulunmaz. Provider ve `NetworkManager` `core/agent/agent_host.gd` (`AISidebarAgentHost`) içinde kurulur; kompozisyon kökü `plugin.gd` host'u kurar ve `ChatDock`'a enjekte eder. `AgentRunner` sinyallerini presenter'lar (`ui/presenters/`) ve `TaskController` dinler; `ChatDock` yalnızca sahne düğümlerini bağlar, birimleri kompoze eder ve host'un model listesi / hazırlık olaylarını dinler (bkz. `ARCHITECTURE.md`).
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

Yeni bir özellik veya düzeltme yapıldığında tek komut koşulur; herhangi bir adım kırmızıysa iş bitmiş sayılmaz:

```bash
# Typecheck (addons/ + tests/ + tools/) + sıkı uyarı cırcırı + tüm birim testleri. Godot'u kendisi bulur
# (-GodotPath > $env:GODOT_BIN > PATH > Masaüstü). Fail-closed: hata -> exit 1.
powershell -ExecutionPolicy Bypass -File .\verify.ps1

# Ağ/provider davranışı değiştiyse: canlı 9Router testini de ekle (127.0.0.1:20128)
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Live
```

* Test/dosya sayıları dokümanlara elle yazılmaz (hızla eskir); güncel sayı `verify.ps1` çıktısındadır.
* Adımlar ayrı ayrı gerekirse: `typecheck.ps1`, `tests/test_runner.gd`, `tests/integration/test_real_9router_live.gd`.
* **Uyarı cırcırı:** `addons/` için 5 sıkı uyarı türü (`untyped_declaration`, `unsafe_method_access`, `unsafe_property_access`, `unsafe_call_argument`, `unsafe_cast`) dosya başına `tools/typecheck_baseline.json` ile karşılaştırılır; bir dosyada sayı artarsa `verify.ps1` kırmızıdır. Yeni dosya tabanda yoksa sıfır uyarıyla başlamalıdır (tam tipli yazılır). Tip ekleyip sayıyı düşürdüysen tabanı düşür: `godot --headless --path . -s res://tools/warning_report.gd -- --update-baseline` (tabanı asla yukarı çekmek için kullanma).

---

## 🔒 6. Güvenlik ve Gizlilik Politikası

* API anahtarları asla kodun içine, commit mesajlarına veya git geçmişine yazılmaz.
* Anahtarlar `$env:GODOT_AI_TEST_API_KEY` veya git-ignored `.env` dosyasından okunur.
* `res://project.godot`, `.git/**` ve `addons/godot_sidebar_ai/**` dosyaları `PathPolicy` kalkanıyla korunur.

---

## 📦 7. Chat Export Invariantı (Mimari Kural)

* Yeni kullanıcı-görünür özellik veya yeni transcript/task event'i eklendiğinde, verinin Chat Export / Task Export / Copy Chat çıktılarında temsil edilip edilmediği **bilinçli olarak değerlendirilir**.
* Tek kaynak `TaskTranscript` / `ChatSession` verisidir; aynı bilgi ikinci kez modellenmez, exporter gereksiz büyütülmez.
* Export'a alınmayan veri (örn. Action Summary: UI-only, tool event'lerden türetilebilir) raporda gerekçesiyle belirtilir.
* Bilinmeyen gelecek event tipleri `_` fallback ile ham görünür kalır (sessiz kayıp yok).
* Kapsam testleri: `tests/test_export_coverage.gd`.

---

## 🔧 8. Refactor Kuralları

Aktif plan ve ilerleme: `docs/REFACTOR_PLAN.md`.

1. **Refactor commit'i davranış değiştirmez.** Kod taşınır; mantık, metin ve görünüm aynen kalır.
2. **Yolda bulunan bug ayrı commit'te düzeltilir**, onu kanıtlayan testle birlikte.
3. **Her adımdan sonra `verify.ps1` yeşil olmalı.** Kırmızıysa adım geri alınır, üstüne yama yapılmaz.
4. **Testler taşınan birime yönlendirilir.** Eski private isimler için geçici delege bırakılmaz.
5. Yeni dosyalar `preload` ile bağlanır ve `AISidebar` önekini korur (bkz. §3.3).
6. **Git çalışma biçimi (tek geliştirici):** Doğrulanmış küçük, atomik commit'ler doğrudan `main`'e push'lanır; dal veya PR zorunlu değildir. Her commit'ten önce typecheck + tüm testler (`verify.ps1`) yeşil olmalı; kırmızı kod `main`'e push'lanmaz. Refactor ve bug düzeltmesi yine ayrı commit'lerdir (madde 1–2).

---

## 📚 9. Doküman Haritası

* `AGENTS.md` — tüm ajanlar için tek giriş noktası (bu dosya).
* `ARCHITECTURE.md` — katmanlar ve veri akışı. `ROADMAP.md` — fazlar. `CHANGELOG.md` — tarihçe (geçmiş sayılar düzeltilmez).
* `docs/KNOWLEDGE.md` — kalıcı teknik bilgi (paylaşılan kaynak). `brain/`, `archives/` git-ignored yerel çalışma alanlarıdır; kalıcı kararlar oradan `docs/`'a taşınır.

---

## 📝 10. Doküman Güncelleme Kuralı

Doküman, onu eskiten değişiklikle **aynı iş kapsamında** güncellenir; sonraya bırakılmaz.

| Değişiklik | Güncellenecek belge |
|---|---|
| `addons/` altına yeni / taşınan / silinen `.gd` | `ARCHITECTURE.md` (test zorunlu kılar: `tests/test_docs_coverage.gd`) |
| Kullanıcının göreceği özellik veya düzeltme | `CHANGELOG.md` → `[Unreleased]` |
| Ürün fazı tamamlandı, yeni özellik planlandı | `ROADMAP.md` (ürün fazları; refactor fazları `docs/REFACTOR_PLAN.md`'de "Refactor Faz N" olarak ayrı tutulur) |
| Sürüm çıkarıldı | `CHANGELOG.md` `[Unreleased]` → sürüm numarası + tarih; README sürüm rozeti |
| Refactor adımı, bulunan bug, faz durumu | `docs/REFACTOR_PLAN.md` |
| Kalıcı teknik öğrenim (motor davranışı, protokol, tuzak) | `docs/KNOWLEDGE.md` |
| Mimari kural değişikliği | `AGENTS.md` |
| Arayüz görünümü değişti | `tools/readme_shots.gd` ile README görselleri yeniden üretilir |
