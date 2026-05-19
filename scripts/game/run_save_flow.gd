extends RefCounted

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const RUN_SAVE_RUNTIME_FLOW := preload("res://scripts/game/run_save_runtime_flow.gd")
const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")

static func save_run_state(main: Node) -> void:
	if main.game_over or main.player == null or DEVELOPER_MODE.should_disable_save():
		return
	var save_start_usec: int = Time.get_ticks_usec()
	PERFORMANCE_RECORDER.begin_scope("save_run_ms")

	var game_bgm = main._get_game_bgm()
	var music_position: float = 0.0
	if game_bgm != null and game_bgm.has_method("get_saved_playback_position"):
		music_position = float(game_bgm.get_saved_playback_position())

	var save_data: Dictionary = {
		"survival_time": main.survival_time,
		"music_position": music_position,
		"spawned_elite_count": main.spawned_elite_count,
		"spawned_small_boss_count": main.spawned_small_boss_count,
		"boss_spawned": main.boss_spawned,
		"defeated_boss_count": main.defeated_boss_count,
		"player": main.player.get_save_data(),
		"enemies": [],
		"enemy_projectiles": [],
		"gems": [],
		"heart_pickups": []
	}

	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "enemies", "enemies")
	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "enemy_projectiles", "enemy_projectiles")
	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "gems", "exp_gems")
	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "heart_pickups", "heart_pickups")

	var payload_chars: int = int(SAVE_MANAGER.save_run(save_data))
	PERFORMANCE_RECORDER.end_scope("save_run_ms")
	_record_save_probe_counters(save_data, payload_chars, Time.get_ticks_usec() - save_start_usec)

static func _record_save_probe_counters(save_data: Dictionary, payload_chars: int, elapsed_usec: int) -> void:
	PERFORMANCE_COUNTERS.add("save_run_calls", 1)
	PERFORMANCE_COUNTERS.add("save_run_ms_x10", int(round(float(max(0, elapsed_usec)) / 100.0)))
	PERFORMANCE_COUNTERS.add("save_payload_kb", int(ceil(float(max(0, payload_chars)) / 1024.0)))
	PERFORMANCE_COUNTERS.add("save_enemies", (save_data.get("enemies", []) as Array).size())
	PERFORMANCE_COUNTERS.add("save_enemy_projectiles", (save_data.get("enemy_projectiles", []) as Array).size())
	PERFORMANCE_COUNTERS.add("save_gems", (save_data.get("gems", []) as Array).size())
	PERFORMANCE_COUNTERS.add("save_hearts", (save_data.get("heart_pickups", []) as Array).size())

static func _get_runtime_or_group_nodes(main: Node, group_name: String) -> Array:
	return RUN_SAVE_RUNTIME_FLOW.get_runtime_or_group_nodes(main, group_name)

static func load_saved_run(main: Node) -> bool:
	if main._is_developer_mode():
		return false
	var save_data := SAVE_MANAGER.load_run()
	if save_data.is_empty():
		return false

	main.survival_time = float(save_data.get("survival_time", 0.0))
	main.autosave_elapsed = 0.0
	main.spawned_elite_count = int(save_data.get("spawned_elite_count", 0))
	main.spawned_small_boss_count = int(save_data.get("spawned_small_boss_count", 0))
	main.boss_spawned = bool(save_data.get("boss_spawned", false))
	main.defeated_boss_count = int(save_data.get("defeated_boss_count", 0))
	main.boss_enemy = null

	main.player.apply_save_data(save_data.get("player", {}))
	_restore_enemies(main, save_data.get("enemies", []))
	_restore_enemy_projectiles(main, save_data.get("enemy_projectiles", []))
	_restore_gems(main, save_data.get("gems", []))
	_restore_heart_pickups(main, save_data.get("heart_pickups", []))

	var game_bgm = main._get_game_bgm()
	if game_bgm != null and game_bgm.has_method("restore_playback_position"):
		game_bgm.restore_playback_position(float(save_data.get("music_position", 0.0)))

	main._refresh_hud()
	save_run_state(main)
	return true

static func _restore_enemies(main: Node, enemies_data: Array) -> void:
	RUN_SAVE_RUNTIME_FLOW.restore_enemies(main, enemies_data)

static func _restore_enemy_projectiles(main: Node, projectiles_data: Array) -> void:
	RUN_SAVE_RUNTIME_FLOW.restore_enemy_projectiles(main, projectiles_data)

static func _restore_gems(main: Node, gems_data: Array) -> void:
	RUN_SAVE_RUNTIME_FLOW.restore_gems(main, gems_data)

static func _restore_heart_pickups(main: Node, hearts_data: Array) -> void:
	RUN_SAVE_RUNTIME_FLOW.restore_heart_pickups(main, hearts_data)
