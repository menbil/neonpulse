shader_type canvas_item;

// Approach Circle Shader - style osu!lazer
// Cercle d'approche avec glow et animation

uniform float approach_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 circle_color : source_color = vec4(1.0, 0.5, 0.7, 1.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float time = 0.0;

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv) * 2.0;
    
    // Rayon du cercle d'approche (commence grand, devient petit)
    float target_radius = 0.9;  // Rayon final
    float start_radius = 2.5;   // Rayon initial
    float current_radius = mix(start_radius, target_radius, approach_progress);
    
    // Épaisseur du cercle
    float thickness = 0.08 + (1.0 - approach_progress) * 0.05;
    
    // Dessiner le cercle
    float circle = smoothstep(current_radius + thickness, current_radius, dist) - 
                   smoothstep(current_radius, current_radius - thickness, dist);
    
    // Pulse animation
    float pulse = sin(time * pulse_speed) * 0.5 + 0.5;
    float pulse_effect = 1.0 + pulse * 0.2 * approach_progress;
    
    // Glow effect
    float glow_dist = abs(dist - current_radius);
    float glow = exp(-glow_dist * 5.0) * glow_intensity * (0.5 + approach_progress * 0.5);
    
    // Couleur finale
    vec4 final_color = circle_color;
    final_color.rgb *= pulse_effect;
    
    // Combiner cercle et glow
    float alpha = max(circle, glow * 0.5);
    alpha *= (0.3 + approach_progress * 0.7);  // Fade in pendant l'approche
    
    // Ajouter un effet de brillance au centre quand proche
    if (approach_progress > 0.8) {
        float center_glow = exp(-dist * 3.0) * (approach_progress - 0.8) * 5.0;
        final_color.rgb += vec3(center_glow) * 0.5;
    }
    
    COLOR = vec4(final_color.rgb, alpha);
}
