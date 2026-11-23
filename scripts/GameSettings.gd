extends Node

# Paramètres de gameplay
var approach_speed := 1.0  # 0.5 = plus lent, 2.0 = plus rapide
var note_size := 1.0  # 0.8 = petites notes, 1.2 = grandes notes
var audio_offset := 0.0  # en secondes, peut être négatif
var visual_effects := true
var auto_play := false
var relax_mode := true
var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.8

# Paramètres de difficulté
var difficulty_modifier := 1.0
var enable_hold_notes := true
var enable_combos := true

# Paramètres visuels
var show_fps := false
var particles_enabled := true
var screen_shake := true
var background_brightness := 1.0
var hit_error_bar_enabled := true  # NOUVEAU
var approach_circle_enabled := true  # NOUVEAU

# Paramètres d'accessibilité
var colorblind_mode := false
var high_contrast := false
var note_trails := true

# Limites de validation
const MIN_APPROACH_SPEED := 0.5
const MAX_APPROACH_SPEED := 3.0
const MIN_NOTE_SIZE := 0.5
const MAX_NOTE_SIZE := 1.5
const MIN_AUDIO_OFFSET := -0.2  # -200ms
const MAX_AUDIO_OFFSET := 0.2   # +200ms

const SETTINGS_FILE = "user://game_settings.save"

func _ready():
	load_settings()

func save_settings():
	# Valider les valeurs avant sauvegarde
	approach_speed = clamp(approach_speed, MIN_APPROACH_SPEED, MAX_APPROACH_SPEED)
	note_size = clamp(note_size, MIN_NOTE_SIZE, MAX_NOTE_SIZE)
	audio_offset = clamp(audio_offset, MIN_AUDIO_OFFSET, MAX_AUDIO_OFFSET)
	master_volume = clamp(master_volume, 0.0, 1.0)
	music_volume = clamp(music_volume, 0.0, 1.0)
	sfx_volume = clamp(sfx_volume, 0.0, 1.0)
	
	var settings_data = {
		"approach_speed": approach_speed,
		"note_size": note_size,
		"audio_offset": audio_offset,
		"visual_effects": visual_effects,
		"auto_play": auto_play,
		"relax_mode": relax_mode,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"difficulty_modifier": difficulty_modifier,
		"enable_hold_notes": enable_hold_notes,
		"enable_combos": enable_combos,
		"show_fps": show_fps,
		"particles_enabled": particles_enabled,
		"screen_shake": screen_shake,
		"background_brightness": background_brightness,
		"colorblind_mode": colorblind_mode,
		"high_contrast": high_contrast,
		"note_trails": note_trails,
		"hit_error_bar_enabled": hit_error_bar_enabled,
		"approach_circle_enabled": approach_circle_enabled
	}
	
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data))
		file.close()

func load_settings():
	if FileAccess.file_exists(SETTINGS_FILE):
		var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var data = JSON.parse_string(json_text)
			if data:
				approach_speed = data.get("approach_speed", 1.0)
				note_size = data.get("note_size", 1.0)
				audio_offset = data.get("audio_offset", 0.0)
				visual_effects = data.get("visual_effects", true)
				auto_play = data.get("auto_play", false)
				relax_mode = data.get("relax_mode", true)
				master_volume = data.get("master_volume", 1.0)
				music_volume = data.get("music_volume", 0.8)
				sfx_volume = data.get("sfx_volume", 0.8)
				difficulty_modifier = data.get("difficulty_modifier", 1.0)
				enable_hold_notes = data.get("enable_hold_notes", true)
				enable_combos = data.get("enable_combos", true)
				show_fps = data.get("show_fps", false)
				particles_enabled = data.get("particles_enabled", true)
				screen_shake = data.get("screen_shake", true)
				background_brightness = data.get("background_brightness", 1.0)
				colorblind_mode = data.get("colorblind_mode", false)
				high_contrast = data.get("high_contrast", false)
				note_trails = data.get("note_trails", true)
				hit_error_bar_enabled = data.get("hit_error_bar_enabled", true)
				approach_circle_enabled = data.get("approach_circle_enabled", true)

func apply_audio_settings():
	var master_bus = AudioServer.get_bus_index("Master")
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))

func get_effective_approach_time(base_time: float) -> float:
	return base_time / approach_speed

func get_effective_note_scale() -> float:
	return note_size

func should_auto_play() -> bool:
	return auto_play

func should_relax() -> bool:
	return relax_mode
