extends Node2D
class_name HitEffect

## Hit Effect amélioré style osu!lazer
## Particules burst + ripple + numbers flottants

# Particules de hit avec effet néon
var particles: Array[Dictionary] = []
var ring_scale := 0.0
var ring_alpha := 0.0
var flash_alpha := 0.0
var is_playing := false

# === P1: AMÉLIORATIONS ===
var ripple_rings: Array[Dictionary] = []  # Plusieurs ripples
var star_particles: Array[Dictionary] = []  # Étoiles qui tournent
var combo_number := 0  # Numéro du combo à afficher
var number_alpha := 0.0
var number_scale := 1.0
var number_y_offset := 0.0

# Couleurs selon le type de hit
var effect_color := Color.CYAN
var secondary_color := Color.WHITE

const PARTICLE_COUNT := 16  # Plus de particules
const STAR_COUNT := 8  # Étoiles
const RING_DURATION := 0.5
const FLASH_DURATION := 0.2
const RIPPLE_COUNT := 3  # Nombre de ripples

func _ready():
	visible = false

func play_flash(accuracy := "Perfect", combo: int = 0):
	is_playing = true
	visible = true
	combo_number = combo
	
	# Couleur selon l'accuracy
	match accuracy:
		"Perfect":
			effect_color = Color(1.0, 0.84, 0.0)  # Or/Jaune brillant
			secondary_color = Color(1.0, 1.0, 0.8)
		"Good":
			effect_color = Color(0.0, 1.0, 0.5)  # Vert
			secondary_color = Color(0.7, 1.0, 0.8)
		_:
			effect_color = Color(0.5, 0.5, 0.5)  # Gris pour miss
			secondary_color = Color(0.7, 0.7, 0.7)
	
	# Reset des effets
	ring_scale = 0.0
	ring_alpha = 1.0
	flash_alpha = 1.0
	number_alpha = 1.0
	number_scale = 1.5
	number_y_offset = 0.0
	
	# === PARTICULES BURST ===
	particles.clear()
	for i in range(PARTICLE_COUNT):
		var angle = (float(i) / PARTICLE_COUNT) * TAU + randf_range(-0.2, 0.2)
		var speed = randf_range(200, 400)
		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"size": randf_range(5, 12),
			"alpha": 1.0,
			"rotation": randf() * TAU,
			"color": effect_color if randf() > 0.3 else secondary_color
		})
	
	# === ÉTOILES QUI TOURNENT ===
	star_particles.clear()
	for i in range(STAR_COUNT):
		var angle = (float(i) / STAR_COUNT) * TAU
		star_particles.append({
			"angle": angle,
			"radius": 20.0,
			"size": randf_range(8, 14),
			"alpha": 1.0,
			"spin": randf_range(3.0, 6.0) * (1 if randf() > 0.5 else -1)
		})
	
	# === RIPPLES MULTIPLES ===
	ripple_rings.clear()
	for i in range(RIPPLE_COUNT):
		ripple_rings.append({
			"scale": 0.0,
			"alpha": 1.0,
			"delay": i * 0.08,
			"started": false
		})
	
	# Lancer les tweens
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Ring principal
	tween.tween_property(self, "ring_scale", 100.0, RING_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "ring_alpha", 0.0, RING_DURATION).set_ease(Tween.EASE_IN)
	
	# Flash central
	tween.tween_property(self, "flash_alpha", 0.0, FLASH_DURATION).set_ease(Tween.EASE_OUT)
	
	# Numéro de combo qui monte
	tween.tween_property(self, "number_y_offset", -60.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "number_scale", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "number_alpha", 0.0, 0.6).set_delay(0.2)
	
	tween.chain().tween_callback(stop_effect)

func _process(delta):
	if not is_playing:
		return
	
	var time = Time.get_ticks_msec() / 1000.0
	
	# Mettre à jour les particules
	for p in particles:
		p.pos += p.vel * delta
		p.vel *= 0.92  # Friction
		p.alpha = max(0, p.alpha - delta * 2.5)
		p.size = max(1, p.size - delta * 8.0)
		p.rotation += delta * 5.0
	
	# Mettre à jour les étoiles
	for s in star_particles:
		s.angle += s.spin * delta
		s.radius += 80.0 * delta  # S'éloignent
		s.alpha = max(0, s.alpha - delta * 2.0)
		s.size = max(1, s.size - delta * 6.0)
	
	# Mettre à jour les ripples
	for r in ripple_rings:
		if not r.started:
			r.delay -= delta
			if r.delay <= 0:
				r.started = true
		else:
			r.scale += 200.0 * delta
			r.alpha = max(0, r.alpha - delta * 2.5)
	
	queue_redraw()

func _draw():
	if not is_playing:
		return
	
	# Flash central avec gradient
	if flash_alpha > 0:
		for i in range(3):
			var radius = (30 + i * 15) + (1.0 - flash_alpha) * 20
			var col = secondary_color
			col.a = flash_alpha * (0.6 - i * 0.15)
			draw_circle(Vector2.ZERO, radius, col)
	
	# Ripples multiples
	for r in ripple_rings:
		if r.started and r.alpha > 0:
			var ring_color = effect_color
			ring_color.a = r.alpha * 0.8
			draw_arc(Vector2.ZERO, r.scale, 0, TAU, 48, ring_color, 4.0)
			
			# Glow externe
			ring_color.a = r.alpha * 0.3
			draw_arc(Vector2.ZERO, r.scale + 8, 0, TAU, 48, ring_color, 12.0)
	
	# Ring principal
	if ring_alpha > 0:
		var ring_color = effect_color
		ring_color.a = ring_alpha
		draw_arc(Vector2.ZERO, ring_scale, 0, TAU, 48, ring_color, 5.0)
		
		# Double glow
		ring_color.a = ring_alpha * 0.5
		draw_arc(Vector2.ZERO, ring_scale + 6, 0, TAU, 48, ring_color, 10.0)
		ring_color.a = ring_alpha * 0.2
		draw_arc(Vector2.ZERO, ring_scale + 12, 0, TAU, 48, ring_color, 16.0)
	
	# Étoiles
	for s in star_particles:
		if s.alpha <= 0:
			continue
		var pos = Vector2(cos(s.angle), sin(s.angle)) * s.radius
		var col = secondary_color
		col.a = s.alpha
		draw_star(pos, s.size, col)
	
	# Particules burst
	for p in particles:
		if p.alpha <= 0:
			continue
		
		var col = p.color
		col.a = p.alpha
		
		# Glow
		var glow_col = col
		glow_col.a = col.a * 0.4
		draw_circle(p.pos, p.size * 2, glow_col)
		
		# Core
		draw_circle(p.pos, p.size, col)
	
	# Numéro de combo flottant
	if number_alpha > 0 and combo_number > 0:
		draw_combo_number()

func draw_star(pos: Vector2, size: float, color: Color):
	## Dessine une étoile à 4 branches
	var points = PackedVector2Array()
	for i in range(8):
		var angle = (float(i) / 8.0) * TAU - PI / 2
		var r = size if i % 2 == 0 else size * 0.4
		points.append(pos + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, color)

func draw_combo_number():
	## Dessine le numéro de combo qui flotte vers le haut
	# Note: Pour un vrai rendu de texte, il faudrait un Label
	# Ici on dessine des cercles pour simuler
	var pos = Vector2(0, number_y_offset)
	var col = effect_color
	col.a = number_alpha
	
	# Fond sombre
	var bg_col = Color(0, 0, 0, number_alpha * 0.5)
	draw_circle(pos, 20 * number_scale, bg_col)
	
	# Cercle coloré
	draw_circle(pos, 16 * number_scale, col)

func stop_effect():
	is_playing = false
	visible = false
	particles.clear()
	star_particles.clear()
	ripple_rings.clear()
