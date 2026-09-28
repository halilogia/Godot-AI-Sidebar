# Ajan puan tablosu

Her satır bir `tools/demo_bench.ps1` çalıştırması (başarısızlar dahil). Puan `tools/demo_score.ps1`'deki kurala göre yalnız ölçümlerden hesaplanır: tamamlanma 40, oyunu çalıştırıp doğrulama 20, süre 15, başarısız araç 15, adım 10. Son iki sütun eklentinin kendi maliyeti (puana girmez): model isteklerinin ortalama / en büyük boyutu ve modelin dışında geçen süre.

| Tarih | Tür | Puan | Durum | Süre | Adım | Başarısız araç | Model | İstek KB ort / max | Eklenti süresi |
|---|---|---|---|---|---|---|---|---|---|
| 2026-09-27 23:05 | platformer | **20** | timeout | 20 dk | 26 | 6 | a | 101 / 157 | 12 s |
| 2026-09-27 23:33 | platformer | **85** | başarılı | 11.7 dk | 37 | 3 | a | 116 / 212 | 12.7 s |
| 2026-09-27 23:46 | topdown-shooter | **95** | başarılı | 7.6 dk | 26 | 5 | a | 91 / 167 | 4.6 s |
| 2026-09-27 23:59 | card-game | **40** | bitti, başarısız | 31.5 dk | 127 | 22 | a | 160 / 354 | 39.9 s |
