# First person 3D (FPS, walk-and-collect, shooter)

A first person game looks unfinished for three reasons: an empty world (a floor and a few boxes), flat washed-out light, and a first-person model that is too big or too plain. Fix the world first, then light, then the weapon, then the HUD.

## 1. A world with places in it (procedural, seeded)

Build the level in code from a few builder functions and a seeded `RandomNumberGenerator` (`rng.seed = 1944`) so it is the same every run:

- **Ground:** one big `StaticBody3D` box (collision layer 1) with a muted colour; add a **road strip** (`PlaneMesh` 6-8 m wide, slightly darker, `y = 0.02`) so the eye has a line to follow.
- **Ruined buildings (12-16):** four walls of `BoxMesh` per building, a door gap in the front wall (two side pieces plus a lintel), one wall broken down to half height, two tones (brick `Color(0.5, 0.36, 0.3)`, plaster `Color(0.62, 0.58, 0.5)`). Skip positions near the player start.
- **Cover (40+):** crates 1.2 m, sandbag walls (3-6 m x 1.1 m x 0.8 m, random yaw), placed with `rng`.
- **Trees (50+):** cylinder trunk + a sphere crown in dark green; static collision on the trunk only.
- **Boundary walls** 6 m high around the map so nobody falls off.
- Every mesh instance that must block the player or bullets needs a collision shape on **layer 1**; the player is layer 2, enemies layer 4, and enemy line-of-sight rays use mask `1 | 2`.

### Props from Blender (when a `blender` MCP server is connected)

Replace the box crates, cylinder trees and box soldiers with modeled `.glb` files (crate ~200 triangles, barrel ~560, tree ~360, sandbag row ~360, rifle ~180, soldier ~190). In a real comparison this changed the screenshot from "boxes on a plane" to a recognizable battlefield. Rules: export with the tool's default `recenter` (else the model shows up metres away from its collision body), wrap each model in a `StaticBody3D` with a `BoxShape3D` from the merged `MeshInstance3D` AABB (trees: a thin trunk box only), keep the primitive as a fallback when `load()` returns null, and check `inspect_runtime_node` for a large local offset on the model node.

## 2. Light and atmosphere (this is what lifts the look most)

```gdscript
var env := Environment.new()
var sky := ProceduralSkyMaterial.new()
sky.sky_top_color = Color(0.36, 0.44, 0.52)
sky.sky_horizon_color = Color(0.72, 0.68, 0.6)
sky.ground_horizon_color = Color(0.5, 0.46, 0.4)
var sky_res := Sky.new(); sky_res.sky_material = sky
env.background_mode = Environment.BG_SKY
env.sky = sky_res
env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
env.fog_enabled = true
env.fog_density = 0.003          # 0.006 already looks washed out; keep the horizon readable
env.adjustment_enabled = true
env.adjustment_contrast = 1.08
env.adjustment_saturation = 0.9
```
- One `DirectionalLight3D`, warm (`Color(1.0, 0.92, 0.78)`), pitched -35 to -45 degrees, `shadow_enabled = true`, `directional_shadow_max_distance = 90`.
- Palette rule for a war / gritty theme: desaturated earth tones, ONE accent (muzzle flash, red danger, HUD teal). If the screenshot looks grey and flat, lower fog and raise the sun energy before adding anything else.
- A dark empty sky is a fail: always a gradient sky with a lighter horizon.

## 3. The weapon in your hands (viewmodel)

- Parent it to the `Camera3D`, so it moves with the view. `near = 0.03` on the camera.
- **Size check on the screenshot:** the weapon should cover at most about a quarter of the screen's height and a third of its width. A rifle is about 0.7 m long, a pistol 0.25 m. If it fills half the screen it is too big: shrink the meshes, move it back (`z -0.45`) and towards the edge (`x 0.16, y -0.18`).
- Build it from 4-6 boxes (barrel darker, body, grip angled 0.3 rad, stock in wood brown). Hands: small dark-skin-tone spheres or boxes at the grip and fore-end, no bigger than 0.05 m; pale pink balls read as a bug.
- Aim down sights: lerp the viewmodel to `(0, -0.155, -0.42)` and the FOV from ~78 to ~52; reduce sensitivity while aiming.
- Feel: recoil kick on the head pitch, viewmodel kicks back 0.05 m and returns, muzzle light (`OmniLight3D`, energy 6 for 0.05 s), reload dips the weapon down with a `sin(t * PI)` curve.
- Head bob: `sin(t * 2) * 0.03` on Y and `cos(t) * 0.02` on X, only while walking on the floor, half strength while aiming.

## 4. Enemies that look like people

- 8 boxes: torso, head + a helmet sphere, two legs, two arms, a gun. Cloth colour `Color(0.34, 0.36, 0.28)`, darker legs. Walk cycle: legs and arms swing with `sin(phase)`; hit flash by tinting the torso material red for 80 ms; death rotates the body to lie down, then fades.
- Enemies see the player only when a ray from the eye to the player's chest hits the player first (walls block it).

## 5. HUD (semi-transparent, corner-anchored)

- Build the numbers and captions as `Label` nodes on a `CanvasLayer` (outlined), and draw only bars, compass ticks and the crosshair with `_draw()`; then `audit_runtime_ui` can check them.

- Top centre: a compass strip (ticks every 5 degrees, letters N NE E SE S SW W NW, a red marker in the middle).
- Bottom left: health number + thin bar, stamina thin bar. Bottom right: big ammo number, small `/ reserve`, weapon name; the number turns red at low ammo.
- Crosshair: four short lines with a gap that widens on hit and while moving. Damage: red screen tint that fades in 0.6 s.
- **Order of initialization bug (seen in a real run):** the player emitted its first ammo / health values in `_ready` before the HUD was connected, so the HUD showed `0 / 0`. Connect the HUD to the player's signals first, then call the player's `_emit_all()`; or have the HUD read the current values right after `bind()`.

## 6. Checks on the runtime screenshot

- [ ] The sky is not empty and dark; there is a visible horizon and depth (buildings, trees, road) at three distances.
- [ ] The weapon is well below a third of the screen and its hands are not huge.
- [ ] HUD numbers show real values (not `0 / 0`), text is readable on the sky and on the ground.
- [ ] Health does not drop in the first 5 seconds (spawn enemies at least 18 m from the player).
- [ ] `get_runtime_errors` clean after playing 10 seconds while moving, jumping and shooting.
