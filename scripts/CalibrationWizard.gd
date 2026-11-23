extends Control

# Wizard de calibration audio
# Le joueur tape sur un beat régulier et on calcule l'offset moyen

var tap_times := []
var beat_interval := 0.5  # 120 BPM = 0.5s par beat
var expected_beat_times := []
var current_beat := 0
var calibration_started := false
var metronome_audio: AudioStreamPlayer
var game_settings

@onready var instruction_label = $VBoxContainer/InstructionLabel
@onready var offset_label = $VBoxContainer/OffsetLabel
@onready var tap_count_label = $VBoxContainer/TapCountLabel
@onready var start_button = $VBoxContainer/ButtonContainer/StartButton
@onready var apply_button = $VBoxContainer/ButtonContainer/ApplyButton
@onready var cancel_button = $VBoxContainer/ButtonContainer/CancelButton
@onready var beat_indicator = $VBoxContainer/BeatIndicator
@onready var tap_feedback = $VBoxContainer/TapFeedback

func _ready():
	game_settings = get_node_or_null("/root/GlobalManager/GameSettings")
	
	# Créer un metronome audio (optionnel si tu as un AudioStreamPlayer)
	metronome_audio = AudioStreamPlayer.new()
	add_child(metronome_audio)
	
	apply_button.disabled = true
	apply_button.pressed.connect(_on_apply_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	start_button.pressed.connect(_on_start_pressed)
	
	instruction_label.text = "Appuyez sur Démarrer pour commencer la calibration.\nVous devrez taper en rythme avec le métronome."
	offset_label.text = "Offset actuel: %.0f ms" % (game_settings.audio_offset * 1000.0 if game_settings else 0.0)

func _input(event):
	if calibration_started and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_Z or event.keycode == KEY_X:
			register_tap()

func _on_start_pressed():
	calibration_started = true
	tap_times.clear()
	current_beat = 0
	start_button.disabled = true
	
	instruction_label.text = "Tapez la barre espace en rythme avec le métronome !\n(Au moins 10 taps recommandés)"
	
	# Générer les beats attendus
	expected_beat_times.clear()
	for i in range(20):  # 20 beats = 10 secondes à 120 BPM
		expected_beat_times.append(i * beat_interval)
	
	# Démarrer le métronome (timer pour les beeps)
	var timer = Timer.new()
	timer.wait_time = beat_interval
	timer.one_shot = false
	timer.timeout.connect(_on_metronome_beat)
	add_child(timer)
	timer.start()

func _on_metronome_beat():
	# Jouer un son de metronome (ou flash visuel)
	beat_indicator.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property(beat_indicator, "modulate", Color(0.3, 0.3, 0.3), beat_interval * 0.8)
	
	current_beat += 1
	if current_beat >= expected_beat_times.size():
		finish_calibration()

func register_tap():
	var tap_time = Time.get_ticks_msec() / 1000.0
	tap_times.append(tap_time)
	tap_count_label.text = "Taps: %d" % tap_times.size()
	
	# Feedback visuel
	tap_feedback.modulate = Color.GREEN
	var tween = create_tween()
	tween.tween_property(tap_feedback, "modulate", Color(0.0, 0.5, 0.0), 0.1)

func finish_calibration():
	calibration_started = false
	
	if tap_times.size() < 5:
		instruction_label.text = "Pas assez de taps ! Recommencez."
		start_button.disabled = false
		return
	
	# Calculer l'offset moyen
	var offsets := []
	var start_time = tap_times[0]
	
	for i in range(tap_times.size()):
		var tap_time = tap_times[i] - start_time
		# Trouver le beat attendu le plus proche
		var closest_beat = round(tap_time / beat_interval)
		if closest_beat < expected_beat_times.size():
			var expected_time = closest_beat * beat_interval
			var offset = tap_time - expected_time
			offsets.append(offset)
	
	if offsets.size() == 0:
		instruction_label.text = "Erreur de calcul. Recommencez."
		start_button.disabled = false
		return
	
	# Moyenne et médiane pour robustesse
	offsets.sort()
	var median_offset = offsets[offsets.size() / 2]
	
	var calculated_offset = -median_offset  # Négatif car on veut compenser
	
	instruction_label.text = "Calibration terminée !\nOffset recommandé: %.0f ms" % (calculated_offset * 1000.0)
	offset_label.text = "Nouvel offset: %.0f ms" % (calculated_offset * 1000.0)
	apply_button.disabled = false

func _on_apply_pressed():
	if game_settings:
		var new_offset = float(offset_label.text.split(": ")[1].replace(" ms", "")) / 1000.0
		game_settings.audio_offset = new_offset
		game_settings.save_settings()
	get_tree().change_scene_to_file("res://scenes/TrackSelector.tscn")

func _on_cancel_pressed():
	get_tree().change_scene_to_file("res://scenes/TrackSelector.tscn")
