# Script de démarrage automatique pour NeonPulse
# Ajouter ce script aux autoloads du projet avec le nom "GlobalManager"

extends Node

var beatmap_cache := {}

var game_settings
var progression_system
var audio_analyzer
var debug_manager

func _ready():
	print("🚀 NeonPulse Global Manager - Initialisation...")
	
	# Configuration audio et inputs AVANT les systèmes qui en dépendent
	setup_audio_buses()
	setup_input_actions()
	
	# Chargement des systèmes
	setup_global_systems()
	
	print("✅ NeonPulse initialisé avec succès!")

func setup_global_systems():
	game_settings = load("res://scripts/GameSettings.gd").new()
	progression_system = load("res://scripts/ProgressionSystem.gd").new()
	audio_analyzer = load("res://scripts/AudioAnalyzer.gd").new()
	debug_manager = load("res://scripts/DebugManager.gd").new()
	
	add_child(game_settings)
	add_child(progression_system)
	add_child(audio_analyzer)
	add_child(debug_manager)
	
	game_settings.name = "GameSettings"
	progression_system.name = "ProgressionSystem"
	audio_analyzer.name = "AudioAnalyzer"
	debug_manager.name = "DebugManager"

func setup_input_actions():
	var actions = [
		{"name": "debug_toggle", "key": KEY_F1},
		{"name": "timing_windows", "key": KEY_F2},
		{"name": "note_info", "key": KEY_F3},
		{"name": "training_mode", "key": KEY_F4},
		{"name": "osu_hit_1", "key": KEY_Z},
		{"name": "osu_hit_2", "key": KEY_X},
		{"name": "retry_track", "key": KEY_R}
	]
	
	for action in actions:
		if not InputMap.has_action(action.name):
			InputMap.add_action(action.name)
			var event = InputEventKey.new()
			event.physical_keycode = action.key
			InputMap.action_add_event(action.name, event)

func setup_audio_buses():
	var buses_to_create = ["Music", "SFX"]
	for bus_name in buses_to_create:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var bus_index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus_index, bus_name)
			AudioServer.set_bus_send(bus_index, "Master")

func get_game_settings():
	return game_settings

func get_progression_system():
	return progression_system

func get_audio_analyzer():
	return audio_analyzer

func get_debug_manager():
	return debug_manager

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game_settings:
			game_settings.save_settings()
		if progression_system:
			progression_system.save_progress()
		get_tree().quit()
