extends Node

var debug_mode := false
var show_timing_windows := false
var show_fps := true
var show_note_info := false
var debug_overlay

func _ready():
	create_debug_overlay()

func _input(event):
	if event.is_action_pressed("debug_toggle"): # F1
		toggle_debug_mode()
	elif event.is_action_pressed("timing_windows"): # F2
		show_timing_windows = !show_timing_windows
	elif event.is_action_pressed("note_info"): # F3
		show_note_info = !show_note_info

func toggle_debug_mode():
	debug_mode = !debug_mode
	debug_overlay.visible = debug_mode

func create_debug_overlay():
	debug_overlay = Control.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.size = Vector2(400, 200)
	debug_label.add_theme_color_override("font_color", Color.YELLOW)
	debug_overlay.add_child(debug_label)
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	canvas.add_child(debug_overlay)
	debug_overlay.visible = false
	
	# Timer pour mise à jour des infos
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(_update_debug_info)
	timer.autostart = true
	add_child(timer)

func _update_debug_info():
	if not debug_mode or not debug_overlay:
		return
	
	var main_scene = get_tree().current_scene
	var debug_text = ""
	
	# FPS et performance
	debug_text += "=== PERFORMANCE ===\n"
	debug_text += "FPS: %d (%.1fms)\n" % [Engine.get_frames_per_second(), 1000.0 / max(1, Engine.get_frames_per_second())]
	debug_text += "Process Time: %.2fms\n" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	debug_text += "Physics Time: %.2fms\n" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	
	# Infos mémoire
	debug_text += "\n=== MEMORY ===\n"
	var memory_usage = OS.get_static_memory_usage()
	debug_text += "Static: %.1f MB\n" % (memory_usage / 1024.0 / 1024.0)
	debug_text += "Nodes: %d\n" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	debug_text += "Resources: %d\n" % Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	
	# Infos audio
	debug_text += "\n=== AUDIO ===\n"
	if main_scene.has_node("AudioStreamPlayer"):
		var audio = main_scene.get_node("AudioStreamPlayer")
		if audio.playing:
			debug_text += "Time: %.2fs\n" % audio.get_playback_position()
			debug_text += "Paused: %s\n" % audio.stream_paused
		else:
			debug_text += "Not playing\n"
	
	# Infos de jeu si disponibles
	if main_scene.has_method("get_debug_info"):
		var game_info = main_scene.get_debug_info()
		debug_text += "\n=== GAME ===\n"
		debug_text += "Score: %d (%.1fx)\n" % [game_info.get("score", 0), game_info.get("multiplier", 1.0)]
		debug_text += "Combo: %d (max: %d)\n" % [game_info.get("combo", 0), game_info.get("max_combo", 0)]
		debug_text += "Perfect: %d | Good: %d | Miss: %d\n" % [game_info.get("perfect_hits", 0), game_info.get("good_hits", 0), game_info.get("misses", 0)]
		debug_text += "Pool: %d | Active: %d\n" % [game_info.get("notes_in_pool", 0), game_info.get("active_notes", 0)]
		debug_text += "Progress: %d / %d\n" % [game_info.get("note_index", 0), game_info.get("total_notes", 0)]
	
	# Settings
	var game_settings = get_node_or_null("/root/GlobalManager/GameSettings")
	if game_settings:
		debug_text += "\n=== SETTINGS ===\n"
		debug_text += "Audio Offset: %+.0fms\n" % (game_settings.audio_offset * 1000.0)
		debug_text += "Approach Speed: %.2fx\n" % game_settings.approach_speed
	
	# Infos timing
	if show_timing_windows:
		debug_text += "\n=== TIMING WINDOWS ===\n"
		debug_text += "Perfect: ±120ms\n"
		debug_text += "Good: ±300ms\n"
		debug_text += "Early Hit: -1000ms\n"
		debug_text += "Miss: +500ms\n"
	
	debug_text += "\n[F1] Toggle | [F2] Timing | [F3] Note Info"
	
	var debug_label = debug_overlay.get_child(0)
	debug_label.text = debug_text

func log_performance(event_name: String, duration_ms: float):
	if debug_mode:
		print("[PERF] %s: %.2f ms" % [event_name, duration_ms])

func draw_timing_circle(note_position: Vector2, timing_accuracy: float):
	if show_timing_windows and debug_mode:
		# Cette fonction serait appelée depuis les notes pour visualiser les timing windows
		pass
