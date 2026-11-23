shader_type canvas_item;

// Analyse spectrale
uniform float audio_low = 0.0;
uniform float audio_mid = 0.0;
uniform float audio_high = 0.0;
uniform float spectral_centroid = 0.5;
uniform float audio_intensity = 0.0;

// Gameplay
uniform float hit_pulse = 0.0;
uniform float combo_intensity = 0.0;
uniform float screen_shake = 0.0;

// Paramètres utilisateur
uniform float brightness = 1.0;
uniform bool high_contrast = false;

float noise(vec2 st) {
	vec2 i = floor(st);
	vec2 f = fract(st);
	float a = dot(sin(i), cos(i.yx));
	float b = dot(sin(i + vec2(1.0, 0.0)), cos(i.yx + vec2(0.0, 1.0)));
	float c = dot(sin(i + vec2(0.0, 1.0)), cos(i.yx + vec2(1.0, 0.0)));
	float d = dot(sin(i + 1.0), cos(i.yx + 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0;
}

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);

	// Zoom de marge suffisant pour garder la grosse déformation 3D fluide sans artefacts de bord
	uv = (uv - center) * (0.88 - audio_low * 0.03) + center;

	// Déformation / distorsion organique 3D fluide et marquée (sans tremblement 50Hz)
	vec2 motion = vec2(noise(uv * 2.0 + TIME * 0.25), noise(uv * 2.0 - TIME * 0.22));
	float total_deform = 0.045 + audio_low * 0.12 + audio_mid * 0.08 + audio_high * 0.04 + combo_intensity * 0.06;
	vec2 deformed_uv = clamp(uv + motion * total_deform, vec2(0.002), vec2(0.998));

	// Aberration chromatique sur les basses et les hits
	float chroma = audio_low * 0.004 + hit_pulse * 0.006;
	vec2 dir = normalize(deformed_uv - center + vec2(0.0001));
	float r = texture(TEXTURE, clamp(deformed_uv + dir * chroma, vec2(0.002), vec2(0.998))).r;
	float g = texture(TEXTURE, deformed_uv).g;
	float b = texture(TEXTURE, clamp(deformed_uv - dir * chroma, vec2(0.002), vec2(0.998))).b;
	vec4 tex_color = vec4(r, g, b, 1.0);

	// Grille néon subtile en arrière-plan
	vec2 grid_uv = fract((uv - center) * 10.0 + vec2(0.0, TIME * 0.35));
	float grid_line = smoothstep(0.035, 0.0, min(grid_uv.x, grid_uv.y));
	vec3 neon_cyan = vec3(0.0, 0.85, 1.0);
	vec3 neon_pink = vec3(1.0, 0.15, 0.75);
	vec3 grid_col = mix(neon_cyan, neon_pink, sin(TIME * 0.6 + uv.x * 2.0) * 0.5 + 0.5);
	tex_color.rgb += grid_col * grid_line * (0.06 + audio_mid * 0.14 + audio_high * 0.10);

	// Onde circulaire (pulse du centre sur les beats / hits)
	float dist = length(uv - center);
	float ripple_radius = fract(TIME * 0.45) * 0.85;
	float ripple = smoothstep(0.04, 0.0, abs(dist - ripple_radius)) * (1.0 - ripple_radius);
	tex_color.rgb += mix(neon_cyan, neon_pink, spectral_centroid) * ripple * (0.15 + hit_pulse * 0.55 + audio_low * 0.35);

	// Orbes lumineux flottants
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 orb_pos = vec2(
			0.5 + 0.32 * sin(TIME * 0.45 + fi * 2.09),
			0.5 + 0.28 * cos(TIME * 0.38 + fi * 1.57)
		);
		float d = length(uv - orb_pos);
		float glow = smoothstep(0.26, 0.0, d);
		vec3 orb_col = mix(neon_cyan, neon_pink, fi * 0.5);
		tex_color.rgb += orb_col * glow * (0.08 + audio_mid * 0.18);
	}

	// Flash sur hit & réactivité spectrale
	tex_color.rgb += hit_pulse * 0.18;
	tex_color.r += audio_low * 0.14;
	tex_color.g += audio_mid * 0.08;
	tex_color.b += audio_high * 0.18;

	// Halo de bordure quand le combo monte
	float edge = clamp(1.0 - min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)) * 8.0, 0.0, 1.0);
	vec3 combo_col = mix(neon_cyan, vec3(1.0, 0.82, 0.15), combo_intensity);
	tex_color.rgb += combo_col * edge * (0.08 + combo_intensity * 0.35 + hit_pulse * 0.2);

	// Luminosité & haut contraste
	tex_color.rgb *= brightness;
	if (high_contrast) {
		float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
		tex_color.rgb = vec3(step(0.5, gray));
	}

	COLOR = tex_color;
}
