extends RefCounted

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PERFORMANCE_MONITOR := preload("res://scripts/game/performance_monitor.gd")

const TRACE_PATH := "user://performance_trace_latest.jsonl"
const SETTINGS_REFRESH_INTERVAL := 0.25
const PERIODIC_SAMPLE_INTERVAL := 0.50
const SLOW_FRAME_MS := 33.4
const SLOW_FRAME_LOG_COOLDOWN := 0.10

static var trace_file: FileAccess
static var active: bool = false
static var settings_refresh_elapsed: float = SETTINGS_REFRESH_INTERVAL
static var periodic_elapsed: float = 0.0
static var slow_log_elapsed: float = SLOW_FRAME_LOG_COOLDOWN
static var sample_index: int = 0
static var session_id: String = ""


static func tick(main: Node, delta: float) -> void:
	if main == null:
		return
	var safe_delta: float = max(0.0, delta)
	settings_refresh_elapsed += safe_delta
	if settings_refresh_elapsed >= SETTINGS_REFRESH_INTERVAL:
		settings_refresh_elapsed = 0.0
		var should_enable := GAME_SETTINGS.load_performance_trace_enabled()
		if should_enable and not active:
			start(main)
		elif not should_enable and active:
			stop("disabled")

	if not active:
		return

	periodic_elapsed += safe_delta
	slow_log_elapsed += safe_delta
	var frame_ms := safe_delta * 1000.0
	var should_log_slow := frame_ms >= SLOW_FRAME_MS and slow_log_elapsed >= SLOW_FRAME_LOG_COOLDOWN
	var should_log_periodic := periodic_elapsed >= PERIODIC_SAMPLE_INTERVAL
	if not should_log_slow and not should_log_periodic:
		return

	var reason := "slow_frame" if should_log_slow else "periodic"
	if should_log_periodic:
		periodic_elapsed = 0.0
	if should_log_slow:
		slow_log_elapsed = 0.0
	_write_sample(main, safe_delta, reason)


static func start(main: Node) -> void:
	stop("restart")
	trace_file = FileAccess.open(TRACE_PATH, FileAccess.WRITE)
	if trace_file == null:
		active = false
		return
	active = true
	periodic_elapsed = 0.0
	slow_log_elapsed = SLOW_FRAME_LOG_COOLDOWN
	sample_index = 0
	session_id = "%d_%d" % [Time.get_unix_time_from_system(), Engine.get_process_frames()]
	_write_line({
		"event": "session_start",
		"session_id": session_id,
		"datetime": Time.get_datetime_string_from_system(),
		"time_msec": Time.get_ticks_msec(),
		"log_path": ProjectSettings.globalize_path(TRACE_PATH),
		"slow_frame_ms": SLOW_FRAME_MS,
		"periodic_sample_interval": PERIODIC_SAMPLE_INTERVAL,
		"scene": main.scene_file_path if main != null else ""
	})


static func stop(reason: String = "stop") -> void:
	if trace_file != null:
		_write_line({
			"event": "session_stop",
			"session_id": session_id,
			"reason": reason,
			"datetime": Time.get_datetime_string_from_system(),
			"time_msec": Time.get_ticks_msec(),
			"samples": sample_index
		})
		trace_file = null
	active = false
	session_id = ""
	periodic_elapsed = 0.0
	slow_log_elapsed = SLOW_FRAME_LOG_COOLDOWN


static func _write_sample(main: Node, delta: float, reason: String) -> void:
	if trace_file == null:
		active = false
		return
	if not main.is_inside_tree():
		return
	var tree := main.get_tree()
	var metrics := PERFORMANCE_MONITOR.collect_metrics(main)
	var frame_counters: Dictionary = metrics.get("frame_counters", {})
	var current_frame_counters: Dictionary = frame_counters.get("current_frame", {})
	var peak_counters: Dictionary = frame_counters.get("peak", {})
	var frame_time: Dictionary = metrics.get("frame_time", {})
	var is_paused := tree.paused if tree != null else false
	_write_line({
		"event": "sample",
		"session_id": session_id,
		"sample": sample_index,
		"reason": reason,
		"datetime": Time.get_datetime_string_from_system(),
		"time_msec": Time.get_ticks_msec(),
		"process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames(),
		"delta_ms": delta * 1000.0,
		"fps": Engine.get_frames_per_second(),
		"paused": is_paused,
		"survival_time": float(main.get("survival_time")) if main.get("survival_time") != null else 0.0,
		"difficulty_id": str(main.get("difficulty_id")) if main.get("difficulty_id") != null else "",
		"counts": _build_counts(metrics),
		"frame_time": frame_time,
		"counters_current": current_frame_counters,
		"counters_peak": peak_counters,
			"flags": metrics.get("performance_flags", {}),
			"settings": {
				"autosave_interval": float(main.get("autosave_interval")) if main.get("autosave_interval") != null else 0.0,
				"performance_trace_enabled": true
			}
		})
	sample_index += 1


static func _build_counts(metrics: Dictionary) -> Dictionary:
	return {
		"enemies": int(metrics.get("enemies", 0)),
		"pending_enemy_spawns": int(metrics.get("pending_enemy_spawns", 0)),
		"player_projectiles": int(metrics.get("player_projectiles", 0)),
		"batched_projectiles": int(metrics.get("batched_projectiles", 0)),
		"enemy_projectiles": int(metrics.get("enemy_projectiles", 0)),
		"exp_gems": int(metrics.get("exp_gems", 0)),
		"heart_pickups": int(metrics.get("heart_pickups", 0)),
		"temporary_effects": int(metrics.get("temporary_effects", 0)),
		"total_nodes": int(metrics.get("total_nodes", 0))
	}


static func _write_line(payload: Dictionary) -> void:
	if trace_file == null:
		return
	trace_file.store_line(JSON.stringify(payload))
	trace_file.flush()
