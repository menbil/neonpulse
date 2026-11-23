extends Node

# Mode d'entraînement avancé
var training_mode := false
var practice_speed := 1.0
var practice_section_start := 0.0
var practice_section_end := 0.0
var loop_section := false
var show_hit_timing := true
var metronome_enabled := false
var auto_restart := false

# Paramètres d'aide
var show_approach_rate := true
var highlight_next_notes := 3
var ghost_notes := false # Notes fantômes pour montrer le timing

signal practice_section_loop
signal training_stats_updated(stats)

func _ready():
	set_process(false) # Activé uniquement en mode training

func enable_training_mode():
	training_mode = true
	set_process(true)
	print("🎯 Mode d'entraînement activé")

func disable_training_mode():
	training_mode = false
	set_process(false)
	print("🎯 Mode d'entraînement désactivé")

func set_practice_section(start_time: float, end_time: float):
	practice_section_start = start_time
	practice_section_end = end_time
	loop_section = true
	print("📍 Section d'entraînement: %.2fs - %.2fs" % [start_time, end_time])

func set_practice_speed(speed: float):
	practice_speed = clamp(speed, 0.25, 2.0)
	# Application de la vitesse à l'AudioStreamPlayer
	var main_scene = get_tree().current_scene
	if main_scene.has_method("set_playback_speed"):
		main_scene.set_playback_speed(practice_speed)
	print("⏩ Vitesse d'entraînement: %.0f%%" % (practice_speed * 100))

func _process(delta):
	if not training_mode:
		return
	
	var main_scene = get_tree().current_scene
	if not main_scene.has_method("get_playback_position"):
		return
	
	var current_time = main_scene.get_playback_position()
	
	# Gestion du loop de section
	if loop_section and current_time >= practice_section_end:
		main_scene.seek_to_time(practice_section_start)
		emit_signal("practice_section_loop")
	
	# Métronome
	if metronome_enabled:
		play_metronome_tick(current_time)

func play_metronome_tick(current_time: float):
	# Simple métronome basé sur le BPM estimé
	var bpm = 120.0 # À récupérer depuis l'analyse audio
	var beat_interval = 60.0 / bpm
	var beat_progress = fmod(current_time, beat_interval)
	
	# Jouer un tick au début de chaque beat
	if beat_progress < 0.05: # 50ms de tolérance
		play_tick_sound()

func play_tick_sound():
	# TODO: Jouer un son de métronome
	pass

func get_training_recommendations(player_stats: Dictionary) -> Array:
	var recommendations = []
	
	var accuracy = player_stats.get("accuracy", 0.0)
	var max_combo = player_stats.get("max_combo", 0)
	var misses = player_stats.get("misses", 0)
	
	if accuracy < 90.0:
		recommendations.append({
			"type": "accuracy",
			"message": "Travaillez votre précision. Essayez le mode vitesse réduite.",
			"suggested_speed": 0.7
		})
	
	if max_combo < 20:
		recommendations.append({
			"type": "combo",
			"message": "Travaillez vos combos. Concentrez-vous sur la régularité.",
			"suggested_practice": "sections courtes en boucle"
		})
	
	if misses > player_stats.get("total_notes", 100) * 0.1:
		recommendations.append({
			"type": "timing",
			"message": "Trop de notes ratées. Activez l'aide visuelle.",
			"suggested_settings": {"show_approach_rate": true, "highlight_next_notes": 5}
		})
	
	return recommendations

func create_custom_practice_beatmap(original_beatmap: Array, focus_type: String) -> Array:
	var practice_beatmap = []
	
	match focus_type:
		"timing":
			# Simplifier en gardant seulement les notes de base
			for event in original_beatmap:
				if event.get("event_type") == "single_note":
					var note = event.get("note", {})
					if note.get("note_type") == "tap":
						practice_beatmap.append(event)
		
		"combos":
			# Garder seulement les combos
			for event in original_beatmap:
				if event.get("event_type") == "combo":
					practice_beatmap.append(event)
		
		"holds":
			# Garder seulement les notes hold
			for event in original_beatmap:
				if event.get("event_type") == "single_note":
					var note = event.get("note", {})
					if note.get("note_type") == "hold":
						practice_beatmap.append(event)
				elif event.get("event_type") == "combo":
					var filtered_notes = []
					for note in event.get("notes", []):
						if note.get("note_type") == "hold":
							filtered_notes.append(note)
					if filtered_notes.size() > 0:
						var new_event = event.duplicate()
						new_event["notes"] = filtered_notes
						practice_beatmap.append(new_event)
	
	return practice_beatmap

func analyze_difficulty_spikes(beatmap: Array) -> Array:
	var difficulty_spikes = []
	var note_density_window = 2.0 # 2 secondes
	
	# Analyser la densité de notes par fenêtre temporelle
	var current_time = 0.0
	var max_time = 0.0
	
	# Trouver la durée totale
	for event in beatmap:
		var event_time = 0.0
		if event.get("event_type") == "single_note":
			event_time = event.get("note", {}).get("time", 0.0)
		elif event.get("event_type") == "combo":
			event_time = event.get("end_time", 0.0)
		max_time = max(max_time, event_time)
	
	# Analyser par fenêtres
	while current_time < max_time:
		var window_end = current_time + note_density_window
		var notes_in_window = 0
		
		for event in beatmap:
			var event_time = 0.0
			if event.get("event_type") == "single_note":
				event_time = event.get("note", {}).get("time", 0.0)
				if event_time >= current_time and event_time < window_end:
					notes_in_window += 1
			elif event.get("event_type") == "combo":
				var start_time = event.get("start_time", 0.0)
				var end_time = event.get("end_time", 0.0)
				if (start_time >= current_time and start_time < window_end) or \
				   (end_time >= current_time and end_time < window_end):
					notes_in_window += event.get("notes", []).size()
		
		# Détecter les pics de difficulté (plus de 8 notes par 2 secondes)
		if notes_in_window > 8:
			difficulty_spikes.append({
				"start_time": current_time,
				"end_time": window_end,
				"note_count": notes_in_window,
				"difficulty": "high" if notes_in_window > 12 else "medium"
			})
		
		current_time += note_density_window / 2 # Fenêtre glissante
	
	return difficulty_spikes

func get_training_ui_data() -> Dictionary:
	return {
		"training_mode": training_mode,
		"practice_speed": practice_speed,
		"practice_section": {
			"start": practice_section_start,
			"end": practice_section_end,
			"loop_enabled": loop_section
		},
		"aids": {
			"show_approach_rate": show_approach_rate,
			"highlight_next_notes": highlight_next_notes,
			"ghost_notes": ghost_notes,
			"metronome": metronome_enabled
		}
	}
