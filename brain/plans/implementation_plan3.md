# Auto Approve Sistemi (Cursor Benzeri) Uygulama Planı

Bu plan, Godot AI Sidebar için Cursor benzeri üç seviyeli (`MANUAL`, `AUTO`, `FULL_AUTO`) **Auto Approve** sistemini mevcut onay mimarisine (`AISidebarPermissionPolicy`, `AISidebarToolManager`, `AISidebarAgentRunner`, `ChatDock`) kesintisiz ve güvenli şekilde entegre etmeyi amaçlar.

## User Review Required

> [!IMPORTANT]
> - **Verification Pipeline Koruması:** Auto Approve modu açık olsa bile (`AUTO` veya `FULL_AUTO`), diske yazmadan önceki doğrulama boru hattı (`AISidebarVerificationPipeline`) ASLA atlanmaz. Hatalı GDScript/TSCN tespit edilirse işlem anında durdurulur ve hata modele geri döner.
> - **Güvenlik Kalkanı (`PathPolicy`):** `FULL_AUTO` modunda dahi `res://project.godot`, `.git/**` ve `addons/godot_sidebar_ai/**` gibi kritik dosyaların değiştirilmesi `PathPolicy` seviyesinde fiziksel olarak engellenmeye devam eder.

---

## Proposed Changes

### 1. Yapılandırma ve Kalıcılık (Configuration & Persistence)

#### [MODIFY] [api_config.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/config/api_config.gd)
- `DEFAULT_CONFIG` içerisine `"auto_approve_mode": "MANUAL"` eklenir.

---

### 2. Merkezi İzin ve Risk Kayıt Defteri (Security & Risk Registry)

#### [MODIFY] [permission_policy.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/security/permission_policy.gd)
- **Enumlar:**
  - `AutoApproveMode { MANUAL = 0, AUTO = 1, FULL_AUTO = 2 }`
  - `RiskLevel { READ_ONLY = 0, WRITE = 1, DESTRUCTIVE = 2, EXTERNAL_SENSITIVE = 3 }`
  - `PermissionLevel` (Mevcut testlerle geriye dönük tam uyumluluk için korunur)
- **Merkezi Risk Kayıt Defteri:**
  - `_tool_risk_registry: Dictionary`
  - `register_tool_risk(tool_name: String, risk: int) -> void`
  - `get_tool_risk(tool_name: String) -> int`
  - `get_tool_permission_level(tool_name: String) -> int` (Doğrudan `get_tool_risk` sonucunu döner)
  - `_init_default_risks()`: Projedeki tüm araçları (`READ_ONLY`, `WRITE`, `DESTRUCTIVE`, `EXTERNAL_SENSITIVE`) merkezi tabloda tanımlar.
- **Onay Mantığı:**
  - `parse_auto_approve_mode(val: Variant) -> AutoApproveMode`
  - `get_auto_approve_mode() -> AutoApproveMode`
  - `set_auto_approve_mode(mode: AutoApproveMode) -> void`
  - `requires_user_approval(tool_name: String, args: Dictionary = {}, mode_override: int = -1) -> bool`:
    - `FULL_AUTO`: Daima `false`.
    - `AUTO`: `DESTRUCTIVE` ve `EXTERNAL_SENSITIVE` için `true`; `READ_ONLY` ve `WRITE` için `false`.
    - `MANUAL`: Mevcut davranış (`DESTRUCTIVE` silme onayı, `WRITE` dosya ezme onayı, `EXTERNAL_SENSITIVE`).

---

### 3. Verification-First İcra Akışı (Tool Manager Integration)

#### [MODIFY] [tool_manager.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/tool_manager.gd)
- Kullanıcının talep ettiği icra sırası:
  ```
  AI tool çağrısı
  → validation/verification
  → verification PASS
  → approval policy
  → write
  ```
- `execute_tool(tool_name, args, is_user_approved)` içinde:
  1. Dosya yazma araçları (`create_or_update_script`, `replace_file_content`, `write_files`, `create_scene` içerikli) için aday içerik önce `PathPolicy` ve `AISidebarVerificationPipeline.validate_source` ile doğrulanır.
  2. Doğrulama başarısız olursa (`VerificationStatus.FAILED`), onay sorulmaz ve diske yazılmaz; doğrulama hatası doğrudan AI modeline geri döndürülür.
  3. Doğrulama başarılı olursa, `AISidebarPermissionPolicy.requires_user_approval` kontrolü yapılır.
  4. Onay gerekiyorsa `APPROVAL_REQUIRED` ile kullanıcıya sunulur; gerekmiyorsa (`AUTO` veya `FULL_AUTO`) doğrudan diske yazılır.

#### [MODIFY] [scene_tools.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/primitive/scene_tools.gd)
- `_create_scene`: `tscn_content` parametresi verildiğinde de `AISidebarVerificationPipeline.validate_source` doğrulaması işletilir.

---

### 4. Kullanıcı Arayüzü ve Durum Göstergesi (UI & Status Indication)

#### [MODIFY] [i18n.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/i18n/i18n.gd)
- TR ve EN sözlüklerine onay modu etiketleri eklenir:
  - `mode_manual`: "🛡️ Manual" / "🛡️ Manuel"
  - `mode_auto`: "⚡ Auto" / "⚡ Otomatik"
  - `mode_full_auto`: "🚀 Full Auto" / "🚀 Tam Otomatik"
  - `tooltip_approve_mode`: "Onay Modu (Manual / Auto / Full Auto)"

#### [MODIFY] [chat_dock.tscn](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/docks/chat_dock.tscn) & [chat_dock.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/docks/chat_dock.gd)
- `HeaderBar` veya `ModelBar` üzerine `AutoApproveBtn` (veya `OptionButton`) eklenir.
- Buton tek tıkla modlar arasında geçiş yapar (`Manual` ➔ `Auto` ➔ `Full Auto` ➔ `Manual`) ve seçimi `config.json`'a kaydeder.
- `StatusBadge` veya buton üzerinde aktif mod (`🛡️ Manual`, `⚡ Auto`, `🚀 Full Auto`) belirgin renk ve metinle gösterilir.
- Settings dialog (`settings_dialog.gd`) içine de mod seçici eklenir.

---

### 5. Birim ve Regresyon Testleri

#### [NEW] [test_auto_approve.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/tests/test_auto_approve.gd)
Kullanıcının talep ettiği 7 senaryo ve ek güvenlik doğrulamaları:
1. `MANUAL + normal write (overwrite)` ➔ `APPROVAL_REQUIRED` döner.
2. `AUTO + read-only` ➔ Otomatik çalışır.
3. `AUTO + normal write + valid verification` ➔ Otomatik çalışır ve diske yazar.
4. `AUTO + normal write + verification FAIL` ➔ Diske yazmaz, validation hatası döner.
5. `AUTO + delete` ➔ `APPROVAL_REQUIRED` döner.
6. `FULL_AUTO + write` ➔ Otomatik çalışır.
7. `FULL_AUTO + delete` ➔ Otomatik çalışır.
8. `FULL_AUTO + path violation (res://project.godot)` ➔ `PERMISSION_DENIED` ile engellenir.
9. Merkezi `register_tool_risk` genişletilebilirliği.
10. Mevcut onay/reddet (`approve_pending_action`, `reject_pending_action`) akışlarının bozulmadığı.

#### [MODIFY] [test_runner.gd](file:///c:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/tests/test_runner.gd)
- `TestAutoApprove` test paketini ana koşucuya kaydet.

---

## Verification Plan

### Automated Tests
```powershell
# 1. Tüm Testleri Koş (47 Test Paketi)
godot --headless --path . -s "res://tests/test_runner.gd"

# 2. GDScript Sözdizimi Kontrolü
godot --headless --path . --check-only
```

### Proje Senkronizasyonu
```powershell
# Değişiklikleri tüm test ve kullanıcı projelerine yay
pwsh -File "scripts/sync-example.ps1" -All
```
