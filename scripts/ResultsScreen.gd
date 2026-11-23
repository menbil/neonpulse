extends Control
class_name ResultsScreen

## Écran de résultats amélioré style osu!lazer
## Avec graphe de performance, grade animé, statistiques détaillées

# === NODES ===
var grade_label: Label
var score_label: Label
var accuracy_container: VBoxContainer
var combo_container: VBoxContainer
var stats_container: HBoxContainer
var graph_panel: Panel
var graph_canvas: Control
var buttons_container: HBoxContainer

# === DATA ===
var performance_data: Array = []
var final_score := 0
var final_accuracy := 0.0
var final_combo := 0
var perfect_count := 0
var good_count := 0
var miss_count := 0
var grade := "D"

# === ANIMATION ===
var displayed_score := 0
var displayed_accuracy := 0.0
var animation_started := false

var grade_colors := {
	"SS": Color(1.0, 0.84, 0.0),
	"S": Color(1.0, 0.84, 0.0),
	"A": Color(0.3, 1.0, 0.3),
	"B": Color(0.3, 0.7, 1.0),
	"C": Color(0.8, 0.3, 1.0),
	"D": Color(1.0, 0.3, 0.3),
}

signal retry_pressed
signal menu_pressed

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	setup_ui()
	visible = false

func setup_ui():
	var main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_theme_constant_override("separation", 14)
	main_container.offset_left = 60
	main_container.offset_right = -60
	main_container.offset_top = 20
	main_container.offset_bottom = -20
	add_child(main_container)

	var bg = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.07, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	grade_label = Label.new()
	grade_label.name = "GradeLabel"
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_label.add_theme_font_size_override("font_size", 76)
	grade_label.text = "S"
	main_container.add_child(grade_label)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 38)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.text = "0"
	main_container.add_child(score_label)

	var stats_h = HBoxContainer.new()
	stats_h.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_h.add_theme_constant_override("separation", 50)
	main_container.add_child(stats_h)

	accuracy_container = create_stat_label("Accuracy", "100.00%")
	stats_h.add_child(accuracy_container)

	combo_container = create_stat_label("Max Combo", "0x")
	stats_h.add_child(combo_container)

	var hits_h = HBoxContainer.new()
	hits_h.alignment = BoxContainer.ALIGNMENT_CENTER
	hits_h.add_theme_constant_override("separation", 36)
	main_container.add_child(hits_h)

	hits_h.add_child(create_hit_count_label("Perfect", "0", Color(1.0, 0.84, 0.0)))
	hits_h.add_child(create_hit_count_label("Good", "0", Color(0.3, 1.0, 0.5)))
	hits_h.add_child(create_hit_count_label("Miss", "0", Color(1.0, 0.3, 0.3)))

	graph_panel = Panel.new()
	graph_panel.name = "PerformanceGraph"
	graph_panel.custom_minimum_size = Vector2(560, 100)
	var graph_style = StyleBoxFlat.new()
	graph_style.bg_color = Color(0.08, 0.09, 0.15, 0.92)
	graph_style.border_width_left = 1
	graph_style.border_width_top = 1
	graph_style.border_width_right = 1
	graph_style.border_width_bottom = 1
	graph_style.border_color = Color(0.25, 0.45, 0.7, 0.5)
	graph_style.corner_radius_top_left = 10
	graph_style.corner_radius_top_right = 10
	graph_style.corner_radius_bottom_left = 10
	graph_style.corner_radius_bottom_right = 10
	graph_panel.add_theme_stylebox_override("panel", graph_style)
	graph_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_container.add_child(graph_panel)

	graph_canvas = Control.new()
	graph_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	graph_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_canvas.draw.connect(_draw_graph_canvas)
	graph_panel.add_child(graph_canvas)

	buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_container.add_theme_constant_override("separation", 24)
	main_container.add_child(buttons_container)

	var retry_btn = create_button("Retry", Color(0.2, 0.65, 1.0))
	retry_btn.pressed.connect(func(): retry_pressed.emit())
	buttons_container.add_child(retry_btn)

	var menu_btn = create_button("Menu", Color(0.42, 0.44, 0.55))
	menu_btn.pressed.connect(func(): menu_pressed.emit())
	buttons_container.add_child(menu_btn)

	stats_container = hits_h

func create_stat_label(title: String, value: String) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	container.add_child(title_lbl)

	var value_lbl = Label.new()
	value_lbl.name = title + "Value"
	value_lbl.text = value
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_font_size_override("font_size", 26)
	value_lbl.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(value_lbl)

	return container

func create_hit_count_label(title: String, value: String, color: Color) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	var value_lbl = Label.new()
	value_lbl.name = title + "Count"
	value_lbl.text = value
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.add_theme_font_size_override("font_size", 24)
	value_lbl.add_theme_color_override("font_color", color)
	container.add_child(value_lbl)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", color.darkened(0.25))
	container.add_child(title_lbl)

	return container

func create_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 48)

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.18)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_font_size_override("font_size", 20)
	return btn

func show_results(data: Dictionary):
	final_score = data.get("score", 0)
	final_accuracy = data.get("accuracy", 0.0)
	final_combo = data.get("max_combo", 0)
	perfect_count = data.get("perfect", 0)
	good_count = data.get("good", 0)
	miss_count = data.get("miss", 0)
	grade = data.get("grade", "D")
	performance_data = data.get("timing_errors", [])

	displayed_score = 0
	displayed_accuracy = 0.0
	animation_started = true

	visible = true
	modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.45)

	grade_label.text = grade
	grade_label.add_theme_color_override("font_color", grade_colors.get(grade, Color.WHITE))
	grade_label.scale = Vector2.ZERO
	tween.parallel().tween_property(grade_label, "scale", Vector2(1.15, 1.15), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(grade_label, "scale", Vector2.ONE, 0.1)

	update_hit_counts()
	if graph_canvas:
		graph_canvas.queue_redraw()

func _process(delta: float):
	if not animation_started or not visible:
		return

	if displayed_score < final_score:
		displayed_score = mini(final_score, displayed_score + maxi(1, int(final_score * delta * 2.0)))
		score_label.text = "%d" % displayed_score
	else:
		score_label.text = "%d" % final_score

	if displayed_accuracy < final_accuracy:
		displayed_accuracy = minf(final_accuracy, displayed_accuracy + final_accuracy * delta * 2.0)
		var acc_label = accuracy_container.get_node_or_null("AccuracyValue")
		if acc_label:
			acc_label.text = "%.2f%%" % displayed_accuracy
	else:
		var acc_label = accuracy_container.get_node_or_null("AccuracyValue")
		if acc_label:
			acc_label.text = "%.2f%%" % final_accuracy

	if graph_canvas:
		graph_canvas.queue_redraw()

func update_hit_counts():
	for child in stats_container.get_children():
		if child is VBoxContainer:
			var count_lbl = child.get_child(0) if child.get_child_count() > 0 else null
			if count_lbl:
				if count_lbl.name == "PerfectCount":
					count_lbl.text = str(perfect_count)
				elif count_lbl.name == "GoodCount":
					count_lbl.text = str(good_count)
				elif count_lbl.name == "MissCount":
					count_lbl.text = str(miss_count)

	var combo_value = combo_container.get_node_or_null("Max ComboValue")
	if combo_value:
		combo_value.text = "%dx" % final_combo

func _draw_graph_canvas():
	if not visible or performance_data.is_empty() or not graph_canvas:
		return

	var graph_size := graph_canvas.size
	var pad_left := 58.0
	var pad_right := 20.0
	var pad_y := 14.0
	var graph_width := maxf(10.0, graph_size.x - pad_left - pad_right)
	var graph_height := maxf(10.0, graph_size.y - pad_y * 2.0)
	var center_y := graph_size.y * 0.5

	# Échelle dynamique pour que la courbe reste toujours lisible
	var peak := 0.05
	var sum_err := 0.0
	for e in performance_data:
		var val := float(e)
		peak = maxf(peak, absf(val))
		sum_err += val
	var max_error := clampf(peak * 1.15, 0.06, 0.25)
	var avg_ms := int(round((sum_err / float(performance_data.size())) * 1000.0))

	# Zone "Perfect" (±50ms) mise en évidence
	var perfect_half_h := clampf((0.05 / max_error) * (graph_height * 0.5), 4.0, graph_height * 0.5)
	graph_canvas.draw_rect(
		Rect2(pad_left, center_y - perfect_half_h, graph_width, perfect_half_h * 2.0),
		Color(0.15, 0.85, 0.65, 0.10)
	)

	# Ligne centrale 0ms
	graph_canvas.draw_line(
		Vector2(pad_left, center_y),
		Vector2(graph_size.x - pad_right, center_y),
		Color(0.75, 0.85, 1.0, 0.55),
		1.5
	)

	# Courbe + points lumineux
	var count := performance_data.size()
	var point_spacing := graph_width / maxf(1.0, float(count - 1))
	var line_points := PackedVector2Array()

	for i in range(count):
		var error := float(performance_data[i])
		var x := pad_left + (float(i) * point_spacing if count > 1 else graph_width * 0.5)
		var y := center_y - (error / max_error) * (graph_height * 0.5)
		y = clampf(y, pad_y, graph_size.y - pad_y)
		line_points.append(Vector2(x, y))

	if line_points.size() >= 2:
		graph_canvas.draw_polyline(line_points, Color(0.3, 0.9, 1.0, 0.45), 1.5, true)

	for i in range(count):
		var error := float(performance_data[i])
		var pt := line_points[i]
		var color := Color(0.25, 1.0, 0.55) if absf(error) < 0.05 else (Color(1.0, 0.85, 0.25) if absf(error) < 0.1 else Color(1.0, 0.35, 0.35))
		graph_canvas.draw_circle(pt, 3.2, color)

	# Labels nets au premier plan
	graph_canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(10.0, 20.0),
		"Early",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.8, 1.0)
	)
	graph_canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(10.0, center_y + 4.0),
		"0ms",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.8, 0.85, 0.8)
	)
	graph_canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(10.0, graph_size.y - 8.0),
		"Late",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.45, 0.45)
	)
	graph_canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(graph_size.x - 105.0, 18.0),
		"Avg: %+dms" % avg_ms,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.9, 1.0, 0.85)
	)

func hide_results():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func(): visible = false)
