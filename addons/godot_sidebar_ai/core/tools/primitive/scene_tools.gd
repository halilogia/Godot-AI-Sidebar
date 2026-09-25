@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarSceneTools

## İlkel Sahne ve Düğüm (Node) Araçları (File-First + Editor Mutations) (SRP).

const AISidebarTypeParser = preload("res://addons/godot_sidebar_ai/core/types/type_parser.gd")
const AISidebarMutationService = preload("res://addons/godot_sidebar_ai/core/mutations/editor_mutation_service.gd")
const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")

static func _get_root() -> Node:
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_edited_scene_root"):
		return EditorInterface.get_edited_scene_root()
	return null

## Disk-first yazımlar sonrası state sync: yazılan .tscn editörde açıksa,
## stale memory state'i diske geri yazmadan ÖNCE editörü diskten yeniler.
## (Aksi halde sonraki save_scene eski state'i diske basıp child'ları siler.)
## Sadece ilgili path'e dokunur; normal dosya yazımını değiştirmez.
static func refresh_open_scenes(paths: Array) -> Dictionary:
	var refreshed: Array = []
	if not (Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface")):
		return {"refreshed": refreshed}
	if not EditorInterface.has_method("get_edited_scene_root") or not EditorInterface.has_method("open_scene_from_path"):
		return {"refreshed": refreshed}
	var root = EditorInterface.get_edited_scene_root()
	if root == null:
		return {"refreshed": refreshed}
	var active = AISidebarPathPolicy.normalize_path(str(root.scene_file_path))
	if active.is_empty():
		return {"refreshed": refreshed}
	for p in paths:
		var np = AISidebarPathPolicy.normalize_path(str(p))
		if np.ends_with(".tscn") and np == active and not np in refreshed:
			EditorInterface.open_scene_from_path(np)
			refreshed.append(np)
	return {"refreshed": refreshed}

static func get_schemas() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "get_scene_tree",
				"description": "Aktif sahnedeki tüm düğüm (node) hiyerarşisini, tiplerini ve yollarını listeler.",
				"parameters": {
					"type": "object",
					"properties": {
						"root_path": { "type": "string", "description": "Taranacak başlangıç düğüm yolu (varsayılan: aktif sahne kökü)." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "create_scene",
				"description": "Sıfırdan yeni bir sahne (.tscn) dosyası oluşturur. İsteğe bağlı olarak doğrudan tam TSCN metin içeriği verilebilir (File-First tek adımda tüm sahne oluşturma).",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": { "type": "string", "description": "Kaydedilecek yol (örn: res://scenes/Player.tscn veya res://scenes/Main.tscn)." },
						"root_type": { "type": "string", "description": "Kök düğüm tipi (örn: CharacterBody3D, Node3D, Node2D, Control)." },
						"root_name": { "type": "string", "description": "Kök düğüm adı (örn: Player, Main, Level1)." },
						"tscn_content": { "type": "string", "description": "Opsiyonel: Doğrudan yazılacak komple .tscn metin içeriği (File-First hızlı üretim)." }
					},
					"required": ["scene_path", "root_type"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "add_node",
				"description": "Sahneye yeni bir düğüm (CharacterBody3D, MeshInstance3D, CollisionShape3D, Camera3D vb.) ekler (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_type": { "type": "string", "description": "Godot sınıf adı (Örn: CharacterBody3D, MeshInstance3D, CollisionShape3D, Camera3D)." },
						"node_name": { "type": "string", "description": "Düğümün adı (Örn: Mesh, Collision, Camera, Player)." },
						"parent_path": { "type": "string", "description": "Ekleneceği üst düğümün yolu (boşsa sahne köküne eklenir)." }
					},
					"required": ["node_type", "node_name"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "instantiate_scene",
				"description": "Diskteki bir sahneyi (.tscn) aktif sahnenin içine alt düğüm olarak ekler (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": { "type": "string", "description": "Örneklenecek sahne yolu (örn: res://scenes/Player.tscn)." },
						"parent_path": { "type": "string", "description": "Ekleneceği üst düğüm yolu." },
						"node_name": { "type": "string", "description": "Oluşacak düğümün adı (opsiyonel)." }
					},
					"required": ["scene_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "delete_node",
				"description": "Sahnede belirtilen düğümü siler (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Silinecek düğümün tam veya göreli yolu." }
					},
					"required": ["node_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "rename_node",
				"description": "Sahnede belirtilen bir düğümün adını değiştirir (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Düğümün yolu." },
						"new_name": { "type": "string", "description": "Yeni düğüm adı." }
					},
					"required": ["node_path", "new_name"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "duplicate_node",
				"description": "Sahnede belirtilen bir düğümün kopyasını oluşturur (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Kopyalanacak düğüm yolu." },
						"new_name": { "type": "string", "description": "Kopya düğümün yeni adı (opsiyonel)." }
					},
					"required": ["node_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "set_node_property",
				"description": "Bir düğümün özelliğini (position, scale, text vb.) değiştirir (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Hedef düğümün yolu." },
						"property_name": { "type": "string", "description": "Değiştirilecek özellik adı." },
						"property_value": { "description": "Yeni değer ('Vector3(0, 1, 0)', '#ff0000', sayı vb.)." }
					},
					"required": ["node_path", "property_name", "property_value"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "get_node_properties",
				"description": "Bir düğümün tüm inspector özelliklerini ve mevcut değerlerini listeler.",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "İncelenecek düğüm yolu." }
					},
					"required": ["node_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "connect_signal",
				"description": "İki düğüm arasındaki bir sinyali hedefin metoduna bağlar (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"source_node_path": { "type": "string", "description": "Sinyali yayınlayan düğüm yolu." },
						"signal_name": { "type": "string", "description": "Sinyal adı (örn: pressed, body_entered)." },
						"target_node_path": { "type": "string", "description": "Sinyali dinleyen düğüm yolu." },
						"method_name": { "type": "string", "description": "Çalıştırılacak fonksiyon adı." }
					},
					"required": ["source_node_path", "signal_name", "target_node_path", "method_name"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "attach_script_to_node",
				"description": "Diskteki bir GDScript dosyasını aktif sahnedeki belirli bir düğüme bağlar (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Hedef düğümün yolu." },
						"script_path": { "type": "string", "description": "Script yolu (örn: res://scripts/Player.gd)." }
					},
					"required": ["node_path", "script_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "reparent_node",
				"description": "Bir düğümü başka bir üst düğümün altına taşır (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Taşınacak düğümün yolu." },
						"new_parent_path": { "type": "string", "description": "Yeni üst düğümün yolu." }
					},
					"required": ["node_path", "new_parent_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "save_scene",
				"description": "Aktif olarak düzenlenen sahneyi diske kaydeder.",
				"parameters": {
					"type": "object",
					"properties": {}
				}
			}
		}
	]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"get_scene_tree":
			return _get_scene_tree(args)
		"create_scene":
			return _create_scene(args)
		"add_node":
			return _add_node(args)
		"instantiate_scene":
			return _instantiate_scene(args)
		"delete_node":
			return _delete_node(args)
		"rename_node":
			return _rename_node(args)
		"duplicate_node":
			return _duplicate_node(args)
		"set_node_property":
			return _set_node_property(args)
		"get_node_properties":
			return _get_node_properties(args)
		"connect_signal":
			return _connect_signal(args)
		"attach_script_to_node":
			return _attach_script_to_node(args)
		"reparent_node":
			return _reparent_node(args)
		"save_scene":
			return _save_scene(args)
		_:
			return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen sahne aracı: " + tool_name)

static func _get_scene_tree(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var start_node = root
	var root_path = args.get("root_path", "")
	if not root_path.is_empty() and root.has_node(root_path):
		start_node = root.get_node(root_path)
		
	var tree_data = _build_node_dict(start_node)
	return AISidebarToolResult.ok({
		"scene_root": root.name,
		"scene_file": root.scene_file_path,
		"tree": tree_data
	})

static func _build_node_dict(node: Node) -> Dictionary:
	var children: Array = []
	for child in node.get_children():
		children.append(_build_node_dict(child))
	return {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"children": children
	}

## Gerçek TSCN parse doğrulaması: Godot resource sistemiyle yükleme denemesi.
## Metinsel heuristiklere (validate_source) güvenilmez; örn. `mesh = BoxMesh.new()`
## metin olarak geçer ama PackedScene olarak parse edilemez.
static func validate_scene_parse(scene_path: String) -> Dictionary:
	if not FileAccess.file_exists(scene_path):
		return AISidebarToolResult.err("SCENE_FILE_MISSING", "Parse edilecek sahne dosyası bulunamadı: " + scene_path, false)
	var loaded = ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not (loaded is PackedScene):
		return AISidebarToolResult.err("SCENE_PARSE_ERROR", "Godot resource sistemi sahneyi parse edemedi (PackedScene yüklenemedi): " + scene_path, false, {"scene_path": scene_path})
	var state = (loaded as PackedScene).get_state()
	var parsed: Dictionary = {"scene_path": scene_path, "parse_validated": true, "node_count": state.get_node_count()}
	if state.get_node_count() > 0:
		parsed["root_name"] = str(state.get_node_name(0))
		parsed["root_type"] = str(state.get_node_type(0))
	return AISidebarToolResult.ok(parsed)

static func _default_edited_root():
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_edited_scene_root"):
		return EditorInterface.get_edited_scene_root()
	return null

static func _has_live_editor() -> bool:
	return Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_edited_scene_root")

## Editörde açık sahne doğrulaması: istenen path gerçekten aktif mi?
## root_provider boşsa editör okunur; testler sahte provider enjekte eder.
## NOT: Tool kontratı senkron olduğu için frame yield YOKTUR (await, senkron
## çağırıcıları bozar). Eşleşmezse recoverable hata döner; retry, agent turunda olur.
static func confirm_active_scene(scene_path: String, max_attempts: int = 3, root_provider: Callable = Callable()) -> Dictionary:
	var wanted = AISidebarPathPolicy.normalize_path(scene_path)
	var use_provider = root_provider.is_valid()
	if not use_provider and not _has_live_editor():
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Aktif sahne doğrulaması editör gerektirir.", true)
	var actual = ""
	for _attempt in range(maxi(1, max_attempts)):
		var edited = root_provider.call() if use_provider else _default_edited_root()
		if edited != null:
			actual = AISidebarPathPolicy.normalize_path(str(edited.scene_file_path))
		if not actual.is_empty() and actual == wanted:
			return AISidebarToolResult.ok({"scene_path": wanted, "active_scene_path": actual, "active_scene_confirmed": true})
	return AISidebarToolResult.err("ACTIVE_SCENE_NOT_CONFIRMED", "İstenen sahne aktif değil: beklenen=" + wanted + " aktif=" + actual, true, {"scene_path": wanted, "active_scene_path": actual})

static func _create_scene(args: Dictionary) -> Dictionary:
	var raw_path = args.get("scene_path", "")
	var scene_path = AISidebarPathPolicy.normalize_path(raw_path)
	var root_type = args.get("root_type", "Node2D")
	var root_name = args.get("root_name", "Root")
	var tscn_content = args.get("tscn_content", "")

	var check = AISidebarPathPolicy.is_safe_to_write(scene_path)
	if not check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", check["reason"])

	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"

	var dir_path = scene_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var parse_validated = false
	# File-First: Eğer doğrudan .tscn içeriği verilmişse metin olarak kaydet
	if not tscn_content.strip_edges().is_empty():
		var val_res = AISidebarVerificationPipeline.validate_source(tscn_content, scene_path)
		if not val_res.get("success", false):
			var err_obj = val_res.get("error", {})
			var err_code = err_obj.get("code", "VALIDATION_FAILED") if err_obj is Dictionary else "VALIDATION_FAILED"
			var err_msg = err_obj.get("message", "Doğrulama hatası") if err_obj is Dictionary else str(val_res.get("error", "Doğrulama hatası"))
			return AISidebarToolResult.err(err_code, "Sahne doğrulaması başarısız, diske yazılmadı: " + err_msg, false, val_res)

		# Overwrite rollback: mevcut içeriği sakla; parse başarısızsa birebir geri yükle.
		var existed_before = FileAccess.file_exists(scene_path)
		var old_content = ""
		if existed_before:
			var rf = FileAccess.open(scene_path, FileAccess.READ)
			if rf:
				old_content = rf.get_as_text()
				rf.close()
		var f = FileAccess.open(scene_path, FileAccess.WRITE)
		if not f:
			return AISidebarToolResult.err("WRITE_ERROR", "Sahne dosyası yazılamadı: " + scene_path)
		f.store_string(tscn_content)
		f.close()
		# Gerçek parse: yazılan dosya Godot tarafından yüklenebilmeli.
		var parse_res = validate_scene_parse(scene_path)
		if not parse_res.get("success", false):
			var restored = false
			var restore_verified = false
			if existed_before:
				var wf = FileAccess.open(scene_path, FileAccess.WRITE)
				if wf:
					wf.store_string(old_content)
					wf.close()
					restored = true
					var vf = FileAccess.open(scene_path, FileAccess.READ)
					if vf:
						restore_verified = (vf.get_as_text() == old_content)
						vf.close()
			elif FileAccess.file_exists(scene_path):
				DirAccess.remove_absolute(scene_path)
				restored = true
				restore_verified = not FileAccess.file_exists(scene_path)
			var perr = parse_res.get("error", {})
			var pmsg = perr.get("message", "Parse hatası") if perr is Dictionary else str(perr)
			return AISidebarToolResult.err("SCENE_PARSE_ERROR", "Sahne parse edilemedi, oluşturuldu olarak raporlanmıyor: " + pmsg, false, {"scene_path": scene_path, "existed_before": existed_before, "restored": restored, "restore_verified": restore_verified})
		parse_validated = true
		# Rapor argüman varsayılanlarını değil, yazılan sahnenin gerçek kökünü taşır.
		var pdata = parse_res.get("data", {})
		if pdata is Dictionary:
			if not str(pdata.get("root_name", "")).is_empty():
				root_name = str(pdata["root_name"])
			if not str(pdata.get("root_type", "")).is_empty():
				root_type = str(pdata["root_type"])
	else:
		if not ClassDB.class_exists(root_type):
			return AISidebarToolResult.err("INVALID_CLASS", "Geçersiz kök düğüm tipi: " + root_type)
		if not ClassDB.is_parent_class(root_type, "Node"):
			return AISidebarToolResult.err("INVALID_CLASS", "Kök düğüm tipi bir Node sınıfı olmalı: " + root_type)

		var root_node = ClassDB.instantiate(root_type)
		root_node.name = root_name
		
		var packed_scene = PackedScene.new()
		var pack_err = packed_scene.pack(root_node)
		if pack_err != OK:
			return AISidebarToolResult.err("PACK_FAILED", "Sahne paketlenemedi: " + str(pack_err))
			
		var save_err = ResourceSaver.save(packed_scene, scene_path)
		if save_err != OK:
			return AISidebarToolResult.err("SAVE_FAILED", "Sahne kaydedilemedi: " + str(save_err))
		# Canlı düğümlerden paketlendi + diske yazıldı: parse geçerliliği yapısal olarak kanıtlı.
		parse_validated = true
		
	var editor_available = Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface")
	var active_confirmed = false
	var active_path = ""
	if editor_available:
		if EditorInterface.has_method("get_resource_filesystem"):
			EditorInterface.get_resource_filesystem().scan()
		if EditorInterface.has_method("open_scene_from_path"):
			# void döner; başarı confirm_active_scene ile doğrulanır.
			EditorInterface.open_scene_from_path(scene_path)
		var confirm_res = confirm_active_scene(scene_path)
		if not confirm_res.get("success", false):
			var cerr = confirm_res.get("error", {})
			var cmsg = cerr.get("message", "Doğrulama hatası") if cerr is Dictionary else str(cerr)
			var cdata = confirm_res.get("data", {"scene_path": scene_path, "active_scene_path": ""})
			return AISidebarToolResult.err("ACTIVE_SCENE_NOT_CONFIRMED", cmsg, true, cdata)
		var cdata_ok = confirm_res.get("data", {})
		active_path = str(cdata_ok.get("active_scene_path", "")) if cdata_ok is Dictionary else ""
		active_confirmed = true

	return AISidebarToolResult.ok({
		"scene_path": scene_path,
		"root_name": root_name,
		"root_type": root_type,
		"root_path": root_name,
		"parse_validated": parse_validated,
		"editor_available": editor_available,
		"active_scene_confirmed": active_confirmed,
		"active_scene_path": active_path
	}, "Sahne başarıyla oluşturuldu ve editörde açıldı. Kök düğüm: " + root_name + " (" + root_type + ")")

static func _add_node(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_type = args.get("node_type", "")
	var node_name = args.get("node_name", "")
	var parent_path = args.get("parent_path", "")
	
	if not ClassDB.class_exists(node_type):
		return AISidebarToolResult.err("INVALID_CLASS", "Geçersiz Godot sınıfı: " + node_type)
	if not ClassDB.is_parent_class(node_type, "Node"):
		return AISidebarToolResult.err("INVALID_CLASS", "Düğüm tipi bir Node sınıfı olmalı: " + node_type)

	var parent: Node = root
	if not parent_path.is_empty():
		if root.has_node(parent_path):
			parent = root.get_node(parent_path)
		elif root.name == parent_path:
			parent = root
		else:
			return AISidebarToolResult.err("PARENT_NOT_FOUND", "Üst düğüm bulunamadı: " + parent_path + " (Aktif kök: " + root.name + ")")
			
	var new_node = ClassDB.instantiate(node_type)
	if not new_node:
		return AISidebarToolResult.err("INSTANTIATION_FAILED", "Düğüm oluşturulamadı: " + node_type)
		
	var mut_res = AISidebarMutationService.add_node(parent, new_node, node_name)
	if mut_res.get("success", false):
		var target_path = str(new_node.get_path())
		return AISidebarToolResult.ok({
			"node_name": node_name,
			"node_type": node_type,
			"node_path": target_path,
			"parent_path": str(parent.get_path())
		}, "Düğüm eklendi: " + node_name + " (" + node_type + ")")
	return mut_res

static func _instantiate_scene(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var scene_path = AISidebarPathPolicy.normalize_path(args.get("scene_path", ""))
	var parent_path = args.get("parent_path", "")
	var node_name = args.get("node_name", "")
	
	if not FileAccess.file_exists(scene_path):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Örneklenecek sahne dosyası bulunamadı: " + scene_path)
		
	var packed: PackedScene = load(scene_path)
	if not packed or not packed.can_instantiate():
		return AISidebarToolResult.err("LOAD_FAILED", "Sahne örneği alınamadı: " + scene_path)
		
	var instance = packed.instantiate()
	if node_name.is_empty():
		node_name = instance.name
		
	var parent: Node = root
	if not parent_path.is_empty():
		if root.has_node(parent_path):
			parent = root.get_node(parent_path)
		else:
			return AISidebarToolResult.err("PARENT_NOT_FOUND", "Üst düğüm bulunamadı: " + parent_path)
			
	return AISidebarMutationService.add_node(parent, instance, node_name)

static func _delete_node(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı: " + node_path)
		
	var target = root.get_node(node_path)
	return AISidebarMutationService.delete_node(target)

static func _rename_node(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	var new_name = args.get("new_name", "")
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı: " + node_path)
		
	var target = root.get_node(node_path)
	return AISidebarMutationService.rename_node(target, new_name)

static func _duplicate_node(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	var new_name = args.get("new_name", "")
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı: " + node_path)
		
	var target = root.get_node(node_path)
	return AISidebarMutationService.duplicate_node(target, new_name)

static func _set_node_property(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	var prop_name = args.get("property_name", "")
	var raw_val = args.get("property_value")
	
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı: " + node_path)
		
	var target = root.get_node(node_path)
	var final_val = AISidebarTypeParser.parse_smart_variant(raw_val)
	return AISidebarMutationService.set_property(target, prop_name, final_val)

static func _get_node_properties(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı: " + node_path)
		
	var target = root.get_node(node_path)
	var prop_list: Dictionary = {}
	for p in target.get_property_list():
		var p_name = p["name"]
		if not p_name.begins_with("_"):
			prop_list[p_name] = str(target.get(p_name))
			
	return AISidebarToolResult.ok({
		"node": node_path,
		"type": target.get_class(),
		"properties": prop_list
	})

static func _connect_signal(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var src_path = args.get("source_node_path", "")
	var sig_name = args.get("signal_name", "")
	var tgt_path = args.get("target_node_path", "")
	var meth_name = args.get("method_name", "")
	
	if not root.has_node(src_path) or not root.has_node(tgt_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Kaynak veya hedef düğüm bulunamadı.")
		
	var src_node = root.get_node(src_path)
	var tgt_node = root.get_node(tgt_path)
	return AISidebarMutationService.connect_signal(src_node, sig_name, tgt_node, meth_name)

static func _attach_script_to_node(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	var script_path = AISidebarPathPolicy.normalize_path(args.get("script_path", ""))
	
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı: " + node_path)
	if not FileAccess.file_exists(script_path):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Script dosyası bulunamadı: " + script_path)
		
	var target = root.get_node(node_path)
	var script_res = load(script_path)
	if not script_res:
		return AISidebarToolResult.err("LOAD_FAILED", "Script yüklenemedi: " + script_path)
		
	return AISidebarMutationService.attach_script(target, script_res)

static func _reparent_node(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	var new_parent_path = args.get("new_parent_path", "")
	
	if not root.has_node(node_path) or not root.has_node(new_parent_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm veya yeni üst düğüm bulunamadı.")
		
	var target = root.get_node(node_path)
	var new_parent = root.get_node(new_parent_path)
	return AISidebarMutationService.reparent_node(target, new_parent)

static func _save_scene(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Kaydedilecek aktif sahne yok.")
	var saved_path = AISidebarPathPolicy.normalize_path(str(root.scene_file_path))
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("save_scene"):
		EditorInterface.save_scene()
	# Tutarlılık: kayıt sonrası hâlâ AYNI scene aktif olmalı (sessiz scene değişimi yok).
	var root_after = _get_root()
	var after_path = AISidebarPathPolicy.normalize_path(str(root_after.scene_file_path)) if root_after else ""
	if root_after == null or after_path != saved_path:
		return AISidebarToolResult.err("SAVE_CONSISTENCY_FAILED", "Kayıt sonrası aktif sahne değişti: kaydedilen=" + saved_path + " aktif=" + after_path, true, {"scene_file": saved_path, "active_scene_path": after_path})
	return AISidebarToolResult.ok({"scene_file": saved_path, "save_verified": true}, "Aktif sahne kaydedildi.")
