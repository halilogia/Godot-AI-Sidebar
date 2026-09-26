# Godot AI Sidebar — User Guide

[Türkçe](USER_GUIDE.md)

Godot AI Sidebar is an AI agent inside the Godot editor. It reads your request, carries it out with file and scene tools, then runs the game and checks the result. Every change it makes goes into the editor's undo history.

A short version of this guide is built into the plugin: the **Help** (?) button in the panel header. Its command list is generated from the plugin itself, so it is always current.

## Contents

1. [Installation](#1-installation)
2. [Where the AI comes from (provider)](#2-where-the-ai-comes-from-provider)
3. [The panel](#3-the-panel)
4. [First task and cards](#4-first-task-and-cards)
5. [Approval modes and safety](#5-approval-modes-and-safety)
6. [Slash commands](#6-slash-commands)
7. [@ mentions](#7--mentions)
8. [Keyboard](#8-keyboard)
9. [Goal mode (/goal)](#9-goal-mode-goal)
10. [Rules](#10-rules)
11. [Skills](#11-skills)
12. [External agent bridge (MCP) and Claude Code](#12-external-agent-bridge-mcp-and-claude-code)
13. [Settings](#13-settings)
14. [Troubleshooting](#14-troubleshooting)

## 1. Installation

1. Download the archive from [Releases](https://github.com/halilogia/Godot-AI-Sidebar/releases) or clone the repository.
2. Copy the `addons/godot_sidebar_ai/` folder into your game project's `addons/` folder.
3. In Godot, enable **Godot AI Sidebar** under **Project → Project Settings → Plugins**. The panel opens on the right.

Requires Godot 4.7 or later.

## 2. Where the AI comes from (provider)

Settings (the gear in the panel's top bar) → **Provider**:

| | Antigravity CLI | OpenAI-compatible |
|---|---|---|
| How it works | Uses the `agy` command on your machine | Connects to an HTTP endpoint |
| Needs | `agy` installed and signed in | Base URL, an API key if required |
| Examples | Google Antigravity | 9Router, OpenRouter, Ollama, LM Studio |
| Images (screenshots) | No | Yes, if the model supports them |

- **Advanced:** stream responses (turn off if your endpoint does not support it) and image support (set it by hand if the automatic guess is wrong).
- Pick the model from the list in the top bar; the refresh button fetches the list from the provider again.
- Settings are stored in `addons/godot_sidebar_ai/config.json`. The file is personal; do not commit it.

## 3. The panel

**Header:** status badge (Ready, Thinking, Waiting for approval …), **+ New** (new chat), **Skills** (skill management), **Help**, **History** (earlier chats), **Export** (save the chat to a file), **Copy** (copy the whole chat transcript).

**Top bar:** model, approval mode button (Manual / Auto / Full Auto), refresh the model list, Settings.

**Bottom:** the message box, **Clear** and **Send** (it becomes **Stop** while the agent runs). With an active goal, the goal strip sits above the box; queued requests appear there too.

## 4. First task and cards

Type what you want in plain language and press Enter, e.g. *"Add a double jump to the player"*. While the agent works you may see these cards:

- **Clarification:** if the request can mean more than one thing, the agent asks before starting; click an option or type your own answer.
- **Implementation plan:** for bigger work it proposes a plan first; **Apply Plan** or **Cancel**.
- **Approval required:** a risky action (delete, overwrite an existing file …) waits for you. **View Diff** shows the change line by line.
- **Changes:** changed files and line counts, with **View Diff** and **Undo**.
- **Activity:** the agent's steps and how long they took. "Technical details" shows tool arguments.
- **Testing (runtime):** runtime errors and observations when the game was run.
- **Summary:** when a task ends, time, steps and tool counts; **Copy** copies that task.
- **Error:** what went wrong, with **Retry**.

To resume a task you stopped, type just **continue** (or *devam*).

Messages you type while the agent runs are **queued** and start in order when the task ends; cancel a queued request with ×.

## 5. Approval modes and safety

| Mode | Behavior |
|---|---|
| Manual | Every risky action asks for approval. |
| Auto | Safe code / file writes run on their own; deletes ask. |
| Full Auto | All tools are approved automatically; protected paths stay protected. |

Choose the mode with the button in the top bar or in **Settings → General → Tool approvals**, which also has "ask before deleting" and "ask before overwriting an existing file".

- **Undo:** scene and node changes go into the editor's undo history; press **Ctrl+Z**. **Undo** on the Changes card reverts file changes.
- **Protected paths:** in every mode the agent cannot touch `project.godot`, `.git/` or the plugin's own folder.

## 6. Slash commands

Type `/` in the box to open the list; move with ↑ ↓ and complete with Enter or Tab. Commands are only shortcuts; every feature is also reachable from the interface.

| Command | What it does |
|---|---|
| `/help` | Shows the commands, what they do and how to use them. |
| `/clear` | Clears the chat (same as the Clear button). |
| `/analyze [topic]` | Analyzes the project or scene; changes no files. |
| `/inspect [node or res:// path]` | Inspects the active scene, the node tree or the given target. |
| `/test [scope]` | Runs the relevant tests and code checks and interprets the result. |
| `/run` | Runs the game and reports runtime errors and state. |
| `/debug [error description]` | Analyzes editor and runtime logs, errors and the stack trace. |
| `/fix [problem]` | Tries to fix the last error found, safely. |
| `/review` | Reviews the latest changes against safety and quality criteria. |
| `/explain <file \| node \| last>` | Explains a file, a node or the latest changes. |
| `/skill [name] [request]` | Lists skills, or starts the task with the chosen skill. |
| `/learn [--global] [rule]` | Saves a permanent rule (asks first). See [Rules](#10-rules). |
| `/mcp [on \| off]` | Turns the external agent bridge on / off. See [MCP](#12-external-agent-bridge-mcp-and-claude-code). |
| `/goal [goal \| stop]` | Goal mode. See [Goal mode](#9-goal-mode-goal). |

## 7. @ mentions

Type `@` in the box to open the list. What you mention is added to that request's context.

| Syntax | Meaning |
|---|---|
| `@res://player/player.gd` or `@player.gd` | Adds the file's content to the request. |
| `@Node:Player` | Adds a node from the open scene to the request. |
| `@rules` | Makes the loaded rules apply strictly to this request. |
| `@skill:name` | Does this request with that skill's instructions. |

## 8. Keyboard

| Key | Action |
|---|---|
| Enter | Send (queued if the agent is running). |
| Shift+Enter | New line. |
| Ctrl+V | Attaches the image on the clipboard (sent if the model supports images). |
| `/` or `@` | Opens the command / mention list; ↑ ↓, Enter or Tab. |
| Ctrl+Z | Reverts the agent's last change in the editor. |

## 9. Goal mode (/goal)

Instead of asking for a big or multi-step job in one go, give a **goal**:

```text
/goal The player can double jump and the HUD shows the jump count
```

- The agent works on the goal **round by round**. Each round uses its own step limit, like a normal task.
- At the end of each round it reports: **achieved** (with evidence: validated scripts, the game running without errors, a screenshot …), **in progress** (with the next step) or **blocked** (with what it needs from you).
- "Achieved" without evidence is not accepted; the agent gathers evidence in the next round.
- When the goal is met, the agent is blocked, or the round limit is reached, the result is written to the chat.
- The **goal strip** above the box shows the goal and the round counter; **Stop** ends the goal and stops the running round.
- `/goal` shows the status, `/goal stop` stops it. Round limit: **Settings → Model & Parameters → Goal mode** (default 10).

## 10. Rules

Rules are short instructions the agent follows on every turn. There are three layers:

1. **Built-in rules (system prompt):** the plugin's own working method. Edit it in **Settings → Rules**; the badge shows "Current default" or "Customized". After a plugin update, press **Restore default** to get the new default.
2. **Global rules:** `~/.agents/AGENTS.md` and `~/.agents/rules/*.md`. They apply to all your projects.
3. **Project rules:** `AGENTS.md`, `GEMINI.md`, `.agents/AGENTS.md`, `.agents/rules/*.md` in your game project. They travel with the repository, and other agents (Codex, Antigravity, Cursor …) read the same files.

Global and project rules are added on top of the built-in rules and win on conflict.

- **Add a rule:** type one sentence in Settings → Rules and press **Add rule**, or in the chat `/learn keep all enemy data in data/enemies.json`. `/learn` alone proposes rules from the corrections in this chat; `--global` writes to all projects. It asks before saving.
- **Stress the rules:** add `@rules` to a message.
- **Open a rule file:** Settings → Rules → **Show in folder**.
- The same page has a **token usage** bar showing how much the rules, skills and tools add to the model's context on every turn.

## 11. Skills

A skill is a reusable instruction package (the [Agent Skills](https://agentskills.io) standard, `SKILL.md`). The agent sees the name and description of enabled skills and loads one itself when the task fits.

| Source | Location | Default |
|---|---|---|
| Project | `.agents/skills/`, `.claude/skills/` in the game project | Off (it comes from the repository, so you turn it on) |
| User | `~/.agents/skills/` | On |
| Built-in | ships with the plugin (Godot feature development, scenes, debugging, runtime verification, refactoring, headless CI) | On |

- **Manage:** Settings → **Skills** or the **Skills** button in the header: enable / disable, open SKILL.md, create a new skill skeleton, import from another folder, delete (built-ins cannot be deleted).
- **Use by hand:** `/skill name request` or `@skill:name` in a message.

## 12. External agent bridge (MCP) and Claude Code

Agents such as Claude Code, Cursor or Codex can use this editor over MCP: read the scene, validate scripts, have the editor rescan files they wrote (`sync_project`), run the game, read runtime errors and screenshots, and make small changes in the open scene that Ctrl+Z can undo.

1. **Settings → External Agent (MCP)** → **Turn on** (or `/mcp on` in the chat). The bridge only runs on this machine (`127.0.0.1`) and requires a secret token.
2. Press **Copy Claude Code connect command** and paste it into a terminal in your game project's folder. The token is masked in the interface and complete in the copied command.
3. Start `claude` in that folder and ask it to work on the game.

The port can be changed on the same page. To close the bridge: **Turn off** or `/mcp off`.

## 13. Settings

| Page | Contents |
|---|---|
| Provider | Provider, endpoint (Base URL, API key), streaming, image support |
| Model & Parameters | Temperature, maximum agent steps, goal mode round limit |
| General | Interface language, interface animations, approval mode, delete / overwrite approvals |
| Rules | Token usage, built-in rules (system prompt), global and project rules, add a rule |
| Skills | Skill list and management |
| External Agent (MCP) | Turn the bridge on / off, port, connection command |

**Save & Close** writes the changes. Skill toggles, adding rules and the bridge controls apply immediately with their own buttons.

## 14. Troubleshooting

- **Empty model list / cannot connect:** check the Base URL in Settings → Provider (e.g. `http://127.0.0.1:20128/v1`), then press refresh in the top bar.
- **"AGY preparing" takes long:** the Antigravity CLI prepares its session on first start; check that `agy` works in a terminal and that you are signed in.
- **Screenshots are not sent to the model:** the selected model may not support images; Settings → Provider → Advanced → Image support.
- **The MCP bridge does not start:** another program may be using the port; pick another one in Settings → External Agent.
- **The agent loops on the same error:** stop it, narrow the request, or add the relevant file with `@res://...`. If it is a lasting preference, make it a rule with `/learn`.
- **Reporting a bug:** save the chat with **Export** and attach it to an [issue](https://github.com/halilogia/Godot-AI-Sidebar/issues).
