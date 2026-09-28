# 3D lighting, environment and materials

A 3D scene with default lighting and grey boxes is the 3D version of "prototype". Four things fix most of it: an Environment, one sun with shadows, palette materials, and a sensible camera.

```gdscript
static func setup_stage(parent: Node3D, sun_color := Color("ffe2b8"), sky_top := Color("5b86c9"), sky_horizon := Color("cfe0f2")) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_horizon
	sky_mat.ground_horizon_color = sky_horizon.darkened(0.2)
	sky_mat.ground_bottom_color = sky_horizon.darkened(0.55)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = sky_horizon
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = sun_color
	sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	parent.add_child(sun)
```

Call it once from the main 3D script. For a night or interior look use a dark blue `sky_top`/`sky_horizon`, `ambient_light_energy` 0.3, and add warm `OmniLight3D` nodes (`light_energy` 2, `omni_range` 8, `shadow_enabled = true`) where the action is.

## Materials

```gdscript
static func mat(color: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m
```

- Use palette colours only. Roughness 0.6-0.9 for most things; `metallic` above 0 only for real metal. Emissive accents: `m.emission_enabled = true`, `m.emission = color`, `m.emission_energy_multiplier = 1.5` for pickups, enemy eyes, UI-like markers.
- Vary the ground: two tones of one colour in a checker or stripes beats one flat plane. Add simple props (rocks, trees from `CylinderMesh` + `SphereMesh`, fences) so the level is not an empty plane.
- Give shapes character: bevel-like look by stacking (a `CylinderMesh` roof over a `BoxMesh`), never leave a lone default `BoxMesh` as the hero.

## Camera

- `fov` 40-55 for an overview/isometric feel, 70-80 for first person. Orthographic (`projection = Camera3D.PROJECTION_ORTHOGONAL`, `size` 12-20) for strategy and tower defense.
- Tower defense/strategy: pitch 45-60 degrees down, rotate 30-45 degrees around Y, keep the whole field visible.
- Follow cameras: smooth with `lerp` (weight 5 * delta), small offset behind and above the target.
- First person: eye height 1.6 m, `Camera3D` as child of the body, mouse look with clamped pitch.
