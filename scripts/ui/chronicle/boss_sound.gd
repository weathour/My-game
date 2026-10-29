extends RefCounted
## Original deterministic combat accents. PCM is bounded, short, and attempt-cached.
const RATE := 22050
const DURATIONS := {"boss_impact":.24, "boss_phase":.46, "boss_defeated":.42}

static func create(cue: String) -> AudioStreamWAV:
	if not DURATIONS.has(cue): return null
	var duration: float = DURATIONS[cue]
	var samples := int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 47013 if cue == "boss_impact" else 47017 if cue == "boss_phase" else 47023
	var phase := 0.0
	var landing_phase := 0.0
	var previous_noise := 0.0
	for index in samples:
		var t := float(index) / RATE
		var noise := random.randf_range(-1, 1)
		var crack := noise - previous_noise * .65
		previous_noise = noise
		var value := 0.0
		match cue:
			"boss_impact":
				# A few milliseconds of broadband contact followed by a falling body.
				phase += TAU * (48 + 172 * exp(-t * 36)) / RATE
				value = sin(phase) * .54 * exp(-t * 19)
				value += sin(TAU * 51 * t) * .16 * exp(-t * 24)
				value += crack * .20 * exp(-t * 95)
			"boss_phase":
				# The low swell yields to a distinct landing; there is no long stinger.
				var progress := clampf(t / .35, 0, 1)
				phase += TAU * (42 + 100 * progress * progress) / RATE
				value = sin(phase) * .30 * pow(sin(PI * progress), 2)
				value += noise * .035 * pow(sin(PI * progress), 2)
				if t >= .30:
					var landing := t - .30
					landing_phase += TAU * (47 + 116 * exp(-landing * 32)) / RATE
					var attack := 1 - exp(-landing * 950)
					value += sin(landing_phase) * .55 * exp(-landing * 23) * attack
					value += crack * .16 * exp(-landing * 85) * attack
			"boss_defeated":
				# A compact resolved chord, quieter than the physical impact.
				for frequency in [146.832, 184.997, 220.0]:
					value += sin(TAU * frequency * t) * .16
				value *= (1 - exp(-t * 150)) * exp(-t * 7)
		# Shared contact fade avoids DC steps/clicks without clipping the waveform.
		var envelope := minf(1, t / .0025) * clampf((duration - t) / .024, 0, 1)
		var sample := int(round(value * envelope * .76 * 32767))
		bytes.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream
