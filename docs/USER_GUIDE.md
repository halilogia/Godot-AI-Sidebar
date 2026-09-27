# Godot AI Sidebar — Kullanım Kılavuzu

[English](USER_GUIDE.en.md)

Godot AI Sidebar, Godot editörünün içinde çalışan bir yapay zekâ ajanıdır. İsteğinizi okur, dosya ve sahne araçlarıyla uygular, oyunu çalıştırıp sonucu doğrular. Yaptığı her değişiklik editörün geri alma geçmişine yazılır.

Bu kılavuzun kısa hali eklentinin içinde de var: panelin başlığındaki **Yardım** (?) düğmesi. Oradaki komut listesi eklentiden canlı üretilir, yani her zaman günceldir.

## İçindekiler

1. [Kurulum](#1-kurulum)
2. [Yapay zekâ kaynağı (sağlayıcı)](#2-yapay-zekâ-kaynağı-sağlayıcı)
3. [Panel](#3-panel)
4. [İlk görev ve kartlar](#4-ilk-görev-ve-kartlar)
5. [Onay modları ve güvenlik](#5-onay-modları-ve-güvenlik)
6. [Slash komutları](#6-slash-komutları)
7. [@ bahsetmeleri](#7--bahsetmeleri)
8. [Klavye](#8-klavye)
9. [Hedef modu (/goal)](#9-hedef-modu-goal)
10. [Kurallar](#10-kurallar)
11. [Skill'ler](#11-skiller)
12. [Dış ajan köprüsü (MCP) ve Claude Code](#12-dış-ajan-köprüsü-mcp-ve-claude-code)
13. [Ayarlar](#13-ayarlar)
14. [Sorun giderme](#14-sorun-giderme)

## 1. Kurulum

1. [Releases](https://github.com/halilogia/Godot-AI-Sidebar/releases) sayfasından arşivi indirin ya da depoyu klonlayın.
2. `addons/godot_sidebar_ai/` klasörünü oyun projenizin `addons/` klasörüne kopyalayın.
3. Godot'ta **Project → Project Settings → Plugins** sekmesinde **Godot AI Sidebar**'ı etkinleştirin. Panel sağ tarafta açılır.

Gereksinim: Godot 4.7 veya üstü.

## 2. Yapay zekâ kaynağı (sağlayıcı)

Ayarlar (panel üst çubuğundaki dişli) → **Sağlayıcı**:

| | Antigravity CLI | OpenAI uyumlu |
|---|---|---|
| Nasıl çalışır | Bilgisayarınızdaki `agy` komutunu kullanır | HTTP uç noktasına bağlanır |
| Gereken | `agy` kurulu ve oturum açık | Base URL, gerekiyorsa API anahtarı |
| Örnekler | Google Antigravity | 9Router, OpenRouter, Ollama, LM Studio |
| Görüntü (ekran görüntüsü) | Hayır | Model destekliyorsa evet |

- **Gelişmiş:** yanıtları akışla alma (uç noktanız desteklemiyorsa kapatın) ve görüntü desteği (otomatik tahmin yanlışsa elle seçin).
- Model, üst çubuktaki listeden seçilir; yenile düğmesi listeyi sağlayıcıdan tekrar çeker.
- Ayarlar `addons/godot_sidebar_ai/config.json` dosyasında tutulur. Bu dosya kişiseldir, commit'lemeyin.

## 3. Panel

**Başlık:** durum rozeti (Hazır, Düşünüyor, Onay bekleniyor …), **+ Yeni** (yeni sohbet), **Skills** (skill yönetimi), **Yardım**, **Geçmiş** (eski sohbetler), **Dışa aktar** (sohbeti dosyaya kaydet), **Kopyala** (bütün sohbet dökümünü panoya kopyala).

**Üst çubuk:** model seçimi, onay modu düğmesi (Manuel / Auto / Full Auto), model listesini yenile, Ayarlar.

**Alt kısım:** mesaj kutusu, **Temizle** ve **Gönder** (ajan çalışırken **Durdur** olur). Etkin bir hedef varsa kutunun üstünde hedef şeridi, sırada bekleyen istekler varsa kuyruk görünür.

## 4. İlk görev ve kartlar

Kutuya ne istediğinizi doğal dille yazıp Enter'a basın, ör. *"Oyuncuya çift zıplama ekle"*. Ajan çalışırken sohbette şu kartları görebilirsiniz:

- **Netleştirme:** istek birden fazla anlama geliyorsa ajan başlamadan sorar; bir seçeneğe tıklayın ya da kendi yanıtınızı yazın.
- **Uygulama planı:** büyük işlerde önce plan sunar; **Planı Uygula** ya da **İptal**.
- **Onay gerekli:** riskli bir işlem (silme, var olan dosyanın üzerine yazma …) onayınızı bekler. **Farkı Gör** değişikliği satır satır gösterir.
- **Değişiklikler:** değişen dosyalar ve satır sayıları. **Farkı Gör** ve **Geri Al** buradadır.
- **Etkinlik:** ajanın attığı adımlar ve süreleri. "Teknik ayrıntılar" araç argümanlarını gösterir.
- **Test ediliyor (runtime):** oyun çalıştırıldıysa runtime hataları ve gözlemler.
- **Özet:** görev bitince süre, adım ve araç sayıları; **Kopyala** o görevi panoya alır.
- **Hata:** bir şey ters gittiyse mesajı ve **Tekrar Dene** düğmesi.

Durdurduğunuz bir görevi sürdürmek için kutuya yalnızca **devam** (ya da *continue*) yazın.

Ajan çalışırken yazdığınız mesajlar **kuyruğa** girer ve görev bitince sırayla başlar; kuyruktaki bir isteği × ile iptal edebilirsiniz.

## 5. Onay modları ve güvenlik

| Mod | Davranış |
|---|---|
| Manuel | Her riskli işlemde onay sorulur. |
| Auto | Güvenli kod / dosya yazımları kendiliğinden, silme onaylı. |
| Full Auto | Bütün araçlar kendiliğinden onaylanır; korunan yollar yine korunur. |

Mod, üst çubuktaki düğmeden ya da **Ayarlar → Genel → Araç onayları**'ndan seçilir. Aynı yerde "silmeden önce sor" ve "var olan dosyanın üzerine yazmadan önce sor" seçenekleri vardır.

- **Geri alma:** sahne ve düğüm değişiklikleri editörün geri alma geçmişine yazılır, **Ctrl+Z** ile geri alınır. Değişiklikler kartındaki **Geri Al** dosya değişikliklerini geri alır.
- **Korunan yollar:** ajan `project.godot`, `.git/` ve eklentinin kendi klasörüne hiçbir modda dokunamaz.

## 6. Slash komutları

Kutuya `/` yazınca liste açılır; ↑ ↓ ile gezip Enter ya da Tab ile tamamlarsınız. Komutlar yalnız kısayoldur, her özellik arayüzden de erişilebilir.

| Komut | Ne yapar |
|---|---|
| `/help` | Komutları, açıklamalarını ve kullanımlarını gösterir. |
| `/clear` | Sohbeti temizler (Temizle düğmesiyle aynı). |
| `/analyze [konu]` | Projeyi ya da sahneyi analiz eder; dosya değiştirmez. |
| `/inspect [düğüm veya res:// yolu]` | Etkin sahneyi, düğüm ağacını ya da verilen hedefi inceler. |
| `/test [kapsam]` | İlgili testleri ve kod doğrulamalarını çalıştırıp sonucu yorumlar. |
| `/run` | Oyunu çalıştırır, runtime hatalarını ve durumu raporlar. |
| `/debug [hata açıklaması]` | Editör ve runtime loglarını, hataları ve yığın izini analiz eder. |
| `/fix [sorun]` | Son bulunan hatayı güvenli biçimde düzeltmeye çalışır. |
| `/review` | Son değişiklikleri güvenlik ve kalite ölçütlerine göre inceler. |
| `/explain <dosya \| düğüm \| last>` | Dosyayı, düğümü ya da son değişiklikleri açıklar. |
| `/skill [ad] [istek]` | Skill'leri listeler ya da seçilen skill'le görevi başlatır. |
| `/learn [--global] [kural]` | Kalıcı kural kaydeder (onay ister). Bkz. [Kurallar](#10-kurallar). |
| `/mcp [on \| off]` | Dış ajan köprüsünü açar / kapatır. Bkz. [MCP](#12-dış-ajan-köprüsü-mcp-ve-claude-code). |
| `/goal [hedef \| stop]` | Hedef modu. Bkz. [Hedef modu](#9-hedef-modu-goal). |
| `/bug` | Hata bildirme penceresini açar. Bkz. [Sorun giderme](#14-sorun-giderme). |

## 7. @ bahsetmeleri

Kutuya `@` yazınca liste açılır. Bahsettiğiniz şey o isteğin bağlamına eklenir.

| Yazım | Anlamı |
|---|---|
| `@res://player/player.gd` ya da `@player.gd` | Dosyanın içeriğini isteğe ekler. |
| `@Node:Player` | Açık sahnedeki düğümü isteğe ekler. |
| `@rules` | Yüklü kuralları bu istekte özellikle uygulatır. |
| `@skill:ad` | Bu isteği o skill'in talimatlarıyla yapar. |

## 8. Klavye

| Tuş | İş |
|---|---|
| Enter | Gönder (ajan çalışıyorsa kuyruğa alır). |
| Shift+Enter | Yeni satır. |
| Ctrl+V | Panodaki görseli ekler (model görüntü destekliyorsa gönderilir). |
| `/` ya da `@` | Komut / bahsetme listesini açar; ↑ ↓, Enter ya da Tab. |
| Ctrl+Z | Ajanın editördeki son değişikliğini geri alır. |

## 9. Hedef modu (/goal)

Büyük ya da çok adımlı bir işi tek seferde istemek yerine bir **hedef** verin:

```text
/goal Oyuncu çift zıplayabilsin ve HUD zıplama sayısını göstersin
```

- Ajan hedef üzerinde **tur tur** çalışır. Her tur, normal bir görev gibi kendi adım sınırını kullanır.
- Her turun sonunda durumu bildirir: **tamamlandı** (kanıtıyla: doğrulanan script, hatasız çalışan oyun, ekran görüntüsü …), **sürüyor** (sıradaki adımla) ya da **engellendi** (sizden ne gerektiğiyle).
- Kanıtsız "tamamlandı" kabul edilmez; ajan bir sonraki turda kanıt toplar.
- Hedef tamamlanınca, ajan engele takılınca ya da tur sınırı dolunca sonuç sohbete yazılır.
- Kutunun üstündeki **hedef şeridi** hedefi ve tur sayacını gösterir; **Durdur** hedefi bitirir ve çalışan turu durdurur.
- `/goal` durumu gösterir, `/goal stop` durdurur. Tur sınırı: **Ayarlar → Model & Parametreler → Hedef modu** (varsayılan 10).

## 10. Kurallar

Kurallar, ajanın her turda uyduğu kısa talimatlardır. Üç katman vardır:

1. **Yerleşik kurallar (sistem istemi):** eklentinin kendi çalışma yöntemi. **Ayarlar → Kurallar**'da düzenlenir; rozet "Güncel varsayılan" ya da "Özelleştirilmiş" gösterir. Eklenti güncellenince yeni varsayılanı almak için **Varsayılanı geri yükle**.
2. **Global kurallar:** `~/.agents/AGENTS.md` ve `~/.agents/rules/*.md`. Bütün projelerinizde geçerlidir.
3. **Proje kuralları:** oyun projenizdeki `AGENTS.md`, `GEMINI.md`, `.agents/AGENTS.md`, `.agents/rules/*.md`. Depoyla birlikte gider; aynı dosyaları başka ajanlar (Codex, Antigravity, Cursor …) da okur.

Global ve proje kuralları yerleşik kuralların üstüne eklenir; çelişkide onlar kazanır.

- **Kural eklemek:** Ayarlar → Kurallar'daki kutuya tek cümle yazıp **Kural ekle**, ya da sohbette `/learn her düşman verisi data/enemies.json'da dursun`. `/learn` tek başına bu konuşmadaki düzeltmelerden kural önerir; `--global` bütün projelere yazar. Kayıttan önce onay istenir.
- **Kuralı vurgulamak:** mesaja `@rules` ekleyin.
- **Kural dosyasını açmak:** Ayarlar → Kurallar → **Klasörde göster**.
- Aynı sayfada **token kullanımı** çubuğu, kuralların, skill'lerin ve araçların her turda modele eklediği yükü gösterir.

## 11. Skill'ler

Skill, yeniden kullanılabilir bir talimat paketidir ([Agent Skills](https://agentskills.io) standardı, `SKILL.md`). Ajan açık skill'lerin adını ve açıklamasını görür; görev uyduğunda skill'i kendisi yükler.

| Kaynak | Yer | Varsayılan |
|---|---|---|
| Proje | oyun projesinde `.agents/skills/`, `.claude/skills/` | Kapalı (depodan geldiği için siz açarsınız) |
| Kullanıcı | `~/.agents/skills/` | Açık |
| Yerleşik | eklentiyle gelir (Godot geliştirme, sahne, hata ayıklama, runtime doğrulama, refactor, headless CI) | Açık |

- **Yönetim:** Ayarlar → **Skill'ler** ya da başlıktaki **Skills** düğmesi: aç / kapa, SKILL.md'yi aç, yeni skill iskeleti oluştur, başka bir klasörden içe aktar, sil (yerleşikler silinmez).
- **Elle kullanmak:** `/skill ad istek` ya da mesajda `@skill:ad`.

## 12. Dış ajan köprüsü (MCP) ve Claude Code

Claude Code, Cursor, Codex gibi ajanlar bu editörü MCP üzerinden kullanabilir: sahneyi okuma, script doğrulama, yazdıkları dosyaları editöre taratma (`sync_project`), oyunu çalıştırma, runtime hataları ve ekran görüntüleri, açık sahnede Ctrl+Z ile geri alınabilen küçük değişiklikler.

1. **Ayarlar → Dış Ajan (MCP)** → **Aç** (ya da sohbette `/mcp on`). Köprü yalnız bu bilgisayarda (`127.0.0.1`) ve gizli bir token ile çalışır.
2. **Claude Code bağlantı komutunu kopyala**'ya basın; komutu oyun projenizin klasöründe bir terminale yapıştırın. Token arayüzde maskelidir, kopyalanan komutta tamdır.
3. O klasörde `claude` başlatıp oyun üzerinde çalışmasını isteyin.

Port aynı sayfadan değiştirilebilir. Kapatmak için **Kapat** ya da `/mcp off`.

## 13. Ayarlar

| Sayfa | İçerik |
|---|---|
| Sağlayıcı | Sağlayıcı, uç nokta (Base URL, API anahtarı), yanıt akışı, görüntü desteği, token kullanımını iste |
| Model & Parametreler | Sıcaklık, en çok ajan adımı, hedef modu tur sınırı, bağlam penceresi |
| Genel | Arayüz dili, arayüz animasyonları, onay modu, silme / üzerine yazma onayları, hata bildir |
| Kurallar | Token kullanımı, yerleşik kurallar (sistem istemi), global ve proje kuralları, kural ekleme |
| Skill'ler | Skill listesi ve yönetimi |
| Dış Ajan (MCP) | Köprüyü aç / kapa, port, bağlantı komutu |

**Bağlam göstergesi:** giriş kutusunun üstündeki ince çubuk, bağlamın ne kadar dolduğunu (`kullanılan / pencere`) ve oturumun token toplamlarını gösterir. Sayılar sağlayıcının kendi bildirdiği değerlerdir, tahmin değildir; sağlayıcı bildirmezse gösterge görünmez. Bağlam %80'i geçince eski adımlar özetlenir.

Değişiklikler **Kaydet ve Kapat** ile yazılır. Skill aç / kapa, kural ekleme ve köprü ayarları kendi düğmeleriyle hemen uygulanır.

## 14. Sorun giderme

- **Model listesi boş / bağlanamıyor:** Ayarlar → Sağlayıcı'da Base URL'yi kontrol edin (`http://127.0.0.1:20128/v1` gibi), ardından üst çubukta yenile.
- **"AGY hazırlanıyor" uzun sürüyor:** Antigravity CLI ilk açılışta oturumu hazırlar; `agy` komutunun terminalde çalıştığını ve oturumun açık olduğunu kontrol edin.
- **Ekran görüntüsü modele gitmiyor:** seçili model görüntü desteklemiyor olabilir; Ayarlar → Sağlayıcı → Gelişmiş → Görüntü desteği.
- **MCP köprüsü açılmıyor:** port başka bir program tarafından kullanılıyor olabilir; Ayarlar → Dış Ajan'dan başka bir port seçin.
- **Ajan aynı hatada dönüyor:** Durdurun, isteği daraltın ya da `@res://...` ile ilgili dosyayı bağlama ekleyin. Kalıcı bir tercihse `/learn` ile kural yapın.
- **Hata bildirmek:** Yardım penceresinde, **Ayarlar → Genel**'de ya da `/bug` ile **Hata bildir**. Ne olduğunu yazın, rapora neyin gireceğini seçin (sohbet ve görev kaydı, panel görüntüsü, oyun logu) ve **Raporu oluştur**'a basın. Eklenti bilgisayarınızda tek bir zip hazırlar ve issue metnini panoya kopyalar; **GitHub'da issue aç** ile yeni issue sayfasını açıp metni yapıştırın ve zip'i sürükleyin. API anahtarı ve token'lar rapora yazılmaz; hiçbir şey kendiliğinden gönderilmez.
