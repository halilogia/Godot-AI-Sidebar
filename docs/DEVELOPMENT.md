# Geliştirme Rehberi (DEVELOPMENT)

Bu repo nasıl geliştirilir, doğrulanır ve bakımı yapılır: tek kanonik rehber. Ürünü, mimariyi veya araştırma bulgularını tekrar etmez; gerektiğinde ilgili belgeye bağlantı verir.

| Belge | Konusu |
|---|---|
| [`README.md`](../README.md) | Ürün: ne yapar, nasıl kurulur ve kullanılır |
| [`ARCHITECTURE.md`](../ARCHITECTURE.md) | Sistem tasarımı, katmanlar, dosya listesi |
| [`AGENTS.md`](../AGENTS.md) | Kodlama ajanlarının (ve geliştiricinin) uyması gereken kurallar |
| [`KNOWLEDGE.md`](KNOWLEDGE.md) | Godot / 9Router / AGY hakkında araştırılıp kanıtlanmış teknik gerçekler |
| [`REFACTOR_PLAN.md`](REFACTOR_PLAN.md) | Refactor fazlarının geçmişi, kararları ve bulunan bug'lar |
| [`CHANGELOG.md`](../CHANGELOG.md) | Kullanıcıya görünen değişiklikler |
| **`DEVELOPMENT.md`** (bu belge) | Yerel geliştirme, doğrulama ve bakım akışı |

---

## 1. Geliştirme ortamı

* **Godot 4.7.2-stable** (CI da aynı sürümü indirir: `.github/workflows/verify.yml` → `GODOT_VERSION`).
* Betikler PowerShell'dir: Windows'ta yerleşik `powershell`, Linux/macOS'ta `pwsh` (CI böyle çalışır).
* Godot ikilisi şu sırayla bulunur ([`tools/find_godot.ps1`](../tools/find_godot.ps1)): `-GodotPath` parametresi → `$env:GODOT_BIN` → `PATH` (`godot` / `godot.exe`) → Masaüstünde `*4.7*.exe`, yoksa `Godot*.exe`.
* Git-ignored yerel dosyalar: `addons/godot_sidebar_ai/config.json` (eklenti ayarları), `.env` (canlı test anahtarı). İkisi de asla commit'lenmez.

## 2. Çalışma biçimi

Tek geliştirici + AI ajanları; kurallar [`AGENTS.md`](../AGENTS.md) §8'de. Özet:

1. Küçük, atomik değişiklik. Refactor davranış değiştirmez; bulunan bug ayrı commit'te, düzeltme olmadan kırmızı olan testle düzeltilir.
2. Commit'ten önce `verify.ps1` yeşil (bkz. §3). Kırmızı kod `main`'e gitmez.
3. Doğrulanmış commit doğrudan `main`'e push'lanır; dal / PR zorunlu değil. CI her push'ta aynı doğrulamayı tekrarlar (§11).
4. Aynı iş kapsamında ilgili belge güncellenir ([`AGENTS.md`](../AGENTS.md) §10 tablosu).

## 3. `verify.ps1` — tek komutluk doğrulama

```bash
powershell -ExecutionPolicy Bypass -File .\verify.ps1
```

Sırayla koşar; bir adım kırmızıysa sonrakiler koşmaz ve çıkış kodu 1 olur:

| Adım | Ne yapar | Yeşil sayılma koşulu |
|---|---|---|
| 1. Typecheck | `typecheck.ps1` → `tools/typecheck.gd` (§4) | Çıkış 0 ve çıktıda fatal script hatası yok |
| 1b. Strict warnings | `tools/warning_report.gd` (§5) | Çıkış 0 **ve** `[WARNINGS OK]` satırı |
| 2. Unit tests | `tests/test_runner.gd` (§6) | Çıkış 0 **ve** `ALL TESTS PASSED` satırı |
| 3. Live (yalnız `-Live`) | `tests/integration/test_real_9router_live.gd` (§8) | Çıkış 0 **ve** `LIVE TEST PASSED` satırı |

Parametreler: `-GodotPath <yol>`, `-Live`. Test / dosya sayıları belgelere elle yazılmaz; güncel sayı bu komutun çıktısındadır.

`verify.ps1` motorun kendi `ERROR:` / `WARNING:` satırlarını göstermez. Bir değişikliğin yeni motor hatası getirip getirmediğine bakmak için test runner'ı doğrudan çalıştırıp çıktıyı öncekiyle karşılaştır (§14).

## 4. GDScript typecheck

```bash
powershell -ExecutionPolicy Bypass -File .\typecheck.ps1
```

`addons/godot_sidebar_ai/`, `tests/` ve `tools/` altındaki her `.gd`'yi yükleyip `reload()` ile derler, her `.tscn`'yi yükleyip örnekler. `scripts/` (demo) kapsam dışıdır.

Yakalamadıkları: tipsiz değişken üzerinden var olmayan üyeye erişim, sinyal–handler argüman sayısı, çalışma anında çözülen `load()` yolları. Bunların bir kısmını testler görür (`StaticReferenceTests`, §6). İç üye adı değiştiren bir değişiklikte `tests/diagnostic/` ve `tools/` klasörleri de grep ile taranmalıdır.

## 5. Sıkı uyarı cırcırı ve `tools/typecheck_baseline.json`

```bash
# Ölç ve tabanla karşılaştır (verify.ps1 adım 1b)
godot --headless --path . -s res://tools/warning_report.gd
# Tabanı yeniden yaz
godot --headless --path . -s res://tools/warning_report.gd -- --update-baseline
```

`addons/godot_sidebar_ai/` için beş uyarı türü dosya başına sayılır: `untyped_declaration`, `unsafe_method_access`, `unsafe_property_access`, `unsafe_call_argument`, `unsafe_cast`. Bir dosyada bir türün sayısı tabandakinden fazlaysa adım kırmızıdır. Tabanda olmayan yeni dosya sıfır uyarıyla başlamalıdır.

**Tabanı güncelleme kuralı:**
* Güncellenebilir: tip ekleyerek sayıları **düşürdüğünde** (commit'te düşüşü belirt).
* Güncellenmez: bir artışı "yeşile çevirmek" için. Artış varsa kodu düzelt.
* Tip eklemek bir uyarıyı başka türe kaydırabilir (ör. alıcının tipi bilinince "method on Variant", "Variant argument"a dönüşür). Toplam düşüyorsa taban güncellenebilir; commit mesajında kaymayı açıkla.
* Sayı yalnızca birkaç adet iyileşti diye ayrı commit açma; tabanı bir sonraki tip işiyle birlikte düşür.

Neden alt süreç ve seviye 2 kullanıldığı (Godot 4.7 headless'ta uyarı davranışı): [`KNOWLEDGE.md` → GDScript Derleme ve Önbellek Davranışı](KNOWLEDGE.md).

## 6. Testler

```bash
godot --headless --path . -s res://tests/test_runner.gd
```

* `tests/test_runner.gd` birim / mantık paketlerini koşar; her paket `run() -> {name, passed, failed, errors}` döndürür. Hiç assertion koşmayan veya çöken paket başarısız sayılır (fail-closed).
* Paketler `_init` içinde, SceneTree kökü olmadan koşar: testlerde düğümleri ağaca eklemeye güvenme. Dock testlerinde `_ready()` elle çağrılır; editör dışında `_ready` UI buton bağlantılarından önce döner.
* Yeni test dosyası yalnızca yeni birim için açılır; mümkünse mevcut pakete kontrol eklenir. Yeni paket `test_runner.gd`'deki listeye eklenir.
* Testler bileşenlerin public API'si üzerinden yazılır.
* Arayüz metni kontrol eden testler beklenen metni `AISidebarI18n.get_text` / `translate` ile üretir; sabit İngilizce/Türkçe metin yazılmaz.
* Refactor'dan önce sabitleme (karakterizasyon) testi yazılır ve testin gerçekten yakaladığı, kod kasıtlı bozularak (mutasyon) gösterilir.

**Runner dışındaki betikler:**

| Betik | Ne zaman |
|---|---|
| `tests/integration/test_planning_flow.gd` | Planlama / netleştirme / plan onayı akışı değiştiğinde (sahte provider, LLM'siz) |
| `tests/integration/test_agy_readiness_scenarios.gd` | AGY provider hazırlık / gönderim yolu değiştiğinde (gerçek AGY CLI gerekir) |
| `tests/integration/test_real_agy_live.gd` | AGY ile gerçek iki turlu konuşma kontrolü (gerçek AGY CLI gerekir) |
| `tests/integration/test_real_9router_live.gd` | Bkz. §8 |
| `tests/test_reality_probe.gd` | Elle hızlı gözden geçirme turu (yerel), bkz. [`tests/diagnostic/README.md`](../tests/diagnostic/README.md) |

Hepsi `godot --headless --path . -s res://<yol>` ile çalışır.

## 7. Test izolasyonu ve `config.json`

* Test sonucu geliştiricinin kişisel ayarına bağlı olamaz. `tests/test_runner.gd` koşu başında `addons/godot_sidebar_ai/config.json` byte'larını `user://test_runner_user_config.backup`'a alır, paketleri config'siz (varsayılanlar: onay modu MANUAL, dil TR; CI ile aynı) koşar ve sonunda byte'ları birebir geri yazar. Koşu yarıda çökerse bir sonraki koşu önce yedeği geri yükler.
* Runner dışında config'e yazan bir betik veya test (dil değiştirme, ayar kaydı) dosyanın byte'larını önce saklar, sonunda birebir geri yazar; başta dosya yoksa oluşanı siler. Deseni `tests/test_i18n.gd` T8'de görebilirsin.
* Test için gerçek `user://` / `res://` dosyası oluşturan test, onları kendisi temizler. Oturum yazan testler oluşturdukları oturumları siler.

## 8. `verify.ps1 -Live`

```bash
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Live
```

`127.0.0.1:20128`'de çalışan 9Router'a gerçek istek atar; ağ davranışını kanıtlayan tek test budur (mock testleri kanıt değildir, [`AGENTS.md`](../AGENTS.md) §2). API anahtarı `$env:GODOT_AI_TEST_API_KEY` veya git-ignored `.env` dosyasından okunur; koda, commit'e veya sohbete yazılmaz.

**Ne zaman zorunlu:** `core/network/`, `core/providers/`, SSE ayrıştırma, `AgentHost` provider kurulumu veya istek / yanıt akışını etkileyen değişikliklerde. CI'da koşmaz (servis yereldir).

## 9. Editörde duman testi

Headless testler gerçek editör hissini, GUI yerleşimini ve `EditorInterface` gerektiren araç yollarını kanıtlamaz. Güncel kontrol listesi: [`REFACTOR_PLAN.md` → Editör Duman Testi Kontrol Listesi](REFACTOR_PLAN.md).

**Zorunlu olduğu değişiklikler:** görünür arayüz; dock / sahne bağlantıları; açık sahne veya editör seçimi isteyen araçlar (`add_node`, `instantiate_scene`, ekran görüntüsü, `play_game`); runtime debugger; dil değiştirme. Test projesinde eklenti klasörü repoya junction ile bağlıysa, değişiklikten sonra editörde **Project → Reload Current Project** yapılır.

## 10. Diagnostic probe'lar ve README görselleri

* `tests/diagnostic/`: test değil, tek seferlik ölçüm betikleri (AGY donma araştırmasından). Neyi ölçtükleri ve gereksinimleri: [`tests/diagnostic/README.md`](../tests/diagnostic/README.md).
* README görselleri gerçek arayüz bileşenlerinden üretilir. Arayüzün görünümü veya metni değiştiğinde iki dilde yeniden üret:

```bash
godot --path . -s res://tools/readme_shots.gd -- docs/media en
godot --path . -s res://tools/readme_shots.gd -- docs/media tr
# Headless Linux: xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/readme_shots.gd -- docs/media en
```

Pencere birkaç saniye açılıp kapanır; `config.json` dili geçici değiştirilir ve dosya birebir geri yazılır. Üretilen PNG'leri commit'lemeden önce gözle kontrol et.

## 11. GitHub Actions (CI)

`.github/workflows/verify.yml`: her `main` push'unda ve her PR'da, ubuntu-latest üzerinde:

1. Godot 4.7.2-stable Linux indirilir.
2. Proje bir kez `--headless --editor --quit` ile açılır (içe aktarma önbelleği). Fail-closed: zaman aşımı veya sıfır dışı çıkış kırmızı; kapanıştaki "leaked" satırları bilinen gürültüdür, taranmaz.
3. Yereldekiyle aynı `./verify.ps1` pwsh altında koşar (`-Live` hariç).

CI config'siz çalışır; yerel sonuçla farklıysa önce §7'ye bak. Linux dosya sistemi büyük/küçük harf duyarlıdır: Windows'ta görünmeyen yol harf hataları CI'da çıkar.

## 12. Doğrulama matrisi

| Değişiklik türü | `verify.ps1` | `-Live` | Editör duman testi | Diğer |
|---|---|---|---|---|
| Yalnız belge | — (CI yine koşar) | — | — | Bağlantılar ve komutlar gerçekten var mı kontrol et |
| Çekirdek mantık (`core/agent`, `core/chat`, `core/tools` saf kısımları, doğrulama) | ✅ | — | Araç editör kökü istiyorsa ✅ | Refactor ise önce sabitleme testi |
| Arayüz (`ui/`) | ✅ | — | ✅ | Metin değiştiyse i18n anahtarı iki dile; görünüm değiştiyse README görselleri |
| Provider / ağ (`core/network`, `core/providers`, `AgentHost`) | ✅ | ✅ | Provider değişimi + Refresh | — |
| Runtime / editör etkileşimi (`core/runtime`, `EditorInterface` araçları) | ✅ | — | ✅ (oyunu başlat / durdur) | — |
| Test altyapısı (`tests/`, `tools/`) | ✅ | — | — | Değişen kontrolün hâlâ yakaladığını mutasyonla göster |

## 13. Feature freeze döneminde bug düzeltme

Freeze'de yalnızca gerçek bug düzeltilir; yeni özellik, refactor veya "şunu da temizleyelim" yapılmaz.

1. Bug'ı kanıtla: test, probe veya editörde yeniden üretim.
2. Düzeltme olmadan kırmızı, düzeltmeyle yeşil olan en küçük testi mevcut pakete ekle. Headless'ta yeniden üretilemiyorsa kanıtı (probe) belgele ve duman testi listesine madde ekle.
3. En küçük düzeltmeyi yap; yeni yardımcı / katman ekleme.
4. `verify.ps1`, gerekirse §12'deki ek adımlar, CI yeşil.
5. Tek atomik `fix(...)` commit; `CHANGELOG.md` `[Unreleased]` ve gerekiyorsa `REFACTOR_PLAN.md` bulgu listesi aynı commit'te.

## 14. Sık kullanılan komutlar

```bash
# Tam doğrulama / canlı test dahil
powershell -ExecutionPolicy Bypass -File .\verify.ps1
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Live

# Adımlar tek tek
powershell -ExecutionPolicy Bypass -File .\typecheck.ps1
godot --headless --path . -s res://tools/warning_report.gd
godot --headless --path . -s res://tests/test_runner.gd

# Motor ERROR/WARNING profilini görmek (verify.ps1 bunu gizler)
godot --headless --path . -s res://tests/test_runner.gd 2>&1 | grep -E "^\s*(ERROR|WARNING|SCRIPT ERROR):"

# Uyarı tabanını düşürmek (yalnız sayılar azaldıysa)
godot --headless --path . -s res://tools/warning_report.gd -- --update-baseline

# README görselleri
godot --path . -s res://tools/readme_shots.gd -- docs/media en
godot --path . -s res://tools/readme_shots.gd -- docs/media tr
```

Not: Editörü headless açmak (`--editor --quit`) ikon `.import` dosyalarını yeniden yazabilir ve eksik `.uid` dosyaları üretebilir. Yeni eklediğin birimin `.uid`'i dışındakileri commit'leme.
