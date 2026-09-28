[gd_resource type="Shader" format=3]

[resource]
code = "shader_type canvas_item;

void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c);
	// Vertical dusk gradient + soft vignette so the window is never flat.
	vec3 top = vec3(0.059, 0.086, 0.129);
	vec3 bottom = vec3(0.039, 0.055, 0.078);
	vec3 col = mix(top, bottom, clamp(UV.y, 0.0, 1.0));
	col *= 1.0 - smoothstep(0.35, 0.95, d) * 0.55;
	COLOR = vec4(col, 1.0);
}
"
