---
name: godot-scene-authoring
description: Create or restructure Godot 4 scenes (.tscn), resources (.tres) and large or repetitive content (levels, maps, UI) for a project connected through the Godot AI Sidebar tools. Use when a task needs new scenes, many nodes, instanced scenes or generated content.
---

# Godot scene authoring

## Choose the method

| Situation | Method |
|---|---|
| New scene, or many nodes at once | Write the whole `.tscn` file |
| Hundreds of similar objects (provinces, tiles, units) | Data file (JSON/CSV/`.tres`) + a script that builds nodes at runtime (or a `@tool` generator) |
| One node or property in the scene open in the editor | Bridge scene tools (`add_node`, `set_node_property`, …) |
| Put an existing scene inside the open scene | `instantiate_scene` (its `scene_path` is the scene to insert; `expected_scene_path` is the open scene) |

Repetitive content belongs in data plus code, not in hundreds of `add_node` calls or thousands of hand-written `.tscn` lines.

## Writing a .tscn (Godot 4, format=3)

Order: header, `ext_resource`s, `sub_resource`s, nodes (parents before children), `connection`s.

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/player.gd" id="1_player"]
[ext_resource type="PackedScene" path="res://scenes/enemy.tscn" id="2_enemy"]

[sub_resource type="BoxMesh" id="BoxMesh_body"]

[node name="Main" type="Node3D"]

[node name="Player" type="CharacterBody3D" parent="."]
script = ExtResource("1_player")

[node name="Body" type="MeshInstance3D" parent="Player"]
mesh = SubResource("BoxMesh_body")

[node name="Enemy" parent="." instance=ExtResource("2_enemy")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4, 0, 0)

[connection signal="body_entered" from="Player/Area" to="Player" method="_on_area_body_entered"]
```

- The root node has no `parent`; direct children use `parent="."`; deeper nodes use the path from the root (`parent="Player"`).
- Resource ids only need to be unique inside the file. Leave out `uid=` values you cannot compute; Godot fills them in.
- Use the property names the Inspector shows (`position`, `transform`, `mesh`, `script`, `text`). Check an unfamiliar one with `get_node_properties` on a similar node.

## After writing

1. `sync_project` with the written files in `changed_files`.
2. `open_scene` the scene, then `get_scene_tree` to confirm Godot parsed it (missing nodes mean a parent path or resource id is wrong).
3. `take_viewport_screenshot` to look at it in the editor, or run it (`play_game`) and use `take_runtime_screenshot`.
4. If the editor still shows an old version of a scene you wrote, it was not listed in `changed_files`; call `sync_project` again with it.

## Editing the open scene with tools

- Confirm the open scene with `get_scene_tree` (`scene_file`); if your agent's scene tools require `expected_scene_path` (see "Agent mapping"), pass that value on every call.
- Each call is one Ctrl+Z step for the user. Call `save_scene` when done, before you read the `.tscn` from disk or write it yourself.

## Agent mapping

The method above is the same for every agent; only access differs.

- **Claude Code (or another MCP client) over the bridge:** the tools are `mcp__godot__<tool>` (prefix = the registered server name). Edit project files with your own file tools, then call `sync_project` with the written files in `changed_files`. Scene tools need `expected_scene_path`; connecting needs `/mcp on` and the `claude mcp add ...` command it copies.
- **Godot AI Sidebar agent:** write files with `create_or_update_script`, `write_files`, `replace_file_content` or `create_scene` (they validate before writing; `create_or_update_script`, `write_files` and `replace_file_content` also reload an open scene they rewrite, so there is no `sync_project` step); scene tools run directly under the sidebar's approval mode.
