---
description: Connect Claude Code to this Godot project's AI Sidebar MCP bridge (reads the port and token from the project's config).
---

Connect this Claude Code session to the Godot AI Sidebar MCP bridge of the current Godot project.

1. Find `addons/godot_sidebar_ai/config.json` in the current project (look in the working directory and its parents). If it does not exist, tell the user to open the project in Godot with the "Godot AI Sidebar" plugin enabled (Project Settings → Plugins) and stop.
2. Read `mcp_bridge_enabled`, `mcp_bridge_port` (default 6570) and `mcp_bridge_token` from it. If the bridge is not enabled or the token is empty, tell the user to type `/mcp on` in the sidebar chat (or Settings → External Agent (MCP) → Turn on) and run this command again; stop.
3. Register the server for this project only, exactly once:
   `claude mcp add --transport http --scope local godot http://127.0.0.1:<port>/mcp --header "Authorization: Bearer <token>"`
   If a server named `godot` already exists, run `claude mcp remove godot` first, then add it again.
4. Never print the full token in your reply (show only its first 6 characters).
5. Tell the user: the Godot editor must stay open, and Claude Code has to be restarted once so the `godot` tools load. After the restart, start with `analyze_project` and follow the `godot-runtime-verification` skill.
