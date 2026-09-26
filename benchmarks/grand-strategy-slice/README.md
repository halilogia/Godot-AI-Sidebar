# Benchmark: grand strateji dikey kesiti (v3.2)

Amaç: Claude Code ile Godot AI Sidebar köprüsünün **tek istemle** küçük ama gerçek bir oyunu (province haritası, 3 ülke, seçim, zaman akışı, ekonomi, savaş) ne kadar otonom kurabildiğini **ölçmek**. Sonuçlar sonraki yol haritası kararlarının girdisidir (eksik araç, eksik skill, Companion gerekir mi).

## Dosyalar

| Dosya | İçerik |
|---|---|
| `PROMPT.md` | Claude Code'a tek mesaj olarak verilen istek |
| `ACCEPTANCE.md` | Kabul kriterleri, her birinin hangi kanıtla sayılacağı ve her koşuda kaydedilecekler |
| `new_benchmark_project.ps1` | Boş oyun projesi kurar: `project.godot` (eklenti etkin), eklentiye junction, `ACCEPTANCE.md`, git |

## Koşu

1. `powershell -ExecutionPolicy Bypass -File .\benchmarks\grand-strategy-slice\new_benchmark_project.ps1 -Path <yeni klasör>`
2. Projeyi Godot 4.7'de açın; sidebar'da `/mcp on`; panodaki `claude mcp add …` komutunu proje klasöründe çalıştırın.
3. Proje klasöründe `claude` başlatın ve `PROMPT.md`'nin içeriğini tek mesaj olarak verin. Ajanın sorularını yanıtlayın, başka yönlendirme yapmayın; her müdahaleyi not edin.
4. Bitince `ACCEPTANCE.md`'deki tabloyu doldurun (ajanın raporu + manuel kriterler için kendi denemeniz) ve "What to record per run" alanlarını kaydedin.

Bu depo yalnız altyapıyı içerir; gerçek koşu ve sonuçları final doğrulama fazında yapılır.
