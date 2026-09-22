---
name: Bug report
about: Something is broken in Godot AI Sidebar
title: "[Bug] "
labels: bug
assignees: ''
---

<!--
Please fill this out as completely as you can. "It doesn't work" is very hard to
act on; the fields below are what actually makes a bug reproducible.
-->

## What happened?

<!-- A clear description of what went wrong. -->

## What did you expect to happen?

## Steps to reproduce

1.
2.
3.

## Which part of the plugin is involved?

- [ ] Sidebar UI / chat panel
- [ ] Agent loop (tools, planning, verification)
- [ ] Provider / network (9Router, OpenAI-compatible, AGY CLI)
- [ ] Scene or script editing
- [ ] Undo / redo
- [ ] Runtime inspection / debugger bridge
- [ ] Settings / persistence
- [ ] Other:

## Environment

| | |
| :--- | :--- |
| **Plugin version** | <!-- e.g. 2.7.0 (see addons/godot_sidebar_ai/plugin.cfg) --> |
| **Godot version** | <!-- e.g. 4.7.2-stable --> |
| **OS** | <!-- e.g. Windows 11 24H2 --> |
| **Provider type** | <!-- openai_compatible (9Router / OpenRouter / Ollama / LM Studio) or antigravity_cli --> |
| **Model** | <!-- e.g. gemini-3.8-flash-low, "a" alias, ... --> |
| **Auto-approve mode** | <!-- MANUAL / AUTO / FULL_AUTO --> |

## Does it reproduce in a fresh project?

- [ ] Yes, I reproduced it in a brand new empty Godot project with only this plugin installed
- [ ] No, it only happens in my existing project
- [ ] I have not tried

<!-- This one matters a lot. Many issues come from a stale copy of the addon
     or from a leftover config.json. Please try if you can. -->

## Console output / logs

<!--
Godot's Output panel usually has the useful detail. Plugin log lines are
prefixed with "[Godot AI Core]" or "[TIMING]".
Paste the relevant section between the fences below.
-->

```text

```

## Anything else?

<!-- Screenshots, screen recordings, or what you already tried. -->
