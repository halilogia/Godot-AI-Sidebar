@tool
extends RefCounted
class_name AISidebarRuntimeObservation

## Çalışma Zamanı Gözlem Veri Modeli (Runtime Observation Domain Model) (SRP).
## Oyun sürecinden toplanan hata, uyarı, çağrı yığını (stack trace) ve durum verilerini normalize eder.
## Epistemik durum ayrımı yapar: STARTING, NO_NEW_LOG_DATA, INCONCLUSIVE, ERROR_DETECTED, CRASHED, VERIFIED_CLEAN.

enum RuntimeStatus {
	STOPPED,
	STARTING,
	RUNNING,
	NO_NEW_LOG_DATA,
	ERROR_DETECTED,
	CRASHED,
	VERIFIED_CLEAN,
	INCONCLUSIVE
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
var elapsed_msec: int = 0
var new_log_bytes: int = 0
var is_process_alive: bool = false
var metadata: Dictionary = {}

func _init() -> void:
	timestamp = Time.get_unix_time_from_system()

func has_errors() -> bool:
	return errors.size() > 0 or status == RuntimeStatus.CRASHED or status == RuntimeStatus.ERROR_DETECTED

func is_verified_clean() -> bool:
	return status == RuntimeStatus.VERIFIED_CLEAN

func is_inconclusive() -> bool:
	return status == RuntimeStatus.INCONCLUSIVE or status == RuntimeStatus.STARTING or status == RuntimeStatus.NO_NEW_LOG_DATA

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

func get_observation_verdict() -> String:
	match status:
		RuntimeStatus.ERROR_DETECTED:
			return "ERROR_DETECTED: " + str(errors.size()) + " runtime error(s) found in log."
		RuntimeStatus.CRASHED:
			return "CRASHED: Process terminated abnormally (Exit code: " + str(exit_code) + ")."
		RuntimeStatus.STARTING:
			return "STARTING: Process recently started (" + str(elapsed_msec) + "ms). Observation is inconclusive until engine initializes."
		RuntimeStatus.NO_NEW_LOG_DATA:
			return "NO_NEW_LOG_DATA: Process alive, but no new log output was generated in this observation turn."
		RuntimeStatus.INCONCLUSIVE:
			return "INCONCLUSIVE: Cannot confirm error-free execution yet. Game is running but observation window has not completed."
		RuntimeStatus.VERIFIED_CLEAN:
			return "VERIFIED_CLEAN: Process ran past checkpoint (" + str(elapsed_msec) + "ms) with positive engine initialization and 0 errors."
		RuntimeStatus.STOPPED:
			return "STOPPED: Process is not running."
		_:
			return "RUNNING: Process active."

## Ajan için kompakt teşhis metni üretir (Token tasarruflu ve net kaynak işaretli)
func format_diagnostic_prompt() -> String:
	var lines: PackedStringArray = []
	lines.append("=== OYUN ÇALIŞMA ZAMANI GÖZLEMİ (RUNTIME OBSERVATION) ===")
	lines.append("Durum: " + _status_to_string(status))
	lines.append("Gözlem Kararı: " + get_observation_verdict())
	lines.append("Süreç Aktif: " + str(is_process_alive) + " | Geçen Süre: " + str(elapsed_msec) + "ms | Yeni Log: " + str(new_log_bytes) + " bytes")
	
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
		RuntimeStatus.STARTING: return "Başlatılıyor (STARTING)"
		RuntimeStatus.RUNNING: return "Çalışıyor (RUNNING)"
		RuntimeStatus.NO_NEW_LOG_DATA: return "Yeni Log Yok (NO_NEW_LOG_DATA)"
		RuntimeStatus.ERROR_DETECTED: return "Hata Yakalandı (ERROR_DETECTED)"
		RuntimeStatus.CRASHED: return "Çöktü (CRASHED)"
		RuntimeStatus.VERIFIED_CLEAN: return "Doğrulandı - Temiz (VERIFIED_CLEAN)"
		RuntimeStatus.INCONCLUSIVE: return "Belirsiz (INCONCLUSIVE)"
		_: return "Durduruldu (STOPPED)"

func to_dict() -> Dictionary:
	return {
		"status": status,
		"status_name": _status_to_string(status),
		"observation_verdict": get_observation_verdict(),
		"is_process_alive": is_process_alive,
		"elapsed_msec": elapsed_msec,
		"new_log_bytes": new_log_bytes,
		"is_verified_clean": is_verified_clean(),
		"is_inconclusive": is_inconclusive(),
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
