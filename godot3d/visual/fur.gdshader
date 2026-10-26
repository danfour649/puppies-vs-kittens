shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Shell fur. One mesh is drawn several times; `layer` goes from
// just off the skin to the tip. Strands are a stable hash so the
// coat thins toward the tip instead of looking like stacked balloons.
// Self-made for this project. No textures are sampled except the
// coat albedo the cat already baked (Willie's ginger, Aggie's calico).

uniform vec4 fur_color : source_color = vec4(1.0);
uniform float layer = 0.5;
uniform float fur_length = 0.05;
uniform bool use_tex = false;
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform float density = 0.98;
varying vec3 strand_pos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	vec3 n = normalize(NORMAL);
	float h = layer * fur_length;
	VERTEX += n * h;
	// Gravity in mesh space. Length is already baked into the shell
	// mesh, so this only droops the tips.
	VERTEX.y -= layer * layer * 0.035;
	// Model space, so the strands stay put when the camera moves.
	strand_pos = VERTEX;
}

void fragment() {
	// Inner shells stay solid so the coat has a silhouette even when
	// the GL fallback is coarse. Outer shells break into strands.
	vec3 cell = floor((strand_pos + vec3(5.0)) * vec3(48.0, 72.0, 48.0));
	float strand = hash13(cell);
	float keep = mix(1.0, density * 0.84, smoothstep(0.45, 1.0, layer));
	if (strand > keep) {
		discard;
	}
	vec3 col = fur_color.rgb;
	if (use_tex) {
		col *= texture(albedo_tex, UV).rgb;
	}
	col *= mix(1.06, 0.74, layer);
	ALBEDO = col;
	ROUGHNESS = mix(0.68, 0.96, layer);
	SPECULAR = 0.18;
}
