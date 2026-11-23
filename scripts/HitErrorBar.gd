extends Control

# Hit Error Bar - Affiche la précision du timing (comme osu!)
# Vert = Perfect, Jaune = Good, Rouge = Late/Early

@export var bar_width := 400.0
@export var bar_height := 8.0
@export var perfect_threshold := 0.12
@export var good_threshold := 0.3

var hit_markers := []
var max_markers := 20
var marker_lifetime := 2.0

@onready var center_line: ColorRect
@onready var perfect_zone: ColorRect
@onready var good_zone_left: ColorRect
@onready var good_zone_right: ColorRect

func _ready():
	custom_minimum_size = Vector2(bar_width, bar_height + 40)
	
	# Créer la zone Good (gauche)
	good_zone_left = ColorRect.new()
	good_zone_left.color = Color(1.0, 1.0, 0.0, 0.3)
	good_zone_left.size = Vector2(bar_width * 0.3, bar_height)
	good_zone_left.position = Vector2(bar_width * 0.2, 20)
	add_child(good_zone_left)
	
	# Créer la zone Good (droite)
	good_zone_right = ColorRect.new()
	good_zone_right.color = Color(1.0, 1.0, 0.0, 0.3)
	good_zone_right.size = Vector2(bar_width * 0.3, bar_height)
	good_zone_right.position = Vector2(bar_width * 0.5, 20)
	add_child(good_zone_right)
	
	# Créer la zone Perfect (centre)
	perfect_zone = ColorRect.new()
	perfect_zone.color = Color(0.0, 1.0, 0.0, 0.4)
	perfect_zone.size = Vector2(bar_width * 0.3, bar_height)
	perfect_zone.position = Vector2(bar_width * 0.35, 20)
	add_child(perfect_zone)
	
	# Ligne centrale
	center_line = ColorRect.new()
	center_line.color = Color.WHITE
	center_line.size = Vector2(2, bar_height + 8)
	center_line.position = Vector2(bar_width * 0.5 - 1, 16)
	add_child(center_line)

func _process(delta):
	# Faire vieillir et supprimer les anciens markers
	for i in range(hit_markers.size() - 1, -1, -1):
		hit_markers[i].lifetime += delta
		if hit_markers[i].lifetime > marker_lifetime:
			hit_markers[i].marker.queue_free()
			hit_markers.remove_at(i)
		else:
			# Fade out progressif
			var alpha = 1.0 - (hit_markers[i].lifetime / marker_lifetime)
			hit_markers[i].marker.modulate.a = alpha

func add_hit_error(time_diff: float, accuracy: String):
	# time_diff: négatif = trop tôt, positif = trop tard
	
	# Calculer la position sur la barre
	# Normaliser entre -good_threshold et +good_threshold
	var normalized = clamp(time_diff / good_threshold, -1.0, 1.0)
	var x_pos = (bar_width * 0.5) + (normalized * bar_width * 0.3)
	
	# Créer le marker
	var marker = ColorRect.new()
	marker.size = Vector2(3, bar_height + 4)
	marker.position = Vector2(x_pos - 1.5, 18)
	
	# Couleur selon accuracy
	match accuracy:
		"Perfect":
			marker.color = Color.GREEN
		"Good":
			marker.color = Color.YELLOW
		_:
			marker.color = Color.RED
	
	add_child(marker)
	
	# Stocker le marker
	hit_markers.append({
		"marker": marker,
		"lifetime": 0.0
	})
	
	# Limiter le nombre de markers
	if hit_markers.size() > max_markers:
		hit_markers[0].marker.queue_free()
		hit_markers.remove_at(0)

func clear_markers():
	for hit_data in hit_markers:
		hit_data.marker.queue_free()
	hit_markers.clear()
