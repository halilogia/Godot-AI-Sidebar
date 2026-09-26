# CLAUDE.md — Claude Code'un bu depodaki çalışma kuralları

Bu dosya yalnız Claude Code içindir (eklentiyi geliştiren ajan). Godot AI Sidebar'ın kendi ajanı bu dosyayı okumaz; sidebar'ın kuralları `AGENTS.md`, `.agents/rules/` ve sistem istemidir (`core/config/api_config.gd`). İkisini karıştırma: buradaki kurallar sidebar'ın istemine, köprü talimatına, skill'lerine ya da `AGENTS.md`'ye kopyalanmaz.

Genel proje kuralları için `AGENTS.md`'yi de oku.

## Arayüz grafik kalitesi standardı

Eklentinin arayüzünde (`addons/godot_sidebar_ai/ui/`) yaptığın her değişiklikte:

1. **Yalnız tema belirteçleri.** Renk, boşluk, köşe ve yazı boyu `AISidebarTheme` (`ui/theme/sidebar_theme.gd`) belirteçlerinden gelir. Sabit piksel yazı boyu (`add_theme_font_size_override("font_size", 11)`) ve tema dışı renk sabiti (`Color(0.9, …)`) yazma; yeni renk gerekiyorsa önce temaya adlı belirteç olarak ekle.
2. **Ortak bileşen seti.** Ayarlar sayfaları ve benzeri formlar `ui/components/settings_ui_kit.gd` (`AISidebarSettingsUi`) ile kurulur: kart, ipucu, rozet, birincil / ikincil düğme, form satırı, açılır liste (`option_button()`), menü stilleri. Aynı iş için ikinci bir stil yazma. Yazı boyu editörün yazı boyundan türetilir.
3. **Durumlar eksiksiz.** Düğme ve menü öğelerinde normal / üzerinde / basılı / seçili ayrı görünür. Düğmeler dikeyde uzamaz. Uzun metin sarılır ya da üç noktayla kesilir. Açılır listeler en uzun seçeneğe göre genişlemez. Kaydırma çubuğu içeriğe binmez. Pencere dar ekranda da sığar.
4. **Görmeden bitti deme.** Değişiklikten önce ve sonra görüntü al ve PNG'lere gerçekten bak, iki dilde, geniş ve dar pencerede:

   ```bash
   godot --path . -s res://tools/ui_shots.gd -- <mutlak klasör, repo dışı> tr
   godot --path . -s res://tools/ui_shots.gd -- <mutlak klasör, repo dışı> en
   ```

   Araç pencere ekrana sığmazsa `OVERFLOW` basıp 1 ile çıkar. Dock görselleri için `tools/readme_shots.gd`. Headless çekim çalışmaz. Görüntü editör temasını birebir yansıtmaz; editör içi duman testi yine gerekir.
5. **Cırcırı yeşil tut.** `tests/test_ui_quality.gd` sabit yazı boyu ve renk sabiti sayısını `ui/` dosyası başına tutar. Yeni dosya sıfırla başlar. Eski bir kartı temizlediysen `BASELINE`'daki sayısını düşür, asla yükseltme.
6. **Kullanıcıya kanıt göster.** Arayüz işini bitirdiğinde önce / sonra görüntüsünü kullanıcıya gönder.
