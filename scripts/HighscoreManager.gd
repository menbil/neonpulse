extends Node

var save_path := "user://highscores/"
var track_name := ""

func init(track_id):
	track_name = track_id

func save_score(score: int, rank: String, combo: int = 0, accuracy: float = 0.0, perfect_hits: int = 0, good_hits: int = 0, misses: int = 0):
	var dir = DirAccess.open(save_path)
	if not dir:
		DirAccess.make_dir_absolute(save_path)

	var current_data = load_score()
	var is_new_highscore = score > current_data.get("score", 0)
	
	if is_new_highscore:
		var file = FileAccess.open(save_path + "%s.save" % track_name, FileAccess.WRITE)
		var data = {
			"score": score,
			"rank": rank,
			"combo": combo,
			"accuracy": accuracy,
			"perfect_hits": perfect_hits,
			"good_hits": good_hits,
			"misses": misses,
			"date": Time.get_datetime_string_from_system()
		}
		file.store_string(JSON.stringify(data, "	"))
		file.close()
	
	# Always save to history
	save_to_history(score, rank, combo, accuracy, perfect_hits, good_hits, misses)
	
	return is_new_highscore

func save_to_history(score: int, rank: String, combo: int, accuracy: float, perfect_hits: int, good_hits: int, misses: int):
	var history_file = save_path + "%s_history.save" % track_name
	var history = []
	
	if FileAccess.file_exists(history_file):
		var file = FileAccess.open(history_file, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			if data and typeof(data) == TYPE_ARRAY:
				history = data
			file.close()
	
	var new_entry = {
		"score": score,
		"rank": rank,
		"combo": combo,
		"accuracy": accuracy,
		"perfect_hits": perfect_hits,
		"good_hits": good_hits,
		"misses": misses,
		"date": Time.get_datetime_string_from_system()
	}
	
	history.append(new_entry)
	
	# Keep only last 10 plays
	if history.size() > 10:
		history = history.slice(-10)
	
	var file = FileAccess.open(history_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(history, "	"))
		file.close()

func load_score():
	var file_path = save_path + "%s.save" % track_name
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			return data
	return {"score": 0, "rank": "-", "combo": 0, "accuracy": 0.0}

func load_history():
	var history_file = save_path + "%s_history.save" % track_name
	if FileAccess.file_exists(history_file):
		var file = FileAccess.open(history_file, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			if data and typeof(data) == TYPE_ARRAY:
				return data
	return []

func get_average_score() -> float:
	var history = load_history()
	if history.size() == 0:
		return 0.0
	
	var total = 0
	for entry in history:
		total += entry.get("score", 0)
	
	return float(total) / history.size()

func get_improvement_trend() -> String:
	var history = load_history()
	if history.size() < 3:
		return "Not enough data"
	
	var recent_avg = 0.0
	var older_avg = 0.0
	var mid_point = history.size() / 2
	
	for i in range(mid_point, history.size()):
		recent_avg += history[i].get("score", 0)
	recent_avg /= (history.size() - mid_point)
	
	for i in range(0, mid_point):
		older_avg += history[i].get("score", 0)
	older_avg /= mid_point
	
	var improvement = ((recent_avg - older_avg) / older_avg) * 100.0
	
	if improvement > 10:
		return "Improving!"
	elif improvement < -10:
		return "Declining"
	else:
		return "Stable"
