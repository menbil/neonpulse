extends ColorRect
class_name NeonBackground

# Références
@onready var shader_material: ShaderMaterial

# Configuration des couleurs
@export var color_cyan := Color(0.0, 0.8, 1.0)
@export var color_magenta := Color(1.0, 0.0, 0.8)
@export var color_violet := Color(0.5, 0.0, 1.0)

# Variables pour l'audio réactif
var audio_player: AudioStreamPlayer2D
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance
var audio_low := 0.0
var audio_mid := 0.0
var audio_high := 0.0

# Variables pour les effets
var hit_pulse := 0.0
var combo_intensity := 0.0
var screen_shake := 0.0

# Particules flottantes
var floating_particles: Array[Dictionary] = []
const MAX_PARTICLES = 30

func _ready():
	# Créer le material shader
	var shader = load("res://scenes/NeonBackground.gdshader")
	if shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		material = shader_material
		
		# Appliquer les couleurs
		shader_material.set_shader_parameter("color1", color_cyan)
		shader_material.set_shader_parameter("color2", color_magenta)
		shader_material.set_shader_parameter("color3", color_violet)
	
	# Trouver l'audio player
	var main = get_parent()
	if main:
		audio_player = main.get_node_or_null("AudioStreamPlayer")
		if audio_player == null:
			audio_player = main.get_node_or_null("AudioStreamPlayer2D")
	
	# Configurer l'analyseur de spectre
	setup_spectrum_analyzer()
	
	# Initialiser les particules flottantes
	init_floating_particles()

func setup_spectrum_analyzer():
	# Vérifier si un bus "Master" a un effet SpectrumAnalyzer
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx == -1:
		bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		for i in range(AudioServer.get_bus_effect_count(bus_idx)):
			var effect = AudioServer.get_bus_effect(bus_idx, i)
			if effect is AudioEffectSpectrumAnalyzer:
				spectrum_analyzer = AudioServer.get_bus_effect_instance(bus_idx, i)
				return
	
	# Si pas d'analyseur, en créer un
	if spectrum_analyzer == null:
		var analyzer = AudioEffectSpectrumAnalyzer.new()
		analyzer.buffer_length = 0.1
		AudioServer.add_bus_effect(bus_idx, analyzer)
		spectrum_analyzer = AudioServer.get_bus_effect_instance(bus_idx, AudioServer.get_bus_effect_count(bus_idx) - 1)

func init_floating_particles():
	floating_particles.clear()
	for i in range(MAX_PARTICLES):
		floating_particles.append({
			"pos": Vector2(randf() * size.x, randf() * size.y),
			"vel": Vector2(randf_range(-20, 20), randf_range(-30, -10)),
			"size": randf_range(2, 6),
			"alpha": randf_range(0.3, 0.8),
			"color": [color_cyan, color_magenta, color_violet][randi() % 3],
			"pulse_offset": randf() * TAU
		})

func _process(delta):
	# Analyser l'audio
	analyze_audio()
	
	# Mettre à jour les effets
	update_effects(delta)
	
	# Mettre à jour le shader
	update_shader()
	
	# Mettre à jour et dessiner les particules
	update_particles(delta)
	queue_redraw()

func analyze_audio():
	if spectrum_analyzer == null:
		# Fallback: utiliser le temps de lecture
		if audio_player and audio_player.playing:
			var pos = audio_player.get_playback_position()
			audio_low = 0.3 + 0.2 * sin(pos * 4.0)
			audio_mid = 0.3 + 0.2 * sin(pos * 8.0 + 1.0)
			audio_high = 0.2 + 0.1 * sin(pos * 16.0 + 2.0)
		return
	
	# Analyser les basses (20-250 Hz)
	var low_mag = spectrum_analyzer.get_magnitude_for_frequency_range(20, 250)
	audio_low = clamp((low_mag.x + low_mag.y) * 2.0, 0.0, 1.0)
	
	# Analyser les médiums (250-2000 Hz)
	var mid_mag = spectrum_analyzer.get_magnitude_for_frequency_range(250, 2000)
	audio_mid = clamp((mid_mag.x + mid_mag.y) * 2.0, 0.0, 1.0)
	
	# Analyser les aigus (2000-20000 Hz)
	var high_mag = spectrum_analyzer.get_magnitude_for_frequency_range(2000, 20000)
	audio_high = clamp((high_mag.x + high_mag.y) * 4.0, 0.0, 1.0)

func update_effects(delta):
	# Décroissance du hit pulse
	hit_pulse = max(0.0, hit_pulse - delta * 3.0)
	
	# Décroissance du screen shake
	screen_shake = max(0.0, screen_shake - delta * 5.0)

func update_shader():
	if shader_material == null:
		return
	
	shader_material.set_shader_parameter("audio_low", audio_low)
	shader_material.set_shader_parameter("audio_mid", audio_mid)
	shader_material.set_shader_parameter("audio_high", audio_high)
	shader_material.set_shader_parameter("hit_pulse", hit_pulse)
	shader_material.set_shader_parameter("combo_intensity", combo_intensity)
	shader_material.set_shader_parameter("screen_shake", screen_shake)

func update_particles(delta):
	for p in floating_particles:
		# Mouvement
		p.pos += p.vel * delta
		
		# Réagir à l'audio
		p.vel.x += (audio_mid - 0.3) * 50 * delta
		p.vel.y -= audio_low * 30 * delta
		
		# Reboucler en haut
		if p.pos.y < -10:
			p.pos.y = size.y + 10
			p.pos.x = randf() * size.x
		
		# Reboucler sur les côtés
		if p.pos.x < -10:
			p.pos.x = size.x + 10
		elif p.pos.x > size.x + 10:
			p.pos.x = -10

func _draw():
	# Dessiner les particules flottantes
	var time = Time.get_ticks_msec() / 1000.0
	
	for p in floating_particles:
		var pulse = 0.7 + 0.3 * sin(time * 2.0 + p.pulse_offset)
		var current_size = p.size * (1.0 + audio_low * 0.5) * pulse
		var alpha = p.alpha * pulse
		
		# Dessiner le glow
		var glow_color = p.color
		glow_color.a = alpha * 0.3
		draw_circle(p.pos, current_size * 3, glow_color)
		
		# Dessiner le centre brillant
		var core_color = p.color
		core_color.a = alpha
		draw_circle(p.pos, current_size, core_color)

# API publique pour déclencher les effets
func trigger_hit_pulse(intensity := 1.0):
	hit_pulse = clamp(intensity, 0.0, 1.0)

func trigger_screen_shake(intensity := 0.5):
	screen_shake = clamp(intensity, 0.0, 1.0)

func set_combo_intensity(combo: int):
	combo_intensity = clamp(combo / 50.0, 0.0, 1.0)
