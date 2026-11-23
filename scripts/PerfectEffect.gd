extends ColorRect

func play_flash():
	modulate.a = 0.5
	show()
	create_tween().tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
