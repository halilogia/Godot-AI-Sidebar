---
name: godot-release-workflow
description: Close a milestone or cut a release of a Godot 4 game - update the project memory documents, verify the build, bump the version, export and tag. Use when the user asks to finish a milestone, prepare a release, export a build or wrap up a work session.
---

# Godot milestone and release workflow

## Closing a milestone

1. Verify every acceptance criterion of the milestone (godot-runtime-verification skill). Criteria that need a manual play test are listed for the user, not assumed.
2. Update the project memory:
   - `ROADMAP.md`: tick finished items; move unfinished ones to the next milestone with a reason.
   - `DECISIONS.md`: decisions made during the milestone, dated, with the reason.
   - `KNOWN_ISSUES.md`: open bugs with reproduction steps; remove fixed ones.
   - `ARCHITECTURE.md`: new or moved systems, scenes, autoloads.
3. Commit with a message that names the milestone.

## Releasing a build

1. Bump `config/version` under `[application]` in `project.godot` (editing it while the editor is open may not be kept; confirm or ask the user to set it in Project Settings).
2. Exports need an export preset (`export_presets.cfg`, created in the editor under Project → Export) and the matching export templates installed. If they are missing, tell the user; do not invent a preset.
3. Export from the terminal with the Godot binary: `godot --headless --path <project> --export-release "<preset name>" <output path>`. Check the exit code and that the output file exists.
4. Smoke-test what you can: the exported build starts (run it briefly from the terminal and read its output), and the editor run is clean (`play_game`, `get_runtime_errors`).
5. Tag the release in git (`vX.Y.Z`) and summarize the changes since the last tag from the commit log.

Export, git and packaging are terminal work; the Godot bridge has no export tool.
