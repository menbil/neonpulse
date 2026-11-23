extends Node2D
class_name NeonCursor

## Curseur néon personnalisé avec traînée fluide et pulse au clic / touche Z-X

const MAX_TRAIL_POINTS := 16
const TRAIL_LIFETIME := 0.14

var trail: Array[Dictionary] = []  # [{pos: Vector2, age: float}]
var pulse_scale := 1.0
var is_pressed := false
var cursor_color := Color(0.2, 0.95, 1.0, 1.0)
var accent_color := Color(1.0, 0.25, 0.75, 1.0)

func _ready():
	z_index = 200
	top_level = true

func _input(event):
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		is_pressed = event.pressed
		if event.pressed:
			trigger_pulse()
	elif (event.is_action_pressed("osu_hit_1") or event.is_action_pressed("osu_hit_2")) and not event.is_echo():
		is_pressed = true
		trigger_pulse()
	elif event.is_action_released("osu_hit_1") or event.is_action_released("osu_hit_2"):
		is_pressed = false

func trigger_pulse():
	pulse_scale = 1.55

func _process(delta: float):
	if not visible:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	global_position = mouse_pos

	# Ajouter un point à la traînée si la souris a bougé
	if trail.is_empty() or trail[-1].pos.distance_to(mouse_pos) > 3.0:
		trail.append({"pos": mouse_pos, "age": 0.0})
		if trail.size() > MAX_TRAIL_POINTS:
			trail.pop_front()

	# Vieillir la traînée
	for i in range(trail.size() - 1, -1, -1):
		trail[i].age += delta
		if trail[i].age >= TRAIL_LIFETIME:
			trail.remove_at(i)

	var target_scale := 1.25 if is_pressed else 1.0
	pulse_scale = lerpf(pulse_scale, target_scale, minf(1.0, delta * 18.0))
	queue_redraw()

func _draw():
	# Traînée néon
	if trail.size() >= 2:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in range(trail.size()):
			var t := float(i) / float(trail.size() - 1)
			var life := 1.0 - clampf(trail[i].age / TRAIL_LIFETIME, 0.0, 1.0)
			pts.append(to_local(trail[i].pos))
			var col := accent_color.lerp(cursor_color, t)
			col.a = t * life * 0.65
			cols.append(col)
		draw_polyline_colors(pts, cols, 6.0, true)

	# Halo externe
	var ring_radius := 14.0 * pulse_scale
	draw_circle(Vector2.ZERO, ring_radius + 3.0, Color(cursor_color.r, cursor_color.g, cursor_color.b, 0.20))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, cursor_color, 2.5, true)

	# Point central lumineux
	draw_circle(Vector2.ZERO, 4.5 * pulse_scale, Color.WHITE)
