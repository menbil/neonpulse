extends Node
class_name ComboColorManager

## Gestionnaire des couleurs de combo style osu!
## Cycle entre 4-8 couleurs pour différencier les notes

# === COULEURS DE COMBO (style osu!) ===
var combo_colors: Array[Color] = [
	Color(1.0, 0.4, 0.6),    # Rose/Magenta
	Color(0.4, 0.8, 1.0),    # Cyan clair
	Color(1.0, 0.9, 0.3),    # Jaune
	Color(0.5, 1.0, 0.5),    # Vert clair
	Color(1.0, 0.6, 0.3),    # Orange
	Color(0.7, 0.5, 1.0),    # Violet
	Color(0.3, 0.9, 0.9),    # Turquoise
	Color(1.0, 0.5, 0.5),    # Rouge clair
]

# === PRESETS DE COULEURS ===
var color_presets = {
	"default": [
		Color(1.0, 0.4, 0.6),
		Color(0.4, 0.8, 1.0),
		Color(1.0, 0.9, 0.3),
		Color(0.5, 1.0, 0.5),
	],
	"neon": [
		Color(1.0, 0.0, 0.5),   # Rose néon
		Color(0.0, 1.0, 1.0),   # Cyan néon
		Color(1.0, 1.0, 0.0),   # Jaune néon
		Color(0.0, 1.0, 0.0),   # Vert néon
	],
	"pastel": [
		Color(1.0, 0.7, 0.8),   # Rose pastel
		Color(0.7, 0.9, 1.0),   # Bleu pastel
		Color(1.0, 1.0, 0.7),   # Jaune pastel
		Color(0.7, 1.0, 0.8),   # Vert pastel
	],
	"rainbow": [
		Color(1.0, 0.3, 0.3),   # Rouge
		Color(1.0, 0.6, 0.2),   # Orange
		Color(1.0, 1.0, 0.3),   # Jaune
		Color(0.4, 1.0, 0.4),   # Vert
		Color(0.3, 0.8, 1.0),   # Cyan
		Color(0.5, 0.5, 1.0),   # Bleu
		Color(0.8, 0.4, 1.0),   # Violet
		Color(1.0, 0.4, 0.8),   # Magenta
	],
	"monochrome": [
		Color(0.9, 0.9, 0.9),   # Blanc
		Color(0.7, 0.7, 0.7),   # Gris clair
		Color(0.5, 0.5, 0.5),   # Gris moyen
		Color(0.8, 0.8, 0.8),   # Gris très clair
	]
}

# === STATE ===
var current_combo_index: int = 0
var current_preset: String = "default"
var notes_per_combo: int = 1  # Combien de notes avant de changer de couleur

# Compteur pour le changement de couleur
var note_counter: int = 0

func _ready():
	load_preset(current_preset)

func load_preset(preset_name: String):
	## Charge un preset de couleurs
	if color_presets.has(preset_name):
		combo_colors.clear()
		for color in color_presets[preset_name]:
			combo_colors.append(color)
		current_preset = preset_name
		current_combo_index = 0

func get_current_color() -> Color:
	## Retourne la couleur actuelle du combo
	if combo_colors.is_empty():
		return Color.WHITE
	return combo_colors[current_combo_index % combo_colors.size()]

func get_next_color() -> Color:
	## Retourne la prochaine couleur du combo
	if combo_colors.is_empty():
		return Color.WHITE
	return combo_colors[(current_combo_index + 1) % combo_colors.size()]

func get_color_for_index(index: int) -> Color:
	## Retourne la couleur pour un index de note donné
	if combo_colors.is_empty():
		return Color.WHITE
	var color_index = (index / notes_per_combo) % combo_colors.size()
	return combo_colors[color_index]

func advance_color():
	## Passe à la couleur suivante
	note_counter += 1
	if note_counter >= notes_per_combo:
		current_combo_index = (current_combo_index + 1) % combo_colors.size()
		note_counter = 0

func reset():
	## Remet le compteur de couleur à zéro
	current_combo_index = 0
	note_counter = 0

func on_combo_break():
	## Appelé quand le combo est cassé - passe à la couleur suivante
	advance_color()

func get_complementary_color(color: Color) -> Color:
	## Retourne une couleur complémentaire pour les effets
	var h = color.h
	var s = color.s
	var v = color.v
	# Rotation de 180° sur la roue chromatique
	h = fmod(h + 0.5, 1.0)
	return Color.from_hsv(h, s, v)

func get_lighter_shade(color: Color, amount: float = 0.3) -> Color:
	## Retourne une version plus claire de la couleur
	return color.lightened(amount)

func get_darker_shade(color: Color, amount: float = 0.3) -> Color:
	## Retourne une version plus sombre de la couleur
	return color.darkened(amount)

func set_custom_colors(colors: Array):
	## Définit des couleurs personnalisées
	combo_colors.clear()
	for color in colors:
		if color is Color:
			combo_colors.append(color)
		elif color is String:
			combo_colors.append(Color(color))

func set_notes_per_combo(count: int):
	## Définit combien de notes partagent la même couleur
	notes_per_combo = max(1, count)
