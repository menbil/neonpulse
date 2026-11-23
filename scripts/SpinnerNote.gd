extends Area2D
class_name SpinnerNote

## Spinner Note - Note de rotation style osu!
## Le joueur doit tourner la souris/doigt autour du centre

# === STATE ===
enum SpinnerState { WAITING, ACTIVE, COMPLETED, FAILED }
var current_state = SpinnerState.WAITING

# === TIMING ===
var start_time := 0.0
var end_time := 0.0
var duration := 3.0

# === SPIN TRACKING ===
var total_rotations := 0.0
var required_rotations := 5.0
var last_angle := 0.0
var spin_velocity := 0.0
var is_spinning := false

# === VISUALS ===
var outer_ring: Node2D
var inner_circle: Node2D
var progress_arc: Node2D
var spin_meter: ColorRect
var bonus_label: Label

# === EFFECTS ===
var glow_intensity := 0.0
var particles: Array[Dictionary] = []

# === REFERENCES ===
var main_node: Node
var audio_player: AudioStreamPlayer2D

# === CONFIGURATION ===
var spinner_color := Color(0.3, 0.8, 1.0)
var bonus_per_extra_spin := 100

signal spinner_completed(bonus_score: int)
signal spinner_failed

func _ready():
	setup_visuals()
	visible = false

func setup_visuals():
	# Anneau extérieur
	outer_ring = Node2D.new()
	outer_ring.name = "OuterRing"
	add_child(outer_ring)
	
	# Cercle intérieur
	inner_circle = Node2D.new()
	inner_circle.name = "InnerCircle"
	add_child(inner_circle)
	
	# Progress arc
	progress_arc = Node2D.new()
	progress_arc.name = "ProgressArc"
	add_child(progress_arc)
	
	# Meter de spin
	spin_meter = ColorRect.new()
	spin_meter.name = "SpinMeter"
	spin_meter.color = spinner_color
	spin_meter.size = Vector2(10, 0)
	spin_meter.position = Vector2(-5, 0)
	add_child(spin_meter)
	
	# Label bonus
	bonus_label = Label.new()
	bonus_label.name = "BonusLabel"
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_label.add_theme_font_size_override("font_size", 30)
	bonus_label.add_theme_color_override("font_color", Color.WHITE)
	bonus_label.position = Vector2(-50, -150)
	bonus_label.size = Vector2(100, 40)
	bonus_label.visible = false
	add_child(bonus_label)
	
	# Collision shape (grand cercle)
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 150
	collision.shape = shape
	add_child(collision)

func setup(data: Dictionary):
	start_time = data.get("time", 0.0)
	duration = data.get("duration", 3.0)
	end_time = start_time + duration
	required_rotations = data.get("required_spins", 5.0)
	position = Vector2(data.get("x", 576), data.get("y", 324))
	
	# Reset state
	current_state = SpinnerState.WAITING
	total_rotations = 0.0
	last_angle = 0.0
	spin_velocity = 0.0
	glow_intensity = 0.0
	particles.clear()
	bonus_label.visible = false
	
	visible = true

func _process(delta):
	if not visible:
		return
	
	main_node = get_node_or_null("/root/Main")
	if main_node:
		audio_player = main_node.get_node_or_null("AudioStreamPlayer")
	
	if not audio_player or not audio_player.playing:
		return
	
	var current_time = audio_player.get_playback_position()
	
	match current_state:
		SpinnerState.WAITING:
			if current_time >= start_time:
				current_state = SpinnerState.ACTIVE
				is_spinning = false
		
		SpinnerState.ACTIVE:
			update_spinning(delta)
			
			# Vérifier si terminé
			if total_rotations >= required_rotations:
				complete_spinner()
			elif current_time >= end_time:
				fail_spinner()
		
		SpinnerState.COMPLETED, SpinnerState.FAILED:
			# Fade out
			modulate.a -= delta * 2
			if modulate.a <= 0:
				visible = false
	
	# Mettre à jour les particules
	update_particles(delta)
	
	queue_redraw()

func update_spinning(delta: float):
	## Détecte et calcule la rotation de la souris
	var mouse_pos = get_local_mouse_position()
	var current_angle = mouse_pos.angle()
	
	# Détecter le clic maintenu
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_spinning:
			is_spinning = true
			last_angle = current_angle
		else:
			# Calculer la différence d'angle
			var angle_diff = current_angle - last_angle
			
			# Normaliser entre -PI et PI
			while angle_diff > PI:
				angle_diff -= TAU
			while angle_diff < -PI:
				angle_diff += TAU
			
			# Accumuler les rotations
			total_rotations += abs(angle_diff) / TAU
			spin_velocity = abs(angle_diff) / delta
			
			last_angle = current_angle
			
			# Spawn particles pendant le spin
			if spin_velocity > 1.0 and randf() < 0.3:
				spawn_spin_particle(mouse_pos)
	else:
		is_spinning = false
		spin_velocity *= 0.9  # Decay
	
	# Glow basé sur la vitesse
	glow_intensity = lerp(glow_intensity, min(1.0, spin_velocity * 0.5), delta * 5.0)

func spawn_spin_particle(pos: Vector2):
	var angle = randf() * TAU
	particles.append({
		"pos": pos,
		"vel": Vector2(cos(angle), sin(angle)) * randf_range(50, 150),
		"size": randf_range(3, 8),
		"alpha": 1.0,
		"color": spinner_color.lerp(Color.WHITE, randf() * 0.5)
	})

func update_particles(delta: float):
	var to_remove = []
	for i in range(particles.size()):
		var p = particles[i]
		p.pos += p.vel * delta
		p.alpha -= delta * 2
		p.size = max(1, p.size - delta * 5)
		if p.alpha <= 0:
			to_remove.append(i)
	
	for i in range(to_remove.size() - 1, -1, -1):
		particles.remove_at(to_remove[i])

func complete_spinner():
	current_state = SpinnerState.COMPLETED
	
	# Calculer le bonus pour les rotations supplémentaires
	var extra_rotations = total_rotations - required_rotations
	var bonus = int(extra_rotations * bonus_per_extra_spin)
	
	# Afficher le bonus
	bonus_label.text = "+%d" % (1000 + bonus)
	bonus_label.visible = true
	
	# Animation
	var tween = create_tween()
	tween.tween_property(bonus_label, "position:y", bonus_label.position.y - 50, 0.5)
	
	spinner_completed.emit(1000 + bonus)
	
	if main_node and main_node.has_method("register_hit"):
		main_node.register_hit("Perfect", global_position, 1.0, 0.0)

func fail_spinner():
	current_state = SpinnerState.FAILED
	spinner_failed.emit()
	
	if main_node and main_node.has_method("register_hit"):
		main_node.register_hit("Miss", global_position, 1.0, 0.0)

func _draw():
	if not visible or current_state == SpinnerState.WAITING:
		return
	
	var progress = total_rotations / required_rotations
	var outer_radius = 120.0
	var inner_radius = 40.0
	
	# Fond semi-transparent
	draw_circle(Vector2.ZERO, outer_radius + 20, Color(0, 0, 0, 0.5))
	
	# Anneau extérieur
	var ring_color = spinner_color
	ring_color.a = 0.5 + glow_intensity * 0.5
	draw_arc(Vector2.ZERO, outer_radius, 0, TAU, 64, ring_color, 5.0)
	
	# Glow
	if glow_intensity > 0.1:
		var glow_color = spinner_color
		glow_color.a = glow_intensity * 0.3
		draw_arc(Vector2.ZERO, outer_radius + 10, 0, TAU, 64, glow_color, 15.0)
	
	# Arc de progression
	var progress_color = Color.GREEN if progress >= 1.0 else spinner_color
	draw_arc(Vector2.ZERO, outer_radius - 10, -PI/2, -PI/2 + TAU * min(1.0, progress), 64, progress_color, 8.0)
	
	# Cercle intérieur (tourne avec le spin)
	var rotation_angle = total_rotations * TAU
	for i in range(4):
		var angle = rotation_angle + i * PI / 2
		var pos = Vector2(cos(angle), sin(angle)) * inner_radius
		draw_circle(pos, 8, spinner_color)
	
	# Centre
	draw_circle(Vector2.ZERO, 15, Color.WHITE)
	
	# Particules
	for p in particles:
		var col = p.color
		col.a = p.alpha
		draw_circle(p.pos, p.size, col)
	
	# Texte de progression
	if current_state == SpinnerState.ACTIVE:
		var spins_left = max(0, int(ceil(required_rotations - total_rotations)))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-20, outer_radius + 40),
			"%d" % spins_left,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 24,
			Color.WHITE if spins_left > 0 else Color.GREEN
		)

func _input_event(viewport, event, shape_idx):
	# Optionnel: gérer les inputs touch
	pass
