@tool
extends RefCounted

## Tool çağrılarının kullanıcıya görünen metinleri (SRP: saf dönüşüm, UI durumu yok).
## İnsan-okur başlık, teknik detay, hata özeti, screenshot yolu ve limit tespiti.

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")

static func human_title(tool_name: String, args: Dictionary) -> String:
	match tool_name:
		"create_or_update_script", "replace_file_content":
			var p := str(args.get("file_path", ""))
			return AISidebarI18n.get_text("tool_title_updated_file", {"file": p.get_file()}) if not p.is_empty() else AISidebarI18n.get_text("tool_title_updated_script")
		"write_files":
			var f_arr: Array = args.get("files", [])
			return AISidebarI18n.get_text("tool_title_write_files", {"count": f_arr.size()})
		"manage_project_settings":
			var target := str(args.get("key", args.get("name", "")))
			return AISidebarI18n.get_text("tool_title_project_settings", {"action": (str(args.get("action", "")) + " " + target).strip_edges()})
		"create_scene":
			return AISidebarI18n.get_text("tool_title_create_scene", {"file": str(args.get("scene_path", "")).get_file()})
		"save_scene":
			return AISidebarI18n.get_text("tool_title_save_scene")
		"analyze_project":
			return AISidebarI18n.get_text("tool_title_analyze_project")
		"get_project_files":
			return AISidebarI18n.get_text("tool_title_get_project_files")
		"read_script":
			return AISidebarI18n.get_text("tool_title_read_script", {"file": str(args.get("file_path", "")).get_file()})
		"file_info":
			return AISidebarI18n.get_text("tool_title_file_info", {"file": str(args.get("file_path", "")).get_file()})
		"find_files":
			return AISidebarI18n.get_text("tool_title_find_files", {"pattern": str(args.get("pattern", "")).left(40)})
		"search_code":
			return AISidebarI18n.get_text("tool_title_search_code", {"query": str(args.get("query", "")).left(40)})
		"validate_script":
			return AISidebarI18n.get_text("tool_title_validate_script")
		"validate_project":
			return AISidebarI18n.get_text("tool_title_validate_project")
		"get_godot_class_info":
			return AISidebarI18n.get_text("tool_title_class_info", {"class": str(args.get("class_name", ""))})
		"play_game":
			return AISidebarI18n.get_text("tool_title_play_game")
		"stop_game":
			return AISidebarI18n.get_text("tool_title_stop_game")
		"get_runtime_errors":
			return AISidebarI18n.get_text("tool_title_get_runtime_errors")
		"delete_node":
			return AISidebarI18n.get_text("tool_title_delete_node", {"path": str(args.get("node_path", ""))})
		"read_file":
			return AISidebarI18n.get_text("tool_title_read_file", {"file": str(args.get("file_path", "")).get_file()})
		"list_files":
			return AISidebarI18n.get_text("tool_title_list_files", {"path": str(args.get("directory", ""))})
		"search_tools":
			return AISidebarI18n.get_text("tool_title_search_tools")
		"ask_user":
			return AISidebarI18n.get_text("tool_title_ask_user")
		"propose_plan":
			return AISidebarI18n.get_text("tool_title_propose_plan")
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

static func format_limit_stop_reason(current_step: int, max_steps: int) -> String:
	return "Tool-call limit reached: " + str(current_step) + "/" + str(max_steps)

## Runtime kartı için kısa özet: ilk hata mesajı + dosya:satır (+N more). Modele giden
## uzun teşhis metni (format_diagnostic_prompt) kullanıcıya gösterilmez.
static func runtime_error_summary(obs) -> String:
	if obs == null or obs.errors.is_empty():
		return "Runtime error: the game crashed or reported an error"
	var first: Dictionary = obs.errors[0]
	var msg = str(first.get("message", "")).strip_edges().split("\n")[0].left(200)
	var text = "Runtime error: " + msg
	var file = str(first.get("file", ""))
	if not file.is_empty():
		var line = int(first.get("line", 0))
		text += " — " + file.get_file() + (":%d" % line if line > 0 else "")
	if obs.errors.size() > 1:
		text += " (+%d more)" % (obs.errors.size() - 1)
	return text
