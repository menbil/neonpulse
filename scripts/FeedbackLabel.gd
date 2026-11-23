extends Label

var fade_timer: Timer

func _ready():
	fade_timer = Timer.new()
	add_child(fade_timer)
	fade_timer.one_shot = true
	fade_timer.timeout.connect(hide)
	visible = false

func show_feedback(text_arg: String):
	fade_timer.stop()
	text = text_arg.to_upper()
	match text_arg:
		"Perfect":
			add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
		"Good":
			add_theme_color_override("font_color", Color(0.4, 1.0, 0.45))
		"Miss":
			add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_:
			add_theme_color_override("font_color", Color.WHITE)
	visible = true
	fade_timer.start(0.75)
