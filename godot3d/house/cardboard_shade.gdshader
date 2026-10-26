shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 tint = vec3(1.0);
uniform float rough : hint_range(0.0, 1.0) = 0.9;
uniform float edge : hint_range(0.0, 0.6) = 0.32;

varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	vec3 n = normalize(world_normal);
	// Faceted boxes keep a flat normal across a face, so the crease
	// is the pixels where that normal changes.
	float crease = clamp(length(fwidth(n)) * 5.0, 0.0, 1.0);
	float up = clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
	float key = clamp(dot(n, normalize(vec3(0.22, 0.92, 0.18))), 0.0, 1.0);
	float mottling = 0.96 + 0.04 * sin(world_pos.x * 13.0 + world_pos.y * 8.0 + world_pos.z * 11.0);
	float shade = mix(0.94, 1.0, up) * mix(0.96, 1.0, key) * mottling;
	shade *= mix(1.0, 1.0 - edge, crease);
	ALBEDO = tex * tint * shade;
	ROUGHNESS = rough;
}
