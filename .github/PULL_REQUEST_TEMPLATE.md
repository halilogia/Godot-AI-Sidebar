## What does this change?

<!-- A short description of the change and the problem it solves. -->

## Why is this the right approach?

<!--
If there were other ways to do it, briefly say why you picked this one. If the
change is obvious, delete this section.
-->

## Which area does this touch?

- [ ] Plugin core (`addons/godot_sidebar_ai/core/`)
- [ ] UI (`addons/godot_sidebar_ai/ui/`)
- [ ] Tests (`tests/`)
- [ ] Documentation only (no behavioural change)
- [ ] Build / tooling (`typecheck.ps1`, `tools/`)

## Checklist

- [ ] `powershell -ExecutionPolicy Bypass -File .\typecheck.ps1` passes
- [ ] `godot --headless --path . -s "res://tests/test_runner.gd"` passes with **0 failures**
- [ ] I added or updated tests covering this change
- [ ] I did **not** change the reported test/assertion counts in the docs by hand
      <!-- These are measurement outputs, not marketing numbers. Quote the real
           number the runner printed, or leave the existing number alone. -->

## Architecture rules

<!-- These are non-negotiable project rules; see AGENTS.md. -->

- [ ] The UI layer still does **not** talk to the network/providers directly
      (no `HTTPRequest` or socket handling inside `ui/`)
- [ ] All scene/node mutations still go through the central mutation service so
      they land in Godot's `EditorUndoRedoManager` (Ctrl+Z must keep working)
- [ ] New scripts that must run under `godot --headless` use
      `const X = preload("res://...")` instead of relying on the global
      `class_name` registry
- [ ] No API keys, tokens, or secrets are committed
      <!-- `addons/godot_sidebar_ai/config.json` and `.env` are gitignored.
           Do not un-ignore them, and do not paste a real key into a test,
           a doc, a comment, or a commit message. -->

## How was this verified?

<!--
Be specific and honest. "Tests pass" is good. "Tested manually in the editor,
and it works" is also fine *if* that is what you actually did - please say
which part you could not verify automatically.
-->

## Related issues

<!-- e.g. Closes #12 -->
