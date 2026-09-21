# Implementation Plan: TSCN Verification Pipeline Desteği

Yapay zekânın ürettiği `.tscn` sahne dosyalarını diske yazmadan önce Godot'un `resource_format_text.cpp` ayrıştırıcı kurallarına göre doğrulayan, yapısal veya sözdizimsel hata tespit edildiğinde diske yazımı engelleyip modele kendi kendini düzeltmesi için açık hata geri bildirim dönen doğrulama altyapısı.

> [!IMPORTANT]
> **Auto-Sanitizer Yapılmayacaktır:** Modelin ürettiği dosya hiçbir şekilde sessizce değiştirilmeyecek veya yeniden sıralanmayacaktır. Hata durumunda yazma işlemi durdurulacak, model açık bir hata alacak ve kendi düzeltmesini üretecektir.

---

## Kullanıcı İncelemesi Gerektiren Konular
* Doğrulama hatası aldığında modelin gördüğü hata mesajı formatı: Modelin hatayı tek adımda anlayıp düzeltebilmesi için satır numarası, kural ihlali ve çözüm önerisi açıkça iletilecektir (Örn: `Satır 10: [ext_resource] etiketi geçersiz konumda. Tüm ext_resource blokları en başta yer almalıdır.`).
* Mevcut GDScript doğrulama boru hattı (`validate_script_source`) ve batch bağımlılık çözümleyicisi korunacaktır.

---

## Önerilen Değişiklikler

### 1. Doğrulama Katmanı (Core / Verification)

#### [MODIFY] [verification_pipeline.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/verification/verification_pipeline.gd)
* `validate_tscn_source(source_code: String, file_path: String = "", batch_context: Dictionary = {}) -> Dictionary` fonksiyonu eklenecek:
  1. **Başlık Denetimi:** Dosyanın ilk geçerli etiketinin `[gd_scene ...]` (veya `.tres` ise `[gd_resource ...]`) olduğunu doğrular (`TSCN_MISSING_HEADER`).
  2. **Bölüm Sıralaması (State Machine):**
     * `HEADER -> EXT_RESOURCES -> SUB_RESOURCES -> NODES -> CONNECTIONS`
     * `[sub_resource]`, `[node]` veya `[connection]` sonrasında gelen herhangi bir `[ext_resource]` tespit edilirse -> `TSCN_DISPLACED_EXT_RESOURCE` (Kullanıcının karşılaştığı hata!).
     * `[node]` veya `[connection]` sonrasında gelen `[sub_resource]` tespit edilirse -> `TSCN_DISPLACED_SUB_RESOURCE`.
     * `[connection]` sonrasında gelen `[node]` tespit edilirse -> `TSCN_DISPLACED_NODE`.
  3. **Mükerrer Kaynak Kimliği (Duplicate ID):**
     * Aynı `id` değerine sahip iki `[ext_resource]` -> `TSCN_DUPLICATE_RESOURCE_ID`.
     * Aynı `id` değerine sahip iki `[sub_resource]` -> `TSCN_DUPLICATE_RESOURCE_ID`.
  4. **Kaynak Referans Bütünlüğü (Reference Integrity):**
     * `path="res://..."` referanslarının diskte veya mevcut `batch_context` içinde var olduğunu denetler (`RESOURCE_REFERENCE_NOT_FOUND`).
     * `ExtResource("id")` ile başvurulan `id`'lerin tanımlı `[ext_resource]` listesinde olduğunu denetler (`TSCN_UNDEFINED_RESOURCE_REFERENCE`).
     * `SubResource("id")` ile başvurulan `id`'lerin tanımlı `[sub_resource]` listesinde olduğunu denetler (`TSCN_UNDEFINED_RESOURCE_REFERENCE`).
  5. **Kök Düğüm Denetimi:**
     * `.tscn` dosyasında en az bir geçerli `[node ...]` olduğunu denetler (`TSCN_MISSING_ROOT_NODE`).
* `validate_batch_files(files_arr: Array)` güncellenerek batch içindeki tüm `.tscn` dosyaları için `validate_tscn_source` çağrılacak.

---

### 2. İlkel Araçlar Katmanı (Core / Tools / Primitive)

#### [MODIFY] [script_tools.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd)
* `_create_or_update_script`: Eğer `path.ends_with(".tscn")` ise `validate_tscn_source` çağrılacak; hata varsa dosya diske yazılmadan model için geri döndürülecek.
* `_replace_file_content`: Eğer hedef dosya `.tscn` ise cerrahi düzenleme sonrası oluşan `new_content` için `validate_tscn_source` çağrılacak; hata varsa disk yazımı durdurulacak.
* `_write_files`: Batch doğrulamasında `validate_batch_files` zaten tüm `.tscn` dosyalarını `validate_tscn_source` ile kontrol edecek.

---

### 3. Test ve Doğrulama Katmanı

#### [NEW] [test_tscn_verification.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/tests/test_tscn_verification.gd)
Kullanıcının talep ettiği tüm test senaryolarını içeren özel test paketi:
1. **Test 1:** Geçerli TSCN -> `PASS`
2. **Test 2:** `[ext_resource]` yanlış sırada (sub_resource veya node sonrasında) -> `FAIL` (Displaced ext_resource)
3. **Test 3:** Duplicate resource ID (`id="1"` iki kez tanımlı) -> `FAIL`
4. **Test 4:** Bozuk/olmayan resource referansı (`ExtResource("99")` veya diskte/batch'te olmayan script) -> `FAIL`
5. **Test 5:** Verification `FAIL` olduğunda dosyanın diskte kesinlikle değişmediği / oluşturulmadığı kanıtı.
6. **Test 6:** Düzeltildikten sonra geçerli TSCN -> `PASS` ve dosya diske başarıyla yazılır.

#### [MODIFY] [test_runner.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/tests/test_runner.gd)
* Yeni `TestTSCNVerification` paketi ana test koşucusuna dahil edilecek.

---

## Doğrulama Planı

### Otomatik Testler
1. Yeni test paketinin doğrudan koşulması:
   ```powershell
   godot --headless --path . -s "res://tests/test_runner.gd"
   ```
2. GDScript sözdizimi denetimi:
   ```powershell
   godot --headless --path . --check-only
   ```
3. Senkronizasyon ile Belgeler ve Examples projelerine güncellemeyi aktarma:
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File ".\scripts\sync-example.ps1" -All
   ```
