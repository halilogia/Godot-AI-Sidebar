# CLAUDE.md — Claude Code'un bu depodaki çalışma kuralları

Bu dosya yalnız Claude Code içindir (eklentiyi geliştiren ajan). Godot AI Sidebar'ın kendi ajanı bu dosyayı okumaz; sidebar'ın kuralları `AGENTS.md`, `.agents/rules/` ve sistem istemidir (`core/config/api_config.gd`). İkisini karıştırma: buradaki kurallar sidebar'ın istemine, köprü talimatına, skill'lerine ya da `AGENTS.md`'ye kopyalanmaz.

Genel proje kuralları için `AGENTS.md`'yi de oku.

## Arayüz grafik kalitesi standardı

Eklentinin arayüzünde (`addons/godot_sidebar_ai/ui/`) yaptığın her değişiklikte uy.

### Tasarım sistemi (Tailwind'in buradaki karşılığı)

| Tailwind | Bu depo |
|---|---|
| `tailwind.config` (renk, boşluk, yazı ölçeği) | `ui/theme/sidebar_theme.gd` → `AISidebarTheme` belirteçleri |
| `@apply` ile bileşen sınıfı | `ui/theme/sidebar_theme_builder.gd` → adlı tip varyasyonu (`AISidebarCard`, `AISidebarTitle`, `AISidebarPrimaryButton` …) |
| `className="…"` | `node.theme_type_variation = AISidebarThemeBuilder.CARD` |
| `hover:` / `focus:` | Varyasyonun `hover` / `pressed` / `focus` stilleri (üretici tanımlar) |
| Ölçek / yoğunluk | `AISidebarTheme.ui_scale` (editör ölçeği) ve `Density.COMPACT` (dock) / `Density.FORM` (pencereler) |

1. **Önce varyasyon.** Yeni denetim görünümünü `theme_type_variation` ile alır. Uygun varyasyon yoksa önce `AISidebarThemeBuilder`'a ekle (ve `tests/test_ui_quality.gd` → `VARIATIONS` listesine), sonra kullan. Tema kökte verilir: dock (`chat_dock_theme.gd`), Ayarlar / Skills / diff pencereleri (`form_theme()` ya da `build(FORM)`). Denetime tek tek `add_theme_font_size_override` / `add_theme_stylebox_override` yazılmaz (test engeller); tek istisna rengi çalışma anında veriden seçilen haplardır. Varyasyon yalnız farklı olan öğeleri tanımlar, gerisini üretici temel tipten kaynak temadan kopyalar (`_complete_variations`).
2. **Sabit değer yok.** Renk yalnız `AISidebarTheme` belirteci (açık ve koyu palette ikisine de değer verilir: `PALETTE_DARK`, `PALETTE_LIGHT`); BBCode rengi `AISidebarTheme.bb(belirteç)`. Yazı boyu, boşluk ve ikon boyu ölçekli: `AISidebarTheme.fs(FONT_SIZE_*)`, `AISidebarTheme.px(SPACE_*)`, ikonlar `ICON_SIZE_SM / MD / LG`. Sahnelerde (`.tscn`) tema geçersiz kılması yazılmaz; kodda ölçekli verilir. Yeni renk gerekiyorsa temaya anlamlı adla eklenir (ör. `COLOR_TONE_WARNING_TEXT`).
3. **Ton ile anlam.** Kart tonu içeriğin anlamını söyler: soru / onay `CARD_QUESTION` / `CARD_WARNING`, hata `CARD_ERROR`, plan / bilgi `CARD_INFO`, değişiklik `CARD_NEUTRAL`, yardımcı bilgi `CARD_SUBTLE`. Sayfada tek birincil eylem (`PRIMARY_BUTTON`), diğerleri `BUTTON` / `GHOST_BUTTON`.
4. **Form ekranları** (`AISidebarSettingsUi`, `ui/components/settings_ui_kit.gd`): kart, ipucu, rozet, düğme, form satırı, açılır liste (`option_button()`, en uzun seçeneğe göre genişlemez). Aynı iş için ikinci bir stil yazma.
5. **Durumlar eksiksiz.** Normal / üzerinde / basılı / seçili / devre dışı ayrı görünür. Düğmeler dikeyde uzamaz. Uzun metin sarılır ya da üç noktayla kesilir. Kaydırma çubuğu içeriğe binmez. Pencere dar ekranda, kartlar dar dock'ta (320 px) sığar.
6. **Hareket ölçülü ve merkezi.** Bütün hareket `AISidebarMotion`'dan (`fade_in`, `reveal`, `pulse`; süre ve yumuşatma belirteçleri orada); başka yerde `create_tween` yazılmaz (test engeller). Yalnız saydamlık değişir, yerleşim oynamaz. Yeni hareket ancak gerçekten kullanılacağı yerle birlikte eklenir; önceden hareket kütüphanesi üretilmez. Kullanıcı Ayarlar → Genel'den kapatabilir; kapalıyken hiçbir şey oynamaz.
7. **Klavye ve kontrast.** Eylem düğmeleri odak alır (`FOCUS_ALL`); odak halkası temadadır. `FOCUS_NONE` yalnız gerekçesiyle yazılır: satır sonunda `# focus: <neden>` (ör. akıştaki açılır başlık yazma odağını almasın). Yeni renk iki palette de WCAG kontrastını sağlar: gövde ve ikincil yazı, dolgulu düğme yazısı 4.5:1; soluk yazı ve bağlantı 3:1 (`tests/test_ui_quality.gd` T7 ölçer).
8. **Metin i18n'den.** Görünen her metin, pencere başlığı ve düğme metni `AISidebarI18n.get_text` ile, iki dilde.

### Görmeden bitti deme

Değişiklikten önce ve sonra görüntü al ve PNG'lere gerçekten bak, iki dilde:

```bash
godot --path . -s res://tools/ui_shots.gd -- <mutlak klasör, repo dışı> tr
godot --path . -s res://tools/ui_shots.gd -- <mutlak klasör, repo dışı> en
godot --path . -s res://tools/ui_shots.gd -- <mutlak klasör> tr all 1.5   # yüksek DPI editör ölçeği
godot --path . -s res://tools/ui_shots.gd -- <mutlak klasör> tr all 1 light   # açık editör teması
```

- **Önce arşivle, sonra karşılaştır:** arayüz işine başlamadan `tools/ui_snapshot.ps1` ile o anki sürümü arşivle; bitince yeniden arşivle ve `-Compare <önce> -With <sonra>` çalıştır. Değişen ekranların yan yana görüntülerini kullanıcıya gönder; beklenmeyen her farkı açıkla ya da düzelt.
- Ayarlar'ın her sayfası (geniş / dar pencere) ve sohbet paneli `tools/ui_scenarios.gd`'deki her senaryoyla (normal / dar dock) çekilir. Taşmada `OVERFLOW` basılır, çıkış kodu 1 olur.
- Yeni bir kart ya da arayüz durumu eklediysen `tools/ui_scenarios.gd`'ye senaryosunu ekle (`NAMES`).
- Headless çekim çalışmaz. `ui_shots.gd` editör dışında çizer (Godot'nun varsayılan teması); son söz gerçek editörün görüntüsüdür.
- **Gerçek editör:** kullanıcının editöründe MCP köprüsü açık ve bu oturuma bağlıysa (`claude mcp add … godot …`), `take_editor_screenshot` aracını `region: "sidebar"` ile çağır; panelin editördeki gerçek görüntüsü (editör teması, ölçek, yazı tipleri) döner. Arayüz işini bitirmeden önce bununla da bak; köprü bağlı değilse kullanıcıya bunu söyle ve bağlamasını iste.
- **Editör duman testi:** arayüz işini bitirmeden `tools/editor_smoke.ps1` çalıştır; panel gerçek editörde yüklenip Ayarlar / Yardım açılıyor mu denetler ve gerçek görüntüleri `ui_snapshots\editor_smoke\` altına yazar (köprü bağlı olmasa da çalışır).
- `tests/test_ui_quality.gd` yeşil kalır: sabit / ölçeksiz yazı boyu, ölçeksiz boşluk, renk ve BBCode renk sabiti sayısı dosya başına `BASELINE`'ı (şu an boş) aşamaz; sahnelerde tema geçersiz kılması yok; her varyasyon tanımlı.
- İş bitince önce / sonra görüntüsünü kullanıcıya gönder.
