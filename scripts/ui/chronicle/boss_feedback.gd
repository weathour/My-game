extends Node
## Bounded, attempt-owned feedback. No global time scale or simulation cooldown changes.
const MAX_VOICES := 3
const MAX_GAIN := .60
const THREATS := preload("res://scripts/ui/chronicle/enemy_threat_view.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const SOUNDS := preload("res://scripts/ui/chronicle/boss_sound.gd")
var clock := 0.0
var marks: Array[Dictionary] = []
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var victory_remaining := 0.0
var phase_remaining := 0.0
var paused := false

func _ready() -> void:
	for i in MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func consume(events: Array) -> void:
	for event in events:
		var kind := str(event.get("kind", ""))
		if kind not in ["boss_phase", "boss_impact", "boss_defeated"]: continue
		var point: Vector2 = event.get("position", Vector2.ZERO)
		var duration := .24
		if kind == "boss_phase": duration = .65; phase_remaining = duration
		if kind == "boss_defeated":
			marks.clear()
			duration = .48
			victory_remaining = duration
		var geometry: Dictionary = event.get("geometry", {}).duplicate(true)
		marks.append({"kind":kind, "point":point, "geometry":geometry, "start":clock, "duration":duration})
		while marks.size() > 8: marks.pop_front()
		_sound(kind)

func advance(delta: float, is_paused: bool, outcome: String) -> void:
	paused = is_paused
	for voice in voices: voice.stream_paused = paused
	if paused: return
	if outcome == "failed": clear(); return
	clock += maxf(0, delta)
	victory_remaining = maxf(0, victory_remaining - delta)
	phase_remaining = maxf(0, phase_remaining - delta)
	for i in range(marks.size() - 1, -1, -1):
		if clock - marks[i].start >= marks[i].duration: marks.remove_at(i)

func clear() -> void:
	marks.clear()
	victory_remaining = 0
	phase_remaining = 0
	for voice in voices:
		voice.stop()
		voice.stream = null
	sounds.clear()

func _sound(kind: String) -> void:
	if voices.is_empty() or DisplayServer.get_name() == "headless": return
	var volume := SETTINGS.load_sfx_volume()
	if volume <= 0: return
	if not sounds.has(kind):
		sounds[kind] = SOUNDS.create(kind)
	var selected := voices[0]
	for voice in voices:
		if not voice.playing: selected = voice; break
	selected.stop()
	selected.stream = sounds[kind]
	selected.volume_db = linear_to_db(volume * MAX_GAIN)
	selected.play()

func draw(painter: Node2D, origin: Vector2, scale: float, reduced_motion: bool, reduced_flash: bool) -> void:
	painter.draw_set_transform(origin, 0, Vector2.ONE * scale)
	for mark in marks:
		var age := clampf((clock - mark.start) / mark.duration, 0, 1)
		var alpha := (1 - age) * (.42 if reduced_flash else .82)
		var color := Color("d5bd88") if mark.kind != "boss_impact" else Color("e8a579")
		color.a = alpha
		if mark.kind == "boss_impact" and not mark.geometry.is_empty():
			# Outline the actual released footprint, never invent a larger damage disc.
			var outline := THREATS.outline(mark.geometry)
			if outline.size() > 2:
				outline.append(outline[0])
				painter.draw_polyline(outline, color, 3 if reduced_flash else 5, true)
		else:
			var radius := 78.0 if reduced_motion else lerpf(46, 124 if mark.kind == "boss_phase" else 164, 1 - pow(1 - age, 3))
			for quarter in 4:
				var start := quarter * PI * .5 + .12
				painter.draw_arc(mark.point, radius, start, start + 1.05, 20, color, 3, true)
