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

## Aynı görsel mi? (yanlışlıkla çift eklemeyi önlemek için)
static func is_same_image(a, b) -> bool:
	if a == null or b == null:
		return false
	var ab = a.image_data_base64 if a is AISidebarVisionInput else str((a as Dictionary).get("image_data_base64", ""))
	var bb = b.image_data_base64 if b is AISidebarVisionInput else str((b as Dictionary).get("image_data_base64", ""))
	if ab.is_empty() or bb.is_empty():
		return false
	return ab == bb

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

## UI önizlemesi için ImageTexture üretir
func get_texture() -> ImageTexture:
	if not image_data_base64.is_empty():
		var raw = Marshalls.base64_to_raw(image_data_base64)
		var img = Image.new()
		var err = img.load_png_from_buffer(raw)
		if err != OK:
			err = img.load_jpg_from_buffer(raw)
		if err == OK:
			return ImageTexture.create_from_image(img)
	elif not image_path.is_empty() and FileAccess.file_exists(image_path):
		var img = Image.new()
		if img.load(image_path) == OK:
			return ImageTexture.create_from_image(img)
	return null

