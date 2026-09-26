---
name: godot-refactor
description: Restructure Godot 4 code or scenes without changing behavior (split scripts, move files, rename classes, extract scenes) with evidence from the Godot AI Sidebar tools. Use when the user asks to clean up, reorganize or refactor a Godot project.
---

# Godot refactor

A refactor changes structure, not behavior. Bugs found on the way are fixed in a separate step with their own evidence.

## Before

1. Record a baseline: `play_game`, wait, `get_runtime_errors`, `take_runtime_screenshot`, `inspect_runtime_tree` for the areas you will touch, `stop_game`.
2. Find every reference to what you will move or rename: `res://` paths in `.gd`, `.tscn`, `.tres` and `project.godot` (autoloads, main scene), `preload` / `load`, `class_name` uses, node paths in `$`/`get_node`, signal connections in `.tscn` files.

## During

- One small step at a time (one move, one rename, one extraction).
- Moving a file: move its `.uid` sidecar with it (`script.gd.uid`), and `.import` files for assets; update every `res://` path you found. Godot also resolves `uid://` references, but text paths must still be correct.
- Renaming a `class_name`: update all uses; two scripts must never declare the same `class_name`.
- Extracting part of a scene into its own `.tscn`: write the new scene file, replace the nodes in the parent scene with an instance (`instance=ExtResource(...)`), keep node names so paths stay valid.
- After each step: `sync_project` (with `changed_files`), `validate_script` on the touched scripts, `open_scene` + `get_scene_tree` for touched scenes.

## After

Run the baseline again (errors, screenshot, runtime tree) and compare. Any difference is either a mistake to undo or a separate, reported behavior change. Update any project document (e.g. `AGENTS.md`) that names moved or renamed parts. Commit the refactor separately from fixes and features.

## Agent mapping

The method above is the same for every agent; only access differs.

- **Claude Code (or another MCP client) over the bridge:** the tools are `mcp__godot__<tool>` (prefix = the registered server name). Edit project files with your own file tools, then call `sync_project` with the written files in `changed_files`. Scene tools need `expected_scene_path`; connecting needs `/mcp on` and the `claude mcp add ...` command it copies.
- **Godot AI Sidebar agent:** write files with `create_or_update_script`, `write_files`, `replace_file_content` or `create_scene` (they validate before writing; `create_or_update_script`, `write_files` and `replace_file_content` also reload an open scene they rewrite, so there is no `sync_project` step); scene tools run directly under the sidebar's approval mode.
