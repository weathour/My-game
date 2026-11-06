extends Node
## One attempt owns every combat voice, priority, position and duck envelope.
signal music_duck(gain: float)
const CATALOG := preload("res://scripts/audio/skill_sound_catalog.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const MAX_VOICES := 14
const RESERVED_WARNINGS := 2
const MASTER_GAIN := 0.55
const CATEGORIES := SETTINGS.AUDIO_CATEGORIES
var voices: Array[AudioStreamPlayer] = []
var streams := {}
var records: Array[Dictionary] = []
var trace_enabled := false
var trace_records: Array[Dictionary] = []
var counters := {"started":0, "limited":0, "missing":0, "voices_peak":0, "warnings_started":0, "cancelled":0,"missing_bindings":0}
var binding_diagnostics: Array[Dictionary] = []
var _missing_binding_keys := {}
var rng := RandomNumberGenerator.new()
var clock := 0.0
var paused := false
var enabled := true
var listener := Vector2.ZERO
var screen_width := 900.0
var cooldowns := {}
var dedup := {}
var _bus_names: Array[String] = []
var _panners: Array[AudioEffectPanner] = []
var _sfx_bus := ""
var _duck_remaining := 0.0
var _duck_gain := 1.0
var _music_gain := 1.0
var _sfx_volume := 0.65
# One bounded contribution per category preserves the shared hold/release envelope.
var _duck_categories := {}

func _ready() -> void:
	rng.seed = 947181
	_sfx_bus = "CombatSFX_%s" % get_instance_id()
	AudioServer.add_bus()
	var master := AudioServer.bus_count - 1
	AudioServer.set_bus_name(master, _sfx_bus)
	AudioServer.set_bus_send(master, "Master")
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(master, limiter)
	_bus_names.append(_sfx_bus)
	for index in MAX_VOICES:
		var bus_name := _sfx_bus + "_%d" % index
		AudioServer.add_bus()
		var bus_index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, _sfx_bus)
		var panner := AudioEffectPanner.new()
		AudioServer.add_bus_effect(bus_index, panner)
		_panners.append(panner)
		_bus_names.append(bus_name)
		var voice := AudioStreamPlayer.new()
		voice.bus = bus_name
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(voice)
		voice.finished.connect(_stop_voice.bind(index))
		voices.append(voice)
		records.append({})

func play_cue(cue: String, point: Vector2, options: Dictionary = {}) -> bool:
	if cue.is_empty() or not enabled or paused: return false
	_update_gains()
	var category := _cue_category(cue, options)
	if SETTINGS.load_sfx_gain(category) <= 0.0: return false
	var spec := CATALOG.cue(cue)
	if spec.is_empty(): counters.missing += 1; return false
	var key := str(options.get("key", ""))
	if not key.is_empty() and dedup.has(key): return false
	var priority := int(options.get("priority", spec.get("priority", 1)))
	var reserved := priority>=4 and str(options.get("stage","")) in ["tell","phase","defeated"]
	var tier := 2 if priority>=5 else 1 if priority>=4 else 0
	var throttle_key := cue+":"+str(tier)
	if clock < float(cooldowns.get(throttle_key,-1.0)): counters.limited += 1; return false
	var instances := 0
	var replacement := -1
	for index in records.size():
		var record: Dictionary = records[index]
		if record.get("cue") == cue:
			instances += 1
			if int(record.get("priority",0))<priority and (index>=RESERVED_WARNINGS or reserved) and (replacement<0 or int(record.priority)<int(records[replacement].priority)): replacement=index
	if instances>=int(spec.get("max_instances",2)) and replacement<0: counters.limited += 1; return false
	var maximum_distance := float(spec.get("spatial", {}).get("max_distance", 1200.0))
	var distance := point.distance_to(listener)
	if distance > maximum_distance and priority < 4: counters.limited += 1; return false
	var selected := replacement if instances>=int(spec.get("max_instances",2)) else -1
	var first := 0 if reserved else RESERVED_WARNINGS
	if selected<0:
		for index in range(first, MAX_VOICES):
			if records[index].is_empty(): selected = index; break
	if selected < 0:
		for index in range(first, MAX_VOICES):
			if int(records[index].get("priority", 0)) < priority:
				if selected < 0 or int(records[index].priority) < int(records[selected].priority) or (records[index].priority == records[selected].priority and records[index].start < records[selected].start): selected = index
	if selected < 0: counters.limited += 1; return false
	var paths: Array = spec.get("variants", [])
	if paths.is_empty(): counters.missing += 1; return false
	var path := str(paths[rng.randi_range(0, paths.size() - 1)])
	if not streams.has(path):
		if not ResourceLoader.exists(path): counters.missing += 1; return false
		streams[path] = load(path)
	var stream: AudioStream = streams[path]
	if stream == null: counters.missing += 1; return false
	_stop_voice(selected)
	var pitch := float(options.get("pitch_scale", 1.0)) * rng.randf_range(0.975, 1.025)
	var voice := voices[selected]
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.set_meta("priority", priority)
	records[selected] = {"cue":cue,"category":category,"point":point,"priority":priority,"start":clock,"remaining":stream.get_length()/pitch+0.08,"form_index":int(options.get("form_index",-1)),"gain_db":float(spec.get("gain_db", -4.0))+float(options.get("gain_db",0.0)),"owner":str(options.get("owner","")),"serial":int(options.get("serial",-1)),"stage":str(options.get("stage","")),"max_distance":maximum_distance,"pan_strength":float(spec.get("spatial",{}).get("panning_strength",0.55))}
	if not key.is_empty(): dedup[key] = clock
	cooldowns[throttle_key] = clock + float(spec.get("cooldown_sec", 0.08))
	if priority >= 4: counters.warnings_started += 1
	var duck: Dictionary = spec.get("duck", {})
	if priority >= 6 or bool(options.get("critical",false)) or not duck.is_empty():
		var contribution: Dictionary = _duck_categories.get(category, {"remaining":0.0,"gain":1.0})
		contribution.remaining = maxf(float(contribution.remaining), float(duck.get("hold_sec",0.22)))
		contribution.gain = minf(float(contribution.gain), db_to_linear(float(duck.get("gain_db",-2.5))))
		_duck_categories[category] = contribution
	_update_gains()
	voice.play()
	counters.started += 1
	var count := 0
	for record in records:
		if not record.is_empty(): count += 1
	counters.voices_peak = maxi(counters.voices_peak, count)
	if trace_enabled: trace_records.append({"kind":"audio_start","cue":cue,"category":cue,"volume_category":category,"path":path,"priority":priority,"voice":selected,"point":point,"clock":clock,"wall_usec":Time.get_ticks_usec(),"owner":records[selected].owner,"stage":records[selected].stage,"serial":records[selected].serial})
	return true

func advance(delta: float, is_paused: bool) -> void:
	paused = is_paused
	for voice in voices: voice.stream_paused = paused
	if paused:
		_update_gains()
		return
	clock += maxf(0.0,delta)
	for index in records.size():
		if records[index].is_empty(): continue
		records[index].remaining -= delta
		if records[index].remaining <= 0: _stop_voice(index)
	for key in dedup.keys():
		if clock - float(dedup[key]) > 3.0: dedup.erase(key)
	var holding := false
	for category in _duck_categories:
		var contribution: Dictionary = _duck_categories[category]
		contribution.remaining = maxf(0.0, float(contribution.remaining)-delta)
		if float(contribution.remaining)>0.0: holding = true
	if not holding:
		for category in _duck_categories.keys():
			var contribution: Dictionary = _duck_categories[category]
			contribution.gain = move_toward(float(contribution.gain),1.0,delta*4.0)
			if float(contribution.gain)>=1.0: _duck_categories.erase(category)
	_update_gains()

func _update_gains() -> void:
	_sfx_volume = SETTINGS.load_sfx_volume()
	var category_gains := {}
	for category in CATEGORIES: category_gains[category] = SETTINGS.load_sfx_gain(category)
	for index in records.size():
		if not records[index].is_empty() and float(category_gains[records[index].category]) <= 0.0: _stop_voice(index)
	_duck_remaining = 0.0
	_duck_gain = 1.0
	for category in _duck_categories.keys():
		if float(category_gains[category]) <= 0.0:
			_duck_categories.erase(category)
			continue
		var contribution: Dictionary = _duck_categories[category]
		_duck_remaining = maxf(_duck_remaining, float(contribution.remaining))
		_duck_gain = minf(_duck_gain, float(contribution.gain))
	var active := 0
	var has_warning := false
	for record in records:
		if not record.is_empty():
			active += 1
			if int(record.priority) >= 4: has_warning = true
	for index in records.size():
		if records[index].is_empty(): continue
		var record: Dictionary = records[index]
		var distance: float = Vector2(record.point).distance_to(listener)
		var attenuation := clampf(1.0-distance/float(record.max_distance),0.08 if int(record.priority)>=4 else 0.0,1.0)
		var crowd_gain := 1.0/sqrt(maxf(1.0,active/3.0)) if int(record.priority)<4 else 1.0
		var secondary_gain := 0.55 if has_warning and int(record.priority)<4 else 1.0
		var gain := float(category_gains[record.category])*MASTER_GAIN*db_to_linear(float(record.gain_db))*attenuation*crowd_gain*secondary_gain
		voices[index].volume_db = linear_to_db(gain) if gain>0 else -80.0
		_panners[index].pan = clampf((Vector2(record.point).x-listener.x)/maxf(1.0,screen_width*0.5),-1.0,1.0)*float(record.pan_strength)
	var target := _duck_gain if _duck_remaining>0 or _duck_gain<1.0 else 1.0
	if not is_equal_approx(target,_music_gain): _music_gain=target; music_duck.emit(target)

func cancel_owner(owner: String, serial: int = -1, stage: String = "") -> void:
	for index in records.size():
		var record: Dictionary = records[index]
		if record.get("owner") == owner and (serial<0 or int(record.get("serial",-1))==serial) and (stage.is_empty() or record.get("stage")==stage):
			_stop_voice(index)
			counters.cancelled += 1

func _stop_voice(index: int) -> void:
	if index>=voices.size(): return
	voices[index].stop()
	voices[index].stream = null
	records[index] = {}

func clear() -> void:
	for index in voices.size(): _stop_voice(index)
	cooldowns.clear()
	dedup.clear()
	_duck_categories.clear()
	_duck_remaining=0.0
	_duck_gain=1.0
	_music_gain=1.0
	music_duck.emit(1.0)

func _exit_tree() -> void:
	clear()
	streams.clear()
	for index in range(_bus_names.size()-1,-1,-1):
		var bus_index := AudioServer.get_bus_index(_bus_names[index])
		if bus_index>=0: AudioServer.remove_bus(bus_index)

func report_missing_binding(key: String, details: Dictionary) -> void:
	if _missing_binding_keys.has(key): return
	counters.missing_bindings+=1
	if _missing_binding_keys.size()<64:
		_missing_binding_keys[key]=true
		var entry:=details.duplicate(true)
		entry.key=key
		entry.kind="missing_binding"
		binding_diagnostics.append(entry)

func _cue_category(cue: String, options: Dictionary) -> String:
	var category := str(options.get("category", ""))
	if category in CATEGORIES: return category
	# Isolated probes and older callers omit source metadata. Production supplies it.
	var stage := str(options.get("stage", ""))
	if stage in ["phase", "defeated"] or cue.begins_with("boss_"): return "boss"
	for event in ["hurt", "guard", "death", "pickup", "level", "elite"]:
		if cue == CATALOG.global_cue(event):
			return str({"guard":"hurt", "level":"rewards", "elite":"rewards"}.get(event, event))
	if str(options.get("owner", "")).begins_with("enemy:"): return "enemy_attack"
	return "player_skill" if str(options.get("owner", "")).begins_with("character:") else "player_attack"
