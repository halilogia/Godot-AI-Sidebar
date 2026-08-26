@tool
extends RefCounted
class_name AISidebarVisualObservation

## Görsel Gözlem ve Sahne Analiz Veri Modeli (Visual Observation Domain Model) (SRP).
## Multimodal modelden dönen görsel teşhis, tespit edilen sorunlar ve güvenilirlik (confidence) skorunu tutar.

const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")

const CONFIDENCE_THRESHOLD: float = 0.65

var screenshot: AISidebarVisionInput = null
var description: String = ""
var detected_issues: Array[Dictionary] = [] # { issue_type, description, location_hint, severity }
var confidence: float = 1.0
var suggested_actions: Array[String] = []
var timestamp: int = 0
var metadata: Dictionary = {}

func _init(p_screenshot: AISidebarVisionInput = null, p_desc: String = "", p_conf: float = 1.0) -> void:
	screenshot = p_screenshot
	description = p_desc
	confidence = p_conf
	timestamp = Time.get_unix_time_from_system()

func add_issue(issue_type: String, desc: String, loc_hint: String = "", severity: String = "WARNING") -> void:
	detected_issues.append({
		"issue_type": issue_type,
		"description": desc,
		"location_hint": loc_hint,
		"severity": severity
	})

func is_confident() -> bool:
	return confidence >= CONFIDENCE_THRESHOLD

func has_issues() -> bool:
	return detected_issues.size() > 0

## Teşhis promptu için kompakt metin üretir
func format_diagnostic_prompt() -> String:
	var lines: PackedStringArray = []
	lines.append("=== GÖRSEL ANALİZ GÖZLEMİ (VISUAL OBSERVATION) ===")
	lines.append("Görsel Açıklama: " + description)
	lines.append("Güvenilirlik Skoru (Confidence): " + str(snappedf(confidence * 100.0, 0.1)) + "%")
	
	if not is_confident():
		lines.append("⚠️ UYARI: Güvenilirlik skoru eşiğin altında (%65). Lütfen yıkıcı değişiklikler yapmadan önce teyit edin.")
		
	if detected_issues.size() > 0:
		lines.append("Tespit Edilen Görsel Sorunlar (" + str(detected_issues.size()) + "):")
		for issue in detected_issues:
			var loc = (" @" + issue["location_hint"]) if not issue.get("location_hint", "").is_empty() else ""
			lines.append(" - [" + issue.get("severity", "WARNING") + "] " + issue.get("issue_type", "ANOMALY") + ": " + issue.get("description", "") + loc)
			
	if suggested_actions.size() > 0:
		lines.append("Önerilen Eylemler:")
		for act in suggested_actions:
			lines.append(" ↳ " + act)
			
	lines.append("==================================================")
	return "\n".join(lines)

func to_dict() -> Dictionary:
	return {
		"description": description,
		"confidence": confidence,
		"is_confident": is_confident(),
		"has_issues": has_issues(),
		"issues": detected_issues,
		"suggested_actions": suggested_actions,
		"timestamp": timestamp,
		"metadata": metadata
	}
