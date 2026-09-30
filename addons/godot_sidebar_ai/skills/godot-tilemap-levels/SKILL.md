---
name: godot-tilemap-levels
description: Build 2D levels, maps and dungeons in Godot 4 with TileMapLayer - a TileSet drawn in code (no art files), walls with collision, procedural generation such as a random-walk cave or dungeon, spawning on valid cells, camera limits. Use when a game needs a grid map, a tile level or generated terrain.
---

# Godot 2D tile levels

Use a `TileMapLayer` node (one node per layer: ground, walls, decoration). The old `TileMap` node is deprecated. The level is built by a script at run time, so the whole map is a few lines and can be random, seeded and tweaked without touching a `.tscn` full of cells.

## 1. A TileSet with no art files

Draw flat-colour tiles into an `Image`, use it as an atlas, add a physics layer so wall tiles block bodies (verified in Godot 4.7):

```gdscript
const TILE := 16
const FLOOR := Vector2i(0, 0)
const WALL := Vector2i(1, 0)

func make_tileset() -> TileSet:
	var img := Image.create(TILE * 2, TILE, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, TILE, TILE), Color(0.25, 0.3, 0.35))            # floor
	img.fill_rect(Rect2i(TILE, 0, TILE, TILE), Color(0.6, 0.45, 0.3))          # wall
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(img)
	atlas.texture_region_size = Vector2i(TILE, TILE)
	atlas.create_tile(FLOOR)
	atlas.create_tile(WALL)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.add_source(atlas)                                                        # source id 0
	var data: TileData = atlas.get_tile_data(WALL, 0)
	var h := TILE / 2.0
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	return ts
```

Real art: put a spritesheet PNG in the project, create the `TileSetAtlasSource` with that texture and the tile size, and `create_tile` for each cell of the sheet. Build the TileSet in code at start-up instead of saving it with `ResourceSaver`: a saved scene embeds the drawn image as a huge base64 block. To keep it, save the image as a PNG (`img.save_png("res://tiles.png")`) and load that.

## 2. Fill and read cells

```gdscript
var layer := TileMapLayer.new()
layer.tile_set = make_tileset()
add_child(layer)
layer.set_cell(Vector2i(x, y), 0, WALL)            # (cell, source id, atlas coords)
layer.get_cell_atlas_coords(cell)                  # Vector2i(-1, -1) when empty
layer.erase_cell(cell)
layer.get_used_cells(); layer.get_used_rect()
layer.map_to_local(cell)                           # centre of a cell in layer pixels
layer.local_to_map(Vector2(40, 56))                # pixel to cell
```

## 3. Generated cave / dungeon: random walk (verified)

Fill the map with wall, then carve floor with a drunk walker; it always gives one connected area:

```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = 7                                        # same seed, same level
var size := Vector2i(40, 24)
for x in size.x:
	for y in size.y:
		layer.set_cell(Vector2i(x, y), 0, WALL)
var pos := size / 2
var carved := 0
var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
while carved < 300:
	if layer.get_cell_atlas_coords(pos) != FLOOR:
		layer.set_cell(pos, 0, FLOOR)
		carved += 1
	pos += dirs[rng.randi() % 4]
	pos = pos.clamp(Vector2i(1, 1), size - Vector2i(2, 2))
```

Rooms and corridors: pick rectangles with `rng`, carve them, connect centres of consecutive rooms with an L-shaped corridor. Keep the carved share around 30 to 45 percent of the map; fewer feels empty, more feels open.

## 4. Use the level

- Spawn the player and enemies on floor cells only: collect `var floors := layer.get_used_cells().filter(func(c): return layer.get_cell_atlas_coords(c) == FLOOR)`, pick one, place at `layer.map_to_local(cell) + layer.position`. Keep enemies a few cells from the player.
- Camera limits: `var r := layer.get_used_rect()`, `camera.limit_left = r.position.x * TILE`, `limit_right = r.end.x * TILE`, same for top and bottom.
- Collision: the physics layer above is layer 1. A `CharacterBody2D` with mask 1 is stopped by wall tiles. Use a cell size that matches the player (player about 0.8 of a cell).
- Pathfinding: `AStarGrid2D` over the same grid (`region`, `cell_size`, `set_point_solid` for wall cells) is enough for enemies; no navigation mesh needed.
- Terrains / autotiling (walls that pick corners by themselves) need a TileSet terrain setup with peering bits; skip it unless the art needs it, and then use `set_cells_terrain_connect`.
- 3D grid levels: `GridMap` with a `MeshLibrary`, same idea.

## 5. Verify

`validate_project`, `play_game`, `get_runtime_errors`, then `take_runtime_screenshot`: floor and wall colours must be visible and the player must stand on a floor cell, not inside a wall. Walk into a wall with `send_input`: the player must stop. If everything is one colour, the atlas coords are wrong; if the player falls through or walks through walls, the physics layer or the tile collision polygon is missing.
