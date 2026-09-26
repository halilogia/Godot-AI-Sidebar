---
name: godot-project-bootstrap
description: Start or take over a Godot 4 game project connected through the Godot AI Sidebar tools - check the connection, set up the project memory documents, folder layout and a runnable main scene. Use at the beginning of work on a new or unfamiliar Godot project.
---

# Godot project bootstrap

## 1. Check the connection

- Call `analyze_project`. If the Godot tools are missing or fail, the user must open the project in Godot with the Godot AI Sidebar plugin enabled and connect your agent (see "Agent mapping"). Stop and tell them.
- `get_project_files` for the current layout. `get_scene_tree` shows the scene open in the editor (`NO_ACTIVE_SCENE` if none).

## 2. Project memory

The project keeps five documents at the repository root. Templates are in the `templates/` folder next to this SKILL.md; copy and fill them, keeping their headings:

| File | Holds |
|---|---|
| `GAME_SPEC.md` | What the game is: pillars, core loop, scope, target platform |
| `ARCHITECTURE.md` | Folders, scenes, autoloads, main systems and how data flows |
| `ROADMAP.md` | Milestones with checkboxes and acceptance criteria |
| `DECISIONS.md` | Dated decisions with the reason |
| `KNOWN_ISSUES.md` | Open bugs and limitations with reproduction steps |

- Read the ones that exist before changing anything.
- For a new project, draft `GAME_SPEC.md` from the user's description and ask them to confirm the open questions; create the other four with what is known. Do not invent other document types.
- Add a short section to `CLAUDE.md` that points to these five files and says construction is file-first (see the godot-feature-development skill).

## 3. Layout and main scene

- Default layout unless the project already has one: `scenes/`, `scripts/`, `resources/`, `assets/`, `data/`. Keep the project's own layout if it exists.
- A new project needs a runnable main scene: write `scenes/main.tscn` (see the godot-scene-authoring skill), set `run/main_scene="res://scenes/main.tscn"` under `[application]` in `project.godot`, then `sync_project`.
- Editing `project.godot` while the editor is open is not guaranteed to be picked up or kept by the editor. Confirm with `play_game` (it must not return `NO_MAIN_SCENE`); if the setting did not take effect, ask the user to set it in Project Settings → Application → Run → Main Scene.
- Never edit `addons/godot_sidebar_ai/`.

## 4. First run

`play_game`, wait, `get_runtime_errors`, `take_runtime_screenshot`, `stop_game`. Report what runs and what the next milestone in `ROADMAP.md` is. Initialize git and commit if the project is not under version control and the user agrees.

## Agent mapping

The method above is the same for every agent; only access differs.

- **Claude Code (or another MCP client) over the bridge:** the tools are `mcp__godot__<tool>` (prefix = the registered server name). Edit project files with your own file tools, then call `sync_project` with the written files in `changed_files`. Scene tools need `expected_scene_path` and the user's permission in the sidebar (`/mcp write ask` or `/mcp write auto`); connecting needs `/mcp on` and the `claude mcp add ...` command it copies.
- **Godot AI Sidebar agent:** write files with `create_or_update_script`, `write_files`, `replace_file_content` or `create_scene` (they validate before writing; `create_or_update_script`, `write_files` and `replace_file_content` also reload an open scene they rewrite, so there is no `sync_project` step); scene tools run directly under the sidebar's approval mode.
