# Art direction — tower-defense

Mood: sıcak alacakaranlık / dusk (koyu mavi-mor ufuk, sıcak turuncu vurgular). 2D, kodla çizim, resim dosyası yok.

Palette (Palette.gd):
- BG_DEEP   #0e1220  arka plan / gökyüzü gradyanı
- SURFACE   #1b2334  taş zemin, paneller
- PATH      #3a3428  yol (toprak), PATH_EDGE #241f18
- PRIMARY   #4ea8de  oyuncu dostu / mermi
- ACCENT    #f2a33c  altın, UI vurgusu
- DANGER    #e2564a  düşman / can göstergesi
- TEXT      #e8eef7 / TEXT_DIM #93a3bd
- FROST     #7fe3e0  yavaşlatma

Layout: 1280x720. HUD üstte 0..72, alan 128,110 boy 1024x512 (16x8 kare, 64px), alt bar 640..720. Alan asla panelin altında kalmaz.
UI: köşe yarıçapı 10, yazı 18-24, başlık 32. Panel gölgeleri, her nesne altında yumuşak gölge elips.
Efekt: hasar flaşı <120ms, ölüm patlaması, kule ateşi için kısa parlama. Shake yok.
