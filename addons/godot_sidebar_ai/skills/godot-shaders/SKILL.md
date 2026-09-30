---
name: godot-shaders
description: Write Godot 4 shaders (.gdshader) for 2D and 3D - hit flash, dissolve, outline, toon shading with rim light, water, scrolling textures - and check them in the running game. Use when the user wants a visual effect that normal materials or modulate cannot give, or asks for a shader.
---

# Godot shaders

Shaders are plain text files: write a `.gdshader` with the file tools, attach it with a `ShaderMaterial`, then look at the running game. Nothing else checks a shader for you, so always finish by running the game and reading the output.

## Steps

1. Pick the type: `shader_type canvas_item;` for sprites, UI and 2D, `shader_type spatial;` for 3D.
2. Write the file under `res://shaders/name.gdshader`. Expose the knobs as `uniform`s with hints (`source_color`, `hint_range(0.0, 1.0)`), so the game can animate them.
3. Attach it in the `.tscn`:

```
[ext_resource type="Shader" path="res://shaders/flash.gdshader" id="2"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_flash"]
shader = ExtResource("2")
shader_parameter/flash_amount = 0.0

[node name="Sprite2D" type="Sprite2D" parent="."]
material = SubResource("ShaderMaterial_flash")
```

   Or from code: `var mat := ShaderMaterial.new(); mat.shader = load("res://shaders/flash.gdshader"); node.material = mat` (3D meshes use `material_override`).
4. Animate a uniform from code: `material.set_shader_parameter("flash_amount", 1.0)`, or with a Tween: `create_tween().tween_property(material, "shader_parameter/flash_amount", 0.0, 0.15)`. One material shared by many nodes flashes all of them: make it unique per node (`material = material.duplicate()`).
5. Verify: `play_game`, `get_output` (shader compile errors appear there with a line number), `get_runtime_errors`, `take_runtime_screenshot`. Trigger the effect with `send_input` or `set_runtime_property` and take a second screenshot.

## Recipes (each one compiled and rendered in Godot 4.7)

Hit flash (canvas_item):

```glsl
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash_amount), tex.a);
}
```

Dissolve with procedural noise, no texture file needed (canvas_item):

```glsl
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float edge_width = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float n = value_noise(UV * 8.0);
	if (n < progress) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.0, edge_width, n - progress);
	COLOR = vec4(mix(tex.rgb, edge_color.rgb, edge), tex.a);
}
```

Toon bands with a rim light (spatial, needs a light in the scene):

```glsl
shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.9, 0.4, 0.2, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim_power = 3.0;
uniform int steps : hint_range(2, 6) = 3;

void fragment() {
	ALBEDO = albedo.rgb;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float banded = floor(ndl * float(steps)) / float(steps - 1);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * banded * ALBEDO / PI + rim_color.rgb * rim * 0.3;
}
```

Water waves (spatial; put it on a subdivided PlaneMesh, `subdivide_width` and `subdivide_depth` about 32):

```glsl
shader_type spatial;

uniform vec4 shallow : source_color = vec4(0.1, 0.5, 0.6, 0.8);
uniform float wave_speed = 0.6;
uniform float wave_height = 0.15;

void vertex() {
	VERTEX.y += sin(VERTEX.x * 2.0 + TIME * wave_speed * 4.0) * wave_height + cos(VERTEX.z * 3.0 + TIME * wave_speed * 3.0) * wave_height * 0.5;
}

void fragment() {
	ALBEDO = shallow.rgb;
	ALPHA = shallow.a;
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
}
```

Scrolling texture (conveyor, lava, sky): `COLOR = texture(TEXTURE, UV + vec2(TIME * 0.1, 0.0));` with the node's texture repeat enabled.

Outline for 3D: a second material in `next_pass` that draws a slightly bigger inverted copy: `render_mode cull_front;` and in `vertex()` `VERTEX += NORMAL * width;` with a flat colour in `fragment()`.

## Pitfalls

- Godot 4 names: `TEXTURE`, `UV`, `COLOR`, `ALBEDO`, `TIME`, `hint_range`, `source_color` (not the Godot 3 colour hint), `render_mode`; `shader_parameter/name` in a `.tscn`.
- A `ColorRect` has no texture, so `TEXTURE` is white there: test texture shaders on a Sprite2D or TextureRect.
- `discard` in a spatial shader makes cut-outs; real transparency needs `ALPHA` and care with sorting.
- Keep loops and texture reads low on mobile; animate uniforms instead of branching per pixel.
- If the screen goes pink or the mesh disappears, read `get_output` first: the compile error names the line.
