extends Node2D
class_name KiaiManager

## Kiai Time Manager - Effets spéciaux pendant les sections intenses
## Style osu! avec étoiles, glow intense, et particules

# === STATE ===
var is_kiai_active := false
var kiai_sections: Array[Dictionary] = []  # [{start_time, end_time}, ...]
var current_section_index := 0
var bpm := 120.0

# === EFFECTS ===
var star_particles: Array[Dictionary] = []
var fountain_particles: Array[Dictionary] = []
var glow_intensity := 0.0
var beat_pulse := 0.0

# === CONFIGURATION ===
const MAX_STARS := 50
const MAX_FOUNTAIN := 30
const STAR_SPAWN_RATE := 0.05  # Secondes entre chaque étoile
var time_since_last_star := 0.0

# === REFERENCES ===
var main_node: Node
var background_dim_node: ColorRect

# Couleurs kiai
var kiai_colors := [
	Color(1.0, 0.3, 0.5),   # Rose
	Color(0.3, 0.8, 1.0),   # Cyan
	Color(1.0, 0.8, 0.2),   # Or
	Color(0.8, 0.3, 1.0),   # Violet
]
var current_color_index := 0

signal kiai_started
signal kiai_ended

func _ready():
	main_node = get_parent()

func load_kiai_sections(beatmap_data: Dictionary):
	## Charge les sections kiai depuis la beatmap
	kiai_sections.clear()
	bpm = float(beatmap_data.get("bpm", 120.0))
	
	if beatmap_data.has("kiai_sections"):
		for section in beatmap_data.kiai_sections:
			kiai_sections.append({
				"start_time": section.get("start", 0.0),
				"end_time": section.get("end", 0.0)
			})
	
	# Si pas de sections définies, en créer automatiquement basé sur la durée
	if kiai_sections.is_empty() and beatmap_data.has("duration"):
		var duration = beatmap_data.duration
		# Kiai aux 2/3 de la chanson pendant 15 secondes
		kiai_sections.append({
			"start_time": duration * 0.65,
			"end_time": duration * 0.65 + 15.0
		})

func _process(delta):
	if not main_node:
		return
	
	var audio_player = main_node.get_node_or_null("AudioStreamPlayer")
	if not audio_player or not audio_player.playing:
		return
	
	var current_time = main_node.get_precise_music_time() if main_node.has_method("get_precise_music_time") else audio_player.get_playback_position()
	
	# Vérifier si on est dans une section kiai
	var was_kiai = is_kiai_active
	is_kiai_active = false
	
	for section in kiai_sections:
		if current_time >= section.start_time and current_time <= section.end_time:
			is_kiai_active = true
			break
	
	# Événements de transition
	if is_kiai_active and not was_kiai:
		start_kiai()
	elif not is_kiai_active and was_kiai:
		end_kiai()
	
	# Mise à jour des effets
	if is_kiai_active:
		update_kiai_effects(delta, current_time)
	
	# Mise à jour des particules (même hors kiai pour le fade out)
	update_particles(delta)
	
	queue_redraw()

func start_kiai():
	## Démarre les effets kiai
	kiai_started.emit()
	current_color_index = (current_color_index + 1) % kiai_colors.size()
	
	# Flash initial
	glow_intensity = 1.0
	
	# Réduire le background dim pendant kiai
	if main_node.has_method("set_background_dim"):
		main_node.set_background_dim(0.1)
	
	print("🌟 KIAI TIME START!")

func end_kiai():
	## Termine les effets kiai
	kiai_ended.emit()
	
	# Restaurer le background dim
	if main_node.has_method("set_background_dim"):
		main_node.set_background_dim(0.3)
	
	print("🌟 KIAI TIME END")

func update_kiai_effects(delta: float, current_time: float):
	## Met à jour les effets pendant le kiai
	
	# Pulse sur les beats (simulé)
	beat_pulse = 0.5 + 0.5 * sin(current_time * (bpm / 60.0) * TAU)
	
	# Glow qui pulse
	glow_intensity = lerp(glow_intensity, 0.3 + beat_pulse * 0.4, delta * 5.0)
	
	# Spawn des étoiles
	time_since_last_star += delta
	if time_since_last_star >= STAR_SPAWN_RATE and star_particles.size() < MAX_STARS:
		spawn_star()
		time_since_last_star = 0
	
	# Spawn fountain particles sur les côtés
	if randf() < 0.3 and fountain_particles.size() < MAX_FOUNTAIN:
		spawn_fountain_particle()

func spawn_star():
	## Crée une étoile qui tombe
	var screen_width = get_viewport_rect().size.x
	star_particles.append({
		"pos": Vector2(randf() * screen_width, -20),
		"vel": Vector2(randf_range(-30, 30), randf_range(100, 200)),
		"rotation": randf() * TAU,
		"spin": randf_range(-3, 3),
		"size": randf_range(8, 20),
		"alpha": 1.0,
		"color": kiai_colors[current_color_index].lerp(Color.WHITE, randf() * 0.5)
	})

func spawn_fountain_particle():
	## Crée une particule de fontaine sur les côtés
	var screen_height = get_viewport_rect().size.y
	var from_left = randf() > 0.5
	
	fountain_particles.append({
		"pos": Vector2(0 if from_left else get_viewport_rect().size.x, screen_height),
		"vel": Vector2(randf_range(100, 200) * (1 if from_left else -1), randf_range(-300, -150)),
		"size": randf_range(5, 12),
		"alpha": 1.0,
		"gravity": 200.0,
		"color": kiai_colors[current_color_index]
	})

func update_particles(delta: float):
	## Met à jour toutes les particules
	
	# Étoiles
	var stars_to_remove = []
	for i in range(star_particles.size()):
		var star = star_particles[i]
		star.pos += star.vel * delta
		star.rotation += star.spin * delta
		star.alpha -= delta * 0.5
		
		if star.alpha <= 0 or star.pos.y > get_viewport_rect().size.y + 50:
			stars_to_remove.append(i)
	
	for i in range(stars_to_remove.size() - 1, -1, -1):
		star_particles.remove_at(stars_to_remove[i])
	
	# Fontaines
	var fountain_to_remove = []
	for i in range(fountain_particles.size()):
		var p = fountain_particles[i]
		p.vel.y += p.gravity * delta
		p.pos += p.vel * delta
		p.alpha -= delta * 1.5
		
		if p.alpha <= 0 or p.pos.y > get_viewport_rect().size.y + 50:
			fountain_to_remove.append(i)
	
	for i in range(fountain_to_remove.size() - 1, -1, -1):
		fountain_particles.remove_at(fountain_to_remove[i])
	
	# Fade du glow hors kiai
	if not is_kiai_active:
		glow_intensity = lerp(glow_intensity, 0.0, delta * 3.0)

func _draw():
	# Glow overlay
	if glow_intensity > 0.01:
		var glow_color = kiai_colors[current_color_index]
		glow_color.a = glow_intensity * 0.15
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), glow_color)
	
	# Étoiles
	for star in star_particles:
		draw_star(star.pos, star.size, star.rotation, star.color, star.alpha)
	
	# Fontaines
	for p in fountain_particles:
		var col = p.color
		col.a = p.alpha
		draw_circle(p.pos, p.size, col)
		# Glow
		col.a = p.alpha * 0.3
		draw_circle(p.pos, p.size * 2, col)

func draw_star(pos: Vector2, size: float, rotation: float, color: Color, alpha: float):
	## Dessine une étoile à 5 branches
	var points = PackedVector2Array()
	var inner_size = size * 0.4
	
	for i in range(10):
		var angle = rotation + (float(i) / 10.0) * TAU - PI / 2
		var r = size if i % 2 == 0 else inner_size
		points.append(pos + Vector2(cos(angle), sin(angle)) * r)
	
	var col = color
	col.a = alpha
	draw_colored_polygon(points, col)
	
	# Glow
	col.a = alpha * 0.4
	for i in range(10):
		var angle = rotation + (float(i) / 10.0) * TAU - PI / 2
		var r = (size if i % 2 == 0 else inner_size) * 1.5
		points[i] = pos + Vector2(cos(angle), sin(angle)) * r
	draw_colored_polygon(points, col)

func trigger_beat_effect():
	## Appelé sur chaque hit pour intensifier les effets pendant kiai
	if is_kiai_active:
		glow_intensity = min(1.0, glow_intensity + 0.2)
		
		# Spawn extra stars
		for i in range(3):
			spawn_star()
