# Benchmark prompt (give this to Claude Code as a single message)

Build a small grand-strategy vertical slice in this Godot 4 project, in the spirit of Europa Universalis / Hearts of Iron, using the godot MCP tools and the Godot skills. Work autonomously through bootstrap and milestones; ask me only when the skills tell you to stop.

Required:

1. **Map:** at least 30 provinces generated from a data file (JSON or `.tres`) by a script, not placed by hand. Each province has an id, name, owner, neighbors and a base income. The map is drawn as colored polygons (or tiles) by owner.
2. **Countries:** 3 countries with a name, color, treasury and capital province.
3. **Selection:** clicking a province shows an info panel (name, owner, income, garrison).
4. **Time:** a date that advances by days, with pause and at least two speeds (keys or buttons). Date shown in a top bar.
5. **Economy:** on the first day of each month every country gains the income of its provinces; treasuries shown in the top bar.
6. **War:** countries can be at war. An army moves between neighboring provinces over several days; entering an enemy province occupies it after a few days, and occupation changes its map color.
7. **Autoplay:** AI countries act on their own: after 30 in-game days one AI country declares war on another and sends an army, so war and occupation happen without player input. An autoplay switch (a constant or a project setting, on by default for this benchmark; `play_game` cannot pass command-line arguments) starts the game at the fastest speed, so the result is visible within one minute of play.

Keep the project memory documents up to date. Finish by verifying each acceptance criterion in `ACCEPTANCE.md` (copy it into the project) with evidence and reporting the result table.
