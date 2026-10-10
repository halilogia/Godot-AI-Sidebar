---
name: godot-sidebar-workflow
description: Godot Engine 4.7+ architecture standards, Undo/Redo safety, headless test pipelines, and MCP bridge rules for Godot AI Sidebar.
---

# 🤖 Godot AI Sidebar Workflow & Guidelines

This skill defines the development standards, architectural boundaries, and verification pipelines for Godot AI Core (Godot AI Sidebar).

---

## 🎯 1. Project Purpose & Target
* **Target Engine:** Godot Engine 4.7+ (GDScript 2.0).
* **Mission:** Embedded Godot editor assistant with complete Undo/Redo (Ctrl+Z) safety, live SSE streaming, and autonomous tool workflows.

---

## 🧭 2. Radical Truth & Epistemic Rules
1. **No Evidence, No Claim:** Real behavior must be proven with concrete runs.
2. **Mock vs. Real Network:** In-memory mocks prove internal logic only. Real 9Router / LLM network behavior is proven solely by `tests/integration/test_real_9router_live.gd`.
3. **Admit Errors:** Report true root causes immediately rather than defending initial assumptions.

---

## 🏛️ 3. Architectural Rules & Invariants
1. **Clean Architecture & Strict SRP:**
   - Presentation (`ui/`) never talks directly to network or providers.
   - UI nodes have zero HTTP logic.
2. **Engine Safety & Centralized Undo/Redo:**
   - All scene and node mutations must go through `AISidebarMutationService` with `EditorUndoRedoManager` (`add_do_reference` mandatory).
3. **Headless CLI Preload Rule:**
   - In headless CLI, global `class_name` index is not auto-loaded; connect scripts with `const MyClass = preload("res://...")`.
4. **Surgical Editing:**
   - Use surgical edits (`replace_file_content`) validated with `VerificationPipeline`.
5. **External Agent Bridge (`core/bridge/`):**
   - Runs on `127.0.0.1` with token.
   - File-first generation: external agents produce files on disk, then call `sync_project`. Bridge scene tools are only for open-scene surgery.
6. **UI Text via i18n:**
   - All user-facing text uses `AISidebarI18n.get_text("key")` with dual `tr.json` / `en.json` keys.
7. **Context Compaction:**
   - Compact older tool outputs after 2 steps; preserve `activate_skill` instructions.

---

## 🧪 4. Verification & Testing
```powershell
# Typecheck + strict warning ratchet + unit tests:
powershell -ExecutionPolicy Bypass -File .\verify.ps1

# Editor integration (when editor/scene behaviors change):
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Editor

# Live provider / 9Router test:
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Live
```
