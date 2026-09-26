---
name: godot-headless-ci
description: Prepare and verify Godot projects with headless editor imports, script and scene compilation, test runners, or CI workflows. Use when a user asks about CI, headless Godot execution, command-line failures, or repeatable engine validation; do not use for runtime visual acceptance alone.
---

# Godot headless and CI verification

Use the target project's own commands and `AGENTS.md` as the authority. A generic command is not proof that a project has the required headless workflow.

## Workflow

1. Read the root `AGENTS.md`, development guide, and CI workflow. Identify the project's exact Godot version, executable discovery, import/cache preparation, test entry points, strict warning policy, and expected success markers.
2. Inspect tool schemas before making editor/MCP calls. `validate_script` may only check in-memory compilation in the current editor context; it does not prove dependency resolution from a clean cache, script execution, or runtime behavior.
3. For a fresh project cache or class registry, run the project's documented headless editor import first (commonly `godot --headless --editor --quit --path .`). Check its exit code and enforce a timeout. Godot also offers `--import` for editor import followed by exit. Then run the project's documented script/test command (commonly `godot --headless --path . -s res://tests/test_runner.gd`). Check both its exit code and its documented success marker; an exit code alone may be insufficient.
4. Use the repository's verification wrapper when available. Preserve its strict warning ratchet and fail-closed behavior; never make a failing check green by raising its warning baseline.
5. If CI is requested, mirror the supported local verification command, Godot version, cache preparation, timeout, and exit/success checks. Keep live network tests separate and secret-free unless the repository documents a secure integration-test setup.
6. For a custom script runner, require a completion marker emitted only after all checks finish; fail on a nonzero exit, a missing marker, a failed assertion, or an unhandled script error. A final `OK` line does not prove earlier checks ran to completion. Some test suites deliberately load invalid scripts to test diagnostics, so classify expected errors by their test and do not blindly reject every engine `ERROR:` line.
7. If PowerShell shows no output, first confirm whether the process ran and exited, which Godot executable is being used, and whether output was redirected to a Godot log file. On Windows, prefer the console Godot executable for terminal runs when both GUI and console builds are installed. Godot's `--log-file <absolute-path>` moves engine output/error logging to that file, so inspect it as well as capturing the process exit code. Test the shell's native stream capture in the current PowerShell version; `cmd /c` is a possible fallback, not a universal fix. Never infer a hang from an empty capture alone.
8. Distinguish compilation evidence, unit-test evidence, editor/runtime evidence, and real network evidence. Report each result with the command and observed outcome; mark unavailable checks as unverified.
