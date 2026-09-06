# 🛠️ Scripts & Otomasyon Rehberi

Bu dizin, Godot AI Core eklentisinin geliştirme araçlarını, örnek oyun projeleriyle senkronizasyon scriptlerini ve prototipleme yardımcılarını içerir.

---

## 📂 Dizin İçeriği

| Dosya | Tür | Açıklama |
| :--- | :--- | :--- |
| **`sync-example.bat`** | Windows Başlatıcı | `sync-example.ps1` dosyasını çift tıklayarak çalıştırmayı sağlayan UTF-8 köprüsü. |
| **`sync-example.ps1`** | PowerShell Otomasyonu | Eklentiyi `examples/` altındaki oyunlara kopyalayan, bağlayan veya canlı izleyen ana script. |
| **`EnemyAuto.gd`** | GDScript Örneği | Basit 2D devriye (patrol) gezen düşman yapay zekası prototip scripti. |
| **`InteractableChest.gd`** | GDScript Örneği | 2D etkileşimli nesne / sandık mekaniği örneği (`Area2D` ve `interacted` sinyali). |

---

## 🚀 `sync-example` Kullanım Kılavuzu

Ana repo kökündeki `addons/godot_sidebar_ai/` eklentisini `examples/` klasörü içindeki oyun projelerine aktarmak ve `project.godot` dosyasında otomatik olarak etkinleştirmek için kullanılır.

### 1. Çift Tıklayarak Çalıştırma (İnteraktif Menü)
Doğrudan **`sync-example.bat`** dosyasına çift tıklayın. Karşınıza şu interaktif menü gelir:

```text
'examples' altında bulunan oyun projeleri:
  [1] yeni-oyun-projesi
  [N] Yeni bir örnek oyun projesi oluştur
  [A] Tüm projelere senkronize et
  [Q] Çıkış
```

* Proje numarasını girerek seçtiğiniz oyuna eklentiyi kopyalayabilirsiniz.
* **`N`** tuşuna basarak sıfırdan yeni bir oyun klasörü ve `project.godot` oluşturabilirsiniz.

---

### 2. Terminal Komutları ve Modlar

PowerShell üzerinden gelişmiş parametrelerle doğrudan çalıştırabilirsiniz:

#### A. Belirli Bir Projeye Senkronize Etme
```powershell
.\scripts\sync-example.ps1 -ProjectName "yeni-oyun-projesi"
```

#### B. Sıfırdan Yeni Oyun Projesi Başlatma
`examples/uzay-savasi` klasörünü açar, `project.godot` dosyasını oluşturur ve eklentiyi hazır şekilde kurar:
```powershell
.\scripts\sync-example.ps1 -NewProject "uzay-savasi"
```

#### C. Canlı Bağlantı Modu (`-Link` / NTFS Junction) — *(Tavsiye Edilen)*
Fiziksel kopyalama yapmaz; Windows NTFS Junction bağlantısı açar. Ana eklenti klasöründe (`addons/godot_sidebar_ai`) yapılan tüm kod değişiklikleri anında oyuna yansır:
```powershell
.\scripts\sync-example.ps1 -ProjectName "yeni-oyun-projesi" -Link
```
> **Avantajı:** Sürekli scripti yeniden çalıştırma veya kopyalama bekleme derdini tamamen ortadan kaldırır.

#### D. Canlı İzleme Modu (`-Watch`)
Terminali arka planda açık tutar. Ana eklenti klasöründe herhangi bir dosya kaydedildiğinde milisaniyeler içinde oyundaki klasöre kopyalar:
```powershell
.\scripts\sync-example.ps1 -ProjectName "yeni-oyun-projesi" -Watch
```

---

## 🔒 Güvenlik & Konfigürasyon Kuralları

1. **`config.json` Koruması:**
   * Hedef projede daha önce tanımlanmış API anahtarı veya model ayarları varsa, kopyalama sırasında bu dosya **asla ezilmez**.
2. **Otomatik `project.godot` Entegrasyonu:**
   * Script, hedef projenin `project.godot` dosyasındaki `[editor_plugins]` bölümünü otomatik olarak yapılandırır. Editör içinde manuel etkinleştirme yapılmasına gerek kalmaz.
3. **Türkçe Karakter Desteği:**
   * Script UTF-8 BOM olarak kodlanmıştır ve konsol girdi/çıktı kodlamasını evrensel UTF-8 (`chcp 65001`) olarak zorlar.
