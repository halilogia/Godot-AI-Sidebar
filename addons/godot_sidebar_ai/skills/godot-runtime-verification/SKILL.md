---
name: godot-runtime-verification
description: Verify a Godot 4 game against acceptance criteria by running it through the Godot AI Sidebar tools and collecting evidence (runtime errors, screenshots, live node state). Use before calling any Godot feature or fix done, and when the user asks to check or test the game.
---

# Godot runtime verification

A feature is done only when each acceptance criterion has evidence from the running game.

## Steps

1. **List the criteria** (from the task or `AGENTS.md`). For each, pick the evidence:
   - "no errors" → `get_runtime_errors` with `is_verified_clean: true`
   - "X is visible / looks like Y" → `take_runtime_screenshot`, then describe what you see
   - "node exists / is at position / is visible" → `inspect_runtime_tree`, `inspect_runtime_node`
   - "UI fits / does not overflow" → `inspect_ui_layout` (editor) plus a runtime screenshot
2. **Prepare:** read each tool schema before calling it. `sync_project` with all changed files if files changed; `validate_script` with `file_path` on changed scripts. Script validation checks in-memory compilation in the current editor context. It does not prove clean-cache dependency compilation or runtime behavior; follow the project's `AGENTS.md` / development guide for headless checks.
3. **Run:** `play_game`; wait 2–3 seconds (longer for heavy scenes); `get_runtime_errors`. If inconclusive (`NO_NEW_LOG_DATA`), wait and ask again.
4. **Collect the evidence** for each criterion. You cannot press keys or click in the running game; for input-driven behavior, check the code path and the state it should produce, and mark the criterion as "needs manual play test" in your report.
5. **Repeat runs** when a change matters: `restart_game` gives a fresh run.
6. **Stop:** `stop_game`.

## Report format

| Criterion | Evidence | Result |
|---|---|---|
| Game starts without errors | get_runtime_errors: verified clean | pass |
| Map shows 3 countries | runtime screenshot: three colored regions | pass |
| Clicking a province selects it | input cannot be simulated | needs manual test |

Never turn "not checked" into "pass". An inconclusive error check is not a clean one.

## Agent mapping

The method above is the same for every agent; only access differs.

- **Claude Code (or another MCP client) over the bridge:** the tools are `mcp__godot__<tool>` (prefix = the registered server name). Edit project files with your own file tools, then call `sync_project` with the written files in `changed_files`. Scene tools need `expected_scene_path`; connecting needs `/mcp on` and the `claude mcp add ...` command it copies.
- **Godot AI Sidebar agent:** write files with `create_or_update_script`, `write_files`, `replace_file_content` or `create_scene` (they validate before writing; `create_or_update_script`, `write_files` and `replace_file_content` also reload an open scene they rewrite, so there is no `sync_project` step); scene tools run directly under the sidebar's approval mode.
