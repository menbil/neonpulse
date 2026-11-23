extends Control
class_name SkinManager

## Skin Manager - Système de skins style osu!
## Gère les textures et couleurs personnalisées

# === CURRENT SKIN ===
var current_skin: Dictionary = {}
var skin_name := "default"

# === PATHS ===
var skins_folder := "user://skins/"
var default_skin_folder := "res://skins/default/"

# === SKIN ELEMENTS ===
# Textures
var cursor_texture: Texture2D
var cursor_trail_texture: Texture2D
var hitcircle_texture: Texture2D
var hitcircle_overlay_texture: Texture2D
var approach_circle_texture: Texture2D
var slider_body_texture: Texture2D
var slider_ball_texture: Texture2D
var slider_reverse_texture: Texture2D
var spinner_bg_texture: Texture2D
var spinner_circle_texture: Texture2D
var hit0_texture: Texture2D  # Miss
var hit50_texture: Texture2D
var hit100_texture: Texture2D
var hit300_texture: Texture2D
var combo_burst_textures: Array[Texture2D] = []
var ranking_textures: Dictionary = {}  # SS, S, A, B, C, D

# Couleurs
var combo_colors: Array[Color] = [
	Color(1.0, 0.4, 0.4),  # Rouge
	Color(0.4, 1.0, 0.4),  # Vert
	Color(0.4, 0.6, 1.0),  # Bleu
	Color(1.0, 1.0, 0.4),  # Jaune
]

# Sounds (chemins)
var sound_paths: Dictionary = {}

# === SIGNALS ===
signal skin_loaded(skin_name: String)
signal skin_changed(skin_name: String)

func _ready():
	# Créer le dossier skins si nécessaire
	if not DirAccess.dir_exists_absolute(skins_folder):
		DirAccess.make_dir_recursive_absolute(skins_folder)
	
	# Charger le skin par défaut
	load_default_skin()

func load_default_skin():
	## Charge le skin par défaut (généré procéduralement si nécessaire)
	current_skin = {
		"name": "default",
		"author": "NeonPulse",
		"version": "1.0",
		
		# Colors
		"combo_colors": combo_colors,
		"menu_glow_color": Color(0.3, 0.8, 1.0),
		"slider_border_color": Color.WHITE,
		"slider_track_color": Color(0.2, 0.2, 0.2, 0.8),
		"spinner_color": Color(0.3, 0.8, 1.0),
		
		# Sizes
		"circle_radius": 50.0,
		"approach_scale": 4.0,
		"cursor_size": 20.0,
		
		# Font
		"hit_circle_font_size": 32,
		
		# Animation
		"hit_lighting": true,
		"slider_style": "modern",  # ou "legacy"
		"cursor_trail": true,
	}
	
	# Générer les textures par défaut
	generate_default_textures()
	
	skin_name = "default"
	skin_loaded.emit(skin_name)

func generate_default_textures():
	## Génère des textures procédurales pour le skin par défaut
	
	# Hitcircle
	hitcircle_texture = generate_circle_texture(100, Color.WHITE, 0.0)
	hitcircle_overlay_texture = generate_circle_texture(100, Color.WHITE, 0.9)
	approach_circle_texture = generate_ring_texture(200, Color.WHITE, 3.0)
	
	# Curseur
	cursor_texture = generate_cursor_texture()
	cursor_trail_texture = generate_cursor_trail_texture()

func generate_circle_texture(size: int, color: Color, alpha_center: float) -> ImageTexture:
	## Génère une texture de cercle avec dégradé
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0 - 2.0
	
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			if dist <= radius:
				var normalized = dist / radius
				var alpha = lerp(alpha_center, 1.0, normalized)
				var pixel_color = color
				pixel_color.a = alpha
				image.set_pixel(x, y, pixel_color)
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	var texture = ImageTexture.create_from_image(image)
	return texture

func generate_ring_texture(size: int, color: Color, thickness: float) -> ImageTexture:
	## Génère une texture d'anneau
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var outer_radius = size / 2.0 - 2.0
	var inner_radius = outer_radius - thickness
	
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			if dist >= inner_radius and dist <= outer_radius:
				# Antialiasing simple
				var alpha = 1.0
				if dist > outer_radius - 1.0:
					alpha = outer_radius - dist + 1.0
				elif dist < inner_radius + 1.0:
					alpha = dist - inner_radius + 1.0
				
				var pixel_color = color
				pixel_color.a = alpha
				image.set_pixel(x, y, pixel_color)
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	var texture = ImageTexture.create_from_image(image)
	return texture

func generate_cursor_texture() -> ImageTexture:
	## Génère une texture de curseur
	var size := 64
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var outer = size / 2.0 - 2.0
	var inner = outer - 4.0
	
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			# Cercle extérieur
			if dist >= inner and dist <= outer:
				var alpha = 1.0
				if dist > outer - 1.0:
					alpha = outer - dist + 1.0
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
			# Centre
			elif dist < 8:
				var alpha = 1.0 - dist / 8.0
				image.set_pixel(x, y, Color(1, 1, 1, alpha * 0.5))
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	return ImageTexture.create_from_image(image)

func generate_cursor_trail_texture() -> ImageTexture:
	## Génère une texture de trail
	var size := 32
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0 - 2.0
	
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			if dist <= radius:
				var alpha = 1.0 - (dist / radius)
				alpha = pow(alpha, 2)
				image.set_pixel(x, y, Color(1, 1, 1, alpha * 0.5))
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	return ImageTexture.create_from_image(image)

func load_skin(skin_path: String) -> bool:
	## Charge un skin depuis un dossier
	
	var config_path = skin_path + "/skin.ini"
	if not FileAccess.file_exists(config_path):
		push_warning("skin.ini not found in " + skin_path)
		return false
	
	# Parser le skin.ini
	var file = FileAccess.open(config_path, FileAccess.READ)
	var section := ""
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2)
		elif ":" in line:
			var parts = line.split(":", true, 1)
			var key = parts[0].strip_edges()
			var value = parts[1].strip_edges()
			
			parse_skin_value(section, key, value, skin_path)
	
	file.close()
	
	skin_name = skin_path.get_file()
	skin_changed.emit(skin_name)
	
	return true

func parse_skin_value(section: String, key: String, value: String, base_path: String):
	## Parse une valeur du skin.ini
	
	match section:
		"General":
			match key:
				"Name":
					current_skin["name"] = value
				"Author":
					current_skin["author"] = value
				"Version":
					current_skin["version"] = value
		
		"Colours":
			if key.begins_with("Combo"):
				var color = parse_color(value)
				var idx = key.replace("Combo", "").to_int() - 1
				if idx >= 0 and idx < 8:
					if combo_colors.size() <= idx:
						combo_colors.resize(idx + 1)
					combo_colors[idx] = color
		
		"Fonts":
			if key == "HitCircleOverlap":
				current_skin["hit_circle_overlap"] = value.to_int()

func parse_color(value: String) -> Color:
	## Parse une couleur RGB depuis un string "R,G,B"
	var parts = value.split(",")
	if parts.size() >= 3:
		return Color(
			parts[0].to_int() / 255.0,
			parts[1].to_int() / 255.0,
			parts[2].to_int() / 255.0
		)
	return Color.WHITE

func get_combo_color(combo: int) -> Color:
	## Retourne la couleur pour un combo donné
	if combo_colors.is_empty():
		return Color.WHITE
	return combo_colors[combo % combo_colors.size()]

func get_texture(element: String) -> Texture2D:
	## Retourne une texture du skin
	match element:
		"hitcircle":
			return hitcircle_texture
		"hitcircle_overlay":
			return hitcircle_overlay_texture
		"approach_circle":
			return approach_circle_texture
		"cursor":
			return cursor_texture
		"cursor_trail":
			return cursor_trail_texture
		_:
			return null

func get_skin_value(key: String, default_value = null):
	## Retourne une valeur du skin
	return current_skin.get(key, default_value)

func set_skin_value(key: String, value):
	## Définit une valeur du skin
	current_skin[key] = value

func list_available_skins() -> Array[String]:
	## Liste tous les skins disponibles
	var skins: Array[String] = ["default"]
	
	var dir = DirAccess.open(skins_folder)
	if dir:
		dir.list_dir_begin()
		var folder = dir.get_next()
		while folder != "":
			if dir.current_is_dir() and folder != "." and folder != "..":
				skins.append(folder)
			folder = dir.get_next()
	
	return skins

func create_skin_ini(skin_path: String):
	## Crée un fichier skin.ini template
	var content = """[General]
Name: Custom Skin
Author: Player
Version: 1.0

[Colours]
Combo1: 255,100,100
Combo2: 100,255,100
Combo3: 100,150,255
Combo4: 255,255,100

[Fonts]
HitCircleOverlap: -2
"""
	
	var file = FileAccess.open(skin_path + "/skin.ini", FileAccess.WRITE)
	file.store_string(content)
	file.close()
