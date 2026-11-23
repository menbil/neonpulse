extends Node

signal level_up(new_level)
signal achievement_unlocked(achievement_name)

var player_level := 1
var experience := 0
var experience_to_next_level := 100
var total_notes_hit := 0
var total_perfect_hits := 0
var total_good_hits := 0
var total_misses := 0
var max_combo_ever := 0
var total_score := 0
var tracks_completed := []
var achievements := []

# Achievements list
var achievement_definitions = {
	"first_perfect": {"name": "First Perfect!", "description": "Hit your first Perfect note", "unlocked": false},
	"combo_master": {"name": "Combo Master", "description": "Achieve a 50+ combo", "unlocked": false},
	"perfectionist": {"name": "Perfectionist", "description": "Get 100% Perfect on a song", "unlocked": false},
	"score_hunter": {"name": "Score Hunter", "description": "Reach 100,000 points", "unlocked": false},
	"veteran": {"name": "Veteran Player", "description": "Complete 10 tracks", "unlocked": false},
	"rhythm_god": {"name": "Rhythm God", "description": "Achieve S rank on 5 tracks", "unlocked": false}
}

const PROGRESS_FILE = "user://player_progress.save"

func _ready():
	load_progress()

func register_game_completed(score: int, rank: String, track_name: String, combo: int, perfect_hits: int, good_hits: int, misses: int):
	# Update stats
	total_score += score
	max_combo_ever = max(max_combo_ever, combo)
	total_perfect_hits += perfect_hits
	total_good_hits += good_hits
	total_misses += misses
	total_notes_hit += (perfect_hits + good_hits)
	
	# Track completion
	if track_name not in tracks_completed:
		tracks_completed.append(track_name)
	
	# Calculate experience gain
	var exp_gain = calculate_experience_gain(score, rank, perfect_hits, good_hits, misses)
	gain_experience(exp_gain)
	
	# Check achievements
	check_achievements(score, rank, combo, perfect_hits, good_hits, misses)
	
	save_progress()

func calculate_experience_gain(score: int, rank: String, perfect_hits: int, good_hits: int, misses: int) -> int:
	var base_exp = score / 100
	
	# Rank bonus
	var rank_multiplier = 1.0
	match rank:
		"S": rank_multiplier = 2.0
		"A": rank_multiplier = 1.5
		"B": rank_multiplier = 1.2
		"C": rank_multiplier = 1.0
		"D": rank_multiplier = 0.8
	
	# Accuracy bonus
	var total_notes = perfect_hits + good_hits + misses
	if total_notes > 0:
		var accuracy = float(perfect_hits + good_hits) / total_notes
		base_exp *= (1.0 + accuracy)
	
	return int(base_exp * rank_multiplier)

func gain_experience(amount: int):
	experience += amount
	check_level_up()

func check_level_up():
	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		player_level += 1
		experience_to_next_level = calculate_exp_needed_for_level(player_level + 1)
		emit_signal("level_up", player_level)

func calculate_exp_needed_for_level(level: int) -> int:
	return 100 * level + (level - 1) * 50

func check_achievements(score: int, rank: String, combo: int, perfect_hits: int, good_hits: int, misses: int):
	# First Perfect
	if perfect_hits > 0 and not achievement_definitions["first_perfect"]["unlocked"]:
		unlock_achievement("first_perfect")
	
	# Combo Master
	if combo >= 50 and not achievement_definitions["combo_master"]["unlocked"]:
		unlock_achievement("combo_master")
	
	# Perfectionist (100% Perfect)
	if misses == 0 and good_hits == 0 and perfect_hits > 0 and not achievement_definitions["perfectionist"]["unlocked"]:
		unlock_achievement("perfectionist")
	
	# Score Hunter
	if total_score >= 100000 and not achievement_definitions["score_hunter"]["unlocked"]:
		unlock_achievement("score_hunter")
	
	# Veteran
	if tracks_completed.size() >= 10 and not achievement_definitions["veteran"]["unlocked"]:
		unlock_achievement("veteran")
	
	# Count S ranks
	var s_rank_count = 0
	# This would need to be tracked separately in a more complete implementation
	
func unlock_achievement(achievement_id: String):
	if achievement_id in achievement_definitions:
		achievement_definitions[achievement_id]["unlocked"] = true
		achievements.append(achievement_id)
		emit_signal("achievement_unlocked", achievement_definitions[achievement_id]["name"])

func get_player_stats() -> Dictionary:
	var accuracy = 0.0
	var total_attempts = total_perfect_hits + total_good_hits + total_misses
	if total_attempts > 0:
		accuracy = float(total_perfect_hits + total_good_hits) / total_attempts * 100.0
	
	return {
		"level": player_level,
		"experience": experience,
		"exp_to_next": experience_to_next_level,
		"total_score": total_score,
		"accuracy": accuracy,
		"max_combo": max_combo_ever,
		"tracks_completed": tracks_completed.size(),
		"achievements": achievements.size(),
		"perfect_hits": total_perfect_hits,
		"good_hits": total_good_hits,
		"misses": total_misses
	}

func save_progress():
	var progress_data = {
		"player_level": player_level,
		"experience": experience,
		"experience_to_next_level": experience_to_next_level,
		"total_notes_hit": total_notes_hit,
		"total_perfect_hits": total_perfect_hits,
		"total_good_hits": total_good_hits,
		"total_misses": total_misses,
		"max_combo_ever": max_combo_ever,
		"total_score": total_score,
		"tracks_completed": tracks_completed,
		"achievements": achievements,
		"achievement_definitions": achievement_definitions
	}
	
	var file = FileAccess.open(PROGRESS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(progress_data))
		file.close()

func load_progress():
	if FileAccess.file_exists(PROGRESS_FILE):
		var file = FileAccess.open(PROGRESS_FILE, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var data = JSON.parse_string(json_text)
			if data:
				player_level = data.get("player_level", 1)
				experience = data.get("experience", 0)
				experience_to_next_level = data.get("experience_to_next_level", 100)
				total_notes_hit = data.get("total_notes_hit", 0)
				total_perfect_hits = data.get("total_perfect_hits", 0)
				total_good_hits = data.get("total_good_hits", 0)
				total_misses = data.get("total_misses", 0)
				max_combo_ever = data.get("max_combo_ever", 0)
				total_score = data.get("total_score", 0)
				tracks_completed = data.get("tracks_completed", [])
				achievements = data.get("achievements", [])
				var saved_achievements = data.get("achievement_definitions", {})
				for achievement_id in saved_achievements:
					if achievement_id in achievement_definitions:
						achievement_definitions[achievement_id] = saved_achievements[achievement_id]
