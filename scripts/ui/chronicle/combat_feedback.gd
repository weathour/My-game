extends Node
## Consumes confirmed facts only. Clocks, voices and cosmetic RNG belong to this attempt.
const AUDIO := preload("res://scripts/audio/combat_audio.gd")
const SOUND_CATALOG := preload("res://scripts/audio/skill_sound_catalog.gd")
const COMBAT_CATALOG := preload("res://scripts/content/combat_catalog.gd")
var audio: Node
var cast_kinds := {}
var enemy_releases := {}

const ABILITY := preload("res://scripts/battle/ability_definition.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const MAX_MARKS := 12
const CONTACTS_PER_CAST := 3
const MAX_FOCUSED_TARGETS := 6
const CONTACT_RANGE := 260.0
const MAX_NUMBERS := 6
const MAX_VOICES := 14
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
	audio = AUDIO.new()
	add_child(audio)
	voices = audio.voices

func refresh_settings() -> void:
	sfx_volume = SETTINGS.load_sfx_volume()
	reduced_motion = SETTINGS.comfort_enabled("reduced_motion")
	reduced_flash = SETTINGS.comfort_enabled("reduced_flash")
	if is_instance_valid(audio): audio._update_gains()

func advance(delta: float, is_paused: bool, outcome: String) -> void:
	if paused != is_paused: refresh_settings()
	paused = is_paused
	if is_instance_valid(audio): audio.advance(delta, paused)
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
		if is_instance_valid(audio): audio.cancel_owner("character:" + player_id)
		clear(false)
		boss_priority_until = boss_window
		suppressed_until = threat_window
		player_id = str(battle.current().id)
	audio.screen_width=maxf(400,visible_world.size.x) if visible_world.has_area() else 900.0
	_consume_audio(events, battle)
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
			"kill":
				if bool(event.get("target_is_boss", false)) or str(event.get("rank", "")) == "boss": continue
				if visible:
					var key := _cast_key(event, false)
					var important := bool(event.get("target_is_elite", false))
					if important or int(death_counts.get(key, 0)) < 2:
						death_counts[key] = int(death_counts.get(key, 0)) + 1
						_mark("death", point, .28, Vector2.UP, important)
			"player_hit":
				player_guarded = bool(event.get("guarded",false)) or (float(event.get("health_loss", 0)) <= 0 and float(event.get("shield_absorbed", 0)) > 0)
				player_flash = .17
				_mark("guard" if player_guarded else "hurt", point, .25, Vector2.UP, true)
			"xp_pickup":
				_mark("pickup", point, .28, Vector2.UP, str(event.get("collection", "")) == "victory_sweep")
			"level":
				if not sound_groups.has("level"):
					sound_groups.level = true
					_mark("level", battle.position, .65, Vector2.UP, true)
			"elite_defeated":
				_mark("elite", point, .65, Vector2.UP, true)

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
	# Compatibility for isolated feedback probes; production uses explicit profiles.
	var cue := str({"cast_blade":"blade.cast","hit_light":"blade.impact","hit_heavy":"heavy_blade.impact","magic":"arcane.impact","death_ghost":"feedback.death"}.get(category, SOUND_CATALOG.global_cue(category)))
	if is_instance_valid(audio):
		audio.trace_enabled = trace_enabled
		audio.trace_records = trace_records
		var volume_category := str({"cast_blade":"player_attack","hit_light":"player_attack","hit_heavy":"player_attack","magic":"player_skill","death_ghost":"death","guard":"hurt","pickup":"pickup","level":"rewards","elite":"rewards"}.get(category,"player_skill"))
		audio.play_cue(cue, audio.listener, {"priority":priority,"gain_db":linear_to_db(clampf(gain,0.001,1.0)),"category":volume_category})
		_sync_audio_counters()

func _sync_audio_counters() -> void:
	counters.sounds_started = audio.counters.started
	counters.sounds_limited = audio.counters.limited
	counters.voices_peak = audio.counters.voices_peak

func _consume_audio(events: Array, battle: RefCounted) -> void:
	if not is_instance_valid(audio): return
	audio.listener = battle.position
	audio.paused = bool(battle.paused)
	audio.trace_enabled = trace_enabled
	audio.trace_records = trace_records
	for event: Dictionary in events:
		var kind := str(event.get("kind", ""))
		var owner := "enemy:"+str(event.get("target_id",event.get("target",event.get("enemy_id",event.get("id",0))))) if kind=="kill" else "enemy:"+str(event.get("enemy_id",event.get("id",0)))
		if kind in ["boss_phase","kill","enemy_remove"]: audio.cancel_owner(owner,-1,"tell")
		if kind in ["enemy_release","enemy_hazard_release"]: audio.cancel_owner(owner,int(event.get("action_serial",-1)),"tell")
		var point: Vector2 = event.get("position",battle.position)
		var cast := int(event.get("cast_id",event.get("cast",0)))
		var source := str(event.get("source",event.get("id","")))
		if kind == "cast":
			var ability := str(event.get("ability",""))
			cast_kinds[str(source)+":"+str(cast)] = int(event.get("ability_kind",-1))
			if cast_kinds.size()>256: cast_kinds.erase(cast_kinds.keys()[0])
			var profile := SOUND_CATALOG.character(source,ability,int(event.get("ability_kind",-1)))
			var options := _profile_options(profile,"character:"+source,cast,"cast")
			options.category = _character_category(source, ability)
			options.key = "cast:%s:%d" % [source,cast]
			if bool(event.get("manual",false)): options.priority=5; options.critical=true
			_play_profile(profile,"cast",point,options,{"owner":source,"ability":ability})
		elif kind in ["damage_dealt", "ability_effect"]:
			var counter := str(event.get("ability",""))=="guard_counter"
			if (bool(event.get("secondary",false)) or bool(event.get("periodic",false))) and not counter: continue
			var profile := SOUND_CATALOG.character(source,str(event.get("ability","")),int(cast_kinds.get(str(source)+":"+str(cast),-1)))
			var options := _profile_options(profile,"character:"+source,cast,"impact")
			options.category = _character_category(source, str(event.get("ability","")))
			options.key = "impact:%s:%d" % [source,cast]
			if counter: options.key += ":delivery:"+str(event.get("delivery",0))
			_play_profile(profile,"impact",point,options,{"owner":source,"ability":str(event.get("ability",""))})
		elif kind in ["enemy_tell","enemy_release","enemy_hazard_release","player_hit"]:
			var metadata := _enemy_metadata(event,battle)
			var profile := SOUND_CATALOG.enemy(str(metadata.get("definition_id","")),int(metadata.get("form_index",0)),str(metadata.get("move_id","")))
			var stage := "tell" if kind=="enemy_tell" else "impact" if kind=="player_hit" else "release"
			var options := _profile_options(profile,"enemy:"+str(metadata.get("enemy_id",0)),int(event.get("action_serial",metadata.get("action_serial",0))),stage)
			options.key = "%s:%s:%s" % [options.owner,options.serial,stage] if stage=="release" else "%s:%s:%s:%s" % [options.owner,options.serial,stage,event.get("kind","")]
			options.form_index=int(metadata.get("form_index",0))
			options.category = "boss" if str(metadata.get("rank",""))=="boss" or str(metadata.get("definition_id","")).begins_with("B") else "enemy_attack"
			if stage=="release":
				# Staggered markers are one attack launch, even after mixer dedup expires.
				var release_serial := int(options.serial)
				if enemy_releases.has(options.owner) and release_serial <= int(enemy_releases[options.owner]): continue
				enemy_releases[options.owner] = release_serial
			if stage=="tell":
				var distance: float = Vector2(metadata.get("position",point)).distance_to(battle.position)
				var boss := str(metadata.get("rank",""))=="boss" or str(metadata.get("definition_id","")).begins_with("B")
				var elite := str(metadata.get("rank",""))=="field_elite" or str(metadata.get("definition_id","")).begins_with("L")
				options.priority = 5 if boss or bool(metadata.get("major",false)) else 3 if elite else 1 if distance>650 else 2
				options.critical = boss and bool(metadata.get("major",false))
				if profile.get("stage_priorities",{}).has(stage): options.priority=maxi(int(options.priority),int(profile.stage_priorities[stage]))
			_play_profile(profile,stage,metadata.get("position",point),options,{"definition":str(metadata.get("definition_id","")),"form":int(metadata.get("form_index",0)),"move":str(metadata.get("move_id",""))})
			if kind=="player_hit":
				var guarded := bool(event.get("guarded",false)) or (float(event.get("health_loss",0))<=0 and float(event.get("shield_absorbed",0))>0)
				audio.play_cue(SOUND_CATALOG.global_cue("guard" if guarded else "hurt"),point,{"priority":5,"owner":"character:"+str(event.get("id","")),"stage":"hurt","category":"hurt"})
		elif kind in ["boss_phase","boss_defeated"]:
			var metadata := _enemy_metadata(event,battle)
			var stage := "phase" if kind=="boss_phase" else "defeated"
			var profile:=SOUND_CATALOG.boss_profile(str(metadata.get("definition_id","")),int(metadata.get("form_index",0)))
			var options:=_profile_options(profile,"enemy:"+str(event.get("id",0)),0,stage)
			options.priority=6;options.critical=true;options.category="boss"
			_play_profile(profile,stage,point,options,{"definition":str(metadata.get("definition_id","")),"form":int(metadata.get("form_index",0)),"move":"boss_event"})
		elif kind in ["kill","xp_pickup","level","elite_defeated"]:
			if kind=="kill" and (bool(event.get("target_is_boss",false)) or str(event.get("rank",""))=="boss" or str(event.get("definition_id","")).begins_with("B")): continue
			var category := str({"kill":"death","xp_pickup":"pickup","level":"level","elite_defeated":"elite"}[kind])
			audio.play_cue(SOUND_CATALOG.global_cue(category),point,{"priority":3 if category in ["level","elite"] else 0,"stage":category,"category":"rewards" if category in ["level","elite"] else category})
	# A batch may contain both admission and cancellation. Only genuinely active
	# source warnings survive; already released one-shots remain independent.
	for index in audio.records.size():
		var record: Dictionary=audio.records[index]
		if record.get("stage")!="tell" or not str(record.get("owner","")).begins_with("enemy:"): continue
		var valid:=false
		for enemy in battle.enemies:
			if "enemy:"+str(enemy.id)==record.owner and not enemy.dead and enemy.windup>0 and enemy.action_serial==int(record.serial) and enemy.form_index==int(record.get("form_index",enemy.form_index)): valid=true; break
		if not valid: audio._stop_voice(index)
	_sync_audio_counters()

func _character_category(source: String, ability: String) -> String:
	var definition := COMBAT_CATALOG.definition(source)
	var basic: Resource = definition.get("basic")
	return "player_attack" if basic != null and str(basic.id) == ability else "player_skill"

func _profile_options(profile: Dictionary, owner: String, serial: int, stage: String) -> Dictionary:
	var options := {"gain_db":float(profile.get("gain_db",0)),"pitch_scale":float(profile.get("pitch_scale",1)),"owner":owner,"serial":serial,"stage":stage}
	if profile.get("stage_priorities",{}).has(stage): options.priority=int(profile.stage_priorities[stage])
	return options

func _enemy_metadata(event: Dictionary, battle: RefCounted) -> Dictionary:
	var result := event.duplicate()
	var geometry: Dictionary = event.get("geometry",{})
	if not result.has("move_id"): result.move_id = str(geometry.get("move_id",event.get("attack",event.get("action_id",""))))
	if not result.has("position"): result.position = geometry.get("origin",battle.position)
	result.enemy_id = int(event.get("enemy_id",event.get("id",0)))
	if not result.has("definition_id"):
		for enemy in battle.enemies:
			if enemy.id==result.enemy_id:
				result.definition_id=enemy.definition_id
				result.form_index=enemy.form_index
				result.major=bool(enemy.current_action.get("major",false))
				result.rank=enemy.rank
				if str(result.move_id).is_empty(): result.move_id=str(enemy.current_action.get("id",""))
	return result

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

func clear(clear_audio: bool = true) -> void:
	marks.clear()
	numbers.clear()
	contacts.clear()
	focused_targets.clear()
	cooldowns.clear()
	sound_casts.clear()
	suppressed_until = 0
	boss_priority_until = 0
	player_flash = 0
	if clear_audio:
		enemy_releases.clear()
		if is_instance_valid(audio): audio.clear()

func _exit_tree() -> void:
	clear()
	streams.clear()

func _play_profile(profile: Dictionary, stage: String, point: Vector2, options: Dictionary, identity: Dictionary) -> void:
	var cue:=str(profile.get(stage,""))
	var intentional:=not str(profile.get(stage+"_silence_reason",profile.get("silence_reason",""))).is_empty()
	var has_identity: bool=not str(identity.get("ability",identity.get("move",""))).is_empty()
	if profile.is_empty() or not profile.has(stage) or (cue.is_empty() and not intentional):
		if has_identity:
			var detail:=identity.duplicate(true);detail.stage=stage
			audio.report_missing_binding(JSON.stringify(detail),detail)
		return
	if not cue.is_empty(): audio.play_cue(cue,point,options)
