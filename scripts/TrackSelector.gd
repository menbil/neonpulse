extends Control

var track_list = []
var current_selection = 0
var preview_player: AudioStreamPlayer
var difficulty_levels = ["easy", "normal", "hard", "expert"]
var current_difficulty = 1 # normal par défaut

func _ready():
	setup_preview_player()
	load_track_list()
	update_ui()
	
	# Connexion des boutons (utiliser les noms snake_case pour matcher les signaux de la scène)
	# Note: certains sont déjà connectés via la scène, on vérifie avant de connecter
	if not $Buttons/PlayButton.pressed.is_connected(_on_play_button_pressed):
		$Buttons/PlayButton.pressed.connect(_on_play_button_pressed)
	if not $Buttons/NextButton.pressed.is_connected(_on_next_button_pressed):
		$Buttons/NextButton.pressed.connect(_on_next_button_pressed)
	if not $Buttons/PrevButton.pressed.is_connected(_on_prev_button_pressed):
		$Buttons/PrevButton.pressed.connect(_on_prev_button_pressed)
	
	# Boutons extra
	if $ExtraButtons.has_node("SettingsButton"):
		$ExtraButtons/SettingsButton.pressed.connect(_on_settings_button_pressed)
	if $ExtraButtons.has_node("StatsButton"):
		$ExtraButtons/StatsButton.pressed.connect(_on_stats_button_pressed)
	
	# Boutons de difficulté
	$DifficultyContainer/EasyButton.pressed.connect(func(): set_difficulty(0))
	$DifficultyContainer/NormalButton.pressed.connect(func(): set_difficulty(1))
	$DifficultyContainer/HardButton.pressed.connect(func(): set_difficulty(2))
	$DifficultyContainer/ExpertButton.pressed.connect(func(): set_difficulty(3))
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	setup_relax_button()
	setup_animated_background()

func setup_animated_background():
	if has_node("Background"):
		var shader = load("res://scenes/Main.gdshader")
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("brightness", 0.75)
			$Background.material = mat

func _process(_delta: float):
	if has_node("Background") and $Background.material is ShaderMaterial:
		var audio_analyzer = get_node_or_null("/root/GlobalManager/AudioAnalyzer")
		if audio_analyzer:
			audio_analyzer.apply_audio_effects_to_shader($Background.material)
			$Background.material.set_shader_parameter("hit_pulse", audio_analyzer.beat_strength * 0.5)

func setup_relax_button():
	var gs = get_node_or_null("/root/GlobalManager/GameSettings")
	var btn := Button.new()
	btn.name = "RelaxButton"
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var font = load("res://assets/airstrikebold3d.ttf")
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_constant_override("outline_size", 1)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	
	var update_label := func():
		var active: bool = gs != null and gs.relax_mode
		btn.text = "RELAX: ON" if active else "RELAX: OFF"
		btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8) if active else Color(0.7, 0.7, 0.7))
	
	update_label.call()
	btn.pressed.connect(func():
		if gs:
			gs.relax_mode = not gs.relax_mode
			gs.save_settings()
		update_label.call()
	)
	$ExtraButtons.add_child(btn)

func setup_preview_player():
	preview_player = AudioStreamPlayer.new()
	preview_player.bus = "Music"
	add_child(preview_player)
	preview_player.volume_db = -10.0

func load_track_list():
	var dir = DirAccess.open("res://data/")
	if dir:
		dir.list_dir_begin()
		var folder = dir.get_next()
		while folder != "":
			if dir.current_is_dir() and folder != "." and folder != "..":
				var metadata_path = "res://data/%s/metadata.json" % folder
				if FileAccess.file_exists(metadata_path):
					var file = FileAccess.open(metadata_path, FileAccess.READ)
					var meta = JSON.parse_string(file.get_as_text())
					meta["folder"] = folder
					file.close()
					
					# Chargement des statistics pour cette track
					var highscore_manager = preload("res://scripts/HighscoreManager.gd").new()
					highscore_manager.init(folder)
					var best_score = highscore_manager.load_score()
					highscore_manager.free()
					meta["best_score"] = best_score.get("score", 0)
					meta["best_rank"] = best_score.get("rank", "-")
					
					track_list.append(meta)
			folder = dir.get_next()

func set_difficulty(difficulty_index: int):
	current_difficulty = difficulty_index
	update_difficulty_ui()
	
	# Arrêter la preview en cours
	if preview_player.playing:
		preview_player.stop()

func update_difficulty_ui():
	var difficulty_buttons = [
		$DifficultyContainer/EasyButton,
		$DifficultyContainer/NormalButton,
		$DifficultyContainer/HardButton,
		$DifficultyContainer/ExpertButton
	]
	
	for i in range(difficulty_buttons.size()):
		if i == current_difficulty:
			difficulty_buttons[i].modulate = Color.YELLOW
		else:
			difficulty_buttons[i].modulate = Color.WHITE

func update_ui():
	if track_list.size() == 0:
		$VBox/TrackTitle.text = "Aucun morceau"
		$VBox/Cover.texture = null
		return

	var track = track_list[current_selection]
	$VBox/TrackTitle.text = track.get("title", "Sans titre")
	$VBox/ArtistLabel.text = track.get("artist", "Artiste inconnu")
	$VBox/BestScoreLabel.text = "Meilleur: %d (%s)" % [track.get("best_score", 0), track.get("best_rank", "-")]
	$VBox/DifficultyLabel.text = "Difficulté: %s" % difficulty_levels[current_difficulty].to_upper()

	var cover_path = "res://data/%s/%s" % [track["folder"], track.get("cover", "cover.png")]
	if ResourceLoader.exists(cover_path):
		$VBox/Cover.texture = load(cover_path)
	else:
		$VBox/Cover.texture = null
	
	update_difficulty_ui()
	start_preview()

func start_preview():
	if track_list.size() == 0:
		return
	
	var track = track_list[current_selection]
	var music_path = "res://data/%s/%s" % [track["folder"], track.get("music", "music.ogg")]
	
	if ResourceLoader.exists(music_path):
		preview_player.stream = load(music_path)
		# Commencer la preview à 30% de la chanson
		preview_player.play()
		var seek_time = preview_player.stream.get_length() * 0.3
		preview_player.seek(seek_time)

func stop_preview():
	if preview_player.playing:
		preview_player.stop()

func _on_play_button_pressed():
	stop_preview()
	print(">>> Le bouton PLAY a été cliqué !") 
	
	var selected = track_list[current_selection].duplicate()
	var difficulty_name = difficulty_levels[current_difficulty]
	selected["difficulty"] = difficulty_name
	
	# Déterminer le fichier beatmap selon la difficulté
	var folder = selected["folder"]
	var candidates := []
	match difficulty_name:
		"easy":
			candidates = ["beatmap_easy.json", "beatmap_v4.json", "beatmap.json"]
		"normal":
			candidates = ["beatmap_normal.json", "beatmap_v4.json", "beatmap.json"]
		"hard":
			candidates = ["beatmap_hard.json", "beatmap_v4_hard.json", "beatmap_v4.json", "beatmap.json"]
		"expert":
			candidates = ["beatmap_expert.json", "beatmap_v4_hard.json", "beatmap_hard.json", "beatmap.json"]
		_:
			candidates = ["beatmap_v4.json", "beatmap.json"]
	
	var beatmap_file = "beatmap.json"
	for candidate in candidates:
		if FileAccess.file_exists("res://data/%s/%s" % [folder, candidate]):
			beatmap_file = candidate
			break
	
	selected["beatmap"] = beatmap_file
	print("Chargement: %s avec difficulté %s" % [beatmap_file, difficulty_name])
	
	get_tree().root.set_meta("selected_track", selected)
	var err = get_tree().change_scene_to_file("res://scenes/Main.tscn")
	print("Résultat changement de scène:", err)

func _on_next_button_pressed():
	stop_preview()
	print(">>> Le bouton NEXT a été cliqué !")
	current_selection = (current_selection + 1) % track_list.size()
	update_ui()

func _on_prev_button_pressed():
	stop_preview()
	print(">>> Le bouton PREV a été cliqué !")
	current_selection = (current_selection - 1 + track_list.size()) % track_list.size()
	update_ui()

func _on_settings_button_pressed():
	print(">>> Ouverture des paramètres")
	# TODO: Implémenter l'écran des paramètres

func _on_stats_button_pressed():
	print(">>> Ouverture des statistiques")
	# TODO: Implémenter l'écran des statistiques

func _on_calibration_button_pressed():
	stop_preview()
	print(">>> Ouverture de la calibration audio")
	get_tree().change_scene_to_file("res://scenes/CalibrationWizard.tscn")
