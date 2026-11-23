shader_type canvas_item;

// Shader de background néon amélioré avec effets dynamiques
uniform float time_offset = 0.0;
uniform float audio_low = 0.0;
uniform float audio_mid = 0.0;
uniform float audio_high = 0.0;
uniform float hit_pulse = 0.0;
uniform float combo_intensity = 0.0;
uniform float screen_shake = 0.0;
uniform float brightness = 1.0;
uniform bool high_contrast = false;

// Couleurs néon
uniform vec4 color1 : source_color = vec4(0.0, 0.8, 1.0, 1.0);  // Cyan
uniform vec4 color2 : source_color = vec4(1.0, 0.0, 0.8, 1.0);  // Magenta
uniform vec4 color3 : source_color = vec4(0.5, 0.0, 1.0, 1.0);  // Violet

// Fonction de bruit
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Génère des lignes de grille néon
float grid_lines(vec2 uv, float spacing, float thickness) {
	vec2 grid = abs(fract(uv * spacing) - 0.5);
	float line = min(grid.x, grid.y);
	return smoothstep(0.0, thickness, line);
}

// Génère un cercle lumineux
float circle_glow(vec2 uv, vec2 center, float radius, float softness) {
	float dist = length(uv - center);
	return 1.0 - smoothstep(radius - softness, radius + softness, dist);
}

// Génère des barres horizontales animées
float scan_lines(vec2 uv, float speed, float density) {
	float line = sin((uv.y + TIME * speed) * density);
	return smoothstep(0.8, 1.0, line) * 0.3;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME + time_offset;
	
	// Screen shake
	uv += vec2(sin(t * 50.0) * screen_shake * 0.01, cos(t * 60.0) * screen_shake * 0.01);
	
	// Couleur de base sombre
	vec3 bg_color = vec3(0.02, 0.02, 0.05);
	
	// === GRILLE NÉON ===
	float grid1 = 1.0 - grid_lines(uv + vec2(t * 0.02, 0.0), 8.0, 0.02);
	float grid2 = 1.0 - grid_lines(uv + vec2(0.0, t * 0.03), 12.0, 0.015);
	
	// Couleur de la grille basée sur la position et le temps
	vec3 grid_color = mix(color1.rgb, color2.rgb, sin(t * 0.5 + uv.x * 3.0) * 0.5 + 0.5);
	grid_color = mix(grid_color, color3.rgb, cos(t * 0.3 + uv.y * 2.0) * 0.5 + 0.5);
	
	// Intensité de la grille réactive à l'audio
	float grid_intensity = 0.15 + audio_low * 0.3 + audio_mid * 0.2;
	bg_color += grid_color * (grid1 + grid2 * 0.5) * grid_intensity;
	
	// === CERCLES DE GLOW ANIMÉS ===
	// Cercle central qui pulse avec les basses
	vec2 center = vec2(0.5, 0.5);
	float pulse = 0.2 + audio_low * 0.3 + hit_pulse * 0.4;
	float glow1 = circle_glow(uv, center, 0.3 + pulse, 0.4);
	bg_color += color1.rgb * glow1 * 0.2;
	
	// Cercles qui se déplacent
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 pos = vec2(
			0.3 + 0.4 * sin(t * 0.5 + fi * 2.1),
			0.3 + 0.4 * cos(t * 0.4 + fi * 1.7)
		);
		float size = 0.1 + 0.05 * sin(t + fi);
		float glow = circle_glow(uv, pos, size, 0.15);
		
		vec3 orb_color = mix(color1.rgb, color2.rgb, fi / 2.0);
		bg_color += orb_color * glow * (0.15 + audio_mid * 0.2);
	}
	
	// === SCAN LINES ===
	float scan = scan_lines(uv, 0.5, 100.0);
	bg_color += vec3(scan) * 0.1;
	
	// === VIGNETTE ===
	float vignette = 1.0 - length(uv - vec2(0.5)) * 0.8;
	vignette = clamp(vignette, 0.0, 1.0);
	bg_color *= vignette;
	
	// === NOISE/GRAIN ===
	float grain = noise(uv * 500.0 + t * 10.0) * 0.03;
	bg_color += grain;
	
	// === EFFETS DE COMBO ===
	if (combo_intensity > 0.3) {
		// Bordures qui s'illuminent avec le combo
		float edge_glow = 1.0 - min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)) * 10.0;
		edge_glow = clamp(edge_glow, 0.0, 1.0);
		
		vec3 combo_color = mix(color1.rgb, vec3(1.0, 0.8, 0.0), combo_intensity);
		bg_color += combo_color * edge_glow * combo_intensity * 0.5;
	}
	
	// === HIT PULSE ===
	if (hit_pulse > 0.0) {
		// Flash lumineux au centre
		float flash = circle_glow(uv, vec2(0.5), hit_pulse * 0.8, 0.5);
		bg_color += vec3(1.0, 1.0, 1.0) * flash * hit_pulse * 0.3;
	}
	
	// === RAYONS DE LUMIÈRE ===
	vec2 ray_uv = uv - vec2(0.5);
	float angle = atan(ray_uv.y, ray_uv.x);
	float rays = sin(angle * 8.0 + t * 2.0) * 0.5 + 0.5;
	rays *= 1.0 - length(ray_uv) * 1.5;
	rays = clamp(rays, 0.0, 1.0);
	bg_color += color3.rgb * rays * (0.05 + audio_high * 0.15);
	
	// === BRIGHTNESS ET CONTRASTE ===
	bg_color *= brightness;
	
	if (high_contrast) {
		bg_color = pow(bg_color, vec3(1.2));
	}
	
	// Texture originale si présente (en overlay léger)
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a > 0.0) {
		bg_color = mix(bg_color, tex.rgb * 0.3 + bg_color * 0.7, tex.a * 0.5);
	}
	
	COLOR = vec4(bg_color, 1.0);
}
