# Godot Asset Library — Submission Checklist

This file prepares the Asset Library submission. It is **internal preparation**,
not a published document. Submitting requires logging into the Asset Library web
form with your own account, so the final click has to be yours.

---

## ⚠️ Read this before submitting

> **The GPL-3.0 question is unresolved.**
>
> Godot's Asset Library is a distribution channel with its own terms, and it is
> a known grey area whether GPL-licensed editor plugins can be distributed
> through it, and under which obligations. I could not find an authoritative
> ruling on this during research, so **I am not claiming this plugin is
> eligible.** Verify this yourself, or get advice, before submitting. If
> eligibility is a problem, the plugin can still be distributed via GitHub
> Releases, which is already done.

> **Version note.** The submission must point at a version whose contents
> actually match the tag. Earlier, the `v1.0.0` release archive contained plugin
> code labelled `2.0.0` and was missing 15 source files. Verify the archive
> before submitting — see "Verify the archive" below.

---

## What the Asset Library requires

| Requirement | Status |
| :--- | :--- |
| Files under `addons/<name>/` | ✅ `addons/godot_sidebar_ai/` |
| `plugin.cfg` present | ✅ |
| `LICENSE` (or `LICENSE.md`) at repo root | ✅ GPL-3.0 |
| Copyright statement with year **and** holder inside the license file | ✅ `Copyright (C) 2026 Halil Emre` |
| Archive must not contain `.git`, OS junk, `__MACOSX` | ✅ handled by `.gitattributes` |
| English name and description | ✅ see below |
| Direct (raw) icon URL, not a page URL | ✅ see below |
| No essential git submodules | ✅ none used |

---

## Copy-paste submission fields

**Category:**

```text
Tools
```

**Godot version:**

```text
4.7
```

**Version string:**

```text
2.7.0
```

**Repository host / URL:**

```text
GitHub
https://github.com/halilogia/Godot-AI-Sidebar
```

**Name:**

```text
Godot AI Sidebar
```

**Description** (plain text, no markup — the form does not render Markdown):

```text
An AI game-development agent that runs inside the Godot 4 editor dock.

Unlike a chat window that sits next to your project, it reads your open scene,
selected node and active script automatically. It asks a clarifying question
when a request is genuinely ambiguous instead of guessing, edits scripts
surgically with a line-level diff, and validates GDScript before writing it to
disk. Every scene and node change goes through Godot's own EditorUndoRedoManager,
so Ctrl+Z behaves exactly as it does for manual edits.

It can also inspect the game while it is running: a debugger bridge exposes the
live scene tree, node values and runtime errors to the agent, and maps stack
traces back to real project files. This makes questions like "why is the player
not moving" answerable rather than guesswork.

Supports OpenAI-compatible backends (9Router, OpenRouter, Ollama, LM Studio) and
the official Antigravity CLI. Includes a path policy that protects project.godot,
export settings and .git, plus three approval modes from fully manual to fully
autonomous.

Requires Godot 4.7 or newer. GDScript projects only. Vision input requires an
OpenAI-compatible provider; the Antigravity CLI backend does not accept images.
```

**Icon URL** (must be a direct link, and `main` must contain this file):

```text
https://raw.githubusercontent.com/halilogia/Godot-AI-Sidebar/main/icon.svg
```

> [!NOTE]
> Asset Library previews render icons as raster images. If `icon.svg` does not
> display correctly, generate a 128x128 PNG at `icon.png` and use that URL
> instead. Verify by opening the URL in a private browser window before
> submitting — a 404 here silently produces an icon-less listing.

**License:**

```text
GPLv3
```

**Issues / support URL:**

```text
https://github.com/halilogia/Godot-AI-Sidebar/issues
```

---

## Verify the archive before submitting

The Asset Library downloads the archive generated for the tag. Run these checks
first, because a broken archive means users install a broken plugin and the
listing gets bad reviews it cannot recover from.

```powershell
# 1. Download the release archive for the version you are submitting, then:

# Confirm the version inside the archive matches the tag
#   addons/godot_sidebar_ai/plugin.cfg  ->  version="2.7.0"

# Confirm the archive actually contains the newer source files.
# All of these must be present:
#   core/providers/agy_cli_provider.gd
#   core/runtime/runtime_bridge.gd
#   core/runtime/debugger_plugin.gd
#   core/agent/context_compactor.gd
#   core/chat/mention_manager.gd
#   ui/components/clarification_card.gd
#   ui/theme/sidebar_theme.gd

# 2. Point Godot at the extracted folder and confirm the plugin loads:
#    Project -> Project Settings -> Plugins -> Enable "Godot AI Sidebar"
#    The Output panel must print: [Godot AI Core] Eklenti başarıyla yüklendi
```

A useful automated cross-check: count the `.gd` files in the archive and compare
against the repository. The current source has **56 `.gd` files** inside
`addons/godot_sidebar_ai/` (105 files total including assets).

---

## Submission steps

1. Log in at <https://godotengine.org/asset-library/asset>.
2. Choose **Submit Asset**.
3. Fill the fields from the section above.
4. Set asset type to **Addon**.
5. Submit and wait for review. Reviews are done by volunteers and can take days
   to weeks; there is no SLA.
6. Note the resulting asset ID and URL, then add a badge to `README.md`.

---

## After it is listed

Once approved, add this to the top of `README.md`, right below the badges:

```markdown
[![Godot Asset Library](https://img.shields.io/badge/Godot%20Asset%20Library-listed-478cbf)](ASSET_LIBRARY_URL)
```

This matters more than it looks: Godot's built-in **AssetLib tab inside the
editor** is a discovery channel that has nothing to do with GitHub search. Most
Godot users find plugins there rather than on GitHub. It is the single
highest-leverage distribution step available for this project.
