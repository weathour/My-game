extends RefCounted

const SETTINGS := preload("res://scripts/game_settings.gd")
const NOTES := {"click": [660.0], "reward": [660.0, 880.0], "stage": [440.0, 660.0, 880.0], "error": [220.0, 165.0]}
static var streams: Dictionary = {}
static var last_click_msec := -100

static func play(cue: String = "click") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or DisplayServer.get_name() == "headless" or SETTINGS.load_sfx_volume() <= 0.0 or not NOTES.has(cue):
		return
	if cue == "click":
		if Time.get_ticks_msec() - last_click_msec < 60:
			return
		last_click_msec = Time.get_ticks_msec()
	if not streams.has(cue):
		streams[cue] = _tone(NOTES[cue])
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = streams[cue]
	player.volume_db = linear_to_db(SETTINGS.load_sfx_volume())
	tree.root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

static func _tone(notes: Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	var samples := 2205
	bytes.resize(samples * notes.size() * 2)
	for note in notes.size():
		for i in samples:
			var envelope := sin(PI * float(i) / samples) * 0.16
			var value := int(sin(TAU * float(notes[note]) * i / 22050.0) * envelope * 32767)
			bytes.encode_s16((note * samples + i) * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	return stream
