extends Node2D
class_name FollowPointsManager

## Gestion des follow points style osu!lazer
## Points/lignes entre les notes successives pour guider le joueur

# === CONFIGURATION ===
@export var point_count: int = 5  # Nombre de points entre chaque note
@export var point_size: float = 8.0
@export var fade_time: float = 0.3
@export var point_spacing: float = 0.15  # Espacement temporel entre points

# === COULEURS ===
var point_color := Color(1.0, 1.0, 1.0, 0.5)
var active_color := Color(1.0, 0.8, 0.2, 0.8)

# === POOLS ===
var point_pool: Array[Sprite2D] = []
var active_connections: Array[Dictionary] = []
const POOL_SIZE = 100

# === REFERENCES ===
var main_node: Node
var audio_player: AudioStreamPlayer2D

func _ready():
	main_node = get_parent()
	if main_node:
		audio_player = main_node.get_node_or_null("AudioStreamPlayer")
	
	setup_point_pool()

func setup_point_pool():
	## Crée un pool de sprites pour les follow points
	for i in range(POOL_SIZE):
		var point = create_follow_point()
		point.visible = false
		point_pool.append(point)
		add_child(point)

func create_follow_point() -> Sprite2D:
	## Crée un follow point (cercle simple)
	var sprite = Sprite2D.new()
	
	# Créer une texture de cercle procéduralement
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var center = Vector2(8, 8)
	var radius = 6.0
	
	for x in range(16):
		for y in range(16):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				var alpha = 1.0 - (dist / radius) * 0.5
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	
	var texture = ImageTexture.create_from_image(img)
	sprite.texture = texture
	sprite.modulate = point_color
	
	return sprite

func update_follow_points(visible_notes: Array):
	## Met à jour les follow points entre les notes visibles
	# Reset tous les points
	for point in point_pool:
		point.visible = false
	
	if visible_notes.size() < 2:
		return
	
	# Trier par hit_time
	visible_notes.sort_custom(func(a, b): return a.hit_time < b.hit_time)
	
	var point_index = 0
	var current_time = 0.0
	if audio_player and audio_player.playing:
		current_time = main_node.get_precise_music_time() if main_node and main_node.has_method("get_precise_music_time") else audio_player.get_playback_position()
	
	# Créer des points entre chaque paire de notes successives
	for i in range(visible_notes.size() - 1):
		var note_a = visible_notes[i]
		var note_b = visible_notes[i + 1]
		
		# Ne pas afficher si la première note est déjà passée
		if note_a.hit_time < current_time:
			continue
		
		var pos_a = note_a.global_position
		var pos_b = note_b.global_position
		var distance = pos_a.distance_to(pos_b)
		
		# Ne pas afficher si les notes sont trop proches
		if distance < 50:
			continue
		
		# Calculer le nombre de points basé sur la distance
		var num_points = min(point_count, int(distance / 40))
		
		for j in range(1, num_points + 1):
			if point_index >= point_pool.size():
				break
			
			var t = float(j) / float(num_points + 1)
			var point_pos = pos_a.lerp(pos_b, t)
			
			var point = point_pool[point_index]
			point.global_position = point_pos
			point.visible = true
			
			# Calculer l'opacité basée sur le timing
			var time_ratio = (note_a.hit_time - current_time) / 2.0  # 2 secondes avant
			var alpha = clamp(1.0 - time_ratio, 0.0, 0.8)
			
			# Points plus petits vers la destination
			var scale_factor = 0.5 + 0.5 * (1.0 - t)
			point.scale = Vector2(scale_factor, scale_factor) * (point_size / 8.0)
			
			# Couleur avec fade
			point.modulate = point_color
			point.modulate.a = alpha * (0.3 + 0.7 * t)  # Plus visible vers la destination
			
			point_index += 1

func create_connection_animation(from_pos: Vector2, to_pos: Vector2, duration: float):
	## Crée une animation de connexion quand on hit une note
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = active_color
	line.add_point(from_pos)
	line.add_point(to_pos)
	add_child(line)
	
	# Animation de fade out
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, duration)
	tween.finished.connect(func(): line.queue_free())

func pulse_point_at(position: Vector2):
	## Fait pulser les points près d'une position (quand on hit)
	for point in point_pool:
		if point.visible and point.global_position.distance_to(position) < 100:
			var tween = create_tween()
			tween.tween_property(point, "scale", point.scale * 1.5, 0.1)
			tween.tween_property(point, "scale", point.scale, 0.1)
