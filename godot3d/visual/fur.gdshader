shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

// Shell fur. One mesh is drawn several times; `layer` goes from
// just off the skin to the tip. Strands are a stable hash so the
// coat thins toward the tip instead of looking like stacked balloons.
// Self-made for this project. No textures are sampled except the
// coat albedo the cat already baked (Willie's ginger, Aggie's tortoiseshell).

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
	vec3 n = NORMAL;
	if (dot(n, n) < 0.0001) {
		n = vec3(0.0, 1.0, 0.0);
	}
	n = normalize(n);
	float h = layer * fur_length;
	VERTEX += n * h;
	// The shell mesh is already extruded. This droop is a hair of
	// gravity on the tip, small enough that the shell stays outside
	// the body. A larger drop sinks the coat and z-fights.
	VERTEX.y -= layer * layer * 0.0015;
	// Model space, so the strands stay put when the camera moves.
	strand_pos = VERTEX;
	NORMAL = n;
}

void fragment() {
	// Inner shells stay solid so the coat has a silhouette even when
	// the GL fallback is coarse. Outer shells break into strands.
	vec3 cell = floor((strand_pos + vec3(5.0)) * vec3(36.0, 48.0, 36.0));
	float strand = hash13(cell);
	// Inner shells stay solid. Only the outer shell breaks into
	// strands, so a discarded fragment shows coat rather than a hole.
	float keep = mix(1.0, density * 0.55, smoothstep(0.72, 1.0, layer));
	if (strand > keep) {
		discard;
	}
	vec3 col = fur_color.rgb;
	if (use_tex) {
		col *= texture(albedo_tex, UV).rgb;
	}
	col *= mix(1.02, 0.88, layer);
	ALBEDO = col;
	ROUGHNESS = mix(0.84, 0.96, layer);
	SPECULAR = 0.03;
}
