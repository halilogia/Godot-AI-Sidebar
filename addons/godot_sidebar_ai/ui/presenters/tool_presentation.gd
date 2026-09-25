@tool
extends RefCounted

## Tool çağrılarının kullanıcıya görünen metinleri (SRP: saf dönüşüm, UI durumu yok).
## İnsan-okur başlık, teknik detay, hata özeti, screenshot yolu ve limit tespiti.

const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")

static func human_title(tool_name: String, args: Dictionary) -> String:
	match tool_name:
		"create_or_update_script":
			var p = args.get("file_path", "")
			return "Updated " + p.get_file() if not p.is_empty() else "Updated script"
		"write_files":
			var f_arr = args.get("files", [])
			return "Batch wrote " + str(f_arr.size()) + " files"
		"create_scene":
			var sp = args.get("scene_path", "")
			return "Created scene " + sp.get_file()
		"save_scene":
			return "Saved active scene"
		"analyze_project":
			return "Inspected project structure"
		"get_project_files":
			return "Scanned project files"
		"read_script":
			return "Read script: " + args.get("file_path", "").get_file()
		"validate_script":
			return "Validated GDScript source"
		"play_game":
			return "Launched game instance"
		"stop_game":
			return "Stopped running game"
		"get_runtime_errors":
			return "Checked runtime logs"
		"delete_node":
			return "Deleted node: " + str(args.get("node_path", ""))
		"replace_file_content":
			var rp = str(args.get("file_path", ""))
			return "Updated " + rp.get_file() if not rp.is_empty() else "Updated script"
		"read_file":
			return "Read file: " + str(args.get("file_path", "")).get_file()
		"list_files":
			return "Listed files: " + str(args.get("directory", ""))
		"search_tools":
			return "Searched available tools"
		"ask_user":
			return "Asked clarification"
		"propose_plan":
			return "Proposed implementation plan"
		_:
			return str(tool_name).replace("_", " ")

## Activity satırının açılır teknik detayı (secret'lar maskelenir, 1200 karakter sınırı).
static func tech_details(tool_name: String, args: Dictionary, result: Dictionary) -> String:
	var args_txt = AISidebarActivityGroup.redact_secrets(JSON.stringify(args))
	var res_txt = AISidebarActivityGroup.redact_secrets(JSON.stringify(result))
	if args_txt.length() > 1200:
		args_txt = args_txt.left(1200) + "..."
	if res_txt.length() > 1200:
		res_txt = res_txt.left(1200) + "..."
	return "tool: " + tool_name + "\nargs: " + args_txt + "\nresult: " + res_txt

static func tool_error(result: Dictionary) -> String:
	# Gerçek hüküm helper'dan (outer ok + payload fail durumunu yakalar).
	var outcome = AISidebarTaskTranscript.effective_tool_outcome(result)
	return str(outcome["error"])

## Başarılı screenshot sonucu varsa image path'ini döndürür (transcript + preview).
static func screenshot_image_path(tool_name: String, result: Dictionary) -> String:
	if tool_name != "take_runtime_screenshot" and tool_name != "take_viewport_screenshot" and tool_name != "take_editor_screenshot":
		return ""
	if not bool(result.get("success", false)):
		return ""
	var data = result.get("data", {})
	if not (data is Dictionary):
		return ""
	if bool(data.get("has_vision_data", false)):
		return str(data.get("path", ""))
	# Editor screenshot yalnızca path döner; dosya diskte varsa preview kurulabilir.
	if tool_name == "take_editor_screenshot" and FileAccess.file_exists(str(data.get("path", ""))):
		return str(data.get("path", ""))
	return ""

static func is_task_limit_error(err_msg: String) -> bool:
	var s = err_msg.to_lower()
	return s.contains("limit") or s.contains("maksimum ajan ad")

static func format_limit_stop_reason(current_step: int, max_steps: int) -> String:
	return "Tool-call limit reached: " + str(current_step) + "/" + str(max_steps)
