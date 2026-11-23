extends Node

# --- Variables de scène ---
var music_player
var note_scene = preload("res://scenes/Note.tscn")
@onready var background = $Background
@onready var results_panel = $Results
@onready var pause_menu = $Results
@onready var hit_error_bar = $UI/HitErrorBar  # null si pas présent
var game_settings
var progression_system

# === NOUVEAUX SYSTÈMES P0 (style osu!lazer) ===
var hitsound_manager: HitsoundManager
var health_bar: HealthBar
var follow_points: FollowPointsManager
var combo_color_manager: ComboColorManager

# === SYSTÈMES P2 (Polish) ===
var combo_burst: ComboBurst
var kiai_manager: KiaiManager
var results_screen: ResultsScreen
var slider_tick_sound: SliderTickSound
var skin_manager: SkinManager
var neon_cursor: NeonCursor

# --- Variables du Pooling amélioré ---
var note_pool = []
var particle_pool = []
var bonus_label_pool = []
const POOL_SIZE = 50
const PARTICLE_POOL_SIZE = 20
const BONUS_LABEL_POOL_SIZE = 10
var pool_expanded = false

# --- Variables de jeu ---
var beatmap = []
var note_index = 0
var total_notes = 0
var score := 0
var hits := 0
var combo_count := 0
var max_combo := 0
var score_multiplier := 1.0
var perfect_hits := 0
var good_hits := 0
var misses := 0
var hit_pulse_amount := 0.0
var approach_time := 2.0  # Réduit pour meilleure lisibilité
var track_folder := ""

# Statistiques avancées
var early_hits := 0
var late_hits := 0
var timing_errors := []
const MAX_TIMING_SAMPLES := 100

# Cache audio spectrum
var audio_spectrum_cache := {"low": 0.0, "mid": 0.0, "high": 0.0, "last_update": 0.0}
const SPECTRUM_UPDATE_INTERVAL := 0.016

# Optimisation UI
var ui_needs_update := false
var last_ui_update := 0.0
const UI_UPDATE_INTERVAL := 0.05

# === NOUVELLES VARIABLES UX ===
var countdown_active := true
var countdown_value := 3
var next_note_line: Line2D  # Ligne guide vers la prochaine note
var combo_label_tween: Tween
var last_hit_feedback := ""  # "EARLY", "LATE", "PERFECT"

# === P1: SCORE ROLLING & BACKGROUND DIM ===
var displayed_score := 0  # Score affiché (pour animation rolling)
var target_score := 0     # Score réel à atteindre
var score_roll_speed := 5000.0  # Points par seconde
var background_dim := 0.3  # 0.0 = pas de dim, 1.0 = noir complet
var background_dim_node: ColorRect  # Overlay de dim
var showing_results := false  # Pour éviter les conflits pause/results
var beatmap_metadata: Dictionary = {}
var audio_offset := 0.0

# S'exécute au lancement de la scène
func _ready():
	# Permet de recevoir les inputs même en pause (pour R et Escape)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Récupération des managers globaux
	game_settings = get_node_or_null("/root/GlobalManager/GameSettings")
	progression_system = get_node_or_null("/root/GlobalManager/ProgressionSystem")
	
	var selected = get_tree().root.get_meta("selected_track")
	track_folder = selected["folder"]
	var folder = "res://data/%s/" % selected["folder"]
	var music_path = folder + selected["music"]
	var beatmap_path = folder + selected["beatmap"]
	
	print("=== MAIN READY ===")
	print("Track folder: ", track_folder)
	print("Music path: ", music_path)
	print("Beatmap path: ", beatmap_path)

	# Configuration du lecteur audio
	$AudioStreamPlayer.stream = load(music_path)
	music_player = $AudioStreamPlayer
	music_player.finished.connect(_on_music_player_finished)

	# Chargement de la beatmap et initialisation des scores
	load_beatmap(beatmap_path)
	print("Beatmap loaded, total notes: ", beatmap.size())
	print("First note: ", beatmap[0] if beatmap.size() > 0 else "NONE")
	
	# Initialisation du gestionnaire de scores
	var highscore_manager = preload("res://scripts/HighscoreManager.gd").new()
	add_child(highscore_manager)
	highscore_manager.name = "HighscoreManager"
	highscore_manager.init(selected["folder"])
	
	# Création de la réserve de notes (pooling)
	for i in range(POOL_SIZE):
		var note = note_scene.instantiate()
		add_child(note)
		note_pool.append(note)
	
	# Pooling des particules d'effets (nouveau HitEffect)
	var hit_effect_scene = preload("res://scenes/HitEffect.tscn")
	for i in range(PARTICLE_POOL_SIZE):
		var effect = hit_effect_scene.instantiate()
		add_child(effect)
		particle_pool.append(effect)
	
	# Pooling des labels de bonus
	for i in range(BONUS_LABEL_POOL_SIZE):
		var label = Label.new()
		label.z_index = 100
		label.visible = false
		add_child(label)
		bonus_label_pool.append(label)
	
	# Application des paramètres
	if game_settings:
		approach_time = game_settings.get_effective_approach_time(approach_time)
		audio_offset = game_settings.audio_offset
		game_settings.apply_audio_settings()
		if hit_error_bar:
			hit_error_bar.visible = game_settings.hit_error_bar_enabled
	
	# === SETUP SYSTÈMES P0 (style osu!lazer) ===
	setup_p0_systems()
	
	# === SETUP SYSTÈMES P2 (Polish) ===
	setup_p2_systems()
	
	# Connecter les données de beatmap au KiaiManager & AudioAnalyzer
	if kiai_manager and not beatmap_metadata.is_empty():
		kiai_manager.load_kiai_sections(beatmap_metadata)
	
	var audio_analyzer = get_node_or_null("/root/GlobalManager/AudioAnalyzer")
	if audio_analyzer:
		if beatmap_metadata.has("bpm"):
			audio_analyzer.set_known_bpm(float(beatmap_metadata["bpm"]))
		if not audio_analyzer.beat_detected.is_connected(_on_audio_beat_detected):
			audio_analyzer.beat_detected.connect(_on_audio_beat_detected)
	
	# === SETUP UX AMÉLIORÉ ===
	setup_next_note_line()
	setup_countdown_ui()
	setup_timing_feedback_ui()
	setup_background_dim()  # P1
	
	# Démarrage du countdown au lieu de jouer directement
	start_countdown()
	
	# Curseur néon personnalisé (masquer le curseur système en jeu)
	neon_cursor = NeonCursor.new()
	neon_cursor.name = "NeonCursor"
	$UI.add_child(neon_cursor)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

# === SETUP SYSTÈMES P0 ===

func setup_p0_systems():
	"""Initialise les systèmes P0 style osu!lazer"""
	
	# 1. Hitsound Manager - Sons de hit
	hitsound_manager = HitsoundManager.new()
	add_child(hitsound_manager)
	
	# 2. Health Bar - Barre de vie
	health_bar = HealthBar.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(20, 20)
	health_bar.health_depleted.connect(_on_health_depleted)
	$UI.add_child(health_bar)
	
	# 3. Follow Points - Points entre les notes
	follow_points = FollowPointsManager.new()
	follow_points.name = "FollowPoints"
	follow_points.z_index = -5
	add_child(follow_points)
	
	# 4. Combo Color Manager - Couleurs cycliques
	combo_color_manager = ComboColorManager.new()
	combo_color_manager.name = "ComboColors"
	add_child(combo_color_manager)
	
	print("[P0] Systèmes osu!lazer initialisés: Hitsounds, HealthBar, FollowPoints, ComboColors")

# === SETUP SYSTÈMES P2 (Polish) ===

func setup_p2_systems():
	"""Initialise les systèmes P2 - Polish (Combo Burst, Kiai, Results Screen)"""
	
	# 1. Combo Burst - Images qui apparaissent aux milestones de combo
	combo_burst = ComboBurst.new()
	combo_burst.name = "ComboBurst"
	$UI.add_child(combo_burst)
	
	# 2. Kiai Manager - Effets spéciaux pendant les sections intenses
	kiai_manager = KiaiManager.new()
	kiai_manager.name = "KiaiManager"
	add_child(kiai_manager)
	
	# 3. Slider Tick Sound - Sons pour les sliders
	slider_tick_sound = SliderTickSound.new()
	slider_tick_sound.name = "SliderTickSound"
	add_child(slider_tick_sound)
	
	# 4. Skin Manager - Système de skins
	skin_manager = SkinManager.new()
	skin_manager.name = "SkinManager"
	add_child(skin_manager)
	
	# 5. Results Screen (sera affiché à la fin) - Ajouté à l'UI pour être par-dessus tout
	results_screen = ResultsScreen.new()
	results_screen.name = "ResultsScreenNew"
	results_screen.visible = false
	results_screen.set_anchors_preset(Control.PRESET_FULL_RECT)  # Couvre tout l'écran
	results_screen.retry_pressed.connect(_on_restart_button_pressed)
	results_screen.menu_pressed.connect(_on_return_button_pressed)
	$UI.add_child(results_screen)  # Ajouter à l'UI CanvasLayer
	
	print("[P2] Systèmes Polish initialisés: ComboBurst, KiaiManager, SliderTickSound, SkinManager, ResultsScreen")

# === P1: BACKGROUND DIM ===

func setup_background_dim():
	"""Crée un overlay sombre sur le background pour mieux voir les notes"""
	background_dim_node = ColorRect.new()
	background_dim_node.name = "BackgroundDim"
	background_dim_node.color = Color(0, 0, 0, background_dim)
	background_dim_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_dim_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_dim_node.z_index = -10  # Derrière les notes mais devant le background
	
	# L'ajouter après le Background mais avant l'UI
	add_child(background_dim_node)
	move_child(background_dim_node, 1)  # Juste après le background

func set_background_dim(value: float):
	"""Change l'intensité du dim (0.0 - 1.0)"""
	background_dim = clamp(value, 0.0, 1.0)
	if background_dim_node:
		background_dim_node.color.a = background_dim

func _on_health_depleted():
	"""Appelé quand la barre de vie atteint 0"""
	# Option: Fail automatique ou continuer
	# Pour l'instant on continue mais on pourrait arrêter le jeu
	print("HP depleted! Game could fail here.")
	# Optionnel: music_player.stop() et show_results()

# === NOUVELLES FONCTIONS UX ===

func setup_next_note_line():
	"""Crée une ligne qui guide vers la prochaine note"""
	next_note_line = Line2D.new()
	next_note_line.width = 3.0
	next_note_line.default_color = Color(1, 1, 1, 0.3)
	next_note_line.z_index = -1
	add_child(next_note_line)

func setup_countdown_ui():
	"""Configure l'UI du countdown - déjà dans la scène"""
	if has_node("UI/CountdownLabel"):
		$UI/CountdownLabel.visible = false

func setup_timing_feedback_ui():
	"""Configure l'UI du feedback de timing - déjà dans la scène"""
	if has_node("UI/TimingFeedback"):
		$UI/TimingFeedback.modulate.a = 0

func start_countdown():
	"""Démarre le countdown 3, 2, 1, GO!"""
	countdown_active = true
	countdown_value = 3
	update_countdown_display()
	
	# Timer pour le countdown
	var countdown_timer = Timer.new()
	countdown_timer.wait_time = 1.0
	countdown_timer.one_shot = false
	countdown_timer.timeout.connect(_on_countdown_tick)
	add_child(countdown_timer)
	countdown_timer.name = "CountdownTimer"
	countdown_timer.start()

func _on_countdown_tick():
	countdown_value -= 1
	if countdown_value > 0:
		update_countdown_display()
	elif countdown_value == 0:
		# Afficher GO!
		if has_node("UI/CountdownLabel"):
			$UI/CountdownLabel.text = "GO!"
			$UI/CountdownLabel.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		# Fin du countdown, démarrer la musique
		countdown_active = false
		if has_node("UI/CountdownLabel"):
			$UI/CountdownLabel.visible = false
		if has_node("CountdownTimer"):
			$CountdownTimer.queue_free()
		music_player.play()

func update_countdown_display():
	if has_node("UI/CountdownLabel"):
		$UI/CountdownLabel.text = str(countdown_value)
		$UI/CountdownLabel.visible = true
		# Animation de scale
		$UI/CountdownLabel.scale = Vector2(1.5, 1.5)
		var tween = create_tween()
		tween.tween_property($UI/CountdownLabel, "scale", Vector2(1, 1), 0.3)

func show_timing_feedback(_timing: String, time_diff: float):
	"""Affiche uniquement EARLY / LATE (en ms) pour éviter les doublons avec FeedbackLabel"""
	if not has_node("UI/TimingFeedback"):
		return
	
	var label = $UI/TimingFeedback
	if absf(time_diff) < 0.05:
		label.modulate.a = 0.0
		return
	
	var ms := int(round(time_diff * 1000.0))
	if time_diff < 0:
		label.text = "EARLY (%dms)" % ms
		label.add_theme_color_override("font_color", Color(0.3, 0.75, 1.0))
	else:
		label.text = "LATE (+%dms)" % ms
		label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	
	label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.2)

func update_next_note_line():
	"""Met à jour la ligne guide vers la prochaine note visible"""
	if not next_note_line:
		return
	
	next_note_line.clear_points()
	
	# Trouver les 2 prochaines notes visibles
	var visible_notes = []
	for note in note_pool:
		if note.visible and note.current_state == note.State.IDLE:
			visible_notes.append(note)
	
	# Trier par hit_time
	visible_notes.sort_custom(func(a, b): return a.hit_time < b.hit_time)
	
	# Dessiner la ligne entre les notes successives
	if visible_notes.size() >= 2:
		for i in range(min(visible_notes.size() - 1, 3)):  # Max 3 lignes
			var from_pos = visible_notes[i].global_position
			var to_pos = visible_notes[i + 1].global_position
			
			if i == 0:
				next_note_line.add_point(from_pos)
			next_note_line.add_point(to_pos)

# Fonction pour seek l'audio (si besoin de skip intro, etc.)
func seek_audio(time_seconds: float):
	if music_player:
		music_player.seek(time_seconds)
	
	# Reset des notes spawnées
	for note in note_pool:
		if note.visible:
			note._return_to_pool()
	
	# Trouver le bon note_index pour le nouveau temps
	note_index = 0
	for i in range(beatmap.size()):
		var event_data = beatmap[i]
		var time_to_check = 0.0
		
		# Support format complexe ET simple
		if event_data.has("event_type"):
			if event_data.event_type == "single_note" and event_data.has("note"):
				time_to_check = event_data.note.get("time", 0.0)
			elif event_data.event_type == "combo":
				time_to_check = event_data.get("start_time", 0.0)
		elif event_data.has("time"):
			time_to_check = event_data.get("time", 0.0)
		
		if time_to_check < time_seconds - approach_time:
			note_index = i + 1
		else:
			break

# Horloge audio haute précision (avec latence mix + offset utilisateur)
func get_precise_music_time() -> float:
	if not is_instance_valid(music_player) or not music_player.playing:
		return 0.0
	var time: float = music_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency() + audio_offset
	return maxf(0.0, time)

func _on_audio_beat_detected(strength: float):
	if countdown_active or get_tree().paused:
		return
	hit_pulse_amount = maxf(hit_pulse_amount, strength * 0.55)
	if kiai_manager and kiai_manager.is_kiai_active:
		kiai_manager.trigger_beat_effect()

func _input(event):
	# Retry rapide avec R (front montant uniquement)
	if event.is_action_pressed("retry_track") and not event.is_echo():
		get_tree().paused = false
		get_tree().reload_current_scene()
		return

	if countdown_active or get_tree().paused or not is_instance_valid(music_player) or not music_player.playing:
		return

	# Arbitrage de hit (Souris gauche/droite OU touches Z/X)
	var is_hit_input := false
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		is_hit_input = true
	elif (event.is_action_pressed("osu_hit_1") or event.is_action_pressed("osu_hit_2")) and not event.is_echo():
		is_hit_input = true

	if is_hit_input:
		_try_hit_note_at_cursor()

func _try_hit_note_at_cursor():
	var current_time := get_precise_music_time()
	var mouse_pos := get_viewport().get_mouse_position()
	var candidates := []

	for note in note_pool:
		if note.is_hittable(current_time) and note.is_cursor_over(mouse_pos):
			candidates.append(note)

	if candidates.is_empty():
		return

	# Toujours frapper la note la plus ancienne (plus petit hit_time)
	candidates.sort_custom(func(a, b): return a.hit_time < b.hit_time)
	candidates[0].handle_initial_hit()

# Boucle principale du jeu
func _process(delta):
	# --- 1. Mise à jour du fond (tourne toujours) ---
	update_background_shader(delta)
	
	# --- 2. Logique de pause ---
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause()
	
	# --- 2c. Skip countdown avec SPACE ---
	if countdown_active and Input.is_action_just_pressed("ui_accept"):
		countdown_value = 0
		_on_countdown_tick()
		return

	# --- 3. Arrêt si countdown actif, musique ne joue pas, ou pause ---
	if countdown_active or not music_player.playing or get_tree().paused:
		return

	# --- 4. Logique de jeu (uniquement si la musique joue) ---
	var current_time = get_precise_music_time()
	spawn_notes_in_window(current_time)
	update_progress_bar(current_time)
	update_next_note_line()  # Mise à jour de la ligne guide
	
	# === P0: FOLLOW POINTS & TARGET HIGHLIGHT ===
	var visible_notes = []
	for note in note_pool:
		if note.visible and note.current_state == note.State.IDLE:
			visible_notes.append(note)
	
	if not visible_notes.is_empty():
		visible_notes.sort_custom(func(a, b): return a.hit_time < b.hit_time)
		for i in range(visible_notes.size()):
			visible_notes[i].is_next_target = (i == 0)
	
	if follow_points:
		follow_points.update_follow_points(visible_notes)
	
	# === P0: HEALTH DRAIN (passive) ===
	if health_bar and not health_bar.is_draining:
		health_bar.start_drain()
	
	# === P1: SCORE ROLLING ANIMATION ===
	if displayed_score < target_score:
		var roll_amount = score_roll_speed * delta
		# Accélérer si l'écart est grand
		if target_score - displayed_score > 1000:
			roll_amount *= 3.0
		displayed_score = min(target_score, displayed_score + int(roll_amount))
		ui_needs_update = true
	
	# OPTIMISATION: batch update de l'UI
	if ui_needs_update and (current_time - last_ui_update) > UI_UPDATE_INTERVAL:
		update_ui_labels()
		last_ui_update = current_time
		ui_needs_update = false

# Met à jour le shader du fond (effets de déformation)
func update_background_shader(delta):
	if not is_instance_valid(background) or background.material == null:
		return
	
	var shader_mat = background.material
	
	# Utilisation du nouvel analyseur audio si disponible
	var audio_analyzer = get_node_or_null("/root/GlobalManager/AudioAnalyzer")
	if audio_analyzer:
		audio_analyzer.apply_audio_effects_to_shader(shader_mat)
	else:
		# OPTIMISATION: ne mettre à jour le spectrum que toutes les 16ms max
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - audio_spectrum_cache.last_update > SPECTRUM_UPDATE_INTERVAL:
			var spectrum = AudioServer.get_bus_effect_instance(1, 0)
			if spectrum:
				audio_spectrum_cache.low = spectrum.get_magnitude_for_frequency_range(20, 250).length()
				audio_spectrum_cache.mid = spectrum.get_magnitude_for_frequency_range(250, 2000).length()
				audio_spectrum_cache.high = spectrum.get_magnitude_for_frequency_range(2000, 20000).length()
				audio_spectrum_cache.last_update = current_time
		
		# Appliquer les valeurs cachées
		shader_mat.set_shader_parameter("audio_low", audio_spectrum_cache.low)
		shader_mat.set_shader_parameter("audio_mid", audio_spectrum_cache.mid)
		shader_mat.set_shader_parameter("audio_high", audio_spectrum_cache.high)
	
	hit_pulse_amount = max(0.0, hit_pulse_amount - delta * 2.0)
	shader_mat.set_shader_parameter("hit_pulse", hit_pulse_amount)
	
	# Effet de combo
	var combo_effect = min(1.0, float(combo_count) / 20.0)
	shader_mat.set_shader_parameter("combo_intensity", combo_effect)
	
	# Pas de tremblement continu sur le shader (seulement 0.0 sauf impulsion ponctuelle)
	shader_mat.set_shader_parameter("screen_shake", 0.0)
	
	# Application des paramètres utilisateur
	if game_settings:
		shader_mat.set_shader_parameter("brightness", game_settings.background_brightness)
		shader_mat.set_shader_parameter("high_contrast", game_settings.high_contrast)

# Fait apparaître les notes visibles à l'écran
func spawn_notes_in_window(current_time: float):
	# SÉCURITÉ: spawner toutes les notes jusqu'à current_time + approach_time
	var spawn_deadline = current_time + approach_time
	
	while note_index < beatmap.size():
		var event_data = beatmap[note_index]
		
		# Support du format simple (notes directes) ET du format complexe (event_type)
		var time_to_check = 0.0
		var notes_to_spawn = []
		
		# Format complexe avec event_type
		if event_data.has("event_type"):
			if event_data.event_type == "single_note":
				if event_data.has("note") and event_data.note.has("time"):
					time_to_check = event_data.note.time
					notes_to_spawn = [event_data.note]
				else:
					note_index += 1
					continue
			elif event_data.event_type == "combo":
				if event_data.has("start_time"):
					time_to_check = event_data.start_time
					notes_to_spawn = event_data.notes
				else:
					note_index += 1
					continue
		# Format simple (note directe avec time, x, y)
		elif event_data.has("time"):
			time_to_check = event_data.get("time", 0.0)
			notes_to_spawn = [event_data]
		else:
			print("Erreur: format de note inconnu à l'index ", note_index, " data: ", event_data)
			note_index += 1
			continue
		
		# Vérifier si c'est le moment de spawner
		if time_to_check > spawn_deadline:
			break  # La note est trop loin dans le futur
		
		# Spawner les notes avec leur numéro
		var spawn_number = note_index + 1
		for note_data in notes_to_spawn:
			var enriched_data = note_data.duplicate()
			enriched_data["note_number"] = spawn_number
			spawn_note(enriched_data)
			spawn_number += 1
		
		note_index += 1

# Fait apparaître une note depuis la réserve
func spawn_note(note_data_arg):
	for note in note_pool:
		if not note.visible:
			note.setup(note_data_arg)
			return
	
	# Si on manque de notes dans le pool, en créer une nouvelle
	if not pool_expanded:
		expand_note_pool()
		# Réessayer de spawner après expansion
		for note in note_pool:
			if not note.visible:
				note.setup(note_data_arg)
				return

func expand_note_pool():
	pool_expanded = true
	print("🔄 Extension du pool de notes")
	for i in range(25):
		var note = note_scene.instantiate()
		add_child(note)
		note_pool.append(note)

func get_particle_from_pool():
	for particle in particle_pool:
		# HitEffect: vérifier si l'effet n'est pas en cours
		if not particle.is_playing:
			return particle
	
	# Si pas de particules disponibles, créer une nouvelle (utiliser HitEffect)
	var new_particle = preload("res://scenes/HitEffect.tscn").instantiate()
	add_child(new_particle)
	particle_pool.append(new_particle)
	return new_particle

# Met à jour la barre de progression
func update_progress_bar(current_time: float):
	if music_player.stream:
		$ProgressBar.value = (current_time / music_player.stream.get_length()) * 100.0

# OPTIMISATION: mise à jour batchée des labels UI
func update_ui_labels():
	# P1: Utiliser displayed_score pour l'animation rolling
	$UI/ScoreLabel.text = "Score: %d" % displayed_score
	$UI/ComboLabel.text = "Combo: %d" % combo_count
	$UI/AccuracyLabel.text = "Accuracy: %.1f%%" % calculate_accuracy()
	$UI/RankLabel.text = "Rank: %s" % calculate_rank()

# Charge et configure la beatmap
func load_beatmap(path):
	# OPTIMISATION: vérifier le cache global
	var global_manager = get_node_or_null("/root/GlobalManager")
	if global_manager and "beatmap_cache" in global_manager:
		if global_manager.beatmap_cache.has(path):
			var cached = global_manager.beatmap_cache[path]
			beatmap = cached.notes
			total_notes = cached.total
			approach_time = cached.approach_time
			beatmap_metadata = cached.get("metadata", {})
			return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if typeof(data) == TYPE_DICTIONARY and data.has("notes"):
			beatmap = data["notes"]
			total_notes = beatmap.size()
			approach_time = data.get("approach_time", 2.0)
			beatmap_metadata = {
				"bpm": data.get("bpm", 120.0),
				"duration": data.get("duration", 0.0),
				"kiai_sections": data.get("kiai_sections", [])
			}
			
			# OPTIMISATION: stocker dans le cache
			if global_manager and "beatmap_cache" in global_manager:
				global_manager.beatmap_cache[path] = {
					"notes": beatmap,
					"total": total_notes,
					"approach_time": approach_time,
					"metadata": beatmap_metadata
				}

# Enregistre un "hit" et met à jour le score
func register_hit(accuracy, note_position: Vector2, pattern_multiplier: float = 1.0, time_diff: float = 0.0, note_data: Dictionary = {}):
	# FEATURE: Envoyer à la hit error bar
	if hit_error_bar and accuracy != "Miss":
		hit_error_bar.add_hit_error(time_diff, accuracy)
	
	# FEATURE: Afficher le feedback de timing (EARLY/LATE/PERFECT)
	if accuracy != "Miss":
		show_timing_feedback(accuracy, time_diff)
	
	# FEATURE: Statistiques avancées
	if accuracy != "Miss":
		timing_errors.append(time_diff)
		if timing_errors.size() > MAX_TIMING_SAMPLES:
			timing_errors.pop_front()
		
		if time_diff < 0:
			early_hits += 1
		else:
			late_hits += 1
	
	# === P0: HITSOUNDS ===
	if hitsound_manager:
		if accuracy != "Miss":
			# Déterminer le type de hitsound selon la note
			var hitsound_type = hitsound_manager.get_hitsound_for_note(note_data)
			# Variation de pitch selon l'accuracy pour feedback auditif
			var pitch_var = 0.0 if accuracy == "Perfect" else 0.05
			hitsound_manager.play_hit(hitsound_type, pitch_var)
		else:
			hitsound_manager.play_miss()
	
	# === P0: HEALTH BAR ===
	if health_bar:
		health_bar.register_hit(accuracy)
	
	var had_combo = combo_count > 10  # Pour le combo break sound
	
	if accuracy != "Miss":
		hits += 1
		combo_count += 1
		max_combo = max(max_combo, combo_count)
		score_multiplier = min(4.0, 1.0 + (combo_count / 10.0))
		hit_pulse_amount = 1.0
		
		# Animation du combo (effet de scale)
		animate_combo_label()
		
		# === P2: COMBO BURST ===
		if combo_burst:
			combo_burst.check_combo(combo_count)
		
		# === P2: KIAI BEAT EFFECT ===
		if kiai_manager and kiai_manager.is_kiai_active:
			kiai_manager.trigger_beat_effect()
		
		# Comptage par type de hit
		if accuracy == "Perfect":
			perfect_hits += 1
		elif accuracy == "Good":
			good_hits += 1
	else:
		# === P0: COMBO BREAK ===
		if had_combo and hitsound_manager:
			hitsound_manager.play_combo_break()
		if combo_color_manager:
			combo_color_manager.on_combo_break()
		
		combo_count = 0
		score_multiplier = 1.0
		misses += 1
		# Shake effect on miss
		shake_screen(5.0)
	
	var base_score = 0
	match accuracy:
		"Perfect":
			base_score = 300
			var particles = get_particle_from_pool()
			if particles:
				particles.global_position = note_position
				particles.play_flash("Perfect", combo_count)  # P1: passer le combo
		"Good":
			base_score = 100
			var particles = get_particle_from_pool()
			if particles:
				particles.global_position = note_position
				particles.play_flash("Good", combo_count)  # P1: passer le combo
		"Miss":
			base_score = 0
	
	# Application du multiplicateur de motif spécial
	var final_score = int(base_score * score_multiplier * pattern_multiplier)
	score += final_score
	target_score = score  # P1: Score rolling - définir le target
	
	# Afficher le bonus de motif spécial si applicable
	if pattern_multiplier > 1.0 and accuracy != "Miss":
		show_pattern_bonus(note_position, pattern_multiplier)
	
	# OPTIMISATION: marquer l'UI comme à mettre à jour
	ui_needs_update = true
	$UI/FeedbackLabel.show_feedback(accuracy)

func animate_combo_label():
	"""Animation de scale sur le label combo"""
	if has_node("UI/ComboLabel"):
		var label = $UI/ComboLabel
		label.scale = Vector2(1.3, 1.3)
		var tween = create_tween()
		tween.tween_property(label, "scale", Vector2(1, 1), 0.15).set_ease(Tween.EASE_OUT)

func shake_screen(intensity: float):
	"""Petit shake de l'écran sur un miss"""
	if game_settings and not game_settings.screen_shake:
		return
	var original_pos = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "position", Vector2(intensity, 0), 0.05)
	tween.tween_property(self, "position", Vector2(-intensity, 0), 0.05)
	tween.tween_property(self, "position", Vector2(0, intensity), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)

# Affiche l'écran des résultats
func show_results():
	# === P2: Utiliser le nouveau ResultsScreen si disponible ===
	if results_screen:
		# Cacher l'ancien panel pour éviter la superposition
		if results_panel:
			results_panel.visible = false
		
		# Cacher les labels UI en haut à droite
		if has_node("UI/ScoreLabel"):
			$UI/ScoreLabel.visible = false
		if has_node("UI/RankLabel"):
			$UI/RankLabel.visible = false
		if has_node("UI/ComboLabel"):
			$UI/ComboLabel.visible = false
		if has_node("UI/AccuracyLabel"):
			$UI/AccuracyLabel.visible = false
		if health_bar:
			health_bar.visible = false
		if has_node("ProgressBar"):
			$ProgressBar.visible = false
		if hit_error_bar:
			hit_error_bar.visible = false
		if has_node("UI/TimingFeedback"):
			$UI/TimingFeedback.visible = false
		if has_node("UI/FeedbackLabel"):
			$UI/FeedbackLabel.visible = false
		
		# Marquer qu'on affiche les résultats (pour bloquer toggle_pause)
		showing_results = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if neon_cursor:
			neon_cursor.visible = false
		
		var game_data = {
			"score": score,
			"max_combo": max_combo,
			"accuracy": calculate_accuracy(),
			"perfect": perfect_hits,
			"good": good_hits,
			"miss": misses,
			"total_notes": total_notes,
			"timing_errors": timing_errors.duplicate(),
			"track_name": track_folder,
			"grade": calculate_rank()
		}
		results_screen.show_results(game_data)
		get_tree().paused = true
		return
	
	# Fallback: ancien système de résultats
	if not results_panel.visible:
		results_panel.visible = true
		results_panel.get_node("VBoxContainer/ScoreLabel").text = "SCORE: %d" % score
		results_panel.get_node("VBoxContainer/RankLabel").text = "RANK: %s" % calculate_rank()
		results_panel.get_node("VBoxContainer/ComboLabel").text = "MAX COMBO: %d" % max_combo
		var accuracy = calculate_accuracy()
		results_panel.get_node("VBoxContainer/AccuracyLabel").text = "ACCURACY: %.1f%%" % accuracy
		
		# FEATURE: Stats avancées
		var stats_text = "Perfect: %d | Good: %d | Miss: %d\n" % [perfect_hits, good_hits, misses]
		
		if timing_errors.size() > 0:
			var avg_error = 0.0
			for err in timing_errors:
				avg_error += err
			avg_error /= timing_errors.size()
			
			var early_late_ratio = 0.0
			if early_hits + late_hits > 0:
				early_late_ratio = float(early_hits) / float(early_hits + late_hits) * 100.0
			
			stats_text += "Avg Timing: %+.0fms\n" % (avg_error * 1000.0)
			stats_text += "Early: %.0f%% | Late: %.0f%%" % [early_late_ratio, 100.0 - early_late_ratio]
		
		if results_panel.has_node("VBoxContainer/StatsLabel"):
			results_panel.get_node("VBoxContainer/StatsLabel").text = stats_text
		
		var saved = $HighscoreManager.load_score()
		results_panel.get_node("VBoxContainer/HighscoreLabel").text = "HIGHSCORE: %d" % saved.get("score", 0)
		get_tree().paused = true

# Gère le menu pause
func toggle_pause():
	# Ne pas permettre la pause si on affiche les résultats
	if showing_results:
		return
	
	var was_paused = get_tree().paused
	get_tree().paused = not was_paused
	pause_menu.visible = get_tree().paused
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_HIDDEN)
	if neon_cursor:
		neon_cursor.visible = not get_tree().paused
	
	# CRITIQUE: Gérer l'audio explicitement
	if music_player:
		music_player.stream_paused = get_tree().paused
	
func calculate_rank():
	var total_judged := perfect_hits + good_hits + misses
	if total_judged == 0:
		return "-"
	
	var acc: float = calculate_accuracy()
	if acc >= 95.0 and misses == 0:
		return "SS"
	elif acc >= 93.0:
		return "S"
	elif acc >= 82.0:
		return "A"
	elif acc >= 70.0:
		return "B"
	elif acc >= 55.0:
		return "C"
	else:
		return "D"

func calculate_accuracy() -> float:
	var total_judged := perfect_hits + good_hits + misses
	if total_judged == 0:
		return 100.0
	return ((float(perfect_hits) * 300.0 + float(good_hits) * 100.0) / (float(total_judged) * 300.0)) * 100.0

# --- Fonctions connectées aux signaux ---

func _on_timer_timeout():
	music_player.play()

func _on_music_player_finished():
	var accuracy = calculate_accuracy()
	var rank = calculate_rank()
	var is_new_highscore = $HighscoreManager.save_score(score, rank, max_combo, accuracy, perfect_hits, good_hits, misses)
	
	# Enregistrer dans le système de progression
	if progression_system:
		progression_system.register_game_completed(score, rank, track_folder, max_combo, perfect_hits, good_hits, misses)
	
	show_results()

func _on_restart_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_return_button_pressed():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/TrackSelector.tscn")

# Affiche un bonus visuel pour les motifs spéciaux
func show_pattern_bonus(position: Vector2, multiplier: float):
	# Chercher un label disponible dans le pool
	var bonus_label: Label = null
	for label in bonus_label_pool:
		if not label.visible:
			bonus_label = label
			break
	
	# Si aucun disponible, créer temporairement (rare)
	if not bonus_label:
		bonus_label = Label.new()
		bonus_label.z_index = 100
		add_child(bonus_label)
		bonus_label_pool.append(bonus_label)
	
	# Configuration du label
	bonus_label.text = "×%.1f" % multiplier
	bonus_label.add_theme_color_override("font_color", Color.GOLD)
	bonus_label.position = position
	bonus_label.modulate = Color.WHITE
	bonus_label.visible = true
	
	# Animation du bonus
	var tween = create_tween()
	tween.parallel().tween_property(bonus_label, "position:y", position.y - 50, 1.0)
	tween.parallel().tween_property(bonus_label, "modulate:a", 0.0, 1.0)
	tween.finished.connect(func(): bonus_label.visible = false)

# Fonction pour le debug manager
func get_debug_info() -> Dictionary:
	var active_notes = 0
	var notes_in_pool = 0
	
	for note in note_pool:
		if note.visible:
			active_notes += 1
		else:
			notes_in_pool += 1
	
	return {
		"score": score,
		"combo": combo_count,
		"notes_in_pool": notes_in_pool,
		"active_notes": active_notes,
		"note_index": note_index,
		"total_notes": total_notes,
		"perfect_hits": perfect_hits,
		"good_hits": good_hits,
		"misses": misses,
		"multiplier": score_multiplier
	}
