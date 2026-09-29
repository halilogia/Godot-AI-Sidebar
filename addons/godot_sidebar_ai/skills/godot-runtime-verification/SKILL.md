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
4. **Collect the evidence** for each criterion. You can drive the running game:
   - `send_input` presses keys and actions, clicks, drags, holds several actions together; pass `steps` to play a whole sequence (with pauses) in ONE call instead of one call per key.
   - `wait_for_runtime` waits until a node property meets a condition (`Main/Player`, `health`, `>`, `0`, timeout 3 s) and reports how long it took; with timeout 0 it is an instant check. Use it instead of inspecting again and again. Numbers may be given as text.
   - `trace_runtime_signals` records which signals a node emits and when (for example the score-changed and game-over signals); `get_runtime_performance` samples FPS, frame time and node/orphan growth (a growing node count is a leak).
   - Every input result lists the new runtime errors: script errors the game logged during that action. `get_runtime_errors` also sees the running game's errors. Read them before the next step.
   - `get_output` reads Godot's Output (terminal) log: source editor (autoload, import, plugin and script-loading errors the editor printed) or game (its print lines and errors). Use it when something fails with no clear error elsewhere, and to read print debugging from the game.
   - `diagnose_physics` explains a pickup, goal, hit box or wall that does nothing (layer / mask mismatch, disabled shape, monitoring off); call it before guessing layer numbers.
   - `set_runtime_property` sets a node property or script variable in the running game (this session only): set score to 99 and check the win screen, health to 0 and check game over, instead of playing for minutes. It proves the reaction, not that a player can reach the state: still play the normal path once.
   Mark a criterion "needs manual play test" only when it cannot be driven this way (e.g. depends on feel or timing you cannot measure).
5. **Repeat runs** when a change matters: `restart_game` gives a fresh run.
6. **Stop:** `stop_game`.

## Knowing when to stop

- Stop when the requested core game runs and each criterion has evidence. Do not add features nobody asked for (finish screens, extra levels); list them as suggestions.
- Before finishing, call `audit_runtime_ui` once: it measures off-screen, overflowing, overlapping and low-contrast text and names the nodes; fix what it lists. Then look at the last screenshot once for overlapping or low-contrast text, labels left over from an earlier state (for example a "pick a card" prompt after the card was played) and clipped elements. Fix what you see.
- If a behavior cannot be checked with input after three tries (for example walking blindly toward a far goal), stop and report it as "needs manual play test" instead of looping.

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
