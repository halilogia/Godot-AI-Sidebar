@tool
extends RefCounted
class_name AISidebarRuntimeObservation

## Çalışma Zamanı Gözlem Veri Modeli (Runtime Observation Domain Model) (SRP).
## Oyun sürecinden toplanan hata, uyarı, çağrı yığını (stack trace) ve durum verilerini normalize eder.

enum RuntimeStatus {
	STOPPED,
	RUNNING,
	ERROR_DETECTED,
	CRASHED
}

var status: RuntimeStatus = RuntimeStatus.STOPPED
var errors: Array[Dictionary] = []       # { raw, message, file, line, column, function, error_type }
var warnings: Array[String] = []
var stack_trace: Array[Dictionary] = []   # { file, line, function }
var stdout_text: String = ""
var stderr_text: String = ""
var exit_code: int = 0
var fps: float = 0.0
var timestamp: int = 0
var metadata: Dictionary = {}

func _init() -> void:
	timestamp = Time.get_unix_time_from_system()

func has_errors() -> bool:
	return errors.size() > 0 or status == RuntimeStatus.CRASHED or status == RuntimeStatus.ERROR_DETECTED

func add_error(msg: String, file: String = "", line: int = 0, fn: String = "", err_type: String = "RUNTIME_ERROR") -> void:
	errors.append({
		"raw": msg,
		"message": msg,
		"file": file,
		"line": line,
		"function": fn,
		"error_type": err_type
	})
	status = RuntimeStatus.ERROR_DETECTED

func add_stack_frame(file: String, line: int, fn: String) -> void:
	stack_trace.append({
		"file": file,
		"line": line,
		"function": fn
	})

## Ajan için kompakt teşhis metni üretir (Token tasarruflu ve net kaynak işaretli)
func format_diagnostic_prompt() -> String:
	var lines: PackedStringArray = []
	lines.append("=== OYUN ÇALIŞMA ZAMANI GÖZLEMİ (RUNTIME OBSERVATION) ===")
	lines.append("Durum: " + _status_to_string(status))
	
	if errors.size() > 0:
		lines.append("Tespit Edilen Hatalar (" + str(errors.size()) + "):")
		for err in errors:
			var loc = ""
			if not err.get("file", "").is_empty():
				loc = " @" + err.get("file", "") + ":" + str(err.get("line", 0))
				if not err.get("function", "").is_empty():
					loc += " in " + err.get("function", "") + "()"
			lines.append(" - [" + err.get("error_type", "ERROR") + "] " + err.get("message", "") + loc)
			
	if stack_trace.size() > 0:
		lines.append("Çağrı Yığını (Stack Trace):")
		for frame in stack_trace:
			lines.append("   ↳ " + frame.get("file", "unknown") + ":" + str(frame.get("line", 0)) + " in " + frame.get("function", "main"))
			
	if not stderr_text.is_empty():
		lines.append("Standart Hata Çıktısı (stderr):\n" + stderr_text.strip_edges())
		
	lines.append("=========================================================")
	return "\n".join(lines)

func _status_to_string(st: RuntimeStatus) -> String:
	match st:
		RuntimeStatus.RUNNING: return "Çalışıyor (RUNNING)"
		RuntimeStatus.ERROR_DETECTED: return "Hata Yakalandı (ERROR_DETECTED)"
		RuntimeStatus.CRASHED: return "Çöktü (CRASHED)"
		_: return "Durduruldu (STOPPED)"

func to_dict() -> Dictionary:
	return {
		"status": status,
		"status_name": _status_to_string(status),
		"errors": errors,
		"warnings": warnings,
		"stack_trace": stack_trace,
		"stdout": stdout_text,
		"stderr": stderr_text,
		"exit_code": exit_code,
		"fps": fps,
		"timestamp": timestamp,
		"metadata": metadata
	}
