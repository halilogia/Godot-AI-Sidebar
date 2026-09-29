# Art Direction — card-game demo

Mood: sıcak, loş "tahta masa" akşamı; derin mavi-mor zemin, altın vurgular.

Palette (Palette.gd tek kaynak):
- BG_DEEP  = #12101f (arka plan gradyanının koyu ucu)
- BG_LIGHT = #241f3d (gradyanın açık ucu)
- SURFACE  = #2e2748 (panel / kart zemini)
- PRIMARY  = #e8c26a (altın: başlıklar, kazanan kart, çerçeve)
- ACCENT   = #5fd0c5 (turkuaz: aktif seçim, buton hover)
- DANGER   = #e0576b (kırmızı: kaybeden kart, uyarı)

Field / composition:
- Tasarım 1280x720, stretch mode canvas_items, aspect expand.
- Oyun alanı ekranın kısa kenarının ~%70'ini kaplar; HUD üstte 96px, alan üstten 96+24px başlar.
- Kartlar 120x168, köşe yarıçapı 12, 2px PRIMARY kenarlık, altında yumuşak gölge.

UI:
- Köşe yarıçapı 10 panel, 8 buton. Yazı boyutları: başlık 32, HUD 22, kart değeri 28. Koyu zeminde açık metin + 2px koyu outline.
- Tipografi: kalın (bold) sans, tek aile.

Effect intensity:
- Flash 120ms, kart yükselmesi 8px, sarsıntı yok. Sürekli partikül yok.
