# Plan: Professional AI IDE Experience for Godot AI Sidebar (ChatDock Refactor)

Transform the presentation layer of Godot AI Sidebar from a debug console into a modern, professional AI IDE experience (Cursor / Claude Code style inside Godot) without modifying backend logic.

## User Review Required

> [!IMPORTANT]
> The backend architecture (`AgentRunner`, `ToolManager`, `ChangeSet`, `VerificationPipeline`, `NetworkManager`, `Provider`) remains intact. Only the UI presentation layer, signal handlers, component orchestration, and stale editor script cleanup during Undo will be upgraded.

---

## Proposed Changes

### Component Architecture (`addons/godot_sidebar_ai/ui/components/`)

Create modular, dedicated single-responsibility UI components following the `srp-modularizer` design:

#### [NEW] [`message_bubble.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/components/message_bubble.gd)
- Renders User and Assistant natural language messages with clear visual hierarchy.
- Selectable text with copy support and clickable `res://` / `file:` links opening in Godot Editor.
- Code blocks with syntax styling, horizontal scrolling, and a Copy button.

#### [NEW] [`activity_group.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/components/activity_group.gd)
- Collapsible progress card (`▾ Activity` / `▾ Working`).
- Human-readable status items (`✓ Inspected project`, `✓ Updated player.gd`, `✓ Validated script`).
- Expandable technical accordion per item showing tool name, arguments, and duration on demand.

#### [NEW] [`changes_card.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/components/changes_card.gd)
- Renders file deltas (`player.gd +12 -2`, `Player.tscn +8 -0`).
- Integrated `[🔍 View Diff]` modal trigger and `[↩ Undo]` action.

#### [NEW] [`approval_card.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/components/approval_card.gd)
- Clean inline approval card for destructive operations with `[✓ Approve]`, `[✕ Reject]`, `[🔍 View Diff]`.

#### [NEW] [`runtime_card.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/components/runtime_card.gd)
- Renders testing lifecycle (`▾ Testing`, `▶ Starting game`, `✓ No runtime errors`).

#### [NEW] [`telemetry_card.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/components/telemetry_card.gd)
- Minimalist task completion summary (`✓ Completed in 2.6s · 2 LLM turns · 1 tool · 1 file`).
- Expandable detail drawer (`LLM: 2.57s`, `Tool: 0.04s`, `Waiting: 0.00s`).

#### [NEW] [`error_card.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/components/error_card.gd)
- Clean error presentation with `[Retry]` action and collapsible technical stack/exception.

---

### Main Dock & Stale Script Cleanup

#### [MODIFY] [`chat_dock.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/docks/chat_dock.gd) and [`chat_dock.tscn`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/ui/docks/chat_dock.tscn)
- Replace monolithic `RichTextLabel` with a modular component stream inside a smart `ScrollContainer`.
- Autoscroll to bottom when user is at bottom; show `"↓ Jump to latest"` pill button when user has scrolled up.
- Responsive layout with flexible margins and no hardcoded widths.
- Input bar with dynamic `[Send]` / `[⏹ Stop]` states.

#### [MODIFY] [`change_set.gd`](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Private/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/types/change_set.gd)
- Robust stale script editor resource clearing before deleting newly created scripts on `Undo` to eliminate `File not found` error during Godot editor filesystem rescan.

---

## Verification Plan

### Automated Unit Tests
- Run `tests/test_runner.gd` with Godot 4.7 headless to verify all 33+ test suites pass with 0 regressions.
- Add UI component lifecycle and autoscroll regression tests in `tests/test_ui_components.gd`.
- Run `--check-only` across the entire project.

### Manual Verification in Real Godot GUI
- Deploy via `install.ps1` to `<local_path>`.
- Perform real GUI testing:
  1. Natural conversation flow (User message, Assistant text, collapsible Activity, Changes Card, Testing, Telemetry).
  2. Create script -> View Diff -> Undo -> verify no "File not found" error.
  3. Modify existing script -> Undo -> verify old content restored.
  4. Test narrow dock width and wide dock width responsiveness.
  5. Test copy buttons and text selection across all cards.
