---
name: godot-debug-and-repair
description: Diagnose and fix errors, crashes and wrong behavior in a Godot 4 game using the Godot AI Sidebar MCP bridge (runtime errors, live scene tree, screenshots). Use when the game shows errors, does not start, behaves incorrectly or looks wrong.
---

# Godot debug and repair

## 1. Reproduce with evidence

- Parse problems first: `validate_script` on the suspected `.gd` files (after `sync_project` if you edited them).
- Run: `play_game` (the main scene; `current_scene_only: true` runs the scene open in the editor), wait 2–3 seconds, then `get_runtime_errors`.
  - Read `errors` / `warnings` with their file and line.
  - `is_verified_clean: true` means no errors were logged. `is_inconclusive` / `NO_NEW_LOG_DATA` means nothing was logged yet: wait and call again before concluding anything.
- `play_game` returning `NO_MAIN_SCENE` means `application/run/main_scene` is not set; `NO_ACTIVE_SCENE` from scene tools means no scene is open in the editor.
- Wrong behavior without errors: `inspect_runtime_tree` (is the node there, under the right parent?) and `inspect_runtime_node` (position, visibility, process mode). Wrong visuals: `take_runtime_screenshot`. UI layout: `inspect_ui_layout`.

## 2. Find the root cause

- Open the reported file and line (`read_script` or your own file reader) and follow the data back to where it goes wrong. State the root cause in one sentence before editing.
- Common Godot causes: wrong node path in `$Node` / `get_node`, `@onready` used before the node is in the tree, signal not connected or connected twice, resource path typo, `class_name` conflict, physics layer/mask mismatch, node not added to the tree, `_process` doing work that belongs in `_ready`.

## 3. Minimal fix, then prove it

1. Make the smallest change that fixes the root cause (no unrelated cleanup).
2. `sync_project` (with `changed_files`), `validate_script`.
3. `stop_game` if still running, `play_game`, wait, `get_runtime_errors` until it is clean, and repeat the observation that showed the bug (screenshot, runtime node values).
4. `stop_game`.

## 4. Report

- Root cause, the fix, and the evidence that it is gone.
- If you could not fix it or it only happens sometimes: add it to `KNOWN_ISSUES.md` with reproduction steps and what you tried. Do not call it fixed.
