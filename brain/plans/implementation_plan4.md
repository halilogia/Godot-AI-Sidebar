# Slash Command (/) Sistemi (Claude Code Benzeri) Uygulama Planı

Bu plan, Godot AI Sidebar için Claude Code benzeri, doğal dille yazmak yerine sık kullanılan ajan görevlerini tek satırda tetikleyen **Slash Command (`/`)** sistemini mevcut mimariyle uyumlu şekilde hayata geçirmeyi amaçlar.

---

## User Review Required

> [!IMPORTANT]
> - **Mevcut Altyapı Korunumu:** Slash komutları sıfırdan paralel bir ajan veya HTTP mekanizması kurmaz; doğrudan `AISidebarAgentRunner`, `AISidebarToolManager`, `AISidebarVerificationPipeline` ve `AISidebarPermissionPolicy` sistemlerini kullanır.
> - **Sohbet Geçmişi Güvencesi (`/clear`):** `/clear` komutu yalnızca aktif ajan çalışma/görev hafızasını sıfırlar; Chat Management oturumunu veya sohbet geçmişini ASLA silmez.
> - **Kapsam Sınırı:** İlk sürümde `/git`, `/web`, `/commit`, `/deploy`, `/custom`, `/plan` komutları implement edilmeyecektir (gelecekte eklenecektir).

---

## Proposed Changes

### 1. Slash Command Çekirdek Mimarisi (Core Architecture)

#### [NEW] [slash_command_manager.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/commands/slash_command_manager.gd)
- **Komut Kayıt Modeli (`SlashCommand`):**
  - `name`: Komut adı (örn: `help`, `inspect`, `debug`)
  - `description`: Kısa açıklama
  - `usage`: Örnek kullanım (örn: `/inspect [node_or_path]`)
  - `risk`: `RiskLevel` (`READ_ONLY`, `WRITE`, vb.)
  - `handler`: Komutu icra eden veya agent promptu üreten fonksiyon
- **Parser & Eşleştirici:**
  - `parse(text: String) -> Dictionary`: Metnin `/` ile başlayıp başlamadığını, komut adını ve argümanlarını ayrıştırır (`{"is_command": bool, "name": String, "args": String, "command": Dictionary}`).
  - `detect_slash_query(text: String, caret_pos: int) -> Dictionary`: İmleç konumunda aktif `/` araması olup olmadığını tespit eder.
  - `get_suggestions(query: String) -> Array[Dictionary]`: Yazılan harflere göre (örn: `/de` ➔ `/debug`) eşleşen komutları önerir.
- **10 Çekirdek Komutun Tanımlanması:**
  1. `/help`: Mevcut tüm slash komutlarını, açıklamalarını ve örneklerini formatlı bir rehber olarak gösterir (LLM çağrısı gerektirmez).
  2. `/clear`: Ajanın çalışma bağlamını (`agent_context.clear()`) sıfırlar; geçmişi silmez, UI'da bildirim gösterir.
  3. `/analyze`: Projeyi/sahneyi inceler (`READ_ONLY`), dosya değiştirmez.
  4. `/inspect`: Argümansızsa aktif sahne + seçili düğüm + ağaç bilgisi; argümanlıysa hedef düğüm/dosya detaylarını inceler.
  5. `/test`: Testleri ve script doğrulamalarını çalıştırır, hata varsa ajana geri besler.
  6. `/run`: Projeyi `play_game` ile çalıştırır ve `AISidebarRuntimeObservation` ile izler.
  7. `/debug`: Runtime/editör loglarını ve stack trace'i analiz eder, self-healing kancalarını tetikler.
  8. `/fix`: Son tespit edilen hata üzerinde normal ajan tamir döngüsünü başlatır (Verification Pipeline ve Auto Approve kuralları devrededir).
  9. `/review`: Son değişiklikleri (bug, Godot 4.7 uyumluluğu, runtime riski, kırık referanslar) denetler ve raporlar.
  10. `/explain`: Verilen dosya/düğüm (`/explain Player`, `/explain res://scripts/Player.gd`) veya son değişiklikleri (`/explain last`) açıklar.

---

### 2. UI ve Otomatik Tamamlama Entegrasyonu (UI / Autocomplete)

#### [MODIFY] [message_bubble.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/components/message_bubble.gd)
- `role == "command"` veya `role == "slash_command"` desteği eklenir.
- Komut mesajı mor/vurgulu kenarlık (`Color(0.6, 0.4, 0.9, 0.8)`), `⚡ Slash Command` rozeti ve temiz komut kartı görünümüyle normal chat mesajından belirgin şekilde ayırt edilir.

#### [MODIFY] [chat_dock.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/docks/chat_dock.gd)
- **Autocomplete Tetikleyici (`_on_input_text_changed`):**
  - Kullanıcı `/` yazdığında slash komut önerileri listelenir (`[CMD] /inspect - Godot bağlamını incele`).
  - `ArrowUp` / `ArrowDown` ile menüde gezilir.
  - `Enter` veya `Tab` tuşuna basıldığında seçilen komut (`/inspect `) input alanına tamamlanır ve imleç sonuna yerleşir.
- **Komut İcra Yolu (`_on_send_pressed`):**
  - Girilen metin `AISidebarSlashCommandManager.parse(user_text)` ile denetlenir.
  - Eğer geçerli bir slash komutu ise:
    - `/help` ve `/clear` yerel olarak anında icra edilir.
    - Diğer komutlar (`/inspect`, `/debug`, `/fix` vb.) UI'a özel komut balonu ekler, ardından ajan döngüsünü uygun araç kısıtları ve bağlamla başlatır.

---

### 3. Test Paketi (Automated Tests)

#### [NEW] [test_slash_commands.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/tests/test_slash_commands.gd)
- Test 1: Parser - Temel komut ve argüman ayrıştırma (`/inspect Player` ➔ `name="inspect"`, `args="Player"`).
- Test 2: Autocomplete / Query Detection (`/` ve `/de` sorgularının doğru komutları filtrelemesi).
- Test 3: `/help` komutu çıktısı ve tüm 10 komutun varlığı.
- Test 4: `/clear` komutunun ajan bağlamını temizlemesi ama chat oturumunu silmemesi.
- Test 5: `/inspect` (argümansız ve argümanlı) prompt/bağlam üretimi.
- Test 6: `/analyze` (Read-only kısıtı).
- Test 7: `/run` ve `/debug` (Runtime altyapısıyla uyumluluk).
- Test 8: `/fix` (Verification Pipeline ve approval entegrasyonu).
- Test 9: `/review` ve `/explain` komut doğrulamaları.
- Test 10: Geçersiz komut (`/invalid_cmd`) durumunun güvenli ele alınışı.

#### [MODIFY] [test_runner.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/tests/test_runner.gd)
- `TestSlashCommands` test paketinin ana koşucuya eklenmesi.

---

## Verification Plan

### Automated Tests
```powershell
# 1. Master Unit Test Koşucusu (Tüm 48 paket)
godot --headless --path . -s "res://tests/test_runner.gd"

# 2. GDScript Sözdizimi Kontrolü
godot --headless --path . --check-only
```

### Proje Senkronizasyonu
```powershell
pwsh -File "scripts/sync-example.ps1" -All
```
