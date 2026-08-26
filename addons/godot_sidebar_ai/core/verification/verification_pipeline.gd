@tool
extends RefCounted
class_name AISidebarVerificationPipeline

## Otomatik İcra Sonrası Doğrulama Hattı (Automated Verification Pipeline) (SRP).
## Modelin 'yaptım' dediği işlemleri doğrular (syntax, node varlığı, property ataması).

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")

## Script sözdizimi ve derleme doğrulaması
static func verify_script(raw_path: String) -> Dictionary:
	var path = AISidebarPathPolicy.normalize_path(raw_path)
	if not FileAccess.file_exists(path):
		return AISidebarToolResult.err("VERIFICATION_FAILED", "Doğrulama başarısız: Script dosyası bulunamadı: " + path, true)
		
	var script_res = load(path)
	if not script_res or not (script_res is Script):
		return AISidebarToolResult.err("SYNTAX_ERROR", "Doğrulama başarısız: Script derlenemedi, sözdizimi hatası mevcut.", true)
		
	return AISidebarToolResult.ok({"file_path": path, "verified": true}, "✓ Script başarıyla doğrulandı ve derlendi.")

## Sahnede düğümün varlığını ve tipini doğrulama
static func verify_node(node_path: String, expected_class: String = "") -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.ok(null, "Editör dışı ortamda doğrulama atlandı.")
		
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık sahne yok.", true)
		
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Doğrulama başarısız: Sahnede beklenen düğüm bulunamadı: " + node_path, true)
		
	var node = root.get_node(node_path)
	if not expected_class.is_empty() and not node.is_class(expected_class):
		return AISidebarToolResult.err("TYPE_MISMATCH", "Düğüm tipi beklenenle eşleşmiyor. Beklenen: " + expected_class + ", Gerçek: " + node.get_class(), true)
		
	return AISidebarToolResult.ok({"node_path": node_path, "type": node.get_class(), "verified": true}, "✓ Düğüm sahnede doğrulandı.")

## Bir araç icrasından sonra otomatik verification çalıştırır
static func auto_verify_tool_execution(tool_name: String, args: Dictionary, result: Dictionary) -> Dictionary:
	if not result.get("success", false):
		return result
		
	match tool_name:
		"create_or_update_script":
			var path = args.get("file_path", "")
			return verify_script(path)
		"add_node":
			var node_name = args.get("node_name", "")
			var parent_path = args.get("parent_path", "")
			var full_path = parent_path.path_join(node_name) if not parent_path.is_empty() else node_name
			return verify_node(full_path, args.get("node_type", ""))
		_:
			return result
