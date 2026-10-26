shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 tint = vec3(1.0);
uniform float rough : hint_range(0.0, 1.0) = 0.9;
uniform float edge : hint_range(0.0, 0.5) = 0.2;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	float axis = max(abs(world_normal.x), max(abs(world_normal.y), abs(world_normal.z)));
	float face = smoothstep(0.55, 0.94, axis);
	float shade = mix(1.0 - edge, 1.0, face);
	ALBEDO = tex * tint * shade;
	ROUGHNESS = rough;
}
