extends AudioStreamPlayer

const CATALOG := preload("res://scripts/audio/music_catalog.gd")
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"
const MUSIC_VOLUME_KEY := "music_volume_linear"
const MUSIC_MUTED_KEY := "music_muted"
const DEFAULT_VOLUME_LINEAR := 0.7
const MUTED_VOLUME_DB := -80.0
const CONTEXT_INTERVAL := 0.25

static var camp_handoff_position: float = 0.0
static var camp_handoff_ready: bool = false

@export var initial_cue: String = "camp_signal"
@export var follow_battle_context: bool = false

var current_cue: String = ""
var stored_playback_position: float = 0.0
var resume_request_id: int = 0
var paused_by_script: bool = false
var _other: AudioStreamPlayer
var _active: AudioStreamPlayer
var _outgoing: AudioStreamPlayer
var _encounters: Array[Node] = []
var _started: bool = false
var _context_elapsed: float = 0.0
var _fade_elapsed: float = 0.0
var _fade_duration: float = 0.0
var _fade_from_gain: float = 1.0
var _active_gain: float = 1.0
var _outgoing_gain: float = 0.0
var _phase_fade: bool = false
var _after_one_shot: String = ""
var _resume_timer: Timer
var context_id := ""
var _stinger: AudioStreamPlayer
var _stinger_cue := ""
var _stinger_remaining := 0.0
var _stinger_duration := 0.0
var _stinger_after := ""
var _duck_gain := 1.0
var _reported_missing := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Scene files no longer own a second, legacy music stream.
	autoplay = false
	stop()
	stream = null
	_active = self
	_other = AudioStreamPlayer.new()
	_other.name = "Crossfade"
	_other.bus = bus
	add_child(_other)
	_stinger = AudioStreamPlayer.new()
	_stinger.name = "Stinger"
	_stinger.bus = bus
	add_child(_stinger)
	_stinger.finished.connect(cancel_stinger.bind(true))
	_resume_timer = Timer.new()
	_resume_timer.one_shot = true
	_resume_timer.ignore_time_scale = true
	add_child(_resume_timer)
	_resume_timer.timeout.connect(_finish_resume)
	finished.connect(_on_finished.bind(self))
	_other.finished.connect(_on_finished.bind(_other))
	if follow_battle_context:
		camp_handoff_ready = false
		get_parent().child_entered_tree.connect(_on_scene_child_entered)
		for child in get_parent().get_children():
			_on_scene_child_entered(child)
	else:
		if CATALOG.arrival_cue != "":
			initial_cue = CATALOG.arrival_cue
			CATALOG.arrival_cue = ""
			_after_one_shot = "camp_signal"
			camp_handoff_ready = false
		set_cue(initial_cue, 0.0)
		start_music(camp_handoff_position if initial_cue == "camp_signal" and camp_handoff_ready else 0.0)
		camp_handoff_ready = false
		_active_gain = 0.0
		_fade_duration = 0.35
		_fade_elapsed = 0.0
		_fade_from_gain = 0.0
	apply_saved_volume()

func _exit_tree() -> void:
	if not follow_battle_context and current_cue == "camp_signal" and _started:
		camp_handoff_position = get_saved_playback_position()
		camp_handoff_ready = true
	_cancel_resume()
	cancel_stinger()
	for player in [self, _other]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_encounters.clear()

func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if not follow_battle_context and current_cue == "camp_signal" and _active.playing and not paused_by_script:
		stored_playback_position = _active.get_playback_position()
	if follow_battle_context:
		_context_elapsed += real_delta
		if _context_elapsed >= CONTEXT_INTERVAL:
			_context_elapsed = 0.0
			refresh_context()
	if not paused_by_script and _stinger_remaining > 0.0:
		if _is_headless_runtime():
			_stinger_remaining = maxf(0.0, _stinger_remaining - real_delta)
			if _stinger_remaining <= 0.0: cancel_stinger(true)
		elif _stinger.playing:
			_stinger_remaining = maxf(0.0, _stinger_duration - _stinger.get_playback_position())
	_apply_gains()
	if paused_by_script or _fade_duration <= 0.0:
		return
	_fade_elapsed = minf(_fade_duration, _fade_elapsed + real_delta)
	var ratio := _fade_elapsed / _fade_duration
	# Correlated phase arrangements use complementary gains to avoid a level bump.
	_active_gain = ratio if _phase_fade else sin(ratio * PI * 0.5)
	_outgoing_gain = _fade_from_gain * (1.0 - ratio if _phase_fade else cos(ratio * PI * 0.5))
	_apply_gains()
	if ratio >= 1.0:
		if is_instance_valid(_outgoing):
			_outgoing.stop()
			_outgoing.stream = null
		_outgoing = null
		_fade_duration = 0.0

func _on_scene_child_entered(child: Node) -> void:
	if not child.has_signal("runtime_configured"):
		return
	var callback := _track_encounter.bind(child.get_instance_id())
	if not child.is_connected("runtime_configured", callback):
		child.connect("runtime_configured", callback)
	if bool(child.get("runtime_configuration_complete")):
		_track_encounter(child.get_instance_id())

func _track_encounter(instance_id: int) -> void:
	var enemy := instance_from_id(instance_id) as Node
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.get_parent() != get_parent():
		return
	if not bool(enemy.get("runtime_configuration_complete")) or not CATALOG.ENCOUNTERS.has(str(enemy.get("archetype_id"))):
		return
	if enemy in _encounters:
		refresh_context()
		return
	_encounters.append(enemy)
	enemy.tree_exiting.connect(_forget_encounter.bind(enemy), CONNECT_ONE_SHOT)
	refresh_context()

func _forget_encounter(enemy: Node) -> void:
	_encounters.erase(enemy)

func refresh_context() -> void:
	if not follow_battle_context:
		return
	var cue := CATALOG.battle_cue(get_parent().get_session_presentation(), _encounters)
	var terminal := CATALOG.is_one_shot(cue)
	set_cue(cue, 0.45 if terminal else 0.8 if CATALOG.same_phase_family(current_cue, cue) else 1.4)

func set_cue(cue: String, fade_seconds: float = 1.4) -> void:
	if cue == current_cue: return
	var resource_path := CATALOG.path(cue)
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		if not _reported_missing.has(cue):
			_reported_missing[cue] = true
			push_warning("Music cue unavailable: %s; retaining current bed or using legacy fallback" % cue)
		if not current_cue.is_empty(): return
		cue = "camp_signal"
		resource_path = CATALOG.path(cue)
	var next_stream := load(resource_path) as AudioStream
	if next_stream == null: return
	if CATALOG.is_one_shot(cue):
		paused_by_script = false
		_started = true
	if next_stream is AudioStreamOggVorbis:
		next_stream.loop = not CATALOG.is_one_shot(cue)
	var phase_change := CATALOG.same_phase_family(current_cue, cue)
	var position := get_saved_playback_position() if phase_change else 0.0
	_cancel_resume()
	var old := _active
	var old_gain := _active_gain
	old.stream_paused = paused_by_script
	_active = _other if old == self else self
	_active.stop()
	_active.stream = next_stream
	_active.stream_paused = paused_by_script
	current_cue = cue
	stored_playback_position = normalize_position(position, next_stream.get_length(), not CATALOG.is_one_shot(cue))
	_active_gain = 0.0 if _started and old.stream != null and fade_seconds > 0.0 else 1.0
	_outgoing = old
	_outgoing_gain = old_gain
	_fade_from_gain = old_gain
	_phase_fade = phase_change
	_fade_elapsed = 0.0
	_fade_duration = maxf(0.0, fade_seconds) if _active_gain == 0.0 else 0.0
	if _fade_duration <= 0.0:
		old.stop()
		old.stream = null
		_outgoing = null
	if _started:
		_play_from_position(stored_playback_position)
	_apply_gains()

func apply_saved_volume() -> void:
	_apply_gains()

func _apply_gains() -> void:
	var volume := 0.0 if load_music_muted() else clampf(load_music_volume(), 0.0, 1.0)
	if is_instance_valid(_active):
		_active.volume_db = linear_to_db(volume * _active_gain * _duck_gain) if volume * _active_gain * _duck_gain > 0.0 else MUTED_VOLUME_DB
	if is_instance_valid(_stinger):
		_stinger.volume_db = linear_to_db(volume * stinger_gain()) if volume > 0.0 else MUTED_VOLUME_DB
	if is_instance_valid(_outgoing):
		_outgoing.volume_db = linear_to_db(volume * _outgoing_gain * _duck_gain) if volume * _outgoing_gain * _duck_gain > 0.0 else MUTED_VOLUME_DB

func _on_finished(player: AudioStreamPlayer) -> void:
	if player != _active or not CATALOG.is_one_shot(current_cue):
		return
	stored_playback_position = player.stream.get_length()
	_started = false
	if _after_one_shot != "":
		var next := _after_one_shot
		_after_one_shot = ""
		set_cue(next, 0.0)
		start_music()

func get_saved_playback_position() -> float:
	if not paused_by_script and is_instance_valid(_active) and _active.playing:
		return _active.get_playback_position()
	return stored_playback_position

static func normalize_position(position: float, length: float, loops: bool) -> float:
	var safe := maxf(position, 0.0) if is_finite(position) else 0.0
	if length <= 0.0:
		return 0.0
	return fposmod(safe, length) if loops else minf(safe, length)

func restore_playback_position(position_seconds: float) -> void:
	refresh_context()
	_cancel_resume()
	for player in [self, _other]:
		if is_instance_valid(player):
			player.stop()
	if is_instance_valid(_outgoing):
		_outgoing.stream = null
	_outgoing = null
	_fade_duration = 0.0
	_active_gain = 1.0
	_apply_gains()
	paused_by_script = true
	_started = true
	stored_playback_position = normalize_position(position_seconds, _active.stream.get_length(), not CATALOG.is_one_shot(current_cue)) if _active.stream != null else maxf(0.0, position_seconds)

func start_music(position_seconds: float = 0.0) -> void:
	refresh_context()
	if _started and not paused_by_script and position_seconds <= 0.0:
		return
	_cancel_resume()
	_started = true
	paused_by_script = false
	stored_playback_position = normalize_position(position_seconds, _active.stream.get_length(), not CATALOG.is_one_shot(current_cue)) if _active.stream != null else 0.0
	_play_from_position(stored_playback_position)

func pause_music() -> void:
	refresh_context()
	if follow_battle_context and CATALOG.is_one_shot(current_cue): return
	_cancel_resume()
	stored_playback_position = get_saved_playback_position()
	paused_by_script = true
	for player in [self, _other, _stinger]:
		if is_instance_valid(player):
			player.stream_paused = true

func resume_music(delay_seconds: float = 0.0) -> void:
	refresh_context()
	_cancel_resume()
	if delay_seconds > 0.0:
		_resume_timer.start(delay_seconds)
	else:
		_finish_resume()

func _cancel_resume() -> void:
	resume_request_id += 1
	if is_instance_valid(_resume_timer):
		_resume_timer.stop()

func _finish_resume() -> void:
	_started = true
	paused_by_script = false
	if is_instance_valid(_stinger): _stinger.stream_paused = false
	if _active.playing:
		for player in [self, _other]:
			player.stream_paused = false
	else:
		_play_from_position(stored_playback_position)

func _play_from_position(position_seconds: float) -> void:
	if _is_headless_runtime() or _active.stream == null:
		return
	_active.play(position_seconds)
	_active.stream_paused = paused_by_script

func _is_headless_runtime() -> bool:
	return str(DisplayServer.get_name()).to_lower() == "headless"

static func load_music_volume() -> float:
	var config := preload("res://scripts/game_settings.gd")._get_config()

	return float(config.get_value(SETTINGS_SECTION, MUSIC_VOLUME_KEY, DEFAULT_VOLUME_LINEAR))

static func save_music_volume(saved_volume_linear: float) -> void:
	var config := preload("res://scripts/game_settings.gd")._get_config()
	config.set_value(SETTINGS_SECTION, MUSIC_VOLUME_KEY, clamp(saved_volume_linear, 0.0, 1.0))
	config.save(SETTINGS_PATH)

static func load_music_muted() -> bool:
	var config := preload("res://scripts/game_settings.gd")._get_config()

	return bool(config.get_value(SETTINGS_SECTION, MUSIC_MUTED_KEY, false))

static func save_music_muted(muted: bool) -> void:
	var config := preload("res://scripts/game_settings.gd")._get_config()
	config.set_value(SETTINGS_SECTION, MUSIC_MUTED_KEY, muted)
	config.save(SETTINGS_PATH)

## Independent one-shot overlay. Its timer shares pause ownership with both beds.
func play_stinger(cue: String, after_cue: String = "") -> bool:
	cancel_stinger()
	var resource_path := CATALOG.path(cue)
	if not CATALOG.is_one_shot(cue) or resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		push_warning("Stinger unavailable or not a one-shot: " + cue)
		if not after_cue.is_empty(): set_cue(after_cue, 0.6)
		return false
	var audio := load(resource_path) as AudioStream
	if audio == null: return false
	audio = audio.duplicate()
	if audio is AudioStreamOggVorbis: audio.loop = false
	_stinger.stream = audio
	_stinger_cue = cue
	_stinger_after = after_cue
	_stinger_duration = audio.get_length()
	_stinger_remaining = _stinger_duration
	_duck_gain = 0.32
	_stinger.stream_paused = paused_by_script
	_apply_gains()
	if not _is_headless_runtime():
		_stinger.play()
		_stinger.stream_paused = paused_by_script
	return true

func stinger_gain() -> float:
	return minf(1.0, _stinger_remaining / 0.22) if _stinger_remaining > 0.0 else 0.0

func cancel_stinger(complete: bool = false) -> void:
	var next := _stinger_after if complete else ""
	_stinger_after = ""
	_stinger_remaining = 0.0
	_stinger_cue = ""
	_duck_gain = 1.0
	if is_instance_valid(_stinger):
		_stinger.stop()
		_stinger.stream = null
	_apply_gains()
	if not next.is_empty(): set_cue(next, 0.6)

func capture_snapshot() -> Dictionary:
	return {"cue":current_cue, "position":get_saved_playback_position(), "paused":paused_by_script, "started":_started, "context":context_id}

func restore_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty(): return
	cancel_stinger()
	context_id = str(snapshot.get("context", ""))
	set_cue(str(snapshot.get("cue", "")), 0.0)
	restore_playback_position(float(snapshot.get("position", 0.0)))
	_started = bool(snapshot.get("started", true))
	paused_by_script = bool(snapshot.get("paused", false))
	if _started and not paused_by_script: resume_music()

func restart_cue(cue: String) -> void:
	cancel_stinger()
	set_cue(cue, 0.0)
	restore_playback_position(0.0)
	resume_music()
