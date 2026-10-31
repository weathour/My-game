extends Node
## Consumes confirmed facts only. Clocks, voices and cosmetic RNG belong to this attempt.
const ABILITY := preload("res://scripts/battle/ability_definition.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const MAX_MARKS := 12
const CONTACTS_PER_CAST := 3
const MAX_FOCUSED_TARGETS := 6
const CONTACT_RANGE := 260.0
const MAX_NUMBERS := 6
const MAX_VOICES := 6
const VOICE_GAIN := .25
const MAX_EVENT_GAIN := 1.0
const CATEGORIES := {"cast_blade":3, "hit_light":3, "hit_heavy":2, "guard":2, "death_ghost":3, "magic":3, "pickup":2, "level":2, "elite":2}
const COOLDOWNS := {"cast_blade":.12, "hit_light":.065, "hit_heavy":.09, "guard":.14, "death_ghost":.11, "magic":.12, "pickup":.10, "level":.18, "elite":.30}
var trace_enabled := false
var trace_records: Array[Dictionary] = []
var clock := 0.0
var marks: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var contacts: Dictionary = {}
var focused_targets: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var cooldowns: Dictionary = {}
var sound_casts: Dictionary = {}
var rng := RandomNumberGenerator.new()
var player_flash := 0.0
var player_guarded := false
var player_id := ""
var paused := false
var sfx_volume := .65
var reduced_motion := false
var reduced_flash := false
var settings_clock := 0.0
var suppressed_until := 0.0
var boss_priority_until := 0.0
var counters := {"damage_events":0,"damage_amount":0.0,"marks_peak":0,"numbers_peak":0,"voices_peak":0,"sounds_started":0,"sounds_limited":0,"offscreen_skipped":0,"number_merged":0}

func _ready() -> void:
	rng.seed = 934871 # Never uses BattleSession.rng or the global random generator.
	refresh_settings()
	for category in CATEGORIES:
		var variants: Array[AudioStream] = []
		for index in int(CATEGORIES[category]):
			var path := "res://assets/sfx/chronicle-feedback/%s_%02d.wav" % [category, index + 1]
			if ResourceLoader.exists(path): variants.append(load(path))
		streams[category] = variants
	for i in MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(voice)
		voice.set_meta("priority", 0)
		voices.append(voice)

func refresh_settings() -> void:
	sfx_volume = SETTINGS.load_sfx_volume()
	reduced_motion = SETTINGS.comfort_enabled("reduced_motion")
	reduced_flash = SETTINGS.comfort_enabled("reduced_flash")
	for voice in voices:
		if sfx_volume <= 0: voice.stop()
		voice.volume_db = linear_to_db(maxf(.00001, sfx_volume * VOICE_GAIN))

func advance(delta: float, is_paused: bool, outcome: String) -> void:
	if paused != is_paused: refresh_settings()
	paused = is_paused
	for voice in voices: voice.stream_paused = paused
	if outcome == "failed": clear(); return
	if paused: return
	clock += maxf(0, delta)
	settings_clock += delta
	if settings_clock >= .5: settings_clock = 0; refresh_settings()
	player_flash = maxf(0, player_flash - delta)
	for key in focused_targets.keys():
		if clock >= float(focused_targets[key]): focused_targets.erase(key)
	for key in sound_casts.keys():
		if clock - float(sound_casts[key]) > .18: sound_casts.erase(key)
	for collection in [marks, numbers]:
		for i in range(collection.size() - 1, -1, -1):
			if clock - collection[i].start >= collection[i].duration: collection.remove_at(i)

func consume(events: Array, battle: RefCounted, visible_world: Rect2) -> void:
	contacts.clear()
	# View consumes the first resumed tick before advance(), so read current truth here.
	if paused != bool(battle.paused): refresh_settings()
	paused = bool(battle.paused)
	for voice in voices: voice.stream_paused = paused
	if paused or battle.outcome == "failed": return
	if player_id != str(battle.current().id):
		# A new controlled body must not inherit the previous actor's flash, numbers or sound tails.
		var boss_window := boss_priority_until
		var threat_window := suppressed_until
		clear()
		boss_priority_until = boss_window
		suppressed_until = threat_window
		player_id = str(battle.current().id)
	# Reserve the mix for authored major enemy cues before considering ordinary facts.
	for event in events:
		if str(event.get("kind", "")) in ["boss_phase", "boss_impact", "boss_defeated"] or _major_warning(event, battle):
			suppressed_until = maxf(suppressed_until, clock + .22)
			var major := str(event.get("kind", "")) != "enemy_tell"
			if major: boss_priority_until = maxf(boss_priority_until, clock + .3)
			for voice in voices:
				if int(voice.get_meta("priority")) < (4 if major else 3): voice.stop()
	var primary_contacts := _primary_contacts(events, battle, visible_world)
	var contact_counts := {}
	var death_counts := {}
	var sound_groups := {}
	for event in events:
		var kind := str(event.get("kind", ""))
		var point: Vector2 = event.get("position", battle.position)
		var visible := not visible_world.has_area() or visible_world.grow(80).has_point(point)
		match kind:
			"damage_dealt":
				counters.damage_events += 1
				counters.damage_amount += float(event.get("amount", 0))
				var periodic := bool(event.get("secondary", false)) or str(event.get("ability", "")) == "curse_dot"
				var direct := bool(event.get("direct", false))
				var cast_key := _cast_key(event, periodic)
				if visible:
					var target := int(event.get("target_id", event.get("target", 0)))
					var primary := primary_contacts.has(cast_key + ":" + str(target))
					if primary and (not contacts.has(target) or (contacts[target].periodic and not periodic)):
						contacts[target] = {"direction":event.get("direction", Vector2.RIGHT), "periodic":periodic}
						focused_targets[target] = clock + .24
						while focused_targets.size() > MAX_FOCUSED_TARGETS: focused_targets.erase(focused_targets.keys()[0])
					# Contact anchors survive even when no enemy view existed before lethal resolution.
					if primary and int(contact_counts.get(cast_key, 0)) < CONTACTS_PER_CAST:
						contact_counts[cast_key] = int(contact_counts.get(cast_key, 0)) + 1
						_mark("hit", point, .12, event.get("direction", Vector2.RIGHT), bool(event.get("lethal", false)))
					_number(cast_key, point, float(event.get("amount", 0)), direct and not periodic)
				else: counters.offscreen_skipped += 1
				if not sound_groups.has(cast_key) and not sound_casts.has(cast_key):
					sound_groups[cast_key] = true
					sound_casts[cast_key] = clock
					if not periodic and visible:
						var category := "magic" if str(event.get("damage_type", "")) not in ["physical", "0", ""] else "hit_heavy" if bool(event.get("target_is_elite", false)) else "hit_light"
						_sound(category, 2 if direct else 1, 1 if direct and point.distance_to(battle.position) <= CONTACT_RANGE else .35)
			"kill":
				if bool(event.get("target_is_boss", false)) or str(event.get("rank", "")) == "boss": continue
				if visible:
					var key := _cast_key(event, false)
					var important := bool(event.get("target_is_elite", false))
					if important or int(death_counts.get(key, 0)) < 2:
						death_counts[key] = int(death_counts.get(key, 0)) + 1
						_mark("death", point, .28, Vector2.UP, important)
					_sound("death_ghost", 1, .7)
			"player_hit":
				player_guarded = float(event.get("health_loss", 0)) <= 0 and float(event.get("shield_absorbed", 0)) > 0
				player_flash = .17
				_mark("guard" if player_guarded else "hurt", point, .25, Vector2.UP, true)
				_sound("guard" if player_guarded else "hit_heavy", 4, 1.15)
			"xp_pickup":
				_mark("pickup", point, .28, Vector2.UP, str(event.get("collection", "")) == "victory_sweep")
				_sound("pickup", 0, .65)
			"level":
				if not sound_groups.has("level"):
					sound_groups.level = true
					_mark("level", battle.position, .65, Vector2.UP, true)
					_sound("level", 3, 1)
			"elite_defeated":
				_mark("elite", point, .65, Vector2.UP, true)
				_sound("elite", 3, 1.1)
			"cast":
				if bool(event.get("direct", false)) and visible and int(event.get("ability_kind", -1)) in [ABILITY.Kind.SWEEP, ABILITY.Kind.THRUST] and int(event.get("damage_type", -1)) == ABILITY.DamageType.PHYSICAL:
					_sound("cast_blade", 0, .55)

func _cast_key(event: Dictionary, periodic: bool) -> String:
	return "%s:%s:%s" % [event.get("cast_id", event.get("cast", 0)), event.get("source", ""), periodic]

func _primary_contacts(events: Array, battle: RefCounted, visible_world: Rect2) -> Dictionary:
	var grouped := {}
	for event in events:
		if event.get("kind", "") != "damage_dealt" or not bool(event.get("direct", false)) or bool(event.get("secondary", false)) or str(event.get("ability", "")) == "curse_dot": continue
		var point: Vector2 = event.get("position", battle.position)
		if visible_world.has_area() and not visible_world.grow(80).has_point(point): continue
		var important := bool(event.get("target_is_elite", false)) or bool(event.get("target_is_boss", false))
		if not important and point.distance_to(battle.position) > CONTACT_RANGE: continue
		var key := _cast_key(event, false)
		if not grouped.has(key): grouped[key] = []
		grouped[key].append({"target":int(event.get("target_id", event.get("target", 0))),"distance":point.distance_squared_to(battle.position),"important":important})
	var selected := {}
	for key in grouped:
		var candidates: Array = grouped[key]
		candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			if a.important != b.important: return a.important
			return a.distance < b.distance)
		for i in mini(CONTACTS_PER_CAST,candidates.size()): selected[key + ":" + str(candidates[i].target)] = true
	return selected

func _major_warning(event: Dictionary, battle: RefCounted) -> bool:
	if str(event.get("kind", "")) != "enemy_tell": return false
	if bool(event.get("major", false)): return true
	for enemy in battle.enemies:
		if enemy.id == int(event.get("id", -1)):
			return bool(enemy.current_action.get("major", false))
	return false

func _mark(kind: String, point: Vector2, duration: float, direction: Vector2, important: bool) -> void:
	if marks.size() >= MAX_MARKS:
		var victim := -1
		# Keep both a contact and a disappearance cue during simultaneous crowd kills.
		for i in marks.size():
			if marks[i].kind == kind: victim = i; break
		if victim < 0:
			for i in marks.size():
				if not marks[i].important: victim = i; break
		if victim < 0 and not important: return
		marks.remove_at(maxi(0, victim))
	if trace_enabled: trace_records.append({"kind":"mark_start","category":kind,"wall_usec":Time.get_ticks_usec(),"clock":clock})
	marks.append({"kind":kind,"point":point,"direction":direction.normalized(),"start":clock,"duration":duration,"important":important})
	counters.marks_peak = maxi(counters.marks_peak, marks.size())

func _number(key: String, point: Vector2, amount: float, allowed: bool) -> void:
	if amount <= 0 or not allowed: return
	for number in numbers:
		if number.key == key and clock - number.start < .14:
			number.amount += amount
			number.point = (number.point * number.count + point + Vector2(0,-54)) / (number.count + 1)
			number.count += 1
			counters.number_merged += 1
			return
	if numbers.size() >= MAX_NUMBERS: return
	numbers.append({"key":key,"point":point + Vector2(0,-54 - posmod(numbers.size(), 3) * 18),"amount":amount,"count":1,"start":clock,"duration":.64})
	counters.numbers_peak = maxi(counters.numbers_peak, numbers.size())

func _sound(category: String, priority: int, gain: float) -> void:
	if sfx_volume <= 0 or paused: return
	if (priority < 3 and clock < suppressed_until) or (priority < 4 and clock < boss_priority_until):
		counters.sounds_limited += 1
		return
	if clock < float(cooldowns.get(category, -1)):
		counters.sounds_limited += 1; return
	var variants: Array = streams.get(category, [])
	if variants.is_empty(): return
	var selected: AudioStreamPlayer
	for voice in voices:
		if not voice.playing: selected = voice; break
	if selected == null:
		for voice in voices:
			if int(voice.get_meta("priority")) < priority: selected = voice; break
	if selected == null: counters.sounds_limited += 1; return
	selected.stop()
	selected.stream = variants[rng.randi_range(0, variants.size() - 1)]
	selected.pitch_scale = rng.randf_range(.96, 1.04)
	selected.volume_db = linear_to_db(maxf(.00001, sfx_volume * VOICE_GAIN * clampf(gain, 0, MAX_EVENT_GAIN)))
	selected.set_meta("priority", priority)
	selected.play()
	if trace_enabled: trace_records.append({"kind":"audio_start","category":category,"path":selected.stream.resource_path,"wall_usec":Time.get_ticks_usec(),"clock":clock})
	cooldowns[category] = clock + float(COOLDOWNS.get(category, .1))
	counters.sounds_started += 1
	var playing := 0
	for voice in voices:
		if voice.playing: playing += 1
	counters.voices_peak = maxi(counters.voices_peak, playing)

func draw(painter: Node2D, origin: Vector2, scale: float, font: Font, screen_size: Vector2) -> void:
	painter.draw_set_transform(origin, 0, Vector2.ONE * scale)
	for mark in marks:
		var age := clampf((clock - mark.start) / mark.duration, 0, 1)
		var color := Color("eef8ff")
		if mark.kind in ["guard", "pickup"]: color = Color("9bdde7")
		elif mark.kind == "hurt": color = Color("eea185")
		elif mark.kind in ["level", "elite"]: color = Color("eac879")
		elif mark.kind == "death": color = Color("b3c5c1")
		color.a = (1 - age) * (.5 if reduced_flash else .9)
		var point: Vector2 = mark.point + (Vector2(0,-27) if mark.kind in ["hit", "death"] else Vector2.ZERO)
		if mark.kind == "hit":
			var along: Vector2 = mark.direction
			var across := along.orthogonal()
			var length := 12.0 if reduced_motion else lerpf(7, 25, age)
			painter.draw_line(point - across * length, point + across * length, color, 2.2, true)
			painter.draw_line(point - along * length * .55, point + along * length * .55, color, 1.5, true)
		else:
			var radius := 23.0 if reduced_motion else lerpf(10, 43 if mark.important else 29, age)
			for i in 4:
				var angle := i * PI * .5 + .2
				painter.draw_arc(point, radius, angle, angle + .85, 9, color, 2, true)
	# Floating totals use screen pixels and reserve one readable rectangle each.
	painter.draw_set_transform(Vector2.ZERO)
	for number in number_layout(origin, scale, font, screen_size):
		painter.draw_string_outline(font, number.point, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color(0.07,.08,.07,number.alpha))
		painter.draw_string(font, number.point, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1,.89,.68,number.alpha))

func number_layout(origin: Vector2, scale: float, font: Font, screen_size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for number in numbers:
		var age := clampf((clock - number.start) / number.duration, 0, 1)
		var text := String.num(float(number.amount), 2 if number.amount < 1 else 1).trim_suffix(".0")
		if int(number.count) > 1: text = "合计 " + text
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var point: Vector2 = origin + number.point * scale + Vector2(-width * .5, -14 * age if not reduced_motion else 0)
		point.x = clampf(point.x, 12, maxf(12, screen_size.x - width - 12))
		point.y = clampf(point.y, 92, maxf(92, screen_size.y - 150))
		var base: Vector2 = point
		var rect := Rect2(point + Vector2(-4,-18),Vector2(width + 8,22))
		for attempt in 24:
			var overlaps := false
			for previous in result:
				if rect.intersects(previous.rect): overlaps = true; break
			if not overlaps: break
			point.y -= 23
			if point.y < 92:
				point = base + Vector2((width + 14) * (1 + attempt / 10),0)
			rect.position = point + Vector2(-4,-18)
		result.append({"point":point,"rect":rect,"text":text,"alpha":1 - age})
	return result

func clear() -> void:
	marks.clear()
	numbers.clear()
	contacts.clear()
	focused_targets.clear()
	cooldowns.clear()
	sound_casts.clear()
	suppressed_until = 0
	boss_priority_until = 0
	player_flash = 0
	for voice in voices:
		voice.stream_paused = false
		voice.stop()
		voice.stream = null

func _exit_tree() -> void:
	clear()
	streams.clear()
