# tests/diagnostic — tek seferlik ölçüm probe'ları

Bu klasördeki betikler **test değildir**: `test_runner.gd` onları koşmaz, başarı/başarısızlık döndürmezler, ölçüm yazdırırlar. Çoğu 22.09 "AGY ile gönderimde 10–35 sn donma" araştırmasından kalır; sorun AGY hazırlık durum makinesiyle çözüldü ve kalıcı davranış `tests/integration/test_agy_readiness_scenarios.gd` ile test altındadır.

Neden tutuluyorlar (Refactor Faz 3.5 kararı, 2026-09-26): hepsi derleniyor, eriştikleri iç üyeler (`_ensure_process`, `_stdio`, `_reader_thread`, `_format_prompt`) hâlâ mevcut; yerel olanlar koşturulup çalıştığı görüldü. Ağ / AGY / GUI performansı yeniden şüpheli olursa aynı ölçümü tekrar almak için değerli; silmek yalnızca git geçmişine taşırdı. Kırık olan iki probe (`agy_send_path_probe`, `integrated_send_path_probe`) bulgu #19'da silindi.

Çalıştırma: `godot --headless --path . -s res://tests/diagnostic/<dosya>.gd`

| Probe | Ölçtüğü | Gerektirdiği |
|---|---|---|
| `gui_freeze_probe.gd` | Gönderimden önceki senkron çağrıların (context, mention, şema filtreleme, i18n…) tek tek maliyeti | Yerel (headless) |
| `phase_a_real_probe.gd` | Aynı zincirin gerçek fonksiyonlarla toplam maliyeti (10 sn blokaj var mı) | Yerel; `api_config` okur |
| `freeze_probe_phase2.gd` | Çekirdek dışı adaylar: `OS.execute_with_pipe("agy")`, UI bileşen inşası | AGY CLI (`agy`) kurulu |
| `agy_lifecycle_probe.gd` | `stop_process()` → `wait_to_finish()` ana thread'i blokluyor mu | AGY CLI |
| `agy_stop_process_order_probe.gd` | Gerçek kapanış sırasıyla (`close` → `kill` → `wait`) blokaj | AGY CLI |
| `agy_send_substep_probe.gd` | AGY gönderim yolunun alt adım süreleri (`store_string` payı) | AGY CLI, oturum açık |
| `agy_pipe_backpressure_probe.gd` | `store_string` blokajının pipe backpressure mı süreç hazırlığı mı olduğu | AGY CLI, oturum açık |
| `agy_warmup_gap_probe.gd` | `pre_warm` ile ilk gönderim arasındaki boşluğun etkisi | AGY CLI, oturum açık |
| `model_alias_verify_probe.gd` | Model takma adlarının HTTP durum kodları (403 ücretsiz katman bulgusu) | 9Router `127.0.0.1:20128` |
| `streaming_ttft_probe.gd` | Streaming ilk token süresi: soğuk / sıcak ayrımı | 9Router `127.0.0.1:20128` |

Not: `typecheck` bu betikleri derler ama tipsiz üye erişimini yakalamaz (bkz. REFACTOR_PLAN bulgu #19). İç üye adı değişen bir refactor'da bu klasör de grep ile taranmalıdır.

`tests/test_reality_probe.gd` da runner dışıdır: sahte provider ile ajan döngüsü, PathPolicy normalizasyonu, UndoRedo ve ChangeSet üzerinde gözle okunan bir "gerçeklik" turu yazdırır (yerel, 2026-09-26'da koşturuldu ve çalışıyor). Kapsadığı davranışlar runner'daki paketlerde (`PathPolicyTests`, `ChangeSetTests`, `AgentRunnerStateTests`) assertion'larla test altındadır; elle hızlı kontrol için tutulur.
