@tool
extends RefCounted

## Sidebar skill sistemi (Agent Skills standardı) ve proje AGENTS.md okuması.

const AISidebarSkillParser = preload("res://addons/godot_sidebar_ai/core/skills/skill_parser.gd")
const AISidebarSkillRegistry = preload("res://addons/godot_sidebar_ai/core/skills/skill_registry.gd")
const AISidebarRulesRegistry = preload("res://addons/godot_sidebar_ai/core/skills/rules_registry.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarExternalAgentGateway = preload("res://addons/godot_sidebar_ai/core/bridge/external_agent_gateway.gd")
const AISidebarMentionManager = preload("res://addons/godot_sidebar_ai/core/chat/mention_manager.gd")
const AISidebarContextCompactor = preload("res://addons/godot_sidebar_ai/core/agent/context_compactor.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")

const TMP := "user://ai_test_skills"

static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

static func _skill(root: String, name: String, desc: String, body: String = "Body") -> void:
	_write(root.path_join(name).path_join("SKILL.md"), "---\nname: %s\ndescription: %s\n---\n\n%s\n" % [name, desc, body])

## Gizli girdiler dahil siler (Linux'ta ".agents" gizlidir; get_directories_at onu atlar ve CI'da T5 kırılıyordu).
static func _rm(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.include_hidden = true
	for f in da.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	for d in da.get_directories():
		_rm(dir.path_join(d))
	DirAccess.remove_absolute(dir)

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	# 1. Ayrıştırıcı: blok açıklama, tırnak, iç içe metadata, CRLF + BOM; hatalı dosyalar atlanır.
	var ok := AISidebarSkillParser.parse("\ufeff---\r\nname: pdf-tools\r\ndescription: >\r\n  Extract text.\r\n  Use for PDFs.\r\nmetadata:\r\n  author: x\r\nlicense: \"MIT\"\r\n---\r\n# Title\r\nSteps\r\n", "pdf-tools")
	var no_fm := AISidebarSkillParser.parse("# no frontmatter", "a")
	var no_desc := AISidebarSkillParser.parse("---\nname: a\n---\nbody", "a")
	var mismatch := AISidebarSkillParser.parse("---\nname: Other\ndescription: d\n---\n", "folder")
	var f1: Dictionary = ok["fields"]
	if ok["ok"] and ok["name"] == "pdf-tools" and ok["description"] == "Extract text. Use for PDFs." and ok["body"] == "# Title\nSteps" \
			and f1.get("license") == "MIT" and str(f1.get("metadata", "")).contains("author") and (ok["warnings"] as Array).is_empty() \
			and not no_fm["ok"] and not no_desc["ok"] and mismatch["ok"] and (mismatch["warnings"] as Array).size() == 2:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (parser) failed: ok=%s mismatch=%s" % [str(ok), str(mismatch)])

	# 2. Keşif ve öncelik: proje > kullanıcı > yerleşik; proje skill'i varsayılan kapalı; tercih kazanır.
	_rm(TMP)
	var proj := TMP + "/proj"
	var usr := TMP + "/user"
	var blt := TMP + "/builtin"
	_skill(proj, "alpha", "project alpha")
	_skill(usr, "alpha", "user alpha")
	_skill(usr, "beta", "user beta")
	_skill(blt, "gamma", "builtin gamma")
	_skill(proj, "delta", "project delta")
	_write(usr + "/not-a-skill/README.md", "x")
	var roots: Array[Dictionary] = [{"path": proj, "scope": "project"}, {"path": usr, "scope": "user"}, {"path": blt, "scope": "builtin"}]
	var all := AISidebarSkillRegistry.discover(roots)
	var alpha := AISidebarSkillRegistry.find("alpha", all)
	var names_default: Array = []
	for s in AISidebarSkillRegistry.enabled_skills(roots, {}):
		names_default.append(s["name"])
	var names_pref: Array = []
	for s in AISidebarSkillRegistry.enabled_skills(roots, {"delta": true, "gamma": false}):
		names_pref.append(s["name"])
	names_default.sort()
	names_pref.sort()
	var catalog := AISidebarSkillRegistry.catalog_prompt(AISidebarSkillRegistry.enabled_skills(roots, {}))
	if all.size() == 4 and alpha["description"] == "project alpha" and (alpha["warnings"] as Array).size() == 1 \
			and names_default == ["beta", "gamma"] and names_pref == ["beta", "delta"] \
			and catalog.contains("<name>beta</name>") and not catalog.contains("delta") and AISidebarSkillRegistry.catalog_prompt([]) == "":
		passed += 1
	else:
		failed += 1
		errors.append("T2 (discovery/precedence) failed: all=%d default=%s pref=%s" % [all.size(), str(names_default), str(names_pref)])

	# 3. Etkinleştirme: ön bilgisiz gövde + ek dosya listesi; ek dosya okuma klasör dışına çıkamaz; silme.
	_write(usr + "/beta/references/guide.md", "guide text")
	var beta := AISidebarSkillRegistry.find("beta", all)
	var content := AISidebarSkillRegistry.activation_content(beta)
	var res_ok := AISidebarSkillRegistry.read_resource(beta, "references/guide.md")
	var res_up := AISidebarSkillRegistry.read_resource(beta, "../alpha/SKILL.md")
	var res_abs := AISidebarSkillRegistry.read_resource(beta, "C:/Windows/win.ini")
	var del_builtin := AISidebarSkillRegistry.delete_skill(AISidebarSkillRegistry.find("gamma", all))
	var del_user := AISidebarSkillRegistry.delete_skill(beta)
	if content.begins_with("<skill_content name=\"beta\">") and content.contains("Body") and not content.contains("description:") \
			and content.contains("<file>references/guide.md</file>") and not content.contains("<file>SKILL.md</file>") \
			and res_ok["ok"] and res_ok["content"] == "guide text" and not res_up["ok"] and not res_abs["ok"] \
			and not del_builtin["ok"] and del_user["ok"] and not DirAccess.dir_exists_absolute(usr + "/beta"):
		passed += 1
	else:
		failed += 1
		errors.append("T3 (activation/resources/delete) failed: content=%s up=%s" % [content.left(200), str(res_up)])
	_rm(TMP)

	# 4. Sıkıştırma: eski activate_skill sonucu korunur, diğer eski araç sonuçları özetlenir.
	var long_text := "x".repeat(3000)
	var msgs: Array = [
		{"role": "tool", "name": "activate_skill", "content": long_text},
		{"role": "tool", "name": "read_script", "content": long_text},
		{"role": "tool", "name": "get_scene_tree", "content": "{}"},
		{"role": "tool", "name": "get_scene_tree", "content": "{}"},
	]
	var compacted := AISidebarContextCompactor.compact_messages(msgs, 2)
	if str(compacted[0]["content"]) == long_text and str(compacted[1]["content"]) != long_text:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (compaction keeps skills) failed")

	# 5. Kurallar: global önce, proje sonra; .agents/rules/*.md alfabetik, .md dışı atlanır; kesme; add_rule.
	_rm(TMP)
	var g_dir := TMP + "/home/.agents"
	var p_agents := TMP + "/proj/AGENTS.md"
	var p_rules := TMP + "/proj/.agents/rules"
	_write(g_dir + "/AGENTS.md", "G-main")
	_write(g_dir + "/rules/b.md", "G-b")
	_write(g_dir + "/rules/a.md", "G-a")
	_write(p_agents, "P-main")
	_write(p_rules + "/x.md", "P-x")
	_write(p_rules + "/notes.txt", "ignored")
	var pfiles: Array[String] = [p_agents, TMP + "/proj/GEMINI.md"]
	var rules := AISidebarRulesRegistry.discover(g_dir, pfiles, p_rules)
	var order: Array = []
	for r in rules:
		order.append("%s:%s" % [r["scope"], str(r["path"]).get_file()])
	var text := AISidebarRulesRegistry.prompt_text(rules)
	var learn_file := p_rules + "/AGENTS.md"
	var add1 := AISidebarRulesRegistry.add_rule("Keep data in JSON", "project", g_dir, learn_file)
	var add2 := AISidebarRulesRegistry.add_rule("Two\nlines", "project", g_dir, learn_file)
	var add_g := AISidebarRulesRegistry.add_rule("Global one", "global", g_dir, learn_file)
	var add_empty := AISidebarRulesRegistry.add_rule("  ", "project", g_dir, learn_file)
	var add_long := AISidebarRulesRegistry.add_rule("z".repeat(600), "project", g_dir, learn_file)
	var learned := FileAccess.get_file_as_string(learn_file)
	var g_text := FileAccess.get_file_as_string(g_dir + "/AGENTS.md")
	_write(p_agents, "y".repeat(AISidebarRulesRegistry.MAX_TOTAL_CHARS + 50))
	var rules_long := AISidebarRulesRegistry.prompt_text(AISidebarRulesRegistry.discover(g_dir, pfiles, p_rules))
	_rm(TMP)
	var none := AISidebarRulesRegistry.prompt_text(AISidebarRulesRegistry.discover(g_dir, pfiles, p_rules))
	if order == ["global:AGENTS.md", "global:a.md", "global:b.md", "project:AGENTS.md", "project:x.md"] \
			and text.find("G-main") < text.find("P-main") and text.contains("global rules") and text.contains("project rules") \
			and add1["ok"] and add2["ok"] and add_g["ok"] and not add_empty["ok"] and not add_long["ok"] \
			and learned == "# Rules\n- Keep data in JSON\n- Two lines\n" and g_text.ends_with("- Global one\n") \
			and rules_long.contains("truncated") and none == "":
		passed += 1
	else:
		failed += 1
		errors.append("T5 (rules) failed: order=%s learned=%s" % [str(order), learned.c_escape()])

	# 5b. add_rule onay ister (Manuel / Otomatik), köprüde açık değil; /learn, @rules, @skill:ad.
	var manual_asks := AISidebarPermissionPolicy.requires_user_approval("add_rule", {}, AISidebarPermissionPolicy.AutoApproveMode.MANUAL)
	var auto_asks := AISidebarPermissionPolicy.requires_user_approval("add_rule", {}, AISidebarPermissionPolicy.AutoApproveMode.AUTO)
	var full_asks := AISidebarPermissionPolicy.requires_user_approval("add_rule", {}, AISidebarPermissionPolicy.AutoApproveMode.FULL_AUTO)
	var gateway := AISidebarExternalAgentGateway.new()
	var learn_g := AISidebarSlashCommandManager.parse("/learn --global Use typed GDScript")
	var learn_res: Dictionary = (learn_g["command"]["execute_fn"] as Callable).call(str(learn_g["args"]), {})
	var learn_empty: Dictionary = (learn_g["command"]["execute_fn"] as Callable).call("", {})
	var mention := AISidebarMentionManager.resolve_prompt_context("fix it @skill:godot-refactor please")
	var sugg_names: Array = []
	for s in AISidebarMentionManager.get_suggestions("rul"):
		sugg_names.append(s["insert_text"])
	if manual_asks and auto_asks and not full_asks and not gateway.is_tool_exposed("add_rule") \
			and learn_res.get("action") == "run_agent" and str(learn_res["prompt"]).contains("scope=global") and str(learn_res["prompt"]).contains("Use typed GDScript") \
			and str(learn_empty["prompt"]).contains("corrections") and str(learn_empty["prompt"]).contains("scope=project") \
			and mention["has_mentions"] and str(mention["augmented_prompt"]).contains("<skill_content name=\"godot-refactor\">") \
			and sugg_names.has("@rules"):
		passed += 1
	else:
		failed += 1
		errors.append("T5b (add_rule policy, /learn, mentions) failed: manual=%s auto=%s full=%s learn=%s sugg=%s" % [manual_asks, auto_asks, full_asks, str(learn_res).left(160), str(sugg_names)])

	# 6. Araç ve /skill: yerleşik skill'ler açık gelir; activate_skill enum'u ve içerik; /skill ajanı başlatır.
	var tool_schema: Dictionary = {}
	for s in AISidebarToolManager.get_all_schemas():
		if s["function"]["name"] == "activate_skill":
			tool_schema = s
	var enum_names: Array = tool_schema.get("function", {}).get("parameters", {}).get("properties", {}).get("name", {}).get("enum", [])
	var act := AISidebarToolManager.execute_tool("activate_skill", {"name": "godot-debug-and-repair"}, false)
	var bad := AISidebarToolManager.execute_tool("activate_skill", {"name": "no-such-skill"}, false)
	var slash_parsed := AISidebarSlashCommandManager.parse("/skill godot-debug-and-repair fix the crash")
	var slash_cmd: Dictionary = slash_parsed.get("command", {})
	var slash_res: Dictionary = (slash_cmd["execute_fn"] as Callable).call(str(slash_parsed["args"]), {}) if slash_cmd.has("execute_fn") else {}
	if enum_names.has("godot-feature-development") and enum_names.has("godot-debug-and-repair") \
			and act["success"] and str(act["data"]["content"]).contains("<skill_content name=\"godot-debug-and-repair\">") \
			and not bad["success"] and bad["error"]["code"] == "SKILL_NOT_FOUND" \
			and slash_res.get("action") == "run_agent" and str(slash_res.get("prompt", "")).contains("fix the crash") and str(slash_res.get("prompt", "")).contains("<skill_content"):
		passed += 1
	else:
		failed += 1
		errors.append("T6 (tool + slash) failed: enum=%s act=%s slash=%s" % [str(enum_names), str(act).left(160), str(slash_res).left(160)])

	return {"name": "SkillsTests", "passed": passed, "failed": failed, "errors": errors}
