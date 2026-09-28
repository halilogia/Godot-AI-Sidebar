# Composition, layers and 2D light

## Fill the screen

- Project settings (use `manage_project_settings`): `display/window/size/viewport_width` 1280, `viewport_height` 720, `display/window/stretch/mode` `canvas_items`, `display/window/stretch/aspect` `expand`.
- Compute sizes from the viewport, never hard-code positions for one resolution: `var size := get_viewport_rect().size`.
- A board/grid game (match-3, tactics, cards): choose the cell size so the board takes ~70-80% of the shorter side, centre it, leave room for one HUD row on top and one hint/button row at the bottom. `cell = floor(min(size.x * 0.8 / cols, (size.y - hud_height) * 0.8 / rows))`.
- Side-scrollers: the player sits at about 1/3 of the width, the ground occupies the lower ~20%, the rest is sky and background layers.
- Top-down: the arena fills the window; HUD is a thin bar over it, not a separate box.

## Depth in 2D (three layers minimum)

1. **Background:** vertical gradient (`GradientTexture2D` on a `TextureRect`, `fill = GradientTexture2D.FILL_LINEAR`, `fill_from = Vector2(0,0)`, `fill_to = Vector2(0,1)`, two or three palette colours).
2. **Mid layer:** silhouettes in a slightly lighter or darker tone of the background (hills, city blocks, trees as `Polygon2D`), moved slower than the camera (`ParallaxBackground` + `ParallaxLayer`, `motion_scale = Vector2(0.3, 1)`).
3. **Foreground/play layer:** saturated colours. The play layer must be the most contrasting thing on screen.

## Objects that sit in the world

- Soft shadow: duplicate the shape, colour `Color(0, 0, 0, 0.25)`, offset (0, 4), `z_index = -1`.
- Outline: a slightly larger copy in a darker tone of the fill, behind it; or `Line2D` closed loop, width 2.
- Tiles/blocks: fill + a 2 px lighter top edge + a 2 px darker bottom edge makes them look raised.
- Highlights: a small lighter shape on the top-left of round things.

## 2D light and mood

```gdscript
# Darken the scene, then add light where it matters.
var mod := CanvasModulate.new()
mod.color = Color("8a94b8")            # dusk tint; use Color.WHITE for full brightness
add_child(mod)

var tex := GradientTexture2D.new()      # radial light texture, no image file needed
tex.fill = GradientTexture2D.FILL_RADIAL
tex.fill_from = Vector2(0.5, 0.5)
tex.fill_to = Vector2(1.0, 0.5)
tex.width = 256
tex.height = 256
var g := Gradient.new()
g.set_color(0, Color.WHITE)
g.set_color(1, Color(1, 1, 1, 0))
tex.gradient = g

var lamp := PointLight2D.new()
lamp.texture = tex
lamp.texture_scale = 2.0
lamp.color = Color("ffd9a0")
lamp.energy = 1.1
lamp.shadow_enabled = true
add_child(lamp)
```

Use lights for: the player's torch, windows, explosions, pickups. One or two lights are enough.

## Vignette (cheap and effective)

Write `res://shaders/vignette.gdshader`:

```
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.35;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float v = smoothstep(0.35, 0.85, length(uv));
	COLOR = vec4(0.0, 0.0, 0.0, v * strength);
}
```

Then a full-screen `ColorRect` on a `CanvasLayer` (layer 5) with a `ShaderMaterial` using it, `mouse_filter = Control.MOUSE_FILTER_IGNORE`, anchors full rect.
