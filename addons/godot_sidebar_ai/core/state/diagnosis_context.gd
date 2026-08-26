@tool
extends RefCounted
class_name AISidebarDiagnosisContext

## Çok Boyutlu Teşhis Bağlamı (Holistic Diagnosis Context) (SRP).
## Editör durumu, çalışma zamanı logları, görsel gözlem ve son değişiklikleri birleştirerek teşhis bağlamı kurar.

const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarVisualObservation = preload("res://addons/godot_sidebar_ai/core/types/visual_observation.gd")
const AISidebarEditorStateSnapshot = preload("res://addons/godot_sidebar_ai/core/state/editor_state_snapshot.gd")

var runtime_observation: AISidebarRuntimeObservation = null
var visual_observation: AISidebarVisualObservation = null
var recent_changes: Array = []
var relevant_files: Array[String] = []

func _init(p_runtime: AISidebarRuntimeObservation = null, p_visual: AISidebarVisualObservation = null, p_changes: Array = []) -> void:
	runtime_observation = p_runtime
	visual_observation = p_visual
	recent_changes = p_changes

func format_full_diagnosis() -> String:
	var blocks: PackedStringArray = []
	blocks.append("====================================================")
	blocks.append("     BİRLEŞİK SİSTEM TEŞHİS RAPORU (DIAGNOSIS)      ")
	blocks.append("====================================================")
	
	# 1. Editör Durumu
	blocks.append(AISidebarEditorStateSnapshot.get_grounding_prompt_text())
	
	# 2. Runtime Log Gözlemi
	if runtime_observation and runtime_observation.has_errors():
		blocks.append("\n" + runtime_observation.format_diagnostic_prompt())
	else:
		blocks.append("\n[Runtime] Çalışma zamanında log hatası bulunamadı (Temiz).")
		
	# 3. Görsel Gözlem
	if visual_observation:
		blocks.append("\n" + visual_observation.format_diagnostic_prompt())
		
	# 4. Son Değişiklikler
	if recent_changes.size() > 0:
		blocks.append("\n[Son AI Değişiklikleri]:")
		for ch in recent_changes.slice(-3):
			blocks.append(" - " + str(ch))
			
	blocks.append("====================================================")
	blocks.append("Lütfen yukarıdaki log, görsel ve editör durumunu birlikte değerlendirerek kök sebebi teşhis edin ve düzeltici ChangeSet'i önerin.")
	return "\n".join(blocks)
