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
