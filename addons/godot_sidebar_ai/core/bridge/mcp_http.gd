@tool
extends RefCounted
class_name AISidebarMcpHttp

## MCP köprüsünün HTTP katmanı (saf; soket bilmez, test edilebilir).
## Yalnızca köprünün ihtiyacı olan alt küme: tek istek / bağlantı, Content-Length gövde,
## yanıtta `Connection: close`. Chunked gövde desteklenmez (411 döner).

const MAX_BODY_BYTES := 4 * 1024 * 1024

## Gelen ham byte'ları ayrıştırır.
## Dönüş: {"complete": false} (daha fazla veri bekleniyor) veya
## {"complete": true, "method", "path", "headers" (anahtarlar küçük harf), "body": String}
## ya da {"complete": true, "error_status": int, "error": String}.
static func parse_request(buffer: PackedByteArray) -> Dictionary:
	var header_end := _find_header_end(buffer)
	if header_end < 0:
		if buffer.size() > 64 * 1024:
			return {"complete": true, "error_status": 431, "error": "Request header too large"}
		return {"complete": false}
	var head := buffer.slice(0, header_end).get_string_from_utf8()
	var lines := head.split("\r\n")
	var request_line := lines[0].split(" ")
	if request_line.size() < 3:
		return {"complete": true, "error_status": 400, "error": "Malformed request line"}
	var headers: Dictionary = {}
	for i in range(1, lines.size()):
		var sep := lines[i].find(":")
		if sep > 0:
			headers[lines[i].left(sep).strip_edges().to_lower()] = lines[i].substr(sep + 1).strip_edges()
	if str(headers.get("transfer-encoding", "")).to_lower().contains("chunked"):
		return {"complete": true, "error_status": 411, "error": "Chunked bodies are not supported; send Content-Length"}
	var length := str(headers.get("content-length", "0")).to_int()
	if length < 0 or length > MAX_BODY_BYTES:
		return {"complete": true, "error_status": 413, "error": "Body too large"}
	var body_start := header_end + 4
	if buffer.size() - body_start < length:
		return {"complete": false}
	var body := buffer.slice(body_start, body_start + length).get_string_from_utf8()
	return {"complete": true, "method": request_line[0].to_upper(), "path": request_line[1], "headers": headers, "body": body}

static func _find_header_end(buffer: PackedByteArray) -> int:
	for i in range(0, buffer.size() - 3):
		if buffer[i] == 13 and buffer[i + 1] == 10 and buffer[i + 2] == 13 and buffer[i + 3] == 10:
			return i
	return -1

## Tam bir HTTP/1.1 yanıtı üretir (UTF-8 gövde, Content-Length ile).
static func build_response(status: int, body: String = "", content_type: String = "application/json", extra_headers: Dictionary = {}) -> PackedByteArray:
	var body_bytes := body.to_utf8_buffer()
	var head := "HTTP/1.1 %d %s\r\n" % [status, _reason(status)]
	if not body.is_empty():
		head += "Content-Type: %s\r\n" % content_type
	head += "Content-Length: %d\r\n" % body_bytes.size()
	for k: Variant in extra_headers.keys():
		head += "%s: %s\r\n" % [str(k), str(extra_headers[k])]
	head += "Connection: close\r\n\r\n"
	var out := head.to_utf8_buffer()
	out.append_array(body_bytes)
	return out

static func _reason(status: int) -> String:
	match status:
		200: return "OK"
		202: return "Accepted"
		400: return "Bad Request"
		401: return "Unauthorized"
		403: return "Forbidden"
		404: return "Not Found"
		405: return "Method Not Allowed"
		411: return "Length Required"
		413: return "Payload Too Large"
		431: return "Request Header Fields Too Large"
		_: return "Error"
