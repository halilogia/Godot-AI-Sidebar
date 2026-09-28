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
