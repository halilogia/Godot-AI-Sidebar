@tool
extends RefCounted
class_name AISidebarToolResult

## Standart Araç Sonuç Modeli (SRP).
## Başarı ve hata durumlarını yapısal olarak temsil eder.

static func ok(data: Variant = null, message: String = "") -> Dictionary:
	var res: Dictionary = {
		"success": true,
		"data": data,
		"error": null
	}
	if not message.is_empty():
		res["message"] = message
	return res

## Modelin çağrısının argümanları kesilmiş ya da geçerli JSON değil (çoğunlukla çıktı çok uzayınca): araç çalışmaz.
static func invalid_arguments(tool_name: String) -> Dictionary:
	return err("TOOL_ARGUMENTS_INVALID", "The arguments of your %s call were cut off or are not valid JSON (usually because the output got too long), so nothing ran. Call it again with less content: at most 3-4 files per call, each short, and keep your reasoning brief." % tool_name, true)

static func err(code: String, message: String, recoverable: bool = true, extra_data: Variant = null) -> Dictionary:
	return {
		"success": false,
		"data": extra_data,
		"error": {
			"code": code,
			"message": message,
			"recoverable": recoverable
		}
	}
