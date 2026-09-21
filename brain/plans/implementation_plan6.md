# Implementation Plan: AI-Native UI Layout Telemetry Engine (`inspect_ui_layout`)

Build a dedicated, read-only UI inspection and telemetry engine for Godot AI Sidebar that extracts hierarchical geometry, bounding boxes, size constraints, visibility, Theme Type Variations, Godot 4.7 accessibility attributes, and evidence-based layout conflict diagnostics.

## Proposed Changes

### Core Tools Layer

#### [NEW] [ui_telemetry_tools.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd)
- Creates `AISidebarUITelemetryTools` extending `AISidebarToolBase`.
- Implements `inspect_ui_layout(root_path: String, max_depth: int, include_invisible: bool, include_theme_details: bool) -> Dictionary`.
- Recursively inspects `Control` nodes up to `max_depth` (default: 4, cap: 8).
- Extracts:
  - Node path, name, class type, parent class.
  - Geometry: `rect`, `global_rect`, `size`, `position`, `custom_minimum_size`, `combined_minimum_size`.
  - Layout & Flags: `size_flags_horizontal`, `size_flags_vertical`, `stretch_ratio`, `anchors_preset`, `anchor_*`, `offset_*`.
  - Interaction & Visibility: `is_visible_in_tree()`, `clip_contents`, `mouse_filter`, `focus_mode`, `has_focus`.
  - Theme: `theme_type_variation`.
  - A11y (Godot 4.7): `accessibility_name`, `accessibility_description`, `accessibility_live`.
  - Semantic Metadata: `ui_role`, `ui_intent`, `ui_id` from `get_meta()`.
  - Specific inspections for `Label` (`is_clipping_text()`, line counts, overrun behavior).
- Heuristic Evidence-Based Diagnostics (with `rule_id`, `severity`, `confidence`, `evidence`):
  - `UI_TEXT_CLIPPED`: Detects genuine label clipping with allocated vs required width.
  - `UI_CONTAINER_OVERFLOW`: Detects child combined minimum size exceeding non-scroll container size.
  - `UI_NON_CONTAINER_CHILD_MISMATCH`: Detects `Container` children inside non-container Controls (e.g. `Button`).

#### [MODIFY] [tool_manager.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/tools/tool_manager.gd)
- Preload `AISidebarUITelemetryTools`.
- Register `inspect_ui_layout` schema in `get_all_schemas()`.
- Add routing for `inspect_ui_layout` in `get_relevant_schemas()` (under UI, layout, inspection keywords).
- Execute `inspect_ui_layout` via `AISidebarUITelemetryTools.execute()`.

#### [MODIFY] [permission_policy.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/addons/godot_sidebar_ai/core/security/permission_policy.gd)
- Register `inspect_ui_layout` as safe `READ_ONLY` tool (approval never required).

---

### Testing & Verification

#### [NEW] [test_ui_telemetry.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/tests/test_ui_telemetry.gd)
- Unit tests for:
  1. Tool schema validity and registration in `ToolManager`.
  2. Telemetry extraction on standard Control hierarchy (geometry, sizes, flags).
  3. Godot 4.7 accessibility extraction (`accessibility_name`, `accessibility_description`).
  4. Semantic metadata extraction (`ui_role`, `ui_intent`).
  5. `UI_TEXT_CLIPPED` evidence generation when a Label overflows its allocated width.
  6. `UI_CONTAINER_OVERFLOW` detection on oversized child inside fixed container.
  7. `UI_NON_CONTAINER_CHILD_MISMATCH` detection when child is nested in a Button.
  8. Depth limiting (`max_depth`) preventing infinite recursion.
  9. Execution on live UI components (`HistoryPanel`, `SettingsDialog`).

#### [MODIFY] [test_runner.gd](file:///C:/Users/Halil%20Emre/Desktop/GitHub/Public/Godot%20AI%20Sidebar/tests/test_runner.gd)
- Register `TestUITelemetry` in the master test runner suite array.

## Verification Plan

### Automated Tests
- Run master test runner via Godot 4.7 headless:
  `godot --headless --path . -s "res://tests/test_runner.gd"`
- Ensure all 275+ existing tests pass, plus all new UI telemetry tests (0 failures).
