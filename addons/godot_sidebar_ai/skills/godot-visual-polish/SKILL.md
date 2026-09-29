---
name: godot-visual-polish
description: Make a Godot 4 game look designed instead of like a prototype - screen composition, palette, readable text, custom UI theme, lighting, depth and hit feedback - and check it on a runtime screenshot. Use when creating a new game or scene, when the user asks for better graphics, visuals, UI or polish, and once at the end of every new-game build.
---

# Godot visual polish

Prototypes look "1980s" for the same few reasons: the play field is small in a big window, text is hard to read, the UI is the default grey theme, everything is one flat colour, and nothing reacts when you hit it. Fix those, in this order. You draw with code, so there is no artist: the look comes from **composition, contrast, layers and feedback**.

## Process (one pass, about 6 tool calls; gameplay comes first)

1. **Pick the art direction once**, before the first scene. Choose 5 colours (background, surface, primary, accent, danger) and one mood (e.g. warm dusk, neon night, pastel toy). Write them to `res://.agents/rules/art-direction.md` (a rule file: you see it in every later turn, so menus and HUD stay consistent). Keep it under 15 lines: palette hex codes, camera/field size, UI style (corner radius, font sizes), effect intensity.
2. **Build the game** with those colours as constants in one script (`Palette.gd` or a `const` block); never scatter literal colours.
3. **Polish pass** (after the game runs): go through the checklist below, `play_game`, `take_runtime_screenshot`, look at it, fix the worst 3 problems, screenshot again. Stop after two rounds; do not polish forever.
4. For details load only what you need with `activate_skill` (`file`):
   - `references/composition.md`: screen use, scale, depth layers, 2D lights, vignette
   - `references/ui-theme.md`: one Theme for the whole UI, readable text
   - `references/lighting-3d.md`: WorldEnvironment, sun, shadows, materials
   - `references/characters.md`: drawing people and creatures from primitives (read when the game has characters)
   - `references/juice.md`: hit flash, screen shake, particles, floating numbers
   - `references/genres/<genre>.md`: the detailed look recipe for YOUR genre (read exactly one; it lists layout numbers, layers, code, feedback and screenshot checks): `fps-3d`, `turn-based-rpg`, `grand-strategy`, `card-game`, `platformer`, `tower-defense`, `topdown-shooter`, `match3`, `endless-runner`, `racing`, `snake`. `references/genres.md` is the short index; for a genre not listed, use the closest one.

## Checklist (check each against the screenshot)

- [ ] The play field fills at least ~70% of the window's shorter side. No big empty margins. Design for 1280x720 with the stretch mode set to canvas items and the aspect set to expand.
- [ ] Nothing overlaps the play field: HUD bars and panels never cover part of it. In the screenshot, check the edges of the field explicitly: the first and last row/column of a board must be fully visible, and no unit or tile may sit under a panel. Compute the field position from the HUD height (field top = HUD bottom + margin), do not guess.
- [ ] Text has contrast 4.5:1 or has an outline; no dark text on a dark unit or tile. Font sizes: title 32+, HUD 20-24, body 16+.
- [ ] UI uses a custom Theme (rounded panels, styled buttons with hover/pressed states), not default grey Godot controls.
- [ ] Background is not one flat colour: a gradient, a second layer, or a pattern behind the field.
- [ ] Every gameplay object has a silhouette that reads at a glance (player, enemy, pickup, hazard use different shapes and colours).
- [ ] Objects sit in the world: a soft shadow or outline, not floating flat shapes.
- [ ] Important actions react: hit flash, small shake, particles, a number popping up.
- [ ] Palette stays within the 5 chosen colours plus tints/shades of them.

## Rules

- Do not spend the step budget on polish before the game works. A working plain game beats a beautiful broken one.
- No random colours; no pure white text on pure black; no more than ~2 fonts sizes per screen level.
- Effects stay subtle: shake under 8 px, flash under 150 ms, glow low. Never leave a loop of particles running forever on a static scene.
- Keep everything procedural (shapes, gradients, shaders, particles). Do not reference image files you have not created.
- **Real 3D models:** in a 3D game, primitive boxes and spheres cap the look. If a `blender` MCP server (Blender Copilot, `github.com/halilogia/Blender-Copilot`) is connected next to this one, model props there (crate, barrel, tree, rock, weapon, soldier; its `blender-game-assets` skill has tested recipes), export `.glb`, copy it under `res://assets/models/`, call `sync_project`, and instantiate it with a collision body (`blender-to-godot` skill). Always keep a primitive fallback if `load()` returns null.
