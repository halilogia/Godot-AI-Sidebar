# Claude Code entegrasyonu (v3.1)

Godot AI Sidebar'ın MCP köprüsüyle çalışan Claude Code için **skill'ler** (nasıl çalışılacağını anlatan talimat paketleri) ve oyun projesi **hafıza belgesi şablonları**.

Skill'ler yeni bir Godot API'si eklemez; köprünün mevcut araçlarını (okuma, `sync_project`, sahne araçları, oyunu çalıştırma, runtime hataları, ekran görüntüsü) doğru sırayla kullanmayı öğretir. Temel kural: **üretim dosya-öncelikli** (script, sahne, kaynak ve veri dosyalarını ajan kendisi yazar, sonra `sync_project`), **editör etkileşimi araç-öncelikli** (açık sahnede küçük, Undo'lu düzenlemeler).

## Kurulum

1. Godot'da oyun projesini açın, sidebar'da `/mcp on` yazın, panoya kopyalanan `claude mcp add …` komutunu oyun projesinin klasöründe çalıştırın (`claude mcp list` → `✔ Connected`).
2. Skill'leri kopyalayın:
   * yalnız bu oyun için: `skills/` altındaki klasörleri oyun projesinde `.claude/skills/` içine,
   * bütün projeleriniz için: `~/.claude/skills/` içine.
3. Sahne araçlarını kullanacaksanız sidebar'da `/mcp write ask` (her değişikliği onaylarsınız) ya da `/mcp write auto`. Varsayılan kapalıdır ve editör her açıldığında kapanır.

## Skill'ler

| Skill | Ne zaman |
|---|---|
| `godot-project-bootstrap` | Yeni ya da ilk kez çalışılan proje: bağlantı, hafıza belgeleri, klasör düzeni, çalışan ana sahne |
| `godot-feature-development` | Yeni mekanik / sistem / sahne / arayüz: kabul kriteri → dosya-öncelikli uygulama → sync → doğrula → çalıştır → gözle → düzelt |
| `godot-scene-authoring` | `.tscn` / `.tres` yazımı, çok düğümlü veya tekrarlı içerik (veri + kod), açık sahnede araçla düzenleme |
| `godot-debug-and-repair` | Hata, çökme, yanlış davranış: kanıtla yeniden üret, kök neden, en küçük düzeltme, tekrar kanıtla |
| `godot-runtime-verification` | "Bitti" demeden önce: her kabul kriteri için oyundan kanıt (hata kontrolü, ekran görüntüsü, canlı düğüm) |
| `godot-refactor` | Davranışı değiştirmeden yeniden yapılandırma: önce / sonra karşılaştırması, `.uid` ve `res://` yolları |
| `godot-release-workflow` | Milestone kapanışı ve sürüm: belgeler, sürüm numarası, dışa aktarma, etiket |

## Proje hafızası

Oyun deposunun kökünde beş belge tutulur; şablonlar `templates/` altında: `GAME_SPEC.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `DECISIONS.md`, `KNOWN_ISSUES.md`. Skill'ler bunları okur ve günceller. Gerekmedikçe başka belge türü eklenmez.
