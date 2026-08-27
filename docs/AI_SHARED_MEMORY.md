# 🧠 AI Coding Assistant Ortak Hafıza (Shared Memory) Kılavuzu

> **Yeni Başlanacak Sohbetlerde AI İçin Ortak Hafıza Nasıl Oluşturulur?**  
> Bu belge, modern yapay zekâ kodlama asistanlarının (Antigravity, Claude Code, Cursor, Codex, Aider vb.) oturumlar (sessions/chats) arası bağlam kaybını ("AI Amnesia") önlemek için kullanılan en popüler ve kanıtlanmış endüstri standartlarını açıklar.

---

## 🧭 1. Problem: "Yapay Zekâ Amnezisi" (AI Context Amnesia)

Büyük dil modelleri (LLM) durumsuz (stateless) çalışır. Her yeni sohbet penceresi açıldığında:
1. Model önceki sohbetlerde keşfedilen mimari kararları,
2. Çözülen zorlu ağ/protokol bug'larını (örn. 9Router `finish_reason: stop` + TCP Status 8 davranışı),
3. Projeye özel dosya yapısını ve katı kuralları (SRP, preload kuralı vb.)
**unutur**.

Bu problemi çözmek için endüstride **Katmanlı Hafıza Mimarisi (Tiered Memory Architecture)** standardı geliştirilmiştir.

---

## 🏗️ 2. En Popüler ve Etkili Ortak Hafıza Yöntemleri

```
┌─────────────────────────────────────────────────────────────┐
│ 1. STATİK ÇEKİRDEK KURAL KATMANI (Universal L1 Layer)       │
│    • AGENTS.md (Açık Kaynak Standart - Tüm Asistanlar)     │
│    • CLAUDE.md (Claude Code) / .cursorrules (Cursor)        │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 2. ALAN VE BİLGİ KATMANI (Knowledge Base & Memory L2)       │
│    • brain/knowledge.md (Öğrenilen kritik teknik bilgiler)  │
│    • ARCHITECTURE.md (Mimari şema ve bağımlılıklar)        │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ 3. DEVİR VE İLERLEME KATMANI (Session Handoff / L3)         │
│    • CHANGELOG.md & ROADMAP.md (Neredeyiz, sırada ne var?)   │
│    • brain/tasks.md / HANDOFF.md (Canlı görev durumu)       │
└─────────────────────────────────────────────────────────────┘
```

---

## 📄 3. Hangi Dosya Ne İçin Kullanılır?

| Dosya Adı | Kime Hitap Eder? | Amacı | İçermesi Gerekenler |
| :--- | :--- | :--- | :--- |
| **`AGENTS.md`** *(Önerilen Standart)* | Tüm AI Ajanları (Evrensel) | Proje genel kurallarını, test komutlarını ve katı mimari ilkeleri anlatır. | Proje kimliği, SRP kuralları, test komutları, preload kuralı, güvenlik sandbox'ı. |
| **`README.md`** | İnsan Geliştiriciler & Kullanıcılar | Projeyi tanıtmak, özelliklerini anlatmak ve kurulum adımlarını göstermek. | Özellik listesi, ekran görüntüleri, kurulum rehberi, release linkleri. |
| **`CHANGELOG.md`** | İnsan & AI | Sürümler arasındaki somut değişiklik geçmişi. | Keep a Changelog formatında eklenenler, düzeltilenler ve kaldırılanlar. |
| **`ROADMAP.md`** | İnsan & AI | Projenin tamamlanan ve gelecekteki fazları. | Faz 1-7 kontrol listesi, tamamlanan ve sıradaki kilometre taşları. |
| **`ARCHITECTURE.md`** | Geliştirici & AI Mimarlar | Katmanlar, bağımlılıklar ve veri akış diyagramları. | Mermaid şemaları, presentation/domain/infra sorumlulukları. |
| **`brain/knowledge.md`** | AI Karar Destek Sistemi | Çözülen bug'lar, işletim sistemi ve ağ gariplikleri. | 9Router SSE `finish_reason` kapanış davranışı, Windows localhost DNS çözümü. |

---

## 🚀 4. Yeni Bir Sohbete Başlarken En İyi Pratik (Best Practice)

Yeni bir sohbet başlattığınızda yapay zekaya sadece şunu söylemeniz yeterlidir:

> *"Projeyi anlamak için lütfen önce `AGENTS.md` ve `brain/knowledge.md` dosyalarını oku."*

Veya çoğu modern ajan (Antigravity, Claude Code, Cursor) proje kökündeki `AGENTS.md` dosyasını ilk adımda **otomatik olarak** context'e yükler. Böylece:
* Ajan aynı hataları tekrarlamaz,
* Yanlış teşhis koymaz,
* Mevcut mimariyi ve test komutlarını bilerek doğrudan göreve odaklanır.
