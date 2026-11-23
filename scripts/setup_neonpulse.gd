# Auto-installation script pour NeonPulse
# Ce script configure automatiquement les autoloads nécessaires

extends EditorScript

func _run():
	print("🚀 Configuration automatique de NeonPulse...")
	
	# Autoloads à ajouter
	var autoloads = [
		{"name": "GlobalManager", "path": "res://scripts/AutoSetup.gd"},
		{"name": "GameSettings", "path": "res://scripts/GameSettings.gd"},
		{"name": "ProgressionSystem", "path": "res://scripts/ProgressionSystem.gd"},
		{"name": "AudioAnalyzer", "path": "res://scripts/AudioAnalyzer.gd"},
		{"name": "DebugManager", "path": "res://scripts/DebugManager.gd"}
	]
	
	for autoload in autoloads:
		if ProjectSettings.has_setting("autoload/" + autoload.name):
			print("✅ Autoload '%s' déjà configuré" % autoload.name)
		else:
			ProjectSettings.set_setting("autoload/" + autoload.name, {
				"path": autoload.path,
				"enabled": true
			})
			print("➕ Ajouté autoload: %s" % autoload.name)
	
	# Configuration des input actions
	var input_actions = [
		{"name": "debug_toggle", "key": KEY_F1},
		{"name": "timing_windows", "key": KEY_F2},
		{"name": "note_info", "key": KEY_F3},
		{"name": "training_mode", "key": KEY_F4}
	]
	
	for action in input_actions:
		if not InputMap.has_action(action.name):
			InputMap.add_action(action.name)
			var event = InputEventKey.new()
			event.physical_keycode = action.key
			InputMap.action_add_event(action.name, event)
			print("⌨️ Ajouté input: %s (F%d)" % [action.name, action.key - KEY_F1 + 1])
	
	# Sauvegarde des modifications
	ProjectSettings.save()
	print("💾 Configuration sauvegardée")
	print("🎮 NeonPulse est maintenant configuré! Redémarrez le projet pour appliquer les changements.")
