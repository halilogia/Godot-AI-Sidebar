@tool
extends RefCounted
class_name AISidebarVisionInput

## Görsel Gözlem ve Ekran Görüntüsü Modeli (Vision Input Abstraction) (SRP).
## Multimodal modellere görüntü (Base64 / PNG) beslemek için kullanılır.

var image_data_base64: String = ""
var image_path: String = ""
var mime_type: String = "image/png"
var width: int = 0
var height: int = 0
var captured_at: int = 0

func _init(p_image_path: String = "", p_base64: String = "", p_w: int = 0, p_h: int = 0) -> void:
	image_path = p_image_path
	image_data_base64 = p_base64
	width = p_w
	height = p_h
	captured_at = Time.get_unix_time_from_system()

static func from_file(file_path: String) -> RefCounted:
	if not FileAccess.file_exists(file_path):
		return null
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return null
		
	var buffer = file.get_buffer(file.get_length())
	file.close()
	
	var base64 = Marshalls.raw_to_base64(buffer)
	var img = Image.new()
	var err = img.load(file_path)
	var w = img.get_width() if err == OK else 0
	var h = img.get_height() if err == OK else 0
	
	var vi = new(file_path, base64, w, h)
	return vi

## Image nesnesinden doğrudan VisionInput üretir
static func from_image(img: Image, p_path: String = "", p_mime: String = "image/png") -> RefCounted:
	if not img or img.is_empty():
		return null
	var buffer: PackedByteArray
	if p_mime == "image/jpeg" or p_mime == "image/jpg":
		buffer = img.save_jpg_to_buffer(0.85)
	else:
		buffer = img.save_png_to_buffer()
	var base64 = Marshalls.raw_to_base64(buffer)
	var vi = new(p_path, base64, img.get_width(), img.get_height())
	vi.mime_type = p_mime
	return vi

## OpenAI formatında multimodal image_url content parçası üretir
func to_openai_content_part() -> Dictionary:
	return {
		"type": "image_url",
		"image_url": {
			"url": "data:" + mime_type + ";base64," + image_data_base64
		}
	}
