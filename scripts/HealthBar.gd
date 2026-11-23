extends Control
class_name HealthBar

## Barre de vie style osu!lazer
## La vie descend quand on miss et remonte quand on hit

# === NODES ===
@onready var background_bar: ColorRect
@onready var health_fill: ColorRect
@onready var glow_effect: ColorRect

# === CONFIGURATION ===
@export var max_health: float = 100.0
@export var drain_rate: float = 2.0  # HP perdu par seconde (passive drain)
@export var miss_damage: float = 15.0
@export var good_heal: float = 3.0
@export var perfect_heal: float = 6.0

# === STATE ===
var current_health: float = 100.0
var is_draining: bool = false
var target_health: float = 100.0  # Pour animation smooth
var health_tween: Tween

# Couleurs selon le niveau de vie
var color_full := Color(0.2, 1.0, 0.4)      # Vert
var color_medium := Color(1.0, 0.8, 0.2)    # Jaune
var color_low := Color(1.0, 0.3, 0.2)       # Rouge
var color_critical := Color(1.0, 0.1, 0.1)  # Rouge vif

signal health_depleted  # Émis quand HP = 0
signal health_critical  # Émis quand HP < 20%

func _ready():
	setup_visuals()
	current_health = max_health
	target_health = max_health
	update_visual()

func setup_visuals():
	# Background sombre de la barre
	background_bar = ColorRect.new()
	background_bar.name = "BackgroundBar"
	background_bar.color = Color(0.1, 0.1, 0.15, 0.9)
	background_bar.custom_minimum_size = Vector2(300, 20)
	background_bar.size = Vector2(300, 20)
	add_child(background_bar)
	
	# Barre de remplissage
	health_fill = ColorRect.new()
	health_fill.name = "HealthFill"
	health_fill.color = color_full
	health_fill.custom_minimum_size = Vector2(300, 20)
	health_fill.size = Vector2(300, 20)
	background_bar.add_child(health_fill)
	
	# Effet de glow
	glow_effect = ColorRect.new()
	glow_effect.name = "GlowEffect"
	glow_effect.color = Color(1, 1, 1, 0.3)
	glow_effect.custom_minimum_size = Vector2(300, 4)
	glow_effect.size = Vector2(300, 4)
	glow_effect.position = Vector2(0, 2)
	health_fill.add_child(glow_effect)
	
	# Bordure
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color(0.4, 0.4, 0.5, 1.0)
	border.custom_minimum_size = Vector2(304, 24)
	border.size = Vector2(304, 24)
	border.position = Vector2(-2, -2)
	border.z_index = -1
	background_bar.add_child(border)

func _process(delta):
	# Passive drain quand le jeu est en cours
	if is_draining and current_health > 0:
		current_health -= drain_rate * delta
		current_health = max(0, current_health)
		target_health = current_health
		update_visual()
		
		if current_health <= 0:
			health_depleted.emit()

func update_visual():
	if not health_fill:
		return
	
	var health_ratio = current_health / max_health
	
	# Mise à jour de la largeur de la barre
	var bar_width = 300.0 * health_ratio
	health_fill.size.x = bar_width
	if glow_effect:
		glow_effect.size.x = bar_width
	
	# Mise à jour de la couleur selon le niveau
	var new_color: Color
	if health_ratio > 0.6:
		new_color = color_full.lerp(color_medium, 1.0 - (health_ratio - 0.6) / 0.4)
	elif health_ratio > 0.3:
		new_color = color_medium.lerp(color_low, 1.0 - (health_ratio - 0.3) / 0.3)
	else:
		new_color = color_low.lerp(color_critical, 1.0 - health_ratio / 0.3)
		# Effet de pulse quand critique
		if health_ratio < 0.2:
			var pulse = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
			new_color.a = pulse
			health_critical.emit()
	
	health_fill.color = new_color

func start_drain():
	## Commence le drain passif de vie
	is_draining = true

func stop_drain():
	## Arrête le drain passif
	is_draining = false

func take_damage(amount: float = -1.0):
	## Inflige des dégâts (miss)
	if amount < 0:
		amount = miss_damage
	
	current_health = max(0, current_health - amount)
	target_health = current_health
	
	# Animation de flash rouge
	flash_damage()
	update_visual()
	
	if current_health <= 0:
		health_depleted.emit()

func heal(amount: float):
	## Soigne (hit réussi)
	current_health = min(max_health, current_health + amount)
	target_health = current_health
	
	# Animation de flash vert
	flash_heal()
	update_visual()

func register_hit(accuracy: String):
	## Enregistre un hit et ajuste la vie en conséquence
	match accuracy:
		"Perfect":
			heal(perfect_heal)
		"Good":
			heal(good_heal)
		"Miss":
			take_damage(miss_damage)

func flash_damage():
	## Flash rouge quand on prend des dégâts
	if health_tween:
		health_tween.kill()
	
	var original_color = health_fill.color
	health_fill.color = Color.RED
	
	health_tween = create_tween()
	health_tween.tween_property(health_fill, "color", original_color, 0.2)

func flash_heal():
	## Flash blanc/vert quand on heal
	if health_tween:
		health_tween.kill()
	
	var original_color = health_fill.color
	health_fill.color = Color.WHITE
	
	health_tween = create_tween()
	health_tween.tween_property(health_fill, "color", original_color, 0.15)

func reset():
	## Remet la vie au maximum
	current_health = max_health
	target_health = max_health
	is_draining = false
	update_visual()

func get_health_ratio() -> float:
	return current_health / max_health

func set_difficulty_multipliers(difficulty: String):
	## Ajuste les paramètres selon la difficulté
	match difficulty:
		"easy":
			drain_rate = 1.0
			miss_damage = 10.0
			good_heal = 5.0
			perfect_heal = 8.0
		"normal":
			drain_rate = 2.0
			miss_damage = 15.0
			good_heal = 3.0
			perfect_heal = 6.0
		"hard":
			drain_rate = 3.5
			miss_damage = 20.0
			good_heal = 2.0
			perfect_heal = 4.0
		"expert":
			drain_rate = 5.0
			miss_damage = 25.0
			good_heal = 1.0
			perfect_heal = 3.0
