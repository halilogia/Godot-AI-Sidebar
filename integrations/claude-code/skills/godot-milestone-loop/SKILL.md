---
name: godot-milestone-loop
description: Work autonomously through a Godot 4 game's milestones with the Godot AI Sidebar MCP bridge - research, plan, implement, sync, run, inspect, repair, verify, commit, then continue with the next item. Use when the user asks to build a game or a milestone end to end, or to keep going without step-by-step instructions.
---

# Godot milestone loop

The project memory (`GAME_SPEC.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `DECISIONS.md`, `KNOWN_ISSUES.md`) is the state of the work. Everything you would need to resume in a new session goes there, not only into the conversation.

## Start

1. Read the five documents. If they do not exist, run the godot-project-bootstrap skill first.
2. Pick the first unticked item of the current milestone in `ROADMAP.md`. If it has no acceptance criteria, write them before implementing.

## Loop (one roadmap item at a time)

1. **Research** only what you do not know: read the relevant project code; for Godot APIs you are unsure about, check the official documentation for the project's Godot version instead of guessing.
2. **Plan** the item in a few concrete steps: files to create or change, data format, how each acceptance criterion will be checked. Record real design choices in `DECISIONS.md`.
3. **Implement** file-first (godot-feature-development, godot-scene-authoring).
4. **Sync:** `sync_project` with `changed_files`; `validate_script` on changed scripts.
5. **Run and inspect:** `play_game`, wait, `get_runtime_errors`, screenshot / runtime tree as the criteria need (godot-runtime-verification).
6. **Repair** failures (godot-debug-and-repair) and go back to step 4.
7. **Verify** every criterion with evidence; `stop_game`.
8. **Record and commit:** tick the item in `ROADMAP.md`, update `ARCHITECTURE.md` if structure changed, add unfixed problems to `KNOWN_ISSUES.md`, commit with a message naming the item.
9. **Next item.** At the end of a milestone, run the godot-release-workflow milestone close, then continue with the next milestone.

## Stop and ask the user when

- `GAME_SPEC.md` does not answer a question that changes the result (mark it under "Open questions").
- A change would delete or overwrite work you did not create, or needs the user's editor action (enabling scene writes, main scene or export settings).
- The same criterion fails after three different repair attempts: record it in `KNOWN_ISSUES.md` and ask instead of looping.
- A tool is refused with `USER_DENIED`.

## Keep it honest

- One item is finished only with runtime evidence; "should work" is not evidence.
- Criteria that need real input (clicks, keys) are reported as "needs manual play test", and the milestone summary lists them.
- Keep commits small: one verified item per commit, refactors separate from features.
