shader_type canvas_item;

// Shader de glow pulsant pour les notes
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float approach_progress : hint_range(0.0, 1.0) = 0.0;  // 0 = loin, 1 = proche

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Pulse animé qui s'accélère quand la note approche
	float speed = pulse_speed * (1.0 + approach_progress * 2.0);
	float pulse = 0.6 + 0.4 * sin(TIME * speed);
	
	// Intensité du glow augmente quand la note approche
	float intensity = glow_intensity * (0.5 + approach_progress * 0.5) * pulse;
	
	// Appliquer le glow
	vec3 final_color = tex_color.rgb;
	if (tex_color.a > 0.1) {
		// Ajouter une teinte néon
		vec3 neon = glow_color.rgb * intensity;
		final_color = tex_color.rgb + neon * 0.5;
		
		// Augmenter la saturation quand proche
		float saturation = 1.0 + approach_progress * 0.3;
		vec3 gray = vec3(dot(final_color, vec3(0.299, 0.587, 0.114)));
		final_color = mix(gray, final_color, saturation);
	}
	
	COLOR = vec4(final_color, tex_color.a);
}
