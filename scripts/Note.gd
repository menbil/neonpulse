extends Area2D

enum State { IDLE, HOLDING, FADING_OUT }
enum NoteType { TAP, HOLD, DOUBLE_TAP, SWIPE, ARC, SPIRAL, WAVE }

var current_state = State.IDLE
var note_type_enum = NoteType.TAP

var hit_time := 0.0
var note_type := "tap"
var duration := 0.0
var end_position := Vector2.ZERO
var swipe_direction := Vector2.ZERO
var double_tap_count := 0
var last_tap_time := 0.0
var note_data_ref: Dictionary = {}

# Motifs spéciaux & trajectoires
var pattern_type := "standard"
var original_position := Vector2.ZERO
var trajectory_points: Array[Vector2] = []

# Paramètres de suivi de slider / trajectoire
var follow_radius := 95.0
var slider_follow_time := 0.0
var slider_total_time := 0.0
var next_tick_progress := 0.25
var tick_interval := 0.25

# Paramètres des motifs
var arc_center: Vector2
var arc_radius: float = 100.0
var arc_start_angle: float = 0.0
var arc_end_angle: float = 1.57
var spiral_center: Vector2
var spiral_radius: float = 80.0
var spiral_revolutions: float = 2.0
var wave_amplitude: float = 50.0
var wave_frequency: float = 2.0
var wave_start_pos: Vector2
var wave_end_pos: Vector2

@onready var note_sprite = $NoteSprite
@onready var end_circle_sprite = $EndCircleSprite
@onready var slider_track = $SliderTrack
@onready var slider_ball = $SliderBall
@onready var follow_circle = $FollowCircle
@onready var approach_circle = $ApproachCircle
@onready var collision_shape = $CollisionShape2D
@onready var swipe_arrow = $SwipeArrow

@onready var pattern_effects = $PatternEffects
@onready var arc_trail = $PatternEffects/ArcTrail
@onready var spiral_effect = $PatternEffects/SpiralEffect
@onready var spiral_particles = $PatternEffects/SpiralEffect/SpiralParticles
@onready var wave_effect = $PatternEffects/WaveEffect
@onready var wave_particles = $PatternEffects/WaveEffect/WaveParticles
@onready var pattern_glow = $PatternEffects/PatternGlow

var active_tweens: Array[Tween] = []

var main_node
var audio_player
var game_settings
var approach_time := 2.0
var miss_threshold := 0.45
var perfect_threshold := 0.10
var early_hit_window := 0.65
var audio_offset := 0.0
var hit_radius := 75.0

var note_number := 0
var note_scale := 1.0
var is_next_target := false
var target_pulse_phase := 0.0
var combo_color := Color.WHITE
var base_sprite_scale := Vector2(1.42857, 1.45238)
var base_approach_scale := Vector2(1.15209, 1.08365)

func _ready():
	visible = false
	set_process(false)
	if note_sprite:
		base_sprite_scale = note_sprite.scale
	if approach_circle:
		base_approach_scale = approach_circle.scale
	_refresh_references()

	if not has_node("NumberLabel"):
		var number_label = Label.new()
		number_label.name = "NumberLabel"
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number_label.add_theme_font_size_override("font_size", 24)
		number_label.add_theme_color_override("font_color", Color.WHITE)
		number_label.add_theme_color_override("font_outline_color", Color.BLACK)
		number_label.add_theme_constant_override("outline_size", 3)
		number_label.position = Vector2(-14, -16)
		number_label.z_index = 10
		add_child(number_label)

func _refresh_references():
	main_node = get_node_or_null("/root/Main")
	if main_node:
		audio_player = main_node.get_node_or_null("AudioStreamPlayer")
		if "approach_time" in main_node:
			approach_time = main_node.approach_time
	game_settings = get_node_or_null("/root/GlobalManager/GameSettings")
	if game_settings and "audio_offset" in game_settings:
		audio_offset = game_settings.audio_offset

func _get_current_time() -> float:
	if main_node and main_node.has_method("get_precise_music_time"):
		return main_node.get_precise_music_time()
	if is_instance_valid(audio_player):
		return audio_player.get_playback_position() + audio_offset
	return 0.0

func setup(note_data: Dictionary):
	_refresh_references()
	note_data_ref = note_data.duplicate()

	for tween in active_tweens:
		if is_instance_valid(tween):
			tween.kill()
	active_tweens.clear()

	visible = false
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0
	is_next_target = false
	target_pulse_phase = 0.0
	current_state = State.IDLE
	collision_shape.disabled = false
	note_sprite.position = Vector2.ZERO
	note_sprite.modulate = Color.WHITE
	slider_track.visible = false
	slider_ball.visible = false
	if follow_circle:
		follow_circle.visible = false
	end_circle_sprite.visible = false
	swipe_arrow.visible = false
	double_tap_count = 0
	slider_follow_time = 0.0
	slider_total_time = 0.0
	next_tick_progress = 0.25
	trajectory_points.clear()

	# Couleur de combo
	var color_manager = get_node_or_null("/root/Main/ComboColors")
	if color_manager:
		combo_color = color_manager.get_color_for_index(note_data.get("note_number", 0))
		color_manager.advance_color()
	else:
		combo_color = Color.WHITE

	# Taille de note (combinaison du scale de pattern et du paramètre GameSettings)
	var settings_scale := 1.0
	if game_settings and "note_size" in game_settings:
		settings_scale = game_settings.note_size
	note_scale = note_data.get("scale", 1.0) * settings_scale

	var visual_scale := base_sprite_scale * note_scale
	note_sprite.scale = visual_scale
	collision_shape.scale = Vector2(note_scale, note_scale)
	hit_radius = 135.0 * note_scale
	follow_radius = 140.0 * note_scale

	var show_approach := true
	if game_settings and "approach_circle_enabled" in game_settings:
		show_approach = game_settings.approach_circle_enabled
	approach_circle.visible = show_approach
	approach_circle.scale = base_approach_scale * note_scale * 3.0

	# Numéro de note
	note_number = note_data.get("note_number", 0)
	if has_node("NumberLabel"):
		var label = $NumberLabel
		if note_number > 0 and note_number <= 99:
			label.text = str(note_number)
			label.visible = true
		else:
			label.visible = false

	pattern_type = note_data.get("pattern_type", "standard")
	hit_time = float(note_data.get("time", 0.0))
	original_position = Vector2(note_data.get("x", 576), note_data.get("y", 324))
	position = original_position
	note_type = note_data.get("note_type", "tap")

	match note_type:
		"hold":
			note_type_enum = NoteType.HOLD
			duration = maxf(0.25, float(note_data.get("duration", 1.0)))
			end_position = Vector2(note_data.get("end_x", position.x + 150), note_data.get("end_y", position.y))
			slider_track.visible = true
			end_circle_sprite.visible = true
			end_circle_sprite.global_position = end_position
			var curve_type: String = note_data.get("curve_type", "linear")
			var control_points: Array = note_data.get("control_points", [])
			setup_slider_curve(curve_type, control_points)
		"arc":
			note_type_enum = NoteType.ARC
			pattern_type = "arc"
			duration = maxf(0.4, float(note_data.get("duration", 1.5)))
			generate_trajectory(note_data)
		"spiral":
			note_type_enum = NoteType.SPIRAL
			pattern_type = "spiral"
			duration = maxf(0.5, float(note_data.get("duration", 2.0)))
			generate_trajectory(note_data)
		"wave":
			note_type_enum = NoteType.WAVE
			pattern_type = "wave"
			duration = maxf(0.4, float(note_data.get("duration", 1.8)))
			generate_trajectory(note_data)
		"double_tap":
			note_type_enum = NoteType.DOUBLE_TAP
		"swipe":
			note_type_enum = NoteType.SWIPE
			swipe_direction = Vector2(note_data.get("swipe_x", 1.0), note_data.get("swipe_y", 0.0)).normalized()
			swipe_arrow.visible = true
			swipe_arrow.rotation = swipe_direction.angle()
		_:
			note_type_enum = NoteType.TAP

	setup_pattern_visuals()
	_update_approach_circle(_get_current_time())
	set_process(true)
	visible = true

# === COURBES DE SLIDER ===

func setup_slider_curve(curve_type: String, control_points: Array):
	var curve_points: PackedVector2Array = []
	var start_local := Vector2.ZERO
	var end_local := to_local(end_position)

	match curve_type:
		"bezier", "quadratic", "cubic":
			if control_points.size() >= 2:
				var cp1 := Vector2(control_points[0].get("x", 0), control_points[0].get("y", 0)) - position
				var cp2 := Vector2(control_points[1].get("x", 0), control_points[1].get("y", 0)) - position
				curve_points = generate_cubic_bezier(start_local, cp1, cp2, end_local, 24)
			elif control_points.size() == 1:
				var cp1 := Vector2(control_points[0].get("x", 0), control_points[0].get("y", 0)) - position
				curve_points = generate_quadratic_bezier(start_local, cp1, end_local, 20)
			else:
				curve_points = PackedVector2Array([start_local, end_local])
		"catmull":
			var all_points := [start_local]
			for cp in control_points:
				all_points.append(Vector2(cp.get("x", 0), cp.get("y", 0)) - position)
			all_points.append(end_local)
			curve_points = generate_catmull_rom(all_points, 6)
		"arc_curve":
			var mid_point := (start_local + end_local) * 0.5
			var perpendicular := (end_local - start_local).normalized().rotated(PI * 0.5)
			var arc_height: float = control_points[0].get("height", 50.0) if control_points.size() > 0 else 50.0
			var control := mid_point + perpendicular * arc_height
			curve_points = generate_quadratic_bezier(start_local, control, end_local, 18)
		_:
			curve_points = PackedVector2Array([start_local, end_local])

	slider_track.points = curve_points
	slider_track.default_color = combo_color.lightened(0.2)
	slider_track.width = 10.0 * note_scale
	trajectory_points.clear()
	for p in curve_points:
		trajectory_points.append(p)

func generate_quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var t := float(i) / segments
		points.append((1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2)
	return points

func generate_cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var t := float(i) / segments
		var u := 1.0 - t
		points.append(u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3)
	return points

func generate_catmull_rom(control_points: Array, segments_per_curve: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	if control_points.size() < 2:
		return points
	for i in range(control_points.size() - 1):
		var p0: Vector2 = control_points[maxi(0, i - 1)]
		var p1: Vector2 = control_points[i]
		var p2: Vector2 = control_points[mini(control_points.size() - 1, i + 1)]
		var p3: Vector2 = control_points[mini(control_points.size() - 1, i + 2)]
		for j in range(segments_per_curve):
			var t := float(j) / segments_per_curve
			points.append(catmull_rom_point(p0, p1, p2, p3, t))
	points.append(control_points[-1])
	return points

func catmull_rom_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func get_point_on_trajectory(progress: float) -> Vector2:
	if trajectory_points.is_empty():
		return Vector2.ZERO.lerp(to_local(end_position), clampf(progress, 0.0, 1.0))
	if trajectory_points.size() == 1:
		return trajectory_points[0]
	var clamped := clampf(progress, 0.0, 1.0)
	var scaled := clamped * float(trajectory_points.size() - 1)
	var idx := mini(int(floor(scaled)), trajectory_points.size() - 2)
	var frac := scaled - float(idx)
	return trajectory_points[idx].lerp(trajectory_points[idx + 1], frac)

# === TRAJECTOIRES SPÉCIALES ===

func generate_trajectory(data: Dictionary):
	trajectory_points.clear()
	match pattern_type:
		"arc":
			arc_center = Vector2(data.get("arc_center_x", position.x + 100) - position.x, data.get("arc_center_y", position.y + 100) - position.y)
			arc_radius = float(data.get("arc_radius", 120.0))
			arc_start_angle = float(data.get("arc_start_angle", 0.0))
			arc_end_angle = float(data.get("arc_angle", 1.57))
			trajectory_points.append(Vector2.ZERO)
			for i in range(1, 16):
				var angle := lerpf(arc_start_angle, arc_end_angle, float(i) / 15.0)
				trajectory_points.append(arc_center + Vector2(cos(angle), sin(angle)) * arc_radius)
		"spiral":
			spiral_center = Vector2(data.get("spiral_center_x", position.x) - position.x, data.get("spiral_center_y", position.y + 40) - position.y)
			spiral_radius = float(data.get("spiral_radius", 80.0))
			spiral_revolutions = float(data.get("spiral_revolutions", 1.5))
			trajectory_points.append(Vector2.ZERO)
			for i in range(1, 25):
				var p := float(i) / 24.0
				var angle := p * spiral_revolutions * TAU
				var r := spiral_radius * (1.0 - p * 0.7)
				trajectory_points.append(spiral_center + Vector2(cos(angle), sin(angle)) * r)
		"wave":
			wave_start_pos = Vector2.ZERO
			wave_end_pos = Vector2(data.get("wave_end_x", position.x + 200) - position.x, data.get("wave_end_y", position.y) - position.y)
			wave_amplitude = float(data.get("wave_amplitude", 40.0))
			wave_frequency = float(data.get("wave_frequency", 1.5))
			for i in range(19):
				var p := float(i) / 18.0
				var base_pos := wave_start_pos.lerp(wave_end_pos, p)
				trajectory_points.append(base_pos + Vector2(0.0, sin(p * wave_frequency * TAU) * wave_amplitude))

# === BOUCLE PRINCIPALE ===

func _process(delta: float):
	if not visible or current_state == State.FADING_OUT:
		return
	if not is_instance_valid(audio_player) or not audio_player.playing:
		return

	var current_time := _get_current_time()

	# AutoPlay (pour test ou mode auto)
	if game_settings and game_settings.should_auto_play():
		if current_state == State.IDLE and current_time >= hit_time:
			handle_initial_hit()
			if note_type_enum == NoteType.DOUBLE_TAP and current_state == State.IDLE:
				handle_initial_hit()
			return

	# Mod Relax (visée seule sans cliquer - déclenche pile sur le beat)
	if game_settings and game_settings.should_relax():
		if current_state == State.IDLE and current_time >= hit_time - 0.015 and is_cursor_over(get_global_mouse_position()):
			handle_initial_hit()
			if note_type_enum == NoteType.DOUBLE_TAP and current_state == State.IDLE:
				handle_initial_hit()
			return

	_update_approach_circle(current_time)
	update_note_glow(current_time)
	check_for_miss(current_time)
	check_double_tap_timeout(current_time)

	if is_next_target and current_state == State.IDLE:
		target_pulse_phase += delta * 8.0
		queue_redraw()
	elif target_pulse_phase != 0.0:
		target_pulse_phase = 0.0
		queue_redraw()

	if current_state == State.HOLDING:
		update_slider_ball(current_time, delta)

func _update_approach_circle(current_time: float):
	if not approach_circle or not approach_circle.visible:
		return
	var time_until_hit := hit_time - current_time
	var progress := clampf(1.0 - (time_until_hit / maxf(approach_time, 0.1)), 0.0, 1.15)
	var target_scale := base_approach_scale * note_scale * 0.90
	approach_circle.scale = (base_approach_scale * note_scale * 3.0).lerp(target_scale, progress)

func update_note_glow(current_time: float):
	var time_until_hit := hit_time - current_time
	var approach_progress := clampf(1.0 - (time_until_hit / maxf(approach_time, 0.1)), 0.0, 1.0)

	var pulse_speed := 3.0 + approach_progress * 4.0
	var base_pulse := sin(current_time * pulse_speed * TAU)
	var glow_intensity := 0.3 + approach_progress * 0.7

	var base_color := combo_color
	match note_type_enum:
		NoteType.HOLD:
			base_color = base_color.lightened(0.1)
		NoteType.DOUBLE_TAP:
			base_color = base_color.lerp(Color.YELLOW, 0.25)
		NoteType.SWIPE:
			base_color = base_color.lerp(Color.CYAN, 0.25)
		NoteType.ARC:
			base_color = Color.CYAN
		NoteType.SPIRAL:
			base_color = Color.MAGENTA
		NoteType.WAVE:
			base_color = Color.ORANGE

	var pulse_color := 0.9 + 0.1 * base_pulse
	note_sprite.modulate = base_color.lerp(Color.WHITE, pulse_color * glow_intensity * 0.4)

	if approach_circle:
		approach_circle.modulate = base_color
		approach_circle.modulate.a = 0.45 + approach_progress * 0.55

	var base_scale := base_sprite_scale * note_scale
	if approach_progress > 0.5:
		var t := (approach_progress - 0.5) / 0.5
		var intensity := t * t * t
		var scale_shake := 1.0 + base_pulse * intensity * 0.08
		note_sprite.scale = base_scale * scale_shake
	else:
		note_sprite.scale = base_scale

# === INTERACTION & ARBITRAGE ===

func is_hittable(current_time: float) -> bool:
	if not visible or current_state != State.IDLE:
		return false
	var time_diff := current_time - hit_time
	return time_diff >= -early_hit_window and time_diff <= miss_threshold

func is_cursor_over(mouse_pos: Vector2) -> bool:
	return mouse_pos.distance_to(global_position) <= hit_radius

func _input(event):
	if current_state != State.HOLDING:
		return
	var released := false
	if event is InputEventMouseButton and not event.pressed:
		released = true
	elif (event.is_action_released("osu_hit_1") or event.is_action_released("osu_hit_2")):
		released = true

	if released and not (game_settings and (game_settings.should_auto_play() or game_settings.should_relax())):
		handle_release()

func update_slider_ball(current_time: float, delta: float):
	var elapsed := current_time - hit_time
	var progress := clampf(elapsed / maxf(duration, 0.1), 0.0, 1.0)

	var local_ball_pos := get_point_on_trajectory(progress)
	slider_ball.position = local_ball_pos

	var is_auto: bool = game_settings != null and game_settings.should_auto_play()
	var mouse_pos := get_global_mouse_position()
	var dist_to_ball := mouse_pos.distance_to(slider_ball.global_position)
	var following := is_auto or (dist_to_ball <= follow_radius)

	slider_total_time += delta
	if following:
		slider_follow_time += delta

	if follow_circle:
		follow_circle.visible = true
		follow_circle.position = local_ball_pos
		follow_circle.modulate = Color(0.4, 1.0, 0.5, 0.85) if following else Color(1.0, 0.3, 0.3, 0.5)

	# Slider ticks sonores
	if progress >= next_tick_progress and progress < 0.95:
		next_tick_progress += tick_interval
		if following and main_node and main_node.slider_tick_sound:
			main_node.slider_tick_sound.play_tick(progress)

	# Fin du slider atteinte dans le temps
	if progress >= 1.0:
		var follow_ratio := slider_follow_time / maxf(slider_total_time, 0.001)
		var accuracy := "Miss"
		if follow_ratio >= 0.70:
			accuracy = "Perfect"
		elif follow_ratio >= 0.35:
			accuracy = "Good"

		if accuracy != "Miss" and main_node and main_node.slider_tick_sound:
			main_node.slider_tick_sound.play_finish()

		if main_node:
			main_node.register_hit(accuracy, slider_ball.global_position, get_pattern_score_multiplier(), 0.0, note_data_ref)
		start_fading_out(accuracy == "Miss")

func check_for_miss(current_time: float):
	if current_state == State.IDLE and current_time > hit_time + miss_threshold:
		if main_node:
			main_node.register_hit("Miss", global_position, get_pattern_score_multiplier(), miss_threshold, note_data_ref)
		start_fading_out(true)

func check_double_tap_timeout(current_time: float):
	if note_type_enum == NoteType.DOUBLE_TAP and double_tap_count == 1:
		if current_time > last_tap_time + 0.35:
			if main_node:
				main_node.register_hit("Miss", global_position, get_pattern_score_multiplier(), 0.35, note_data_ref)
			start_fading_out(true)

func handle_initial_hit():
	if not is_instance_valid(audio_player) or not audio_player.playing:
		return

	var current_time := _get_current_time()
	var time_diff := current_time - hit_time

	if time_diff < -early_hit_window or time_diff > miss_threshold:
		return

	var hit_accuracy := absf(time_diff)
	var accuracy_string := "Good"
	if hit_accuracy <= perfect_threshold:
		accuracy_string = "Perfect"

	var pattern_multiplier := get_pattern_score_multiplier()

	match note_type_enum:
		NoteType.TAP, NoteType.SWIPE:
			if main_node:
				main_node.register_hit(accuracy_string, global_position, pattern_multiplier, time_diff, note_data_ref)
			start_fading_out(false)

		NoteType.HOLD, NoteType.ARC, NoteType.SPIRAL, NoteType.WAVE:
			if main_node:
				main_node.register_hit(accuracy_string, global_position, pattern_multiplier, time_diff, note_data_ref)
			current_state = State.HOLDING
			approach_circle.visible = false
			slider_ball.visible = true
			slider_ball.position = Vector2.ZERO
			slider_follow_time = 0.0
			slider_total_time = 0.0
			next_tick_progress = 0.25

		NoteType.DOUBLE_TAP:
			double_tap_count += 1
			last_tap_time = current_time
			if double_tap_count >= 2:
				if main_node:
					main_node.register_hit(accuracy_string, global_position, pattern_multiplier, time_diff, note_data_ref)
				start_fading_out(false)
			else:
				note_sprite.modulate = Color.GREEN

func handle_release():
	if current_state != State.HOLDING:
		return

	var current_time := _get_current_time()
	var elapsed := current_time - hit_time
	var time_progress := clampf(elapsed / maxf(duration, 0.1), 0.0, 1.0)
	var follow_ratio := slider_follow_time / maxf(slider_total_time, 0.001)

	var accuracy := "Miss"
	if time_progress >= 0.85 and follow_ratio >= 0.60:
		accuracy = "Perfect"
	elif time_progress >= 0.50 and follow_ratio >= 0.30:
		accuracy = "Good"

	if accuracy != "Miss" and main_node and main_node.slider_tick_sound:
		main_node.slider_tick_sound.play_finish()

	if main_node:
		main_node.register_hit(accuracy, slider_ball.global_position, get_pattern_score_multiplier(), elapsed - duration, note_data_ref)
	start_fading_out(accuracy == "Miss")

func start_fading_out(is_miss := false):
	if current_state == State.FADING_OUT:
		return
	current_state = State.FADING_OUT
	collision_shape.set_deferred("disabled", true)
	if follow_circle:
		follow_circle.visible = false

	var tween := create_tween()
	tween.set_parallel(true)
	if is_miss:
		tween.tween_property(note_sprite, "modulate", Color.RED, 0.15)
		if approach_circle:
			tween.tween_property(approach_circle, "modulate", Color.RED, 0.15)
		tween.tween_property(self, "position:y", position.y + 45.0, 0.35).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "modulate:a", 0.0, 0.35)
		tween.tween_property(self, "rotation", 0.25, 0.35)
	else:
		tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.1).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 0.0, 0.22)

	tween.chain().tween_callback(_return_to_pool)
	active_tweens.append(tween)

func _draw():
	if not is_next_target or current_state != State.IDLE or not visible:
		return
	var current_time := _get_current_time()
	var in_window := is_hittable(current_time)
	var base_r := 118.0 * note_scale
	var pulse := 1.0 + 0.07 * sin(target_pulse_phase)
	var ring_color := Color(1.0, 0.9, 0.25, 0.95) if in_window else Color(0.3, 0.95, 1.0, 0.45)
	draw_arc(Vector2.ZERO, base_r * pulse, 0.0, TAU, 48, ring_color, 4.0 if in_window else 2.5, true)

func _return_to_pool():
	is_next_target = false
	queue_redraw()
	cleanup_pattern_effects()
	visible = false
	scale = Vector2.ONE
	rotation = 0.0
	set_process(false)

func setup_pattern_visuals():
	arc_trail.visible = false
	spiral_effect.visible = false
	wave_effect.visible = false
	pattern_glow.visible = false
	spiral_particles.emitting = false
	wave_particles.emitting = false

	if pattern_type in ["arc", "spiral", "wave"] and trajectory_points.size() > 1:
		slider_track.visible = true
		slider_track.clear_points()
		for point in trajectory_points:
			slider_track.add_point(point)
		match pattern_type:
			"arc":
				slider_track.default_color = Color.CYAN
			"spiral":
				slider_track.default_color = Color.MAGENTA
			"wave":
				slider_track.default_color = Color.ORANGE
		slider_track.width = 6.0 * note_scale
		end_circle_sprite.visible = true
		end_circle_sprite.position = trajectory_points[-1]
		end_circle_sprite.modulate = slider_track.default_color

func get_pattern_score_multiplier() -> float:
	match pattern_type:
		"arc":
			return 1.2
		"spiral":
			return 1.3
		"wave":
			return 1.25
		_:
			return 1.0

func cleanup_pattern_effects():
	for tween in active_tweens:
		if is_instance_valid(tween):
			tween.kill()
	active_tweens.clear()

	if spiral_particles:
		spiral_particles.emitting = false
	if wave_particles:
		wave_particles.emitting = false
	if arc_trail:
		arc_trail.visible = false
		arc_trail.clear_points()
	if spiral_effect:
		spiral_effect.visible = false
	if wave_effect:
		wave_effect.visible = false
	if pattern_glow:
		pattern_glow.visible = false

	note_sprite.scale = base_sprite_scale
	note_sprite.position = Vector2.ZERO
	note_sprite.modulate = Color.WHITE
	approach_circle.rotation = 0.0
	approach_circle.modulate = Color.WHITE
	position = original_position
	slider_track.visible = false
	slider_ball.visible = false
	if follow_circle:
		follow_circle.visible = false
	end_circle_sprite.visible = false
