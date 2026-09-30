---
name: godot-blender-assets
description: Make 3D models, props, characters and animation in Blender (Blender Copilot) and bring them into the Godot project as .glb files. Use when a game needs a 3D asset that is more than a box or sphere (crate, tree, house, car, person, robot), when the user mentions Blender, or when blender_call is available.
---

# 3D assets from Blender

If `blender_tools` and `blender_call` are not in your tool list, the Blender bridge is off: tell the user it can be turned on in Settings > Blender, and continue with primitives (BoxMesh, CylinderMesh) meanwhile. Do not pretend a model exists.

## Process

1. `blender_tools` once: it lists Blender's tools in one line each. Read the schema of a tool (`blender_tools` with `name`) before its first use.
2. **Start with `create_prop`**: one call builds a proportioned, coloured crate, barrel, tree, rock, house, tower, fence, lamp, tent, well, car, chest, table, chair, campfire, or a rig-ready `humanoid` / `robot`. Prefer it over building shapes from parts. Use `create_primitive`, `create_mesh`, `mesh_edit` only for shapes it cannot make.
3. Colour with `set_material` (`base_color`, `roughness`, `metallic`) per part before `join_objects`. Presets (wood, brick ...) are shader nodes that glTF cannot carry: after `join_objects` call `bake_material` on the object (it paints the look into an image the `.glb` keeps), or use flat colours.
4. Characters: `rig_character`, then `animate_character` (walk, run, idle ...). Export with `animations: true`.
5. Call `check_model` on the model and fix its FAIL findings, then `export_gltf` with a plain `filename` such as `crate.glb` and `object_names`. The result of `blender_call` contains `godot_path` (under `res://assets/blender/`): the file is already copied and imported.
6. Use the model: write it into a `.tscn` as `[ext_resource type="PackedScene" path="res://assets/blender/crate.glb" id="1"]` and instance it (`[node name="Crate" parent="." instance=ExtResource("1")]`), then `sync_project`-style verification as usual (`validate_project`, `play_game`, screenshot). 1 unit is 1 meter, Y is up. Add collision yourself (a `StaticBody3D` with a shape sized to the model).

## Rules

- Keep props under about 3000 triangles. The export result reports the count.
- One Blender step failing is normal: read the error, fix the arguments, call again. Do not switch to guessing shapes in GDScript after the first error.
- If `blender_call` says Blender is unreachable, tell the user to open Blender and start the bridge; do not retry in a loop.
- The Blender bridge only runs on the user's computer; never put its token in files or chat.
