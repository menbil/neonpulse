extends Node
class_name HitsoundManager

## Gestionnaire de hitsounds style osu!lazer
## Gère les sons de hit (normal, clap, whistle, finish) et les effets sonores

# === AUDIO PLAYERS ===
var hit_normal_player: AudioStreamPlayer
var hit_clap_player: AudioStreamPlayer
var hit_whistle_player: AudioStreamPlayer
var hit_finish_player: AudioStreamPlayer
var combo_break_player: AudioStreamPlayer
var slider_slide_player: AudioStreamPlayer
var miss_player: AudioStreamPlayer

# === CONFIGURATION ===
var hitsound_volume: float = 0.8  # 0.0 - 1.0
var master_volume_db: float = 0.0

# Types de hitsounds
enum HitsoundType {
	NORMAL,
	CLAP,
	WHISTLE,
	FINISH
}

# === PRELOADED SOUNDS ===
# Ces sons seront générés procéduralement car on n'a pas de fichiers audio
var sounds_ready := false

func _ready():
	name = "HitsoundManager"
	setup_audio_players()
	generate_procedural_sounds()
	sounds_ready = true

func setup_audio_players():
	# Créer les audio players pour chaque type de son
	hit_normal_player = AudioStreamPlayer.new()
	hit_normal_player.name = "HitNormal"
	hit_normal_player.bus = "Master"
	add_child(hit_normal_player)
	
	hit_clap_player = AudioStreamPlayer.new()
	hit_clap_player.name = "HitClap"
	hit_clap_player.bus = "Master"
	add_child(hit_clap_player)
	
	hit_whistle_player = AudioStreamPlayer.new()
	hit_whistle_player.name = "HitWhistle"
	hit_whistle_player.bus = "Master"
	add_child(hit_whistle_player)
	
	hit_finish_player = AudioStreamPlayer.new()
	hit_finish_player.name = "HitFinish"
	hit_finish_player.bus = "Master"
	add_child(hit_finish_player)
	
	combo_break_player = AudioStreamPlayer.new()
	combo_break_player.name = "ComboBreak"
	combo_break_player.bus = "Master"
	add_child(combo_break_player)
	
	slider_slide_player = AudioStreamPlayer.new()
	slider_slide_player.name = "SliderSlide"
	slider_slide_player.bus = "Master"
	add_child(slider_slide_player)
	
	miss_player = AudioStreamPlayer.new()
	miss_player.name = "Miss"
	miss_player.bus = "Master"
	add_child(miss_player)

func generate_procedural_sounds():
	## Génère des sons procéduraux style osu! 
	## En production, on chargerait des vrais fichiers audio
	
	# Hit Normal - "toc" court et sec
	hit_normal_player.stream = generate_hit_sound(440.0, 0.08, 0.7)
	
	# Hit Clap - son de clap plus aigu
	hit_clap_player.stream = generate_clap_sound(0.1, 0.6)
	
	# Hit Whistle - sifflement aigu
	hit_whistle_player.stream = generate_whistle_sound(880.0, 0.12, 0.5)
	
	# Hit Finish - son plus grave et puissant (cymbal-like)
	hit_finish_player.stream = generate_finish_sound(0.2, 0.8)
	
	# Combo Break - son dramatique
	combo_break_player.stream = generate_combo_break_sound(0.3, 0.7)
	
	# Miss - petit son grave
	miss_player.stream = generate_miss_sound(0.15, 0.4)

func generate_hit_sound(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	## Génère un son de hit basique (onde sinusoïdale avec decay)
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 30.0)  # Decay rapide
		var wave = sin(2.0 * PI * frequency * t)
		# Ajouter harmoniques pour plus de richesse
		wave += 0.5 * sin(4.0 * PI * frequency * t)
		wave += 0.25 * sin(6.0 * PI * frequency * t)
		wave *= envelope * volume
		
		var sample = int(clamp(wave * 32767, -32768, 32767))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	
	audio.data = data
	return audio

func generate_clap_sound(duration: float, volume: float) -> AudioStreamWAV:
	## Génère un son de clap (bruit blanc filtré avec decay)
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Seed fixe pour reproductibilité
	
	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 25.0)
		# Bruit blanc filtré
		var noise = rng.randf_range(-1.0, 1.0)
		var wave = noise * envelope * volume
		
		var sample = int(clamp(wave * 32767, -32768, 32767))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	
	audio.data = data
	return audio

func generate_whistle_sound(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	## Génère un sifflement
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = sin(PI * t / duration)  # Envelope en cloche
		var freq_mod = frequency * (1.0 + 0.1 * sin(t * 20.0))  # Légère modulation
		var wave = sin(2.0 * PI * freq_mod * t) * envelope * volume
		
		var sample = int(clamp(wave * 32767, -32768, 32767))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	
	audio.data = data
	return audio

func generate_finish_sound(duration: float, volume: float) -> AudioStreamWAV:
	## Génère un son de finish (cymbal-like)
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 54321
	
	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 8.0)
		# Mélange de fréquences hautes et bruit
		var wave = sin(2.0 * PI * 200.0 * t) * 0.3
		wave += sin(2.0 * PI * 400.0 * t) * 0.2
		wave += rng.randf_range(-0.5, 0.5)  # Bruit métallique
		wave *= envelope * volume
		
		var sample = int(clamp(wave * 32767, -32768, 32767))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	
	audio.data = data
	return audio

func generate_combo_break_sound(duration: float, volume: float) -> AudioStreamWAV:
	## Génère un son de combo break dramatique
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 5.0)
		# Fréquence descendante pour effet dramatique
		var freq = 300.0 * (1.0 - t / duration * 0.5)
		var wave = sin(2.0 * PI * freq * t)
		wave += 0.3 * sin(2.0 * PI * freq * 0.5 * t)  # Sous-harmonique
		wave *= envelope * volume
		
		var sample = int(clamp(wave * 32767, -32768, 32767))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	
	audio.data = data
	return audio

func generate_miss_sound(duration: float, volume: float) -> AudioStreamWAV:
	## Génère un petit son de miss
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 15.0)
		# Son grave qui descend
		var freq = 150.0 * (1.0 - t / duration * 0.3)
		var wave = sin(2.0 * PI * freq * t) * envelope * volume
		
		var sample = int(clamp(wave * 32767, -32768, 32767))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	
	audio.data = data
	return audio

# === PUBLIC API ===

func play_hit(hitsound_type: HitsoundType = HitsoundType.NORMAL, pitch_variation: float = 0.0):
	## Joue un hitsound avec variation de pitch optionnelle
	if not sounds_ready:
		return
	
	var player: AudioStreamPlayer
	match hitsound_type:
		HitsoundType.NORMAL:
			player = hit_normal_player
		HitsoundType.CLAP:
			player = hit_clap_player
		HitsoundType.WHISTLE:
			player = hit_whistle_player
		HitsoundType.FINISH:
			player = hit_finish_player
	
	if player:
		player.volume_db = master_volume_db + linear_to_db(hitsound_volume)
		player.pitch_scale = 1.0 + pitch_variation
		player.play()

func play_combo_break():
	## Joue le son de combo break
	if sounds_ready and combo_break_player:
		combo_break_player.volume_db = master_volume_db + linear_to_db(hitsound_volume)
		combo_break_player.play()

func play_miss():
	## Joue le son de miss
	if sounds_ready and miss_player:
		miss_player.volume_db = master_volume_db + linear_to_db(hitsound_volume * 0.5)
		miss_player.play()

func play_slider_slide(should_play: bool):
	## Active/désactive le son de slider
	if sounds_ready and slider_slide_player:
		if should_play and not slider_slide_player.playing:
			slider_slide_player.volume_db = master_volume_db + linear_to_db(hitsound_volume * 0.3)
			slider_slide_player.play()
		elif not should_play and slider_slide_player.playing:
			slider_slide_player.stop()

func set_volume(volume: float):
	## Définit le volume des hitsounds (0.0 - 1.0)
	hitsound_volume = clamp(volume, 0.0, 1.0)

func get_hitsound_for_note(note_data: Dictionary) -> HitsoundType:
	## Détermine le hitsound à utiliser selon les données de la note
	var hitsound = note_data.get("hitsound", "normal")
	match hitsound:
		"clap":
			return HitsoundType.CLAP
		"whistle":
			return HitsoundType.WHISTLE
		"finish":
			return HitsoundType.FINISH
		_:
			return HitsoundType.NORMAL
