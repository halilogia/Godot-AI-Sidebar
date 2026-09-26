# Acceptance criteria — grand-strategy vertical slice

Each criterion names the evidence that counts. Input-driven criteria use send_input; report a criterion as "needs manual play test" only if send_input cannot reach it.

| # | Criterion | Evidence |
|---|---|---|
| A1 | Project opens and the main scene runs without errors for 60 s | `get_runtime_errors` verified clean after ≥ 60 s of play |
| A2 | ≥ 30 provinces exist, generated from a data file | data file in repo + generator script; `inspect_runtime_tree` shows ≥ 30 province nodes (or one map node with ≥ 30 entries in its state) |
| A3 | Provinces drawn in their owner's color; 3 distinct country colors | runtime screenshot |
| A4 | Each province has id, name, owner, neighbors, income | data file + `inspect_runtime_node` on one province (or its state) |
| A5 | Date advances; pause and ≥ 2 speeds exist | two runtime screenshots / node reads seconds apart show different dates; code review of pause/speed |
| A6 | Monthly income added to treasuries | top-bar treasury read before and after a month change (screenshot or node) |
| A7 | Autoplay: an AI war starts after 30 days without input | screenshot or node state showing war / army after autoplay run |
| A8 | Occupation changes province color | screenshot before and after occupation |
| A9 | Clicking a province opens the info panel | `send_input` click on a province node, then screenshot or `inspect_runtime_node` of the panel |
| A10 | Pause / speed controls respond to input | `send_input` key or action, then two date reads seconds apart |
| A11 | No edits to `addons/godot_sidebar_ai/`, `.godot/` | `git status` / diff |

## What to record per run

- Claude Code and Godot versions, model, date.
- Wall-clock time, number of MCP tool calls (by tool), number of user interventions and why.
- Result per criterion (pass / fail / manual), bugs found, which ones the agent fixed itself.
- Gaps: what the agent could not do with the current tools (this is the input for later roadmap decisions, e.g. Companion).
- Project context / memory (decides whether an episodic memory or retrieval layer is ever needed):
  - Did the agent contradict or forget a decision made earlier (in `AGENTS.md` or earlier in the work)?
  - Did it solve the same bug twice?
  - Did any notes it kept grow too large to read at the start of a session?
  - After a new session (or context compaction), could it resume without re-discovering the project?
  - Rough context cost of the project rules and skills loaded at session start.
