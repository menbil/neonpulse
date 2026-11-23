extends Node2D
class_name SliderTickSound

## Slider Tick Sound Manager - Sons pour les ticks de sliders

# === AUDIO ===
var tick_samples: Array[AudioStreamWAV] = []
var reverse_sample: AudioStreamWAV
var finish_sample: AudioStreamWAV

# === AUDIO POOL ===
var audio_pool: Array[AudioStreamPlayer] = []
var pool_index := 0

func _ready():
	generate_sounds()
	setup_audio_pool()

func setup_audio_pool():
	## Crée un pool d'AudioStreamPlayer pour éviter les délais
	for i in range(8):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = -6
		add_child(player)
		audio_pool.append(player)

func generate_sounds():
	## Génère les sons de slider
	
	# Tick sound (petit "blip")
	tick_samples.append(generate_tick_sound(0.8))
	tick_samples.append(generate_tick_sound(1.0))
	tick_samples.append(generate_tick_sound(1.2))
	
	# Reverse sound (son de retour)
	reverse_sample = generate_reverse_sound()
	
	# Finish sound (fin de slider)
	finish_sample = generate_finish_sound()

func generate_tick_sound(pitch_mult: float = 1.0) -> AudioStreamWAV:
	## Génère un petit son de tick
	var sample_rate := 44100
	var duration := 0.03  # Très court
	var samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)  # 16-bit
	
	var base_freq := 1200.0 * pitch_mult
	
	for i in range(samples):
		var t := float(i) / sample_rate
		var env := 1.0 - (t / duration)  # Decay linéaire
		env = pow(env, 2)  # Decay plus rapide
		
		# Son simple
		var sample := sin(TAU * base_freq * t) * env
		
		# Ajouter une harmonique
		sample += sin(TAU * base_freq * 2 * t) * env * 0.3
		
		var value := int(sample * 16000)
		value = clampi(value, -32768, 32767)
		
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	
	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	
	return stream

func generate_reverse_sound() -> AudioStreamWAV:
	## Son de reverse arrow (swoosh + blip)
	var sample_rate := 44100
	var duration := 0.1
	var samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t := float(i) / sample_rate
		var progress := t / duration
		
		# Envelope en cloche
		var env := sin(progress * PI)
		
		# Fréquence qui monte (swoosh effect)
		var freq: float = lerp(400.0, 1000.0, progress)
		var sample := sin(TAU * freq * t) * env
		
		# Ajouter du bruit pour le swoosh
		var noise := (randf() - 0.5) * 0.3 * env * (1.0 - progress)
		sample += noise
		
		var value := int(sample * 12000)
		value = clampi(value, -32768, 32767)
		
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	
	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	
	return stream

func generate_finish_sound() -> AudioStreamWAV:
	## Son de fin de slider (plus satisfaisant)
	var sample_rate := 44100
	var duration := 0.08
	var samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	
	var base_freq := 800.0
	
	for i in range(samples):
		var t := float(i) / sample_rate
		var progress := t / duration
		
		# Envelope avec attaque rapide
		var env := 1.0 - progress
		env = pow(env, 1.5)
		
		# Son principal
		var sample := sin(TAU * base_freq * t) * env
		
		# Harmoniques pour un son plus riche
		sample += sin(TAU * base_freq * 1.5 * t) * env * 0.4
		sample += sin(TAU * base_freq * 2 * t) * env * 0.2
		
		var value := int(sample * 14000)
		value = clampi(value, -32768, 32767)
		
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	
	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	
	return stream

func play_tick(pitch_variation: float = 0.0):
	## Joue un son de tick
	var idx := randi() % tick_samples.size()
	play_sound(tick_samples[idx], pitch_variation)

func play_reverse():
	## Joue le son de reverse
	play_sound(reverse_sample, randf_range(-0.1, 0.1))

func play_finish():
	## Joue le son de fin
	play_sound(finish_sample, 0.0)

func play_sound(stream: AudioStreamWAV, pitch_offset: float = 0.0):
	## Joue un son avec le pool
	var player = audio_pool[pool_index]
	pool_index = (pool_index + 1) % audio_pool.size()
	
	player.stream = stream
	player.pitch_scale = 1.0 + pitch_offset
	player.play()
