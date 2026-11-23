extends Node

## Analyseur audio temps réel (Godot 4)
## Utilise AudioEffectSpectrumAnalyzerInstance sur le bus "Music" (fallback "Master")
## avec normalisation dB, lissage attaque/relâchement, flux spectral et détection de BPM.

const MIN_DB := 60.0
const ENERGY_HISTORY_SIZE := 45
const BPM_HISTORY_SIZE := 10
const MIN_BPM := 60.0
const MAX_BPM := 220.0

const FREQUENCY_RANGES := {
	"sub_bass": {"min": 20.0, "max": 60.0},
	"bass": {"min": 60.0, "max": 250.0},
	"low_mid": {"min": 250.0, "max": 500.0},
	"mid": {"min": 500.0, "max": 2000.0},
	"high_mid": {"min": 2000.0, "max": 4000.0},
	"presence": {"min": 4000.0, "max": 6000.0},
	"brilliance": {"min": 6000.0, "max": 18000.0}
}

var spectrum_bus_index: int = -1
var spectrum_effect_index: int = -1
var spectrum_instance: AudioEffectSpectrumAnalyzerInstance = null

var audio_features: Dictionary = {}
var smoothed_features: Dictionary = {}
var prev_features: Dictionary = {}

var energy_history: Array[float] = []
var beat_intervals: Array[float] = []

var bpm: float = 120.0
var last_beat_time: float = -10.0
var beat_strength: float = 0.0
var spectral_flux: float = 0.0

signal beat_detected(strength: float)
signal frequency_peak(band_name: String, intensity: float)

func _ready():
	for band_name in FREQUENCY_RANGES:
		audio_features[band_name] = 0.0
		smoothed_features[band_name] = 0.0
		prev_features[band_name] = 0.0
	setup_audio_analysis()

func setup_audio_analysis():
	# Priorité au bus "Music", sinon "Master"
	spectrum_bus_index = AudioServer.get_bus_index("Music")
	if spectrum_bus_index == -1:
		spectrum_bus_index = AudioServer.get_bus_index("Master")
	if spectrum_bus_index == -1:
		return

	# Chercher un AudioEffectSpectrumAnalyzer déjà présent sur le bus
	spectrum_effect_index = -1
	var effect_count := AudioServer.get_bus_effect_count(spectrum_bus_index)
	for i in range(effect_count):
		var fx := AudioServer.get_bus_effect(spectrum_bus_index, i)
		if fx is AudioEffectSpectrumAnalyzer:
			spectrum_effect_index = i
			break

	# Sinon en créer un proprement
	if spectrum_effect_index == -1:
		var analyzer := AudioEffectSpectrumAnalyzer.new()
		analyzer.buffer_length = 0.5
		analyzer.tap_back_pos = 0.01
		analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
		AudioServer.add_bus_effect(spectrum_bus_index, analyzer)
		spectrum_effect_index = AudioServer.get_bus_effect_count(spectrum_bus_index) - 1

	spectrum_instance = AudioServer.get_bus_effect_instance(spectrum_bus_index, spectrum_effect_index) as AudioEffectSpectrumAnalyzerInstance

func _ensure_instance() -> bool:
	if spectrum_instance != null:
		return true
	if spectrum_bus_index != -1 and spectrum_effect_index != -1:
		spectrum_instance = AudioServer.get_bus_effect_instance(spectrum_bus_index, spectrum_effect_index) as AudioEffectSpectrumAnalyzerInstance
	return spectrum_instance != null

func _process(delta: float):
	if not _ensure_instance():
		return
	analyze_spectrum(delta)
	detect_beats(delta)

func analyze_spectrum(delta: float):
	var flux := 0.0
	var attack := minf(1.0, delta * 28.0)
	var decay := minf(1.0, delta * 9.0)

	for band_name in FREQUENCY_RANGES:
		var r: Dictionary = FREQUENCY_RANGES[band_name]
		var raw := get_frequency_range_magnitude(r.min, r.max)
		var prev_val: float = smoothed_features.get(band_name, 0.0)
		var lerp_rate := attack if raw > prev_val else decay
		var smoothed := lerpf(prev_val, raw, lerp_rate)

		var diff := raw - float(prev_features.get(band_name, 0.0))
		if diff > 0.0:
			flux += diff

		prev_features[band_name] = raw
		audio_features[band_name] = raw
		smoothed_features[band_name] = smoothed

		if raw > 0.78:
			frequency_peak.emit(band_name, raw)

	spectral_flux = flux

func get_frequency_range_magnitude(min_freq: float, max_freq: float) -> float:
	if not _ensure_instance():
		return 0.0

	var mag_vec: Vector2 = spectrum_instance.get_magnitude_for_frequency_range(
		min_freq,
		max_freq,
		AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE
	)
	var linear_mag := (mag_vec.x + mag_vec.y) * 0.5
	if linear_mag <= 0.000001:
		return 0.0

	var db := linear_to_db(linear_mag)
	return clampf((db + MIN_DB) / MIN_DB, 0.0, 1.0)

func detect_beats(delta: float):
	beat_strength = maxf(0.0, beat_strength - delta * 4.5)

	var now := Time.get_ticks_msec() / 1000.0
	var sub_bass: float = audio_features.get("sub_bass", 0.0)
	var bass: float = audio_features.get("bass", 0.0)
	var instant_energy := sub_bass * 0.55 + bass * 0.45

	energy_history.append(instant_energy)
	if energy_history.size() > ENERGY_HISTORY_SIZE:
		energy_history.pop_front()

	if energy_history.size() < 10:
		return

	var sum := 0.0
	for e in energy_history:
		sum += e
	var avg := sum / float(energy_history.size())

	var var_sum := 0.0
	for e in energy_history:
		var d := e - avg
		var_sum += d * d
	var variance := var_sum / float(energy_history.size())

	# Seuil adaptatif basé sur l'énergie moyenne + variance
	var threshold := maxf(0.22, avg * (1.28 + clampf(variance * 3.0, 0.0, 0.45)))
	var min_interval := (60.0 / clampf(bpm, MIN_BPM, MAX_BPM)) * 0.65

	if (instant_energy > threshold or (spectral_flux > 0.45 and instant_energy > 0.25)) and (now - last_beat_time) >= min_interval:
		var interval := now - last_beat_time
		last_beat_time = now

		if interval > (60.0 / MAX_BPM) and interval < (60.0 / MIN_BPM):
			beat_intervals.append(interval)
			if beat_intervals.size() > BPM_HISTORY_SIZE:
				beat_intervals.pop_front()
			estimate_bpm_from_beats()

		beat_strength = clampf(instant_energy, 0.4, 1.0)
		beat_detected.emit(beat_strength)

func estimate_bpm_from_beats():
	if beat_intervals.size() < 3:
		return
	var sorted := beat_intervals.duplicate()
	sorted.sort()
	var median_interval: float = sorted[sorted.size() / 2]
	if median_interval > 0.0:
		var estimated := 60.0 / median_interval
		bpm = lerpf(bpm, clampf(estimated, MIN_BPM, MAX_BPM), 0.35)

func set_known_bpm(known_bpm: float):
	if known_bpm >= MIN_BPM and known_bpm <= MAX_BPM:
		bpm = known_bpm

func get_audio_features() -> Dictionary:
	return smoothed_features.duplicate()

func get_band(band_name: String) -> float:
	return float(smoothed_features.get(band_name, 0.0))

func get_dominant_frequency_band() -> String:
	var max_energy := 0.0
	var dominant_band := "mid"
	for band_name in smoothed_features:
		if smoothed_features[band_name] > max_energy:
			max_energy = smoothed_features[band_name]
			dominant_band = band_name
	return dominant_band

func get_spectral_centroid() -> float:
	var weighted_sum := 0.0
	var magnitude_sum := 0.0
	for band_name in FREQUENCY_RANGES:
		var r: Dictionary = FREQUENCY_RANGES[band_name]
		var center_freq: float = (float(r.min) + float(r.max)) * 0.5
		var magnitude: float = smoothed_features.get(band_name, 0.0)
		weighted_sum += center_freq * magnitude
		magnitude_sum += magnitude
	return weighted_sum / maxf(magnitude_sum, 0.001)

func get_audio_intensity() -> float:
	if smoothed_features.is_empty():
		return 0.0
	var total := 0.0
	for value in smoothed_features.values():
		total += value
	return total / float(smoothed_features.size())

func apply_audio_effects_to_shader(shader_material: ShaderMaterial):
	if not shader_material:
		return
	var low := clampf(get_band("sub_bass") * 0.5 + get_band("bass") * 0.5, 0.0, 1.0)
	var mid := clampf(get_band("low_mid") * 0.4 + get_band("mid") * 0.6, 0.0, 1.0)
	var high := clampf(get_band("high_mid") * 0.4 + get_band("presence") * 0.3 + get_band("brilliance") * 0.3, 0.0, 1.0)

	shader_material.set_shader_parameter("audio_low", low)
	shader_material.set_shader_parameter("audio_mid", mid)
	shader_material.set_shader_parameter("audio_high", high)
	shader_material.set_shader_parameter("spectral_centroid", get_spectral_centroid() / 10000.0)
	shader_material.set_shader_parameter("audio_intensity", get_audio_intensity())

func get_eq_visualization_data() -> Array:
	var eq_data := []
	for band_name in FREQUENCY_RANGES:
		eq_data.append({
			"name": band_name,
			"value": smoothed_features.get(band_name, 0.0),
			"frequency": (FREQUENCY_RANGES[band_name].min + FREQUENCY_RANGES[band_name].max) * 0.5
		})
	return eq_data
