shader_type canvas_item;

// Shader de glow néon pour les notes et éléments UI
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float glow_size : hint_range(0.0, 50.0) = 10.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform bool enable_pulse = true;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Pulse animé
	float pulse = 1.0;
	if (enable_pulse) {
		pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	}
	
	// Glow externe (simulé par une couleur additive sur l'alpha)
	float alpha = tex_color.a;
	vec3 final_color = tex_color.rgb;
	
	// Ajouter le glow néon
	if (alpha > 0.1) {
		vec3 neon = glow_color.rgb * glow_intensity * pulse;
		final_color = mix(final_color, final_color + neon, 0.5);
	}
	
	COLOR = vec4(final_color, alpha);
}
