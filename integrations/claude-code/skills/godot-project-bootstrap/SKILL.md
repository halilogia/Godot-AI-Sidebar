---
name: godot-project-bootstrap
description: Start or take over a Godot 4 game project connected through the Godot AI Sidebar MCP bridge - check the connection, set up the project memory documents, folder layout and a runnable main scene. Use at the beginning of work on a new or unfamiliar Godot project.
---

# Godot project bootstrap

## 1. Check the connection

- Call `analyze_project`. If the godot tools are missing or fail to connect, the user must open the project in Godot, run `/mcp on` in the Godot AI Sidebar and add the server to Claude Code with the command it copies. Stop and tell them.
- `get_project_files` for the current layout. `get_scene_tree` shows the scene open in the editor (`NO_ACTIVE_SCENE` if none).

## 2. Project memory

The project keeps five documents at the repository root (templates: `integrations/claude-code/templates/` in the Godot AI Sidebar repository):

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
