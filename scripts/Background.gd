extends ColorRect

@onready var player = get_parent().get_node("AudioStreamPlayer")

func _process(delta):
    if player and player.playing:
        var level = player.get_playback_position() % 1.0
        self.color.r = 0.05 + 0.15 * sin(level * 6.28)
        self.color.b = 0.1 + 0.2 * cos(level * 6.28)
