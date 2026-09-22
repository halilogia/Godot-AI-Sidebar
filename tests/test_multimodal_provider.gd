@tool
extends RefCounted

## Multimodal (Vision) Sağlayıcı Testleri.
##
## ÖNEMLİ - HERMETİKLİK KURALI:
## Bu testler kullanıcının diskindeki `addons/godot_sidebar_ai/config.json`
## dosyasına ASLA bağımlı olmamalıdır. Bu dosya gitignore'da olduğu için her
## geliştiricinin makinesinde farklı bir `selected_model` bulunur; dolayısıyla
## config'e bağlı bir test bir makinede geçip diğerinde çöker ve "tüm testler
## yeşil" iddiasını anlamsız kılar.
##
## Bu yüzden yetenek kararı, disk okumayan saf (pure) `model_supports_vision()`
## fonksiyonu üzerinden doğrulanır.

const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")

class MockNetworkManager extends AISidebarNetworkManager:
	var last_body: Dictionary = {}
	var last_url: String = ""

	func post_request(url: String, _headers: PackedStringArray, body_json: String) -> Error:
		last_url = url
		var parsed = JSON.parse_string(body_json)
		if parsed is Dictionary:
			last_body = parsed
		return OK

## Bilinen vision yetenekli modeller pozitif dönmelidir.
static func _vision_positive_cases() -> Array:
	return [
		"gemini-3.8-flash-low",
		"gemini-3.1-pro-preview",
		"gh/claude-sonnet-4.5",
		"ag/claude-opus-4-6-thinking",
		"kc/openai/gpt-4.1",
		"ds/deepseek-v4-flash-vision-exp",
		"ollama/llava",
		"vision",
		"gemini/gemma-4-31b-it"
	]

## Bilinen vision yeteneksiz modeller negatif dönmelidir.
static func _vision_negative_cases() -> Array:
	return [
		"nvidia/parakeet-ctc-1.1b-asr",
		"whisper-large-v3",
		"text-embedding-3-large",
		"rerank-v1"
	]

## 9Router yönlendirme takma adları (alias) bilinmeyen kimliklerdir ve
## AŞIRI KISITLAYICI olmamalıdır: sunucu reddederse hata gösterilir, ama
## eklenti yeteneği önceden kapatmamalıdır.
static func _vision_unknown_alias_cases() -> Array:
	return ["a", "code", "fast", "money", "gc", "all", "free"]

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# --- Test 1..3: Saf yetenek sınıflandırması (diskten bağımsız) ---

	for model in _vision_positive_cases():
		if AISidebarOpenAICompatibleProvider.model_supports_vision(model):
			passed += 1
		else:
			failed += 1
			errors.append("Vision yetenekli model yanlış sınıflandırıldı: " + model)

	for model in _vision_negative_cases():
		if not AISidebarOpenAICompatibleProvider.model_supports_vision(model):
			passed += 1
		else:
			failed += 1
			errors.append("Vision yeteneksiz model yanlış sınıflandırıldı: " + model)

	for alias in _vision_unknown_alias_cases():
		if AISidebarOpenAICompatibleProvider.model_supports_vision(alias):
			passed += 1
		else:
			failed += 1
			errors.append("Bilinmeyen model takma adı aşırı kısıtlandı (regresyon): " + alias)

	# Boş kimlik güvenli şekilde false dönmelidir.
	if not AISidebarOpenAICompatibleProvider.model_supports_vision(""):
		passed += 1
	else:
		failed += 1
		errors.append("Boş model kimliği true döndürdü.")

	# --- Test 4: Multimodal content parçası üretimi ---

	var v_input = AISidebarVisionInput.new("user://screenshot.png", "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==", 1920, 1080)
	var content_part = v_input.to_openai_content_part()

	if content_part.get("type", "") == "image_url" and "data:image/png;base64," in content_part.get("image_url", {}).get("url", ""):
		passed += 1
	else:
		failed += 1
		errors.append("Multimodal image_url parçası formatı hatalı: " + str(content_part))

	# --- Test 5: Görsel parçasının gönderilen payload'a gerçekten girmesi ---
	# NOT: Bu test artık diski okumaz. Yetenek kontrolü mock ağ yöneticisi
	# üzerinden paketleme davranışını doğrular; model seçimi payload içeriğini
	# değiştirmemelidir.

	var mock_nm = MockNetworkManager.new()
	var prov_with_net = AISidebarOpenAICompatibleProvider.new(mock_nm)
	var messages = [{"role": "user", "content": "What is this image?"}]
	prov_with_net.send_multimodal_chat(messages, [], [v_input])

	var sent_msgs = mock_nm.last_body.get("messages", [])
	var user_msg = sent_msgs[-1] if sent_msgs.size() > 0 else {}
	var user_content = user_msg.get("content", [])
	var has_img_part = false
	if user_content is Array:
		for part in user_content:
			if part is Dictionary and part.get("type") == "image_url":
				if "data:image/png;base64," in part.get("image_url", {}).get("url", ""):
					has_img_part = true
					break

	if has_img_part and mock_nm.last_url.ends_with("/chat/completions"):
		passed += 1
	else:
		failed += 1
		errors.append("OpenAI provider multimodal payload has_img_part failed: " + str(user_content))

	return {"name": "MultimodalProviderTests", "passed": passed, "failed": failed, "errors": errors}
