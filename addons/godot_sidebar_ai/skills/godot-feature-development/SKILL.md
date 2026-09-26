---
name: godot-feature-development
description: Build or change a gameplay feature in a Godot 4 project through the Godot AI Sidebar tools. Use when the user asks for a new mechanic, system, scene, UI or behavior change in a Godot game.
---

# Godot feature development

The Godot editor is open with the Godot AI Sidebar plugin. Its tools give you the editor and the running game; tool names below are the plugin's names (see "Agent mapping" at the end for how your agent reaches them and edits files).

## Rule: construction is file-first

- Write GDScript, `.tscn`, `.tres`, `.gdshader` and data files (JSON, CSV) as files. Prefer one complete `.tscn` or a procedural script over many single-node calls.
- After changing files, synchronize the editor so it sees them and reloads an open scene you rewrote (otherwise a later save overwrites your file with the editor's stale copy).
- Use the scene tools (`add_node`, `set_node_property`, `instantiate_scene`, `attach_script_to_node`, `save_scene`) only for small, precise, undoable edits of the scene that is open in the editor. If the user or an approval step refuses a change, ask; do not work around it.
- Never edit `addons/godot_sidebar_ai/`, `.godot/` or `.git/`.

## Loop

1. **Read the project rules** in `AGENTS.md` at the project root, if present. Call `analyze_project` and `get_project_files` for the current structure.
2. **State the change and its acceptance criteria** (what the player sees or can do, which nodes/scripts exist, what must not break). Keep the step small enough to run and check in one pass.
3. **Implement file-first.** Match the project's existing folder layout, naming and code style; typed GDScript; one responsibility per script.
4. **Sync and validate:** `sync_project` (with `changed_files`), then `validate_script` for every `.gd` you touched. Fix parse errors before running.
5. **Run and observe:** `play_game`, wait 2–3 seconds, `get_runtime_errors`. If it reports `is_inconclusive` / `NO_NEW_LOG_DATA`, wait and call it again. Then `take_runtime_screenshot` and/or `inspect_runtime_tree` / `inspect_runtime_node` to check the acceptance criteria. `stop_game` when done.
6. **Repair** anything that fails (see the godot-debug-and-repair skill) and repeat from step 4.
7. **Report and record:** say which criteria were verified and by what evidence (error check, screenshot, runtime node values); name what was not verified. If a lasting rule or decision came up, propose adding it to `AGENTS.md`. Commit when the user's workflow asks for it.

## Do not

- Claim a feature works without running the game and reading `get_runtime_errors`.
- Retry a refused tool call unchanged (`WRITER_BUSY`: another agent is writing, wait; a rejected approval: the user said no, ask or change approach; `ACTIVE_SCENE_NOT_CONFIRMED`: `open_scene` the intended scene first).
- Add engine-level workarounds when a normal GDScript solution exists.

## Agent mapping

The method above is the same for every agent; only access differs.

- **Claude Code (or another MCP client) over the bridge:** the tools are `mcp__godot__<tool>` (prefix = the registered server name). Edit project files with your own file tools, then call `sync_project` with the written files in `changed_files`. Scene tools need `expected_scene_path`; connecting needs `/mcp on` and the `claude mcp add ...` command it copies.
- **Godot AI Sidebar agent:** write files with `create_or_update_script`, `write_files`, `replace_file_content` or `create_scene` (they validate before writing; `create_or_update_script`, `write_files` and `replace_file_content` also reload an open scene they rewrite, so there is no `sync_project` step); scene tools run directly under the sidebar's approval mode.
