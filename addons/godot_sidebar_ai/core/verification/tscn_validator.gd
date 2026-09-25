@tool
extends RefCounted
class_name AISidebarTscnValidator

## TSCN/TRES yapısal doğrulayıcısı (SRP): başlık, bölüm sırası, kaynak id
## tekrarı, ext_resource yol varlığı ve ExtResource/SubResource referansları.
## `AISidebarVerificationPipeline` kayıt defterine `tscn` / `tres` için bağlanır.

const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")
const VerificationStatus = AISidebarVerificationPipeline.VerificationStatus

## Sahne / Kaynak Metin Sözdizimi ve Yapısal Doğrulaması (TSCN/TRES Structural Validation)
static func validate(source_code: String, file_path: String = "", batch_context: Dictionary = {}) -> Dictionary:
	var lines = source_code.split("\n")
	if lines.is_empty():
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {
				"code": "TSCN_EMPTY_FILE",
				"message": "Sahne dosyası boş olamaz: " + file_path,
				"file_path": file_path,
				"recoverable": true
			}
		}
		
	var is_tscn = file_path.ends_with(".tscn") or file_path.is_empty() or ("[node " in source_code)
	
	# Bölüm sıra durum makinesi (Section order state machine):
	# 0: INIT (ilk etiket header olmalı)
	# 1: HEADER ([gd_scene ...] veya [gd_resource ...])
	# 2: EXT_RESOURCE ([ext_resource ...])
	# 3: SUB_RESOURCE ([sub_resource ...])
	# 4: NODE ([node ...])
	# 5: CONNECTION ([connection ...])
	var section_state: int = 0
	var has_header: bool = false
	var has_root_node: bool = false
	
	var ext_resource_ids: Dictionary = {}
	var sub_resource_ids: Dictionary = {}
	
	var tag_regex = RegEx.new()
	tag_regex.compile('^\\[([a-zA-Z_0-9]+)(\\s+[^\\]]*)?\\]')
	
	var id_regex = RegEx.new()
	id_regex.compile('\\bid="([^"]+)"')
	
	var path_regex = RegEx.new()
	path_regex.compile('\\bpath="([^"]+)"')
	
	for line_idx in range(lines.size()):
		var line_num = line_idx + 1
		var raw_line = lines[line_idx].strip_edges()
		
		# Boş satırlar ve yorumlar geçilir
		if raw_line.is_empty() or raw_line.begins_with(";") or raw_line.begins_with("#"):
			continue
			
		var tag_match = tag_regex.search(raw_line)
		if tag_match:
			var tag_name = tag_match.get_string(1)
			var tag_params = tag_match.get_string(2)
			
			if section_state == 0:
				if tag_name == "gd_scene" or tag_name == "gd_resource":
					section_state = 1
					has_header = true
				else:
					return {
						"status": VerificationStatus.FAILED,
						"success": false,
						"error": {
							"code": "TSCN_MISSING_HEADER",
							"message": "Satır %d: Sahne dosyası '[gd_scene ...]' veya '[gd_resource ...]' başlık etiketiyle başlamalıdır. Bulunan: '[%s]'." % [line_num, tag_name],
							"file_path": file_path,
							"line": line_num,
							"recoverable": true
						}
					}
			elif tag_name == "ext_resource":
				if section_state > 2:
					return {
						"status": VerificationStatus.FAILED,
						"success": false,
						"error": {
							"code": "TSCN_DISPLACED_EXT_RESOURCE",
							"message": "Satır %d: [ext_resource] etiketi geçersiz konumda. Tüm [ext_resource] tanımları dosyanın en üstünde, [sub_resource] ve [node] bloklarından önce yer almalıdır." % [line_num],
							"file_path": file_path,
							"line": line_num,
							"recoverable": true
						}
					}
				section_state = 2
				
				var id_m = id_regex.search(tag_params)
				if id_m:
					var r_id = id_m.get_string(1)
					if ext_resource_ids.has(r_id):
						return {
							"status": VerificationStatus.FAILED,
							"success": false,
							"error": {
								"code": "TSCN_DUPLICATE_RESOURCE_ID",
								"message": "Satır %d: Mükerrer ext_resource id=\"%s\". Bu id daha önce satır %d üzerinde tanımlanmış." % [line_num, r_id, ext_resource_ids[r_id]],
								"file_path": file_path,
								"line": line_num,
								"recoverable": true
							}
						}
					ext_resource_ids[r_id] = line_num
				else:
					return {
						"status": VerificationStatus.FAILED,
						"success": false,
						"error": {
							"code": "TSCN_MALFORMED_TAG",
							"message": "Satır %d: [ext_resource] etiketinde 'id' özniteliği eksik." % [line_num],
							"file_path": file_path,
							"line": line_num,
							"recoverable": true
						}
					}
					
				var path_m = path_regex.search(tag_params)
				if path_m:
					var ref_p = path_m.get_string(1)
					if ref_p.begins_with("res://"):
						var exists_on_disk = FileAccess.file_exists(ref_p)
						var in_batch = batch_context.has(ref_p)
						if not exists_on_disk and not in_batch:
							return {
								"status": VerificationStatus.FAILED,
								"success": false,
								"error": {
									"code": "RESOURCE_REFERENCE_NOT_FOUND",
									"message": "Satır %d: [ext_resource] bulunamayan bir kaynağa işaret ediyor: %s. (Ne diskte mevcut ne de mevcut batch paketinde)." % [line_num, ref_p],
									"file_path": file_path,
									"missing_resource": ref_p,
									"line": line_num,
									"recoverable": true
								}
							}
							
			elif tag_name == "sub_resource":
				if section_state > 3:
					return {
						"status": VerificationStatus.FAILED,
						"success": false,
						"error": {
							"code": "TSCN_DISPLACED_SUB_RESOURCE",
							"message": "Satır %d: [sub_resource] etiketi geçersiz konumda. [sub_resource] blokları [node] ve [connection] bloklarından sonra gelemez." % [line_num],
							"file_path": file_path,
							"line": line_num,
							"recoverable": true
						}
					}
				section_state = 3
				
				var id_m = id_regex.search(tag_params)
				if id_m:
					var r_id = id_m.get_string(1)
					if sub_resource_ids.has(r_id):
						return {
							"status": VerificationStatus.FAILED,
							"success": false,
							"error": {
								"code": "TSCN_DUPLICATE_RESOURCE_ID",
								"message": "Satır %d: Mükerrer sub_resource id=\"%s\". Bu id daha önce satır %d üzerinde tanımlanmış." % [line_num, r_id, sub_resource_ids[r_id]],
								"file_path": file_path,
								"line": line_num,
								"recoverable": true
							}
						}
					sub_resource_ids[r_id] = line_num
				else:
					return {
						"status": VerificationStatus.FAILED,
						"success": false,
						"error": {
							"code": "TSCN_MALFORMED_TAG",
							"message": "Satır %d: [sub_resource] etiketinde 'id' özniteliği eksik." % [line_num],
							"file_path": file_path,
							"line": line_num,
							"recoverable": true
						}
					}
					
			elif tag_name == "node":
				if section_state > 4:
					return {
						"status": VerificationStatus.FAILED,
						"success": false,
						"error": {
							"code": "TSCN_DISPLACED_NODE",
							"message": "Satır %d: [node] etiketi geçersiz konumda. [node] blokları [connection] bloklarından sonra gelemez." % [line_num],
							"file_path": file_path,
							"line": line_num,
							"recoverable": true
						}
					}
				section_state = 4
				has_root_node = true
				
			elif tag_name == "connection":
				section_state = 5
				
	if not has_header:
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {
				"code": "TSCN_MISSING_HEADER",
				"message": "Sahne dosyası geçerli bir '[gd_scene ...]' başlığı içermiyor: " + file_path,
				"file_path": file_path,
				"recoverable": true
			}
		}
		
	if is_tscn and not has_root_node:
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {
				"code": "TSCN_MISSING_ROOT_NODE",
				"message": "TSCN sahne dosyası en az bir kök [node ...] etiketi içermelidir: " + file_path,
				"file_path": file_path,
				"recoverable": true
			}
		}
		
	var ext_ref_regex = RegEx.new()
	ext_ref_regex.compile('ExtResource\\(\\s*"([^"]+)"\\s*\\)|ExtResource\\(\\s*(\\d+)\\s*\\)')
	
	var sub_ref_regex = RegEx.new()
	sub_ref_regex.compile('SubResource\\(\\s*"([^"]+)"\\s*\\)|SubResource\\(\\s*(\\d+)\\s*\\)')
	
	for line_idx in range(lines.size()):
		var line_num = line_idx + 1
		var line = lines[line_idx]
		
		var ext_matches = ext_ref_regex.search_all(line)
		for m in ext_matches:
			var ref_id = m.get_string(1)
			if ref_id.is_empty():
				ref_id = m.get_string(2)
			if not ext_resource_ids.has(ref_id):
				return {
					"status": VerificationStatus.FAILED,
					"success": false,
					"error": {
						"code": "TSCN_UNDEFINED_RESOURCE_REFERENCE",
						"message": "Satır %d: Tanımsız ExtResource(\"%s\") referansı. Tanımlı ext_resource id'leri: %s." % [line_num, ref_id, str(ext_resource_ids.keys())],
						"file_path": file_path,
						"line": line_num,
						"recoverable": true
					}
				}
				
		var sub_matches = sub_ref_regex.search_all(line)
		for m in sub_matches:
			var ref_id = m.get_string(1)
			if ref_id.is_empty():
				ref_id = m.get_string(2)
			if not sub_resource_ids.has(ref_id):
				return {
					"status": VerificationStatus.FAILED,
					"success": false,
					"error": {
						"code": "TSCN_UNDEFINED_RESOURCE_REFERENCE",
						"message": "Satır %d: Tanımsız SubResource(\"%s\") referansı. Tanımlı sub_resource id'leri: %s." % [line_num, ref_id, str(sub_resource_ids.keys())],
						"file_path": file_path,
						"line": line_num,
						"recoverable": true
					}
				}
				
	return {
		"status": VerificationStatus.PASSED,
		"success": true,
		"message": "✓ TSCN/TRES sahne sözdizimi ve kaynak referansları geçerli."
	}
