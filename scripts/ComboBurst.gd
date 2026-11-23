extends Node2D
class_name ComboBurst

## Combo Burst - Images qui apparaissent à certains milestones de combo
## Style osu! avec personnages/images qui surgissent sur le côté

# === CONFIGURATION ===
var burst_thresholds := [50, 100, 150, 200, 300, 500, 750, 1000]
var last_burst_threshold := 0

# === VISUALS ===
var burst_sprite: Sprite2D
var burst_label: Label
var is_showing := false

# Positions d'apparition (gauche ou droite)
var left_position := Vector2(-150, 400)
var right_position := Vector2(1200, 400)
var target_left := Vector2(50, 400)
var target_right := Vector2(1000, 400)
var use_left := true

# Couleurs selon le milestone
var milestone_colors := {
	50: Color(0.5, 1.0, 0.5),    # Vert clair
	100: Color(1.0, 1.0, 0.3),   # Jaune
	150: Color(1.0, 0.7, 0.3),   # Orange clair
	200: Color(1.0, 0.5, 0.2),   # Orange
	300: Color(1.0, 0.3, 0.3),   # Rouge
	500: Color(1.0, 0.2, 0.5),   # Rose
	750: Color(0.8, 0.3, 1.0),   # Violet
	1000: Color(1.0, 0.84, 0.0)  # Or
}

func _ready():
	setup_visuals()
	visible = false

func setup_visuals():
	# Créer le sprite de burst (cercle avec effet)
	burst_sprite = Sprite2D.new()
	burst_sprite.name = "BurstSprite"
	add_child(burst_sprite)
	
	# Créer une texture procédurale (étoile/burst)
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	create_burst_image(img)
	burst_sprite.texture = ImageTexture.create_from_image(img)
	burst_sprite.scale = Vector2(1.5, 1.5)
	
	# Label pour le nombre
	burst_label = Label.new()
	burst_label.name = "BurstLabel"
	burst_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	burst_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	burst_label.add_theme_font_size_override("font_size", 48)
	burst_label.add_theme_color_override("font_color", Color.WHITE)
	burst_label.add_theme_color_override("font_outline_color", Color.BLACK)
	burst_label.add_theme_constant_override("outline_size", 4)
	burst_label.position = Vector2(-50, -30)
	burst_label.size = Vector2(100, 60)
	add_child(burst_label)

func create_burst_image(img: Image):
	## Crée une image d'étoile/burst procéduralement
	var center = Vector2(64, 64)
	var outer_radius = 60.0
	var inner_radius = 25.0
	var points = 8
	
	for x in range(128):
		for y in range(128):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			var angle = (pos - center).angle()
			
			# Calculer le rayon de l'étoile à cet angle
			var star_angle = fmod(angle + PI, TAU / points)
			var star_t = abs(star_angle - TAU / (points * 2)) / (TAU / (points * 2))
			var star_radius = lerp(outer_radius, inner_radius, star_t)
			
			if dist <= star_radius:
				var alpha = 1.0 - (dist / star_radius) * 0.3
				var glow = exp(-dist * 0.03)
				img.set_pixel(x, y, Color(1, 1, 1, alpha * glow))
			elif dist <= star_radius + 10:
				var glow = exp(-(dist - star_radius) * 0.3)
				img.set_pixel(x, y, Color(1, 1, 1, glow * 0.5))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

func check_combo(combo: int):
	## Vérifie si on doit afficher un burst
	for threshold in burst_thresholds:
		if combo >= threshold and last_burst_threshold < threshold:
			show_burst(threshold)
			last_burst_threshold = threshold
			return

func show_burst(milestone: int):
	## Affiche le burst pour un milestone
	if is_showing:
		return
	
	is_showing = true
	visible = true
	
	# Alterner côté gauche/droite
	var start_pos = left_position if use_left else right_position
	var target_pos = target_left if use_left else target_right
	use_left = not use_left
	
	position = start_pos
	modulate = Color.WHITE
	modulate.a = 0
	scale = Vector2(0.5, 0.5)
	
	# Couleur selon le milestone
	var burst_color = milestone_colors.get(milestone, Color.WHITE)
	burst_sprite.modulate = burst_color
	burst_label.text = "%d!" % milestone
	
	# Animation d'entrée
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Slide in + fade in
	tween.tween_property(self, "position", target_pos, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	
	# Pulse
	tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Rotation légère
	tween.parallel().tween_property(burst_sprite, "rotation", 0.2 if use_left else -0.2, 0.3)
	
	# Attendre puis fade out
	tween.chain().tween_interval(0.8)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(hide_burst)

func hide_burst():
	is_showing = false
	visible = false
	burst_sprite.rotation = 0

func reset():
	## Reset pour une nouvelle partie
	last_burst_threshold = 0
	hide_burst()
