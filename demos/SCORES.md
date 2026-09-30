# Ajan puan tablosu

Her satır bir `tools/demo_bench.ps1` çalıştırması (başarısızlar dahil). Puan `tools/demo_score.ps1`'deki kurala göre yalnız ölçümlerden hesaplanır: tamamlanma 40, oyunu çalıştırıp doğrulama 20, süre 15, başarısız araç 15, adım 10. Son iki sütun eklentinin kendi maliyeti (puana girmez): model isteklerinin ortalama / en büyük boyutu ve modelin dışında geçen süre.

| Tarih | Tür | Puan | Durum | Süre | Adım | Başarısız araç | Model | İstek KB ort / max | Eklenti süresi |
|---|---|---|---|---|---|---|---|---|---|
| 2026-09-27 23:05 | platformer | **20** | timeout | 20 dk | 26 | 6 | a | 101 / 157 | 12 s |
| 2026-09-27 23:33 | platformer | **85** | başarılı | 11.7 dk | 37 | 3 | a | 116 / 212 | 12.7 s |
| 2026-09-27 23:46 | topdown-shooter | **95** | başarılı | 7.6 dk | 26 | 5 | a | 91 / 167 | 4.6 s |
| 2026-09-27 23:59 | card-game | **40** | bitti, başarısız | 31.5 dk | 127 | 22 | a | 160 / 354 | 39.9 s |
| 2026-09-28 18:46 | grand-strategy | **55** | bitti, başarısız | 13.8 dk | 44 | 7 | a | 214 / 606 | 60.8 s |
| 2026-09-28 19:11 | grand-strategy | **70** | bitti, başarısız | 7.5 dk | 21 | 5 | a | 98 / 179 | 19.5 s |
| 2026-09-28 19:27 | match3 | **65** | bitti, başarısız | 18.4 dk | 27 | 5 | a | 103 / 196 | 100.4 s |
| 2026-09-28 19:45 | snake | **75** | bitti, başarısız | 4.6 dk | 11 | 2 | a | 44 / 81 | 101.4 s |
| 2026-09-28 19:50 | tower-defense | **65** | bitti, başarısız | 10.8 dk | 33 | 2 | a | 94 / 153 | 87.9 s |
| 2026-09-28 20:05 | snake | **70** | bitti, başarısız | 3.1 dk | 32 | 0 | openrouter/space-bunny-alpha | 46 / 72 | 6 s |
| 2026-09-28 20:08 | match3 | **60** | bitti, başarısız | 9.7 dk | 74 | 4 | openrouter/space-bunny-alpha | 88 / 179 | 17.8 s |
| 2026-09-28 20:18 | tower-defense | **50** | bitti, başarısız | 23.4 dk | 187 | 4 | openrouter/space-bunny-alpha | 82 / 142 | 39.6 s |
| 2026-09-28 20:42 | endless-runner | **60** | bitti, başarısız | 10.6 dk | 46 | 4 | openrouter/space-bunny-alpha | 71 / 107 | 131.4 s |
| 2026-09-28 20:53 | turn-based-rpg | **20** | timeout | 35.1 dk | 154 | 21 | openrouter/space-bunny-alpha | 89 / 127 | 220.1 s |
| 2026-09-28 21:30 | tower-defense | **45** | bitti, başarısız | 19 dk | 112 | 11 | openrouter/space-bunny-alpha | 80 / 386 | 268.9 s |
| 2026-09-28 21:52 | tower-defense | **55** | bitti, başarısız | 5.5 dk | 4 | 0 | openrouter/space-bunny-alpha | 41 / 57 | 129.7 s |
| 2026-09-28 22:02 | tower-defense | **55** | bitti, başarısız | 12.2 dk | 45 | 7 | openrouter/space-bunny-alpha | 73 / 128 | 138.4 s |
| 2026-09-28 22:56 | turn-based-rpg | **50** | bitti, başarısız | 18.9 dk | 130 | 9 | openrouter/space-bunny-alpha | 103 / 223 | 106.5 s |
| 2026-09-28 23:15 | match3 | **75** | bitti, başarısız | 6.7 dk | 17 | 0 | openrouter/space-bunny-alpha | 66 / 94 | 3.2 s |
| 2026-09-28 23:48 | match3 | **55** | bitti, başarısız | 5.7 dk | 7 | 0 | oc/space-bunny-free | 34 / 51 | 125.8 s |
| 2026-09-29 00:33 | turn-based-rpg | **50** | bitti, başarısız | 11 dk | 7 | 1 | space-bunny-free | 36 / 46 | 1.9 s |
| 2026-09-29 00:53 | match3 | **50** | bitti, başarısız | 14.2 dk | 92 | 7 | space-bunny-free | 83 / 224 | 12.9 s |
| 2026-09-29 01:07 | turn-based-rpg | **65** | bitti, başarısız | 5.6 dk | 55 | 4 | space-bunny-free | 69 / 149 | 13 s |
| 2026-09-29 01:21 | endless-runner | **95** | başarılı | 7 dk | 60 | 1 | space-bunny-free | 86 / 143 | 17.7 s |
| 2026-09-29 01:28 | snake | **90** | başarılı | 5.7 dk | 58 | 4 | space-bunny-free | 71 / 275 | 14.4 s |
| 2026-09-29 01:34 | tower-defense | **45** | bitti, başarısız | 15.8 dk | 165 | 12 | space-bunny-free | 81 / 149 | 88.1 s |
| 2026-09-29 01:50 | platformer | **95** | başarılı | 5 dk | 57 | 0 | space-bunny-free | 83 / 208 | 17.3 s |
| 2026-09-29 01:56 | topdown-shooter | **90** | başarılı | 6.7 dk | 89 | 1 | space-bunny-free | 64 / 105 | 19.6 s |
| 2026-09-29 02:03 | topdown-racing | **90** | başarılı | 9.1 dk | 81 | 1 | space-bunny-free | 70 / 137 | 56.8 s |
| 2026-09-29 02:12 | fps-3d | **100** | başarılı | 2.4 dk | 24 | 0 | space-bunny-free | 66 / 101 | 6.7 s |
| 2026-09-29 02:15 | grand-strategy | **70** | bitti, başarısız | 4.9 dk | 59 | 1 | space-bunny-free | 71 / 165 | 9.9 s |
| 2026-09-29 02:20 | card-game | **80** | başarılı | 5.9 dk | 66 | 6 | space-bunny-free | 77 / 147 | 14.2 s |
| 2026-09-29 02:26 | match3 | **60** | bitti, başarısız | 15.6 dk | 156 | 2 | space-bunny-free | 90 / 221 | 107.2 s |
| 2026-09-29 02:42 | turn-based-rpg | **60** | bitti, başarısız | 7.3 dk | 62 | 3 | space-bunny-free | 89 / 158 | 12.6 s |
| 2026-09-29 02:50 | endless-runner | **65** | bitti, başarısız | 6.2 dk | 57 | 3 | space-bunny-free | 92 / 170 | 14.3 s |
| 2026-09-29 02:57 | snake | **95** | başarılı | 4.5 dk | 51 | 2 | space-bunny-free | 66 / 106 | 20.5 s |
| 2026-09-29 03:01 | tower-defense | **90** | başarılı | 9.1 dk | 85 | 1 | space-bunny-free | 81 / 141 | 23.3 s |
| 2026-09-29 03:11 | platformer | **90** | başarılı | 9.1 dk | 106 | 2 | space-bunny-free | 76 / 118 | 39.9 s |
| 2026-09-29 03:21 | topdown-shooter | **95** | başarılı | 4.9 dk | 56 | 1 | space-bunny-free | 66 / 104 | 17.3 s |
| 2026-09-29 03:27 | topdown-racing | **80** | başarılı | 11.5 dk | 94 | 5 | space-bunny-free | 71 / 198 | 36.6 s |
| 2026-09-29 03:38 | fps-3d | **95** | başarılı | 3.8 dk | 44 | 1 | space-bunny-free | 66 / 141 | 14.1 s |
| 2026-09-29 03:43 | grand-strategy | **60** | bitti, başarısız | 9.7 dk | 98 | 4 | space-bunny-free | 98 / 267 | 18.1 s |
| 2026-09-29 03:53 | card-game | **55** | bitti, başarısız | 11.4 dk | 91 | 5 | space-bunny-free | 72 / 135 | 12.1 s |
| 2026-09-29 04:04 | match3 | **80** | başarılı | 12 dk | 107 | 5 | space-bunny-free | 100 / 323 | 40.2 s |
| 2026-09-29 04:17 | turn-based-rpg | **90** | başarılı | 7 dk | 79 | 2 | space-bunny-free | 76 / 143 | 13.4 s |
| 2026-09-29 04:24 | endless-runner | **75** | başarılı | 13.8 dk | 132 | 7 | space-bunny-free | 81 / 132 | 53 s |
| 2026-09-29 04:38 | snake | **95** | başarılı | 4.7 dk | 48 | 1 | space-bunny-free | 59 / 103 | 11.2 s |
| 2026-09-29 04:43 | tower-defense | **85** | başarılı | 7.3 dk | 74 | 3 | space-bunny-free | 77 / 146 | 14.7 s |
| 2026-09-29 05:05 | grand-strategy | **95** | başarılı | 6.3 dk | 45 | 0 | space-bunny-free | 93 / 238 | 18.2 s |
| 2026-09-29 05:11 | card-game | **55** | bitti, başarısız | 5.2 dk | 63 | 6 | space-bunny-free | 67 / 117 | 9.6 s |
| 2026-09-29 05:17 | platformer | **60** | bitti, başarısız | 8.4 dk | 82 | 4 | space-bunny-free | 78 / 124 | 47 s |
| 2026-09-29 05:25 | tower-defense | **80** | başarılı | 10.9 dk | 105 | 5 | space-bunny-free | 80 / 131 | 43.2 s |
| 2026-09-29 05:37 | snake | **45** | bitti, başarısız | 14 dk | 146 | 13 | space-bunny-free | 74 / 106 | 119.9 s |
| 2026-09-29 05:51 | grand-strategy | **95** | başarılı | 4.7 dk | 48 | 0 | space-bunny-free | 76 / 253 | 7.3 s |
| 2026-09-29 05:56 | card-game | **95** | başarılı | 4.4 dk | 52 | 0 | space-bunny-free | 64 / 140 | 7.7 s |
| 2026-09-29 06:01 | platformer | **25** | timeout | 35 dk | 182 | 9 | space-bunny-free | 80 / 122 | 155.4 s |
| 2026-09-29 06:36 | tower-defense | **60** | bitti, başarısız | 16.4 dk | 62 | 2 | space-bunny-free | 72 / 153 | 13 s |
| 2026-09-29 06:53 | snake | **70** | bitti, başarısız | 3.4 dk | 33 | 2 | space-bunny-free | 55 / 95 | 4.8 s |
| 2026-09-29 06:57 | grand-strategy | **60** | bitti, başarısız | 7.8 dk | 89 | 4 | space-bunny-free | 77 / 136 | 20.4 s |
| 2026-09-29 07:05 | card-game | **85** | başarılı | 9.6 dk | 95 | 3 | space-bunny-free | 86 / 190 | 16.3 s |
| 2026-09-29 07:15 | platformer | **85** | başarılı | 10.3 dk | 92 | 1 | space-bunny-free | 71 / 124 | 33.6 s |
| 2026-09-29 07:26 | tower-defense | **90** | başarılı | 7.5 dk | 77 | 1 | space-bunny-free | 75 / 131 | 11.4 s |
| 2026-09-29 07:40 | platformer | **85** | başarılı | 5.9 dk | 71 | 3 | space-bunny-free | 62 / 109 | 18.5 s |
| 2026-09-29 07:46 | card-game | **65** | başarılı | 30.9 dk | 261 | 17 | space-bunny-free | 80 / 141 | 57.6 s |
| 2026-09-29 08:17 | snake | **65** | bitti, başarısız | 3.7 dk | 39 | 3 | space-bunny-free | 62 / 108 | 12.7 s |
| 2026-09-29 08:31 | card-game | **100** | başarılı | 1.4 dk | 17 | 1 | ag/gemini-3.8-flash-low | 39 / 64 | 2.3 s |
| 2026-09-29 08:32 | platformer | **100** | başarılı | 2.2 dk | 30 | 1 | ag/gemini-3.8-flash-low | 40 / 57 | 3.7 s |
| 2026-09-29 08:35 | snake | **100** | başarılı | 0.9 dk | 17 | 1 | ag/gemini-3.8-flash-low | 33 / 47 | 2.4 s |
| 2026-09-29 09:01 | card-game | **95** | başarılı | 3.4 dk | 40 | 1 | space-bunny-free | 72 / 143 | 7.1 s |
| 2026-09-29 09:04 | platformer | **45** | bitti, başarısız | 13.1 dk | 123 | 12 | space-bunny-free | 86 / 134 | 56.1 s |
| 2026-09-29 14:29 | platformer | **65** | bitti, başarısız | 4.8 dk | 54 | 4 | space-bunny-free | 76 / 123 | 21.6 s |
| 2026-09-29 14:34 | card-game | **60** | bitti, başarısız | 6.2 dk | 67 | 4 | space-bunny-free | 74 / 149 | 20.7 s |
| 2026-09-29 14:41 | grand-strategy | **90** | başarılı | 7.5 dk | 80 | 2 | space-bunny-free | 96 / 275 | 16.6 s |
| 2026-09-29 20:30 | fps-6step | **75** | başarılı | 49.3 dk | 51 | 3 | space-bunny-free | 100 / 224 | 15.6 s |
