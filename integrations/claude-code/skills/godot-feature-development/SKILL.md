---
name: godot-feature-development
description: Build or change a gameplay feature in a Godot 4 project through the Godot AI Sidebar MCP bridge. Use when the user asks for a new mechanic, system, scene, UI or behavior change in a Godot game and the godot MCP tools (mcp__godot__*) are available.
---

# Godot feature development

The Godot editor is open with the Godot AI Sidebar plugin and its MCP bridge (`/mcp on`). Its tools appear as `mcp__godot__<tool>` (the prefix is the server name the user registered, usually `godot`). You write files yourself; the bridge gives you the editor and the running game.

## Rule: construction is file-first

- Write GDScript, `.tscn`, `.tres`, `.gdshader` and data files (JSON, CSV) with your own file tools. Prefer one complete `.tscn` or a procedural script over many single-node calls.
- After writing, call `sync_project` and list every file you changed in `changed_files` (always every `.tscn`). An open scene you wrote is reloaded from disk so a later save does not overwrite it.
- Use the bridge scene tools (`add_node`, `set_node_property`, `instantiate_scene`, `attach_script_to_node`, `save_scene`) only for small, precise edits of the scene that is open in the editor. They need an `expected_scene_path` (take `scene_file` from `get_scene_tree`) and the user must have enabled them (`/mcp write ask` or `auto`); `WRITES_DISABLED` means ask the user, do not work around it.
- Never edit `addons/godot_sidebar_ai/`, `.godot/` or `.git/`.

## Loop

1. **Read the project memory** if present: `GAME_SPEC.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `DECISIONS.md`, `KNOWN_ISSUES.md`. Call `analyze_project` and `get_project_files` for the current structure.
2. **State the change and its acceptance criteria** (what the player sees or can do, which nodes/scripts exist, what must not break). Keep the step small enough to run and check in one pass.
3. **Implement file-first.** Match the project's existing folder layout, naming and code style; typed GDScript; one responsibility per script.
4. **Sync and validate:** `sync_project` (with `changed_files`), then `validate_script` for every `.gd` you touched. Fix parse errors before running.
5. **Run and observe:** `play_game`, wait 2–3 seconds, `get_runtime_errors`. If it reports `is_inconclusive` / `NO_NEW_LOG_DATA`, wait and call it again. Then `take_runtime_screenshot` and/or `inspect_runtime_tree` / `inspect_runtime_node` to check the acceptance criteria. `stop_game` when done.
6. **Repair** anything that fails (see the godot-debug-and-repair skill) and repeat from step 4.
7. **Report and record:** say which criteria were verified and by what evidence (error check, screenshot, runtime node values); name what was not verified. Update `ROADMAP.md` checkboxes, add real decisions to `DECISIONS.md`, and unfixed problems to `KNOWN_ISSUES.md`. Commit when the user's workflow asks for it.

## Do not

- Claim a feature works without running the game and reading `get_runtime_errors`.
- Retry a refused tool call unchanged (`WRITER_BUSY`: another agent is writing, wait; `USER_DENIED`: the user said no, ask or change approach; `ACTIVE_SCENE_NOT_CONFIRMED`: `open_scene` the intended scene first).
- Add engine-level workarounds when a normal GDScript solution exists.
