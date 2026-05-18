extends RefCounted

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const RUN_SAVE_RUNTIME_FLOW := preload("res://scripts/game/run_save_runtime_flow.gd")

static func save_run_state(main: Node) -> void:
	if main.game_over or main.player == null or DEVELOPER_MODE.should_disable_save():
		return

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

	SAVE_MANAGER.save_run(save_data)

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
