---
name: godot-2d-pixel-lighting
description: Pixel-art 2D with modern dynamic lighting in Godot 4.7 Forward+ - low-res HDR world viewport at an integer scale with smooth sub-pixel camera, glow bloom, normal-mapped sprites, sun and lamp lights, time-of-day, projected sun shadows, pixel wind, god rays, cloud shadows. Use when the user wants pixel art that is lit and atmospheric (day/night, golden hour, lanterns, shadows) instead of flat sprites.
---

# Godot 2D pixel-art with dynamic lighting

Recipe proven in a working prototype (Forward+, 640x360 world at 3x). Steps are in dependency order. Finish by looking at screenshots at several times of day (step 7).

## 1. Low-res HDR world viewport, integer scale, smooth camera

Render the world in a small `SubViewport`, show it with a nearest `TextureRect`. Full-res layers (god rays, vignette, HUD) sit on top.

```gdscript
world_vp = SubViewport.new()
world_vp.use_hdr_2d = true                       # values > 1.0 survive for glow
world_vp.snap_2d_transforms_to_pixel = true
world_vp.snap_2d_vertices_to_pixel = true
world_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
view = TextureRect.new()
view.texture = world_vp.get_texture()
view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
view.stretch_mode = TextureRect.STRETCH_SCALE
```

project.godot: `rendering/viewport/hdr_2d=true`, `2d/snap/snap_2d_transforms_to_pixel=true`, `2d/snap/snap_2d_vertices_to_pixel=true`, `textures/canvas_textures/default_texture_filter=0`, `window/stretch/mode="disabled"` (you do the scaling).

Integer scale; the viewport is 2 px larger than needed, so there is room for the shift:

```gdscript
pix_scale = maxi(1, int(floor(minf(win.x / BASE.x, win.y / BASE.y) + 0.001)))   # BASE = 640x360
var vp := Vector2i((win / pix_scale).ceil()) + Vector2i(2, 2)
world_vp.size = vp
view.size = Vector2(vp) * pix_scale
```

Smooth scrolling without breaking pixels: the camera sits on whole pixels, the upscaled image moves by the fractional remainder.

```gdscript
var snapped := cam_pos.floor()
camera.position = snapped
var frac := cam_pos - snapped
view.position = win * 0.5 - (Vector2(world_vp.size) * 0.5 + frac) * pix_scale
```

Clamp the cam_pos variable to `[half, world_size - half]` first, with `half = win / pix_scale * 0.5`.

## 2. Glow (bloom)

`WorldEnvironment` with `BG_CANVAS`. `Environment.background_canvas_max_layer` decides which CanvasLayers feed the glow: world and god rays yes, vignette and HUD no.

```gdscript
env.background_mode = Environment.BG_CANVAS
env.background_canvas_max_layer = 1
env.glow_enabled = true
env.glow_normalized = true
env.glow_hdr_threshold = 0.92
env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
for i in 7: env.set_glow_level(i, 1.0 if i in [1, 2, 3, 4] else 0.0)   # tight, not foggy
```

Anything brighter than the threshold blooms. Emission sprites (window glow, flames, glints) use `LIGHT_MODE_UNSHADED`, `BLEND_MODE_ADD` and `self_modulate = Color(k, k, k)` with `k > 1` (about 1.1 by day, 2.4 at night). Fade `k` with the night factor.

## 3. Lit sprites, sun, ambient

- Art ships as pairs: `name.png` (diffuse) and `name_n.png` (normal map). Combine them: `var ct := CanvasTexture.new(); ct.diffuse_texture = d; ct.normal_texture = n; ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST`. Use `ct` as the Sprite2D texture; every 2D light now shades the relief.
- Sun: one `DirectionalLight2D`, `blend_mode = BLEND_MODE_ADD`, `rotation = light_dir.angle() - PI * 0.5` (the light_dir vector = direction the light travels on screen).
- `height` drives N·L on flat ground (a flat normal map faces the camera). Keep `height >= 0.4` even at golden hour, or the ground goes dark. Express the low sun through shadow length (step 5), not through a low `height`.
- Ambient: one `CanvasModulate` under the world root, colour from the time-of-day table.
- Time of day: an autoload with keyframes `[hour, ambient, sun_color, sun_energy, sun_height, rays, night]`, smoothstep-interpolated, producing the light_dir vector, `Daylight.shadow_len`, `Daylight.shadow_alpha`. One node copies them to sun, ambient and shaders every frame. Sun azimuth: east (screen right) at 6h, north (top) at noon, west at 19.5h; at night a dim blue moon light.
- Point lights (lanterns, torches): `PointLight2D` with a 256 px radial `GradientTexture2D` (white centre, black edge), `texture_scale = radius_px / 128`, `height` 18-26, flicker from summed sines, energy multiplied by the night factor, `position.round()`.

## 4. Gotchas

| Problem | Fix |
|---|---|
| Godot applies at most ~15 lights per canvas item, so a big ground sprite loses lights | Split the ground into ~128 px chunks: `Sprite2D` with `region_enabled = true` and one `Sprite2D.region_rect` per chunk |
| Autoload named `Sky` collides with the built-in `Sky` class | Name it `Daylight` (anything else) |
| `CanvasModulate` does not affect CanvasLayers | Put additive glow, glints, flames and particles in a `CanvasLayer` with `follow_viewport_enabled = true`; they move with the world and stay bright at night |
| A window's light pool lights its own wall | Light masks: window `PointLight2D.range_item_cull_mask = 2` (ground, plants, people), wall sprites on mask 1 only, lit ground on mask 3 (both bits) |
| Sprites shimmer by one pixel | `.round()` / `.floor()` positions; keep `snap_2d_*` on |

Window and hearth lights can come from the emission texture: bin pixels with `a > 0.5` into 28 px columns, one pool per column just south of the facade base.

## 5. Projected sun shadows

One shear shader per shadow sprite, all sprites inside a single `CanvasGroup` with `light_mask = 0`. The shader draws pure white; the group's `CanvasItem.self_modulate` (e.g. `Color(0.12, 0.11, 0.26, shadow_alpha)`) gives one even tone, so overlapping shadows do not darken twice. Sprites are anchored at their ground line (local y = 0, pixels above are negative y).

```glsl
shader_type canvas_item;
render_mode unshaded;
uniform vec2 light_dir = vec2(0.8, 0.6);
uniform float len = 1.0;
void vertex() {
	float hgt = -VERTEX.y;
	VERTEX = vec2(VERTEX.x + light_dir.x * hgt * len, light_dir.y * hgt * len);
}
void fragment() { COLOR = vec4(1.0, 1.0, 1.0, step(0.5, texture(TEXTURE, UV).a)); }
```

`len` = `Daylight.shadow_len` (about 1.1 at dawn and dusk, 0.35 at noon) times a per-category factor. 3/4-view sprites show part of their height as depth, so buildings use about 0.55, flora about 0.8, upright props 1.0. Cache one material per (sway key, factor) and update them all in the per-frame sky pass.

## 6. Wind, god rays, cloud shadows, vignette

Pixel-row sway: shift whole pixel rows sideways, more toward the top, phase from the node's world position so neighbours do not sway together. Keep the math in a shared `.gdshaderinc` and include it from the sprite shader and the shadow shader, so a tree and its shadow move together. The sprite shader also samples `NORMAL_MAP` with the shifted UV.

```glsl
vec2 wind_uv(vec2 uv, vec2 texel, float phase, float strength, float speed, float stiffness, float t) {
	float h = 1.0 - uv.y;                       // 0 base .. 1 top
	float row = floor(uv.y / texel.y);
	float gust = 0.55 + 0.45 * sin(t * 0.37 + phase * 0.5) * sin(t * 0.23 + phase);
	float w = sin(t * speed + phase + row * 0.045) * strength * gust * pow(h, stiffness);
	return uv - vec2(round(w) * texel.x, 0.0);  // round() keeps it pixel-art
}
// vertex(): vec2 root = (MODEL_MATRIX * vec4(0,0,0,1)).xy; phase = root.x * 0.031 + root.y * 0.017;
```

Full-resolution layers over the upscaled world: a full-rect `ColorRect` (`MOUSE_FILTER_IGNORE`) with a ShaderMaterial in its own `CanvasLayer`.

- God rays (layer 1, `blend_add, unshaded`): pass `origin` (world px at screen pixel 0,0), pix_scale (int), screen_size (vec2), the light_dir vector, tint. In the shader `world = origin + FRAGCOORD.xy / pix_scale`; project onto the sun's perpendicular, threshold 1D noise (wide and thin shafts, drifting slowly), fade away from the sun's side of the screen. World-anchored, so shafts do not slide with the camera. Layer 1 is within `Environment.background_canvas_max_layer`, so they bloom. Strength comes from the sky table.
- Cloud shadows (`blend_mul, unshaded`): `n = fbm((floor(world) - wind * TIME) * 0.0042)`, `c = smoothstep(0.48, 0.68, n)`, dither the edge with a 4x4 Bayer matrix: `q = floor(c * 4.0 + bayer4(px)) / 4.0`, `COLOR = vec4(mix(vec3(1), shade_color, q * strength), 1.0)`.
- Vignette (layer 2, `render_mode blend_mul`): `mix(vec3(1), tint, smoothstep(0.32, 0.82, length(uv)) * amount)`, stronger at night.
- Put `hash12`, value noise, `fbm`, `bayer4` in one `noise.gdshaderinc`.

## 7. Verification

Add `tools/capture.gd` to the project: a `SceneTree` script that loads the main scene, waits ~20 frames, then for each `preset@x,y` argument sets the time of day and camera, waits ~45 frames and saves `root.get_texture().get_image()` as PNG. Run it with the sidebar's screenshot tool:

```powershell
tools\game_shot.ps1 -Project <project> -Views "golden@640,520 noon@640,520 night@640,520"
```

Look at the PNGs: ground not dark at golden hour, shadows point away from the sun and shorten at noon, lamps and windows bloom at night, no seams between ground chunks, no shimmer while the camera moves. `get_runtime_errors` must be empty.
